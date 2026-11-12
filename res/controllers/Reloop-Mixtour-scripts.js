/*
Reloop Mixtour controller script
*/

// eslint-disable-next-line no-var
var ReloopMixtour = {};

// midi-components-0.0.js does not prevent re-connecting some already connected
// component. The following mixin and the local classes solve this problem.
// Additionally some shutdown method added to all local components.
ReloopMixtour.controlledConnections = (Base) => class extends Base {
    connect() {
        if (this.connections[0] === undefined) {
            super.connect();
        };
    };
    disconnect() {
        super.disconnect();
        this.connections = [];
    };
    shutdown() {
        if (super.shutdown !== undefined) { super.shutdown(); }
        this.disconnect();
    };
};
ReloopMixtour.Button = class extends ReloopMixtour.controlledConnections(components.Button) {};
ReloopMixtour.PlayButton = class extends ReloopMixtour.controlledConnections(components.PlayButton) {};
ReloopMixtour.CueButton = class extends ReloopMixtour.controlledConnections(components.CueButton) {};
ReloopMixtour.HotcueButton = class extends ReloopMixtour.controlledConnections(components.HotcueButton) {};
ReloopMixtour.Pot = class extends ReloopMixtour.controlledConnections(components.Pot) {};
ReloopMixtour.Component = class extends ReloopMixtour.controlledConnections(components.Component) {};

// Cutlab
ReloopMixtour.rollSizes = [0.0625, 0.125, 0.25, 0.5];
// backspin, brake, trans 1/8, echo out
ReloopMixtour.shiftFxCodes = [1, 2, 5, 4];

ReloopMixtour.init = function() {
    // initialize Mixxx with current values on control surface
    const ControllerStatusSysex = [0xF0, 0x26, 0x2D, 0x65, 0x22, 0xF7];
    midi.sendSysexMsg(ControllerStatusSysex, ControllerStatusSysex.length);

    this.syncGroupSelection = function(elem, type, group) {
        if (engine.getValue("[Skin]", `highlight_${type}_${group}`) && elem.currentDeck !== group) {
            elem.setCurrentDeck(group);
        }
    };

    this.reSelectDecks = function() {
        this.syncGroupSelection(this.decks.right, "deck", "[Channel4]");
        this.syncGroupSelection(this.decks.left, "deck", "[Channel3]");
        this.syncGroupSelection(this.decks.right, "deck", "[Channel2]");
        this.syncGroupSelection(this.decks.left, "deck", "[Channel1]");
    };

    this.reSelectMixer = function() {
        this.syncGroupSelection(this.mixer.right, "mixer", "[Channel4]");
        this.syncGroupSelection(this.mixer.left, "mixer", "[Channel3]");
        this.syncGroupSelection(this.mixer.right, "mixer", "[Channel2]");
        this.syncGroupSelection(this.mixer.left, "mixer", "[Channel1]");
    };

    this.connectFourDeckControl = function() {
        for (let i = 1; i <= 4; i++) {
            this[`highlightDeckConnection_[Channel${i}]`] = engine.makeConnection("[Skin]", `highlight_deck_[Channel${i}]`, function(_value, _group, _control) {
                ReloopMixtour.reSelectDecks();
            });
            this[`highlightMixerConnection_[Channel${i}]`] = engine.makeConnection("[Skin]", `highlight_mixer_[Channel${i}]`, function(_value, _group, _control) {
                ReloopMixtour.reSelectMixer();
            });
        }
    };

    this.disconnectFourDeckControl = function() {
        for (let i = 1; i <= 4; i++) {
            if (this[`highlightDeckConnection_[Channel${i}]`] !== undefined) {
                this[`highlightDeckConnection_[Channel${i}]`].disconnect();
            };
            if (this[`highlightMixerConnection_[Channel${i}]`] !== undefined) {
                this[`highlightMixerConnection_[Channel${i}]`].disconnect();
            };
        };
    };

    const leftDeckConfig = parseInt(engine.getSetting("leftControls"));
    const rightDeckConfig = parseInt(engine.getSetting("rightControls"));
    this.decks = new components.ComponentContainer({
        left: new ReloopMixtour.Deck(leftDeckConfig || [1, 3], 0),
        right: new ReloopMixtour.Deck(rightDeckConfig || [2, 4], 1),
    });
    this.mixer = new components.ComponentContainer({
        left: new ReloopMixtour.Mixer(leftDeckConfig || [1, 3], 0),
        right: new ReloopMixtour.Mixer(rightDeckConfig || [2, 4], 1),
    });
    if (!leftDeckConfig || !rightDeckConfig) {
        this.connectFourDeckControl();
    }

    this.shutdown = function() {
        this.decks.shutdown();
        this.mixer.shutdown();
        this.disconnectFourDeckControl();
        this.backBtn.shutdown();
    };

    // there is one shift button, map it to the decks
    this.shiftButton = new ReloopMixtour.Button({
        input: function(_channel, _control, value, _status, _g) {
            if (value) {
                ReloopMixtour.decks.shift();
                ReloopMixtour.mixer.shift();
            } else {
                ReloopMixtour.decks.unshift();
                ReloopMixtour.mixer.unshift();
            }
        },
    });

    this.backBtn = new ReloopMixtour.Button({
        midi: [0x90, 0x08],
        group: "[Skin]",
        key: "show_maximized_library",
        type: components.Button.prototype.types.toggle,
    });

    // the rotarySelector only works if mixxx windows is focused, don't be surprised :)
    this.rotarySelector = new ReloopMixtour.Button({
        group: "[Library]",
        input: function(channel, control, value, status, group) {
            if (value === 0x01) {
                this.inKey = (control < 0x40)?"MoveDown":"MoveRight";
            } else {
                this.inKey = (control < 0x40)?"MoveUp":"MoveLeft";
            }
            components.Button.prototype.input.call(this, channel, control, 0x7F, status, group);
        },
        inputPress: function(_channel, control, value, _status, _group) {
            // Cutlab: with SHIFT the knob moves to the suggested tracks
            if (control >= 0x40) {
                if (value) {
                    engine.setValue("[Cutlab]", "browse_suggestions", engine.getValue("[Cutlab]", "browse_suggestions") + 1);
                }
                return;
            }
            // Cutlab: a press opens the library, goes into the picked folder
            // or picks in a menu; held half a second it opens the menu of
            // the picked track (queue, playlists, crates). It acts on
            // release, to tell them apart.
            if (value) {
                ReloopMixtour.browsePressedAt = Date.now();
                return;
            }
            const held = ReloopMixtour.browsePressedAt > 0 && Date.now() - ReloopMixtour.browsePressedAt >= 500;
            ReloopMixtour.browsePressedAt = 0;
            const key = held ? "track_menu" : "browse_press";
            engine.setValue("[Cutlab]", key, engine.getValue("[Cutlab]", key) + 1);
        },
    });
};

