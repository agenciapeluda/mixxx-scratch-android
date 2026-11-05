import Mixxx 1.0 as Mixxx
import QtQuick

// letsktch!: scratch the voice of a track over its own beat, on one deck.
// A deck has one needle, so the track is split in two:
//  - the deck you play (A or B) keeps only the voice, in a loop of 4 bars:
//    the record, the jog or the waveform under your hand move the voice
//  - a hidden deck (deck 3) plays the same 4 bars without the voice, at the
//    same tempo and in the middle of the crossfader: the beat keeps going
//    while you cut the voice with the crossfader
// Only for tracks split in stems (with a vocals stem). Off, the deck plays
// the whole track again and the hidden deck is emptied.
Item {
    id: root

    // The deck in letsktch!, "" when off
    property string group: ""
    readonly property bool active: root.group !== ""
    // Still setting up: the screen says "armando…"
    readonly property bool busy: setup.running
    // What it is doing now, for the screen
    readonly property string stepText: [qsTr("leyendo los stems"), qsTr("armando el loop"), qsTr("cargando el beat en el deck oculto"), qsTr("separando el beat"), qsTr("sincronizando")][Math.max(0, setup.stage + 1)] || ""
    readonly property string helper: "[Channel3]"
    // The loop was made here (and is removed when it stops)
    property bool madeLoop: false
    property real previousLoopSize: 4

    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group !== "" ? root.group : "[Channel1]")
    readonly property var track: root.player ? root.player.currentTrack : null
    // Looked up when it starts: the hidden deck may not exist yet when the
    // screen opens
    property var helperPlayer: null
    readonly property var helperTrack: root.helperPlayer ? root.helperPlayer.currentTrack : null

    signal failed(string text)

    function toggle(group) {
        if (root.active) {
            const same = root.group === group;
            root.stop();
            if (same) {
                return;
            }
        }
        root.start(group);
    }

    function start(group) {
        const player = Mixxx.PlayerManager.getPlayer(group);
        if (!player || !player.currentTrack) {
            root.failed(qsTr("letsktch!: cargá un tema en el deck primero."));
            return;
        }
        root.group = group;
        root.madeLoop = false;
        setup.tries = 0;
        setup.stage = -1;
        setup.start();
    }

    function fail(text) {
        setup.stop();
        root.stop();
        root.failed(text);
    }

    function stop() {
        if (!root.active) {
            return;
        }
        setup.stop();
        mainStems.muteAllBut("");
        if (root.madeLoop && main.loopEnabled.value > 0) {
            main.reloop.value = 1;
            main.reloop.value = 0;
            main.loopSize.value = root.previousLoopSize;
        }
        root.madeLoop = false;
        helperDeck.play.value = 0;
        if (root.helperPlayer) {
            helperDeck.eject.value = 1;
            helperDeck.eject.value = 0;
        }
        root.group = "";
    }

    // Step by step, each with its own time: the stems of the deck, the loop
    // of the deck, the track on the hidden deck (a stem file takes long on a
    // phone), its stems, and the same loop, place and tempo there
    Timer {
        id: setup

        property int tries: 0
        property int stage: 0

        function next(stage) {
            setup.stage = stage;
            setup.tries = 0;
        }

        interval: 120
        repeat: true
        onTriggered: {
            ++tries;
            if (stage === -1) {
                // The stems of the deck: up to 6 s after a fresh load
                if (mainStems.stemCount === 0 && tries < 50) {
                    return;
                }
                if (mainStems.stemCount === 0 || !mainStems.has("Vocals")) {
                    root.fail(qsTr("letsktch! necesita el tema separado en stems, con la voz aparte. Separalo desde Stems."));
                    return;
                }
                // 4 bars from where it is, unless a loop already runs
                if (main.loopEnabled.value <= 0) {
                    root.previousLoopSize = main.loopSize.value;
                    main.loopSize.value = 16;
                    main.loopActivate.value = 1;
                    main.loopActivate.value = 0;
                    root.madeLoop = true;
                }
                next(0);
                return;
            }
            if (stage === 0) {
                if (main.loopEnabled.value <= 0 || main.loopEnd.value <= main.loopStart.value) {
                    if (tries > 40) {
                        root.fail(qsTr("letsktch! no pudo armar el loop en el deck (paso 1 de 3). ¿Tiene grilla de tiempos el tema?"));
                    }
                    return;
                }
                mainStems.muteAllBut("Vocals");
                if (!root.helperPlayer) {
                    root.helperPlayer = Mixxx.PlayerManager.getPlayer(root.helper);
                }
                if (!root.helperPlayer) {
                    // The hidden deck is created with 4 decks
                    numDecks.value = Math.max(numDecks.value, 4);
                    if (tries > 40) {
                        root.fail(qsTr("letsktch! no encontró el deck oculto (paso 2 de 3). Cerrá y abrí Cutlab."));
                    }
                    return;
                }
                const url = root.track ? root.track.trackLocationUrl : "";
                if (!(root.helperTrack && root.helperTrack.trackLocationUrl.toString() === url.toString())) {
                    root.helperPlayer.loadTrackFromLocationUrl(url, false);
                }
                next(1);
                return;
            }
            if (stage === 1) {
                // Up to 45 s for the track on the hidden deck
                if (!root.track || !root.helperTrack || helperDeck.samples.value <= 0 || root.helperTrack.trackLocationUrl.toString() !== root.track.trackLocationUrl.toString()) {
                    if (tries > 375) {
                        root.fail(qsTr("letsktch! no pudo cargar el beat en el deck oculto (paso 2 de 3). Probá de nuevo."));
                    }
                    return;
                }
                next(2);
                return;
            }
            if (stage === 2) {
                // Up to 10 s for its stems
                if (!helperStems.has("Vocals")) {
                    if (tries > 85) {
                        root.fail(qsTr("letsktch! no pudo sacar la voz del beat (paso 3 de 3). Probá de nuevo."));
                    }
                    return;
                }
                next(3);
                return;
            }
            // The beat: same loop, place, tempo and level, voice muted,
            // in the middle of the crossfader
            helperDeck.loopStart.value = main.loopStart.value;
            helperDeck.loopEnd.value = main.loopEnd.value;
            if (helperDeck.loopEnabled.value <= 0) {
                helperDeck.reloop.value = 1;
                helperDeck.reloop.value = 0;
            }
            helperDeck.position.value = main.position.value;
            helperDeck.rateRange.value = main.rateRange.value;
            helperDeck.rate.value = main.rate.value;
            helperDeck.keylock.value = main.keylock.value;
            helperDeck.orientation.value = 1;
            helperDeck.volume.value = main.volume.value;
            helperDeck.pfl.value = 0;
            helperStems.muteAllBut("!Vocals");
            helperDeck.play.value = main.play.value > 0 ? 1 : 0;
            setup.stage = 4;
            stop();
        }
    }

    Mixxx.ControlProxy {
        id: numDecks

        group: "[App]"
        key: "num_decks"
    }

    // While on, the beat follows the deck: play, pitch fader and volume
    Connections {
        target: root.active && setup.stage === 4 && !setup.running ? main.play : null
        function onValueChanged() {
            helperDeck.play.value = main.play.value > 0 ? 1 : 0;
        }
    }
    Connections {
        target: root.active && !setup.running ? main.rate : null
        function onValueChanged() {
            helperDeck.rate.value = main.rate.value;
        }
    }
    Connections {
        target: root.active && !setup.running ? main.volume : null
        function onValueChanged() {
            helperDeck.volume.value = main.volume.value;
        }
    }
    // A new track on the deck ends it
    Connections {
        target: root.active ? main.loaded : null
        function onValueChanged() {
            root.stop();
        }
    }

    component DeckControls: Item {
        id: deck

        required property string group
        property alias play: playProxy
        property alias position: positionProxy
        property alias samples: samplesProxy
        property alias loopEnabled: loopEnabledProxy
        property alias loopStart: loopStartProxy
        property alias loopEnd: loopEndProxy
        property alias loopSize: loopSizeProxy
        property alias loopActivate: loopActivateProxy
        property alias reloop: reloopProxy
        property alias rate: rateProxy
        property alias rateRange: rateRangeProxy
        property alias keylock: keylockProxy
        property alias orientation: orientationProxy
        property alias volume: volumeProxy
        property alias pfl: pflProxy
        property alias eject: ejectProxy
        property alias loaded: loadedProxy

        Mixxx.ControlProxy {
            id: playProxy

            group: deck.group
            key: "play"
        }
        Mixxx.ControlProxy {
            id: positionProxy

            group: deck.group
            key: "playposition"
        }
        Mixxx.ControlProxy {
            id: samplesProxy

            group: deck.group
            key: "track_samples"
        }
        Mixxx.ControlProxy {
            id: loopEnabledProxy

            group: deck.group
            key: "loop_enabled"
        }
        Mixxx.ControlProxy {
            id: loopStartProxy

            group: deck.group
            key: "loop_start_position"
        }
        Mixxx.ControlProxy {
            id: loopEndProxy

            group: deck.group
            key: "loop_end_position"
        }
        Mixxx.ControlProxy {
            id: loopSizeProxy

            group: deck.group
            key: "beatloop_size"
        }
        Mixxx.ControlProxy {
            id: loopActivateProxy

            group: deck.group
            key: "beatloop_activate"
        }
        Mixxx.ControlProxy {
            id: reloopProxy

            group: deck.group
            key: "reloop_toggle"
        }
        Mixxx.ControlProxy {
            id: rateProxy

            group: deck.group
            key: "rate"
        }
        Mixxx.ControlProxy {
            id: rateRangeProxy

            group: deck.group
            key: "rateRange"
        }
        Mixxx.ControlProxy {
            id: keylockProxy

            group: deck.group
            key: "keylock"
        }
        Mixxx.ControlProxy {
            id: orientationProxy

            group: deck.group
            key: "orientation"
        }
        Mixxx.ControlProxy {
            id: volumeProxy

            group: deck.group
            key: "volume"
        }
        Mixxx.ControlProxy {
            id: pflProxy

            group: deck.group
            key: "pfl"
        }
        Mixxx.ControlProxy {
            id: ejectProxy

            group: deck.group
            key: "eject"
        }
        Mixxx.ControlProxy {
            id: loadedProxy

            group: deck.group
            key: "track_loaded"
        }
    }

    // Mutes the stems of a deck: all but `keep` ("Vocals"), only `keep`
    // when it starts with "!" ("!Vocals" mutes the voice), none with ""
    component StemMuter: Item {
        id: muter

        required property string group
        property var track: null
        readonly property string prefix: muter.group.substr(0, muter.group.length - 1)
        readonly property int stemCount: stems.count

        function has(label) {
            for (let i = 0; i < stems.count; ++i) {
                if (stems.itemAt(i).label === label) {
                    return true;
                }
            }
            return false;
        }
        function muteAllBut(keep) {
            const invert = keep.startsWith("!");
            const label = invert ? keep.substring(1) : keep;
            let found = false;
            for (let i = 0; i < stems.count; ++i) {
                found = found || stems.itemAt(i).label === label;
            }
            for (let i = 0; i < stems.count; ++i) {
                const stem = stems.itemAt(i);
                if (keep === "" || !found) {
                    stem.setMuted(false);
                } else if (invert) {
                    stem.setMuted(stem.label === label);
                } else {
                    stem.setMuted(stem.label !== label);
                }
            }
        }

        Repeater {
            id: stems

            model: muter.track ? muter.track.stemsModel : 0

            Item {
                id: stem

                required property int index
                required property string label

                function setMuted(value) {
                    mute.value = value ? 1 : 0;
                }

                Mixxx.ControlProxy {
                    id: mute

                    group: `${muter.prefix}_Stem${stem.index + 1}]`
                    key: "mute"
                }
            }
        }
    }

    DeckControls {
        id: main

        group: root.group !== "" ? root.group : "[Channel1]"
    }
    // Bound to the hidden deck once it is found, so its controls connect
    // even when the deck is created after this screen
    DeckControls {
        id: helperDeck

        group: root.helperPlayer ? root.helper : "[CutlabNone]"
    }
    StemMuter {
        id: mainStems

        group: root.group !== "" ? root.group : "[Channel1]"
        track: root.track
    }
    StemMuter {
        id: helperStems

        group: root.helper
        track: root.helperTrack
    }
}
