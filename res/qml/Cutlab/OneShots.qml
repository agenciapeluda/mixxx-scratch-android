import Mixxx 1.0 as Mixxx
import QtQuick

// The one shot and rhythmic effects of a deck, fired from the FX pad or
// from a controller through [Cutlab] fx_deckN (the code on press, 0 on
// release):
//  1 backspin, 2 brake, 3 censor (held), 4 echo out,
//  5 trans 1/8, 6 trans 1/16, 7 gater, 8 glitch (held)
// Backspin and brake drive the deck like a hand on the platter, so they do
// nothing while the deck follows a timecode record.
Item {
    id: root

    required property string group
    readonly property int deckNumber: parseInt(group.replace(/\D/g, "")) || 1
    readonly property int unitNumber: deckNumber === 2 || deckNumber === 4 ? 2 : 1
    readonly property string unitGroup: `[EffectRack1_EffectUnit${unitNumber}]`
    readonly property string slotGroup: `[EffectRack1_EffectUnit${unitNumber}_Effect1]`
    readonly property bool dvs: vinylEnabled.value > 0
    // What is running: "", "backspin", "brake", "censor", "echoout", "trans", "gater", "glitch"
    property string running: ""
    // Beats of a backspin and a brake
    property real spinBeats: 2
    property real brakeBeats: 1

    signal fired(string name)

    function beatSeconds() {
        return 60 / Math.max(40, bpm.value > 0 ? bpm.value : 120);
    }

    // ---- Backspin and brake: the deck as if a hand spun or stopped it ----
    property real rampFrom: 0
    property real rampTo: 0
    property real rampMs: 0
    property real rampElapsed: 0
    property bool rampStops: true

    function ramp(from, to, ms, name) {
        if (root.dvs) {
            return;
        }
        root.rampFrom = from;
        root.rampTo = to;
        root.rampMs = ms;
        root.rampElapsed = 0;
        root.running = name;
        scratch.value = from;
        scratchEnable.value = 1;
        rampTimer.restart();
        root.fired(name);
    }
    function backspin() {
        // Fast backwards, slowing down to a stop
        root.ramp(-14 * Math.max(0.5, rateRatio.value), 0, root.spinBeats * root.beatSeconds() * 1000, "backspin");
    }
    function brake() {
        root.ramp(Math.max(0.1, rateRatio.value), 0, root.brakeBeats * root.beatSeconds() * 1000, "brake");
    }

    Timer {
        id: rampTimer

        interval: 16
        repeat: true
        onTriggered: {
            root.rampElapsed += interval;
            const t = Math.min(1, root.rampElapsed / Math.max(1, root.rampMs));
            // Exponential-ish slow down, like a platter losing speed
            const eased = 1 - Math.pow(1 - t, 2.2);
            scratch.value = root.rampFrom + (root.rampTo - root.rampFrom) * eased;
            if (t >= 1) {
                stop();
                scratch.value = 0;
                play.value = 0;
                scratchEnable.value = 0;
                root.running = "";
            }
        }
    }

    // ---- Censor: backwards while held, back where it would be ----
    function censor(on) {
        reverseRoll.value = on ? 1 : 0;
        root.running = on ? "censor" : "";
        if (on) {
            root.fired("censor");
        }
    }

    // ---- Echo out: echo on, the deck fades out over 4 beats ----
    property real volumeBefore: 1
    function echoOut() {
        root.volumeBefore = volume.value;
        root.loadEffect("org.mixxx.effects.echo");
        slotEnabled.value = 1;
        unitEnabled.value = 1;
        routing.value = 1;
        unitMix.value = 1;
        unitSuper.parameter = 1;
        root.running = "echoout";
        root.rampElapsed = 0;
        root.rampMs = 4 * root.beatSeconds() * 1000;
        fadeTimer.restart();
        root.fired("echoout");
    }
    Timer {
        id: fadeTimer

        interval: 16
        repeat: true
        onTriggered: {
            root.rampElapsed += interval;
            const t = Math.min(1, root.rampElapsed / Math.max(1, root.rampMs));
            volume.value = root.volumeBefore * (1 - t);
            if (t >= 1) {
                stop();
                play.value = 0;
                tailTimer.restart();
            }
        }
    }
    // Let the echoes ring, then put the deck back as it was
    Timer {
        id: tailTimer

        interval: 2600
        onTriggered: {
            slotEnabled.value = 0;
            unitSuper.parameter = 0;
            volume.value = root.volumeBefore;
            root.running = "";
        }
    }

    // ---- Trans, gater and glitch: tremolo or glitch on beat, held ----
    function loadEffect(effectId) {
        const slot = Mixxx.EffectsManager.getEffectSlot(root.unitNumber, 1);
        if (slot && slot.effectId !== effectId) {
            slot.effectId = effectId;
        }
    }
    function rhythm(name, on, perBeat) {
        if (!on) {
            slotEnabled.value = 0;
            root.running = "";
            return;
        }
        if (name === "glitch") {
            root.loadEffect("org.mixxx.effects.glitch");
            // delay_time in beats
            parameter1.value = 1 / Math.max(1, perBeat);
        } else {
            root.loadEffect("org.mixxx.effects.tremolo");
            // depth, rate (cycles per beat), width (open part), waveform
            parameter1.value = 1;
            parameter2.value = perBeat;
            parameter3.value = name === "gater" ? 0.25 : 0.5;
            parameter4.value = 0.005;
        }
        unitEnabled.value = 1;
        routing.value = 1;
        unitMix.value = 1;
        slotEnabled.value = 1;
        root.running = name;
        root.fired(name);
    }

    function trigger(code, on) {
        switch (code) {
        case 1:
            if (on) {
                root.backspin();
            }
            break;
        case 2:
            if (on) {
                root.brake();
            }
            break;
        case 3:
            root.censor(on);
            break;
        case 4:
            if (on) {
                root.echoOut();
            }
            break;
        case 5:
            root.rhythm("trans", on, 2);
            break;
        case 6:
            root.rhythm("trans", on, 4);
            break;
        case 7:
            root.rhythm("gater", on, 2);
            break;
        case 8:
            root.rhythm("glitch", on, 4);
            break;
        }
    }

    // From the controllers
    property int lastCode: 0
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: `fx_deck${root.deckNumber}`
        onValueChanged: {
            const code = Math.round(value);
            if (code > 0) {
                root.lastCode = code;
                root.trigger(code, true);
            } else if (root.lastCode > 0) {
                root.trigger(root.lastCode, false);
                root.lastCode = 0;
            }
        }
    }

    Mixxx.ControlProxy {
        id: scratch

        group: root.group
        key: "scratch2"
    }
    Mixxx.ControlProxy {
        id: scratchEnable

        group: root.group
        key: "scratch2_enable"
    }
    Mixxx.ControlProxy {
        id: play

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: rateRatio

        group: root.group
        key: "rate_ratio"
    }
    Mixxx.ControlProxy {
        id: bpm

        group: root.group
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: reverseRoll

        group: root.group
        key: "reverseroll"
    }
    Mixxx.ControlProxy {
        id: volume

        group: root.group
        key: "volume"
    }
    Mixxx.ControlProxy {
        id: vinylEnabled

        group: root.group
        key: "vinylcontrol_enabled"
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
        id: parameter1

        group: root.slotGroup
        key: "parameter1"
    }
    Mixxx.ControlProxy {
        id: parameter2

        group: root.slotGroup
        key: "parameter2"
    }
    Mixxx.ControlProxy {
        id: parameter3

        group: root.slotGroup
        key: "parameter3"
    }
    Mixxx.ControlProxy {
        id: parameter4

        group: root.slotGroup
        key: "parameter4"
    }
}