ReloopMixtour.Deck = class extends components.Deck {
    constructor(deckNumbers, midiChannel) {
        super(deckNumbers);

        const theDeck = this;

        this.load = new ReloopMixtour.Button({
            midi: [0x90 + midiChannel, 0x02],
            key: "LoadSelectedTrack",
            shiftKey: midiChannel?"MoveRight":"MoveLeft",
            shiftOffset: 0x40,
            unshift: function() {
                this.inKey = "LoadSelectedTrack";
                this.group = theDeck.currentDeck;
            },
            shift: function() {
                this.inKey = this.shiftKey;
                this.group = "[Library]";
            },
        });

        this.pfl = new ReloopMixtour.Button({
            midi: [0x90 + midiChannel, 0x03],
            key: "pfl",
            shiftOffset: 0x40,
            type: components.Button.prototype.types.toggle,
            unshift: function() {
                this.inKey = "pfl";
                this.group = theDeck.currentDeck;
            },
            shift: function() {
                this.inKey = "LoadSelectedTrackAndPlay";
                this.group = "[PreviewDeck1]";
            },
        });

        this.loop = new ReloopMixtour.Button({
            midi: [0x90 + midiChannel, 0x09],
            inKey: "beatloop_activate",
            outKey: "loop_enabled",
            unshift: function() {
                this.inKey = "beatloop_activate";
            },
            shift: function() {
                this.inKey = "loop_halve";
            },
        });

        this.beatSync = new ReloopMixtour.Button({
            midi: [0x90 + midiChannel, 0x0A],
            type: components.Button.prototype.types.toggle,
            key: "sync_enabled",
            unshift: function() {
                this.inKey = "sync_enabled";
            },
            shift: function() {
                this.inKey = "loop_double";
            },
        });

        this.play = new ReloopMixtour.PlayButton({
            midi: [0x90 + midiChannel, 0x0C],
        });

        this.cue = new ReloopMixtour.CueButton({
            midi: [0x90 + midiChannel, 0x0B],
        });

        for (let i = 1; i <= 4; i++) {
            this[`hotcue${i}`] = new ReloopMixtour.HotcueButton({
                midi: [0x90 + midiChannel, 0x0C + i],
                number: i,
                on: 0x2B,
            });
            // Cutlab: LOOP held + hot cue = beat roll (1/16, 1/8, 1/4, 1/2),
            // SHIFT + hot cue = the effects of the Cutlab FX pad (backspin,
            // brake, trans 1/8, echo out), see OneShots.qml
            this[`hotcue${i}`].input = function(channel, control, value, status, group) {
                const deckNumber = parseInt(theDeck.currentDeck.replace(/\D/g, ""));
                if (theDeck.loopHeld) {
                    theDeck.loopUsed = true;
                    engine.setValue(theDeck.currentDeck,
                        `beatlooproll_${ReloopMixtour.rollSizes[i - 1]}_activate`, value > 0 ? 1 : 0);
                    return;
                }
                if (control >= 0x40) {
                    engine.setValue("[Cutlab]", `fx_deck${deckNumber}`,
                        value > 0 ? ReloopMixtour.shiftFxCodes[i - 1] : 0);
                    return;
                }
                components.HotcueButton.prototype.input.call(this, channel, control, value, status, group);
            };
        };
        // Cutlab: LOOP held + CUE turns letsktch! on or off on the deck
        this.cue.input = function(channel, control, value, status, group) {
            if (theDeck.loopHeld && control < 0x40) {
                theDeck.loopUsed = true;
                const deckNumber = parseInt(theDeck.currentDeck.replace(/\D/g, ""));
                if (value > 0 && deckNumber <= 2) {
                    engine.setValue("[Cutlab]", `letsktch${deckNumber}`,
                        (engine.getValue("[Cutlab]", `letsktch${deckNumber}`) + 1) % 1000);
                }
                return;
            }
            components.CueButton.prototype.input.call(this, channel, control, value, status, group);
        };
        // LOOP sets a loop when released without a hot cue pressed meanwhile
        this.loop.input = function(channel, control, value, status, group) {
            if (control >= 0x40) {
                components.Button.prototype.input.call(this, channel, control, value, status, group);
                return;
            }
            if (value > 0) {
                theDeck.loopHeld = true;
                theDeck.loopUsed = false;
                return;
            }
            theDeck.loopHeld = false;
            if (!theDeck.loopUsed) {
                components.Button.prototype.input.call(this, channel, control, 0x7F, status, group);
                components.Button.prototype.input.call(this, channel, control, 0x00, status, group);
            }
        };

        this.forEachComponent(function(component) {
            if (component.group === undefined) {
                component.group = this.currentDeck;
            };
            if (component.shiftOffset === 0) {
                component.shiftOffset = 0x3F;
            };
            component.shiftControl = true;
            component.sendShifted = true;
            if (component.on === 127) { // value not changed from default
                component.on = 0x01;    // color for most buttons is green
            }
        });
    }
};

