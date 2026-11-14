import Mixxx 1.0 as Mixxx
import QtQuick

// What the FX pad of a deck plays, kept alive in the performance screen for
// the whole session (one per deck, see DJView.qml). The FX button of the
// Mixtour and the BEAT FX lever of the REV1 ([Cutlab] fx_onN) play the
// picked effect here at once, with the FX pad open or closed: opening the
// pad changes nothing of the audio, it only shows and plays this engine.
// From the start the picked effect is loaded in the first slot of the
// deck's effect unit and the unit is routed to the deck, so turning it on
// is only switching "enabled".
Item {
    id: root

    required property string group
    readonly property int unitNumber: group === "[Channel2]" ? 2 : 1
    readonly property string unitGroup: `[EffectRack1_EffectUnit${unitNumber}]`
    readonly property string slotGroup: `[EffectRack1_EffectUnit${unitNumber}_Effect1]`
    readonly property var shots: Shots.forGroup(group)

    // Shared with the FX SLOT buttons of the controllers
    property string effect: Shots.effectFor(group)
    // Played from a controller: the presets, no finger
    readonly property bool engaged: root.group === "[Channel2]" ? Shots.engaged2 : Shots.engaged1
    property bool engagedPlaying: false
    // The beats the finger picks across the surface for roll, trans, gater
    // and glitch; the fraction buttons are where a press starts
    property real liveFraction: fraction
    // Beats
    property real fraction: 0.5
    property bool hold: false
    property bool playing: false
    property string rollKey: ""
    // The finger moved the Quick Effect filter (to put it back on release)
    property bool filterTouched: false

    readonly property var ambientIds: ({
        echo: "org.mixxx.effects.echo",
        filter: "",
        flanger: "org.mixxx.effects.flanger",
        reverb: "org.mixxx.effects.reverb",
        bitcrush: "org.mixxx.effects.bitcrusher"
    })
    // Left to right: 1/16 to 1 beat (the finger modulates the rhythm)
    readonly property var liveFractions: [0.0625, 0.125, 0.25, 0.5, 1]

    function isRhythm(effect) {
        return effect === "roll" || effect === "trans" || effect === "gater" || effect === "glitch";
    }
    function rollKeyFor(beats) {
        return `beatlooproll_${beats}_activate`;
    }
    function fractionAt(x) {
        const list = root.liveFractions;
        return list[Math.max(0, Math.min(list.length - 1, Math.floor(x * list.length)))];
    }
    // The ambient effect in the slot, the unit on and routed to the deck,
    // the slot itself off: what makes the first press already play
    function preload() {
        unitEnabled.value = 1;
        routing.value = 1;
        unitMix.value = 1;
        const wanted = root.ambientIds[root.effect];
        if (root.playing || !wanted) {
            return;
        }
        const slot = Mixxx.EffectsManager.getEffectSlot(root.unitNumber, 1);
        if (slot && slot.effectId !== wanted) {
            slot.effectId = wanted;
        }
    }

    // x and y from 0 to 1; preset: played from a controller, with the
    // fraction buttons and no finger
    function start(x, y, preset) {
        const effect = root.effect;
        if (root.isRhythm(effect)) {
            const beats = preset ? Math.min(1, root.fraction) : root.fractionAt(x);
            if (root.playing && beats !== root.liveFraction && effect !== "roll" && root.shots) {
                // A new rate while it plays
                root.shots.rhythm(effect, true, Math.min(16, Math.max(1, 1 / beats)));
            }
            root.liveFraction = beats;
        }
        if (effect === "roll") {
            const key = root.rollKeyFor(root.liveFraction);
            if (key !== root.rollKey) {
                if (root.rollKey !== "") {
                    rollControl.value = 0;
                }
                root.rollKey = key;
                rollControl.key = key;
                rollControl.value = 1;
            }
        } else if (effect === "trans" || effect === "gater" || effect === "glitch") {
            if (!root.playing && root.shots) {
                root.shots.rhythm(effect, true, Math.min(16, Math.max(1, 1 / root.liveFraction)));
            }
            // Depth for trans and gater
            if (effect !== "glitch") {
                parameter1.value = 0.35 + 0.65 * y;
            }
        } else if (effect === "filter") {
            // Played from a controller (preset) the filter is left to its
            // own knob (FILTER of the Mixtour): only the finger moves it
            if (!preset) {
                quickFilter.parameter = x;
                root.filterTouched = true;
            }
        } else {
            if (!root.playing) {
                const slot = Mixxx.EffectsManager.getEffectSlot(root.unitNumber, 1);
                const wanted = root.ambientIds[effect];
                if (slot && slot.effectId !== wanted) {
                    slot.effectId = wanted;
                }
                if (effect === "echo") {
                    // delay_time in beats
                    parameter1.value = Math.min(2, root.fraction);
                }
                unitEnabled.value = 1;
                routing.value = 1;
                unitMix.value = 1;
                unitSuper.parameter = 1;
                slotEnabled.value = 1;
            }
            meta.parameter = x;
            if (effect === "echo") {
                // feedback
                parameter2.parameter = 0.2 + 0.75 * y;
            } else {
                unitMix.value = 0.35 + 0.65 * y;
            }
        }
        root.playing = true;
    }
    function stop() {
        if (!root.playing) {
            return;
        }
        const effect = root.effect;
        if (effect === "roll") {
            rollControl.value = 0;
            root.rollKey = "";
        } else if (effect === "trans" || effect === "gater" || effect === "glitch") {
            if (root.shots) {
                root.shots.rhythm(effect, false, 1);
            }
        } else if (effect === "filter") {
            if (root.filterTouched) {
                quickFilter.reset();
                root.filterTouched = false;
            }
        } else {
            slotEnabled.value = 0;
            unitSuper.parameter = 0;
        }
        root.playing = false;
    }
    function pick(effect) {
        if (effect === root.effect) {
            return;
        }
        const wasEngaged = root.engagedPlaying;
        root.stop();
        root.engagedPlaying = false;
        root.effect = effect;
        Shots.setEffect(root.group, effect);
        if (wasEngaged && root.engaged) {
            root.engage();
        } else {
            root.preload();
        }
    }
    function engage() {
        // Also when the finger already plays it (HOLD): the next press of
        // the controller turns it off
        root.engagedPlaying = true;
        if (root.playing) {
            return;
        }
        root.start(0.6, 0.5, true);
        if (fxAmount.value >= 0) {
            root.dose(fxAmount.value);
        }
    }
    // How much of the effect, from a controller knob (the FILTER knob of
    // the Mixtour with FX on), 0 to 1
    function dose(amount) {
        const a = Math.max(0, Math.min(1, amount));
        const effect = root.effect;
        if (effect === "filter" || effect === "roll" || effect === "glitch") {
            return;
        } else if (effect === "trans" || effect === "gater") {
            parameter1.value = 0.35 + 0.65 * a;
        } else {
            unitMix.value = a;
        }
    }
    // The finger left the FX pad: a controller keeps the effect on with the
    // presets, HOLD keeps it where it was
    function fingerUp() {
        if (root.hold) {
            return;
        }
        if (root.engaged) {
            root.start(0.6, 0.5, true);
            return;
        }
        root.stop();
    }

    onEngagedChanged: {
        if (root.engaged) {
            root.engage();
        } else {
            root.engagedPlaying = false;
            root.hold = false;
            root.stop();
        }
    }
    // The effect changed from a controller (FX SLOT, SHIFT + FX)
    Connections {
        target: Shots

        function onEffect1Changed() {
            if (root.group !== "[Channel2]") {
                root.pick(Shots.effect1);
            }
        }
        function onEffect2Changed() {
            if (root.group === "[Channel2]") {
                root.pick(Shots.effect2);
            }
        }
    }
    // Once the effects are up (they are read after the QML is loaded)
    Timer {
        interval: 1200
        running: true
        onTriggered: root.preload()
    }

    Mixxx.ControlProxy {
        id: fxAmount

        group: "[Cutlab]"
        key: `fx_amount${root.unitNumber}`
        onValueChanged: {
            if (root.engagedPlaying && value >= 0) {
                root.dose(value);
            }
        }
    }
    Mixxx.ControlProxy {
        id: rollControl

        group: root.group
        key: "beatlooproll_0.5_activate"
    }
    Mixxx.ControlProxy {
        id: quickFilter

        group: `[QuickEffectRack1_${root.group}]`
        key: "super1"
    }
    Mixxx.ControlProxy {
        id: routing

        group: root.unitGroup
        key: `group_${root.group}_enable`
    }
    Mixxx.ControlProxy {
        id: unitEnabled

        group: root.unitGroup
        key: "enabled"
    }
    Mixxx.ControlProxy {
        id: unitMix

        group: root.unitGroup
        key: "mix"
    }
    Mixxx.ControlProxy {
        id: unitSuper

        group: root.unitGroup
        key: "super1"
    }
    Mixxx.ControlProxy {
        id: slotEnabled

        group: root.slotGroup
        key: "enabled"
    }
    Mixxx.ControlProxy {
        id: meta

        group: root.slotGroup
        key: "meta"
    }
    Mixxx.ControlProxy {
        id: parameter1

        group: root.slotGroup
        key: "parameter1"
    }
    Mixxx.ControlProxy {
        id: parameter2

        group: root.slotGroup
        key: "parameter2"
    }
}