ReloopMixtour.Mixer = class extends components.Deck {
    constructor(deckNumbers, midiChannel) {
        super(deckNumbers);

        const theMixer = this;

        this.gain = new ReloopMixtour.Pot({
            key: "pregain",
        });

        // Cutlab 1.29: the FILTER knob and the FX button are apart
        //  - FILTER: only the filter (the Quick Effect, Filter preset),
        //    always, with FX on or off. Centre does nothing, left low pass,
        //    right high pass. Read as it is (no soft takeover): no jumps and
        //    never stuck.
        //  - FX: only turns on or off the effect picked on the FX pad of the
        //    deck; its LED shows it. How much and which effect is set on the
        //    screen.
        //  - SHIFT + FX: the next effect of the FX pad
        const rackOf = () => `[QuickEffectRack1_${theMixer.currentDeck}]`;
        const deckNumber = () => parseInt(theMixer.currentDeck.replace(/\D/g, ""));
        // Only decks A and B have the Cutlab FX pad
        const hasFx = () => deckNumber() <= 2;
        for (const n of [].concat(deckNumbers)) {
            const rack = `[QuickEffectRack1_[Channel${n}]]`;
            engine.softTakeover(rack, "super1", false);
            // An older mapping could leave an effect in the Quick Effect:
            // back to the Filter, on
            if (engine.getValue(rack, "loaded_chain_preset") !== 1) {
                engine.setValue(rack, "loaded_chain_preset", 1);
            }
            engine.setValue(rack, "enabled", 1);
            // 1.25-1.28 dosed the effect from the knob: not any more
            if (n <= 2) {
                engine.setValue("[Cutlab]", `fx_amount${n}`, -1);
            }
        }

        this.fxKnob = new ReloopMixtour.Pot({
            inKey: "super1",
            input: function(_channel, _control, value, _status, _group) {
                engine.setValue(rackOf(), "super1", value / 0x7F);
            },
            connect: function() {},
            output: function() {},
        });

        this.effect = new ReloopMixtour.Button({
            midi: [0x90 + midiChannel, 0x01],
            shiftOffset: 0x40,
            group: "[Cutlab]",
            // The LED follows fx_on of the deck (connect below); the key only
            // has to be set so the component connects
            outKey: "fx_on",
            input: function(_channel, control, value, _status, _group) {
                if (!value || !hasFx()) {
                    return;
                }
                const deck = deckNumber();
                if (control >= this.shiftOffset) {
                    // SHIFT: the next effect (it keeps playing if on)
                    engine.setValue("[Cutlab]", `fx_next${deck}`,
                        (engine.getValue("[Cutlab]", `fx_next${deck}`) + 1) % 1000);
                    return;
                }
                const on = engine.getValue("[Cutlab]", `fx_on${deck}`) > 0;
                engine.setValue("[Cutlab]", `fx_on${deck}`, on ? 0 : 1);
            },
            output: function(value) {
                this.send(value > 0 ? this.on : this.off);
            },
            connect: function() {
                if (this.connections[0] === undefined && hasFx()) {
                    this.connections.push(engine.makeConnection("[Cutlab]", `fx_on${deckNumber()}`, this.output.bind(this)));
                }
            },
        });

        this.highEq = new ReloopMixtour.Pot({
            key: "parameter3",
            group: `[EqualizerRack1_${theMixer.currentDeck}_Effect1]`,
        });

        this.midEq = new ReloopMixtour.Pot({
            key: "parameter2",
            group: `[EqualizerRack1_${theMixer.currentDeck}_Effect1]`,
        });

        this.lowEq = new ReloopMixtour.Pot({
            key: "parameter1",
            group: `[EqualizerRack1_${theMixer.currentDeck}_Effect1]`,
        });

        this.volumeFader = new ReloopMixtour.Pot({
            inKey: "volume",
        });

        this.faderStart = new ReloopMixtour.Button({
            key: "cue_gotoandplay",
        });

        this.faderStop = new ReloopMixtour.Button({
            key: "cue_gotoandstop",
        });

        this.pflMeter = new ReloopMixtour.Component({
            midi: [0x90 + midiChannel, 0x11],
            key: "vu_meter",
            max: 0x68,
            disconnect: function() {
                components.Component.prototype.disconnect.call(this);
                this.output(0);
            },
        });

        this.masterMeter = new ReloopMixtour.Component({
            midi: [0x90 + midiChannel, 0x12],
            key: (this.currentDeck === "[Channel1]" || this.currentDeck === "[Channel3]")?"vu_meter_left":"vu_meter_right",
            group: "[Main]",
            max: 0x68
        });

        // Lit only while the filter is off centre
        this.fxIndicator = new ReloopMixtour.Component({
            midi: [0x90 + midiChannel, 0x00],
            outKey: "super1",
            outValueScale() {
                return Math.abs(0.5 - engine.getValue(rackOf(), "super1")) > 0.01 ? 0x7F : 0x00;
            },
            connect: function() {
                if (this.connections[0] === undefined) {
                    this.connections.push(engine.makeConnection(rackOf(), "super1", this.output.bind(this)));
                }
            },
        });

        this.forEachComponent(function(component) {
            if (component.group === undefined) {
                component.group = this.currentDeck;
            };
            if (component.shiftOffset === 0) {  // if value not changed from default
                component.shiftOffset = 0x3F;   // offset for most buttons is 0x3F
            };
            component.shiftControl = true;
            component.sendShifted = true;
            if (component.on === 0x7F) {        // if value not changed from default
                component.on = 0x01;            // color for most buttons is green
            }
        });
    }
};
