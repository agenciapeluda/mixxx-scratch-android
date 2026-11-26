// [AI-generated text, Claude (Anthropic) — start]
// Cutlab 1.31: Smart CFX of one deck. The filter knob of the deck (the
// Quick Effect, always the Filter preset) keeps being the filter, and with
// Smart CFX on an effect goes with it, like the Smart CFX of the DDJ-FLX4:
// nothing at the centre, more of the effect the further the knob turns
// either way. Any controller with a filter knob (the FILTER of the REV1
// and the Mixtour, the CFX of the FLX4) and the screen do it.
// The effect plays in its own effect unit (3 for deck A, 4 for deck B), so
// it never meets the FX pad (units 1 and 2).
// [AI-generated text, Claude (Anthropic) — end]
import Mixxx 1.0 as Mixxx
import QtQuick

Item {
    id: root

    required property string group
    readonly property int unitNumber: group === "[Channel2]" ? 4 : 3
    readonly property string unitGroup: `[EffectRack1_EffectUnit${unitNumber}]`
    readonly property string slotGroup: `[EffectRack1_EffectUnit${unitNumber}_Effect1]`
    // 0 off, 1 echo, 2 reverb, 3 flanger
    readonly property int choice: Math.round(smartCfx.value)
    readonly property var effectIds: ["", "org.mixxx.effects.echo", "org.mixxx.effects.reverb", "org.mixxx.effects.flanger"]
    // How far the filter knob is from the centre, 0 to 1
    readonly property real amount: Math.min(1, Math.abs(filterKnob.value - 0.5) * 2)
    property bool ready: false
    // 1.32.4: the effect the Smart Fader asks for while this deck goes out
    // in a transition, 0 to 1; the larger of it and the knob plays
    property real faderAmount: 0

    function apply() {
        if (!root.ready) {
            return;
        }
        if (root.choice <= 0 || root.choice >= root.effectIds.length) {
            slotEnabled.value = 0;
            routing.value = 0;
            return;
        }
        const slot = Mixxx.EffectsManager.getEffectSlot(root.unitNumber, 1);
        const wanted = root.effectIds[root.choice];
        if (slot && slot.effectId !== wanted) {
            slot.effectId = wanted;
        }
        unitEnabled.value = 1;
        unitMix.value = 1;
        routing.value = 1;
        slotEnabled.value = 1;
        root.dose();
    }
    function dose() {
        if (!root.ready || root.choice <= 0) {
            return;
        }
        // A little dead zone at the centre, then up to the full effect
        const knob = Math.max(0, (root.amount - 0.06) / 0.94);
        const a = Math.max(knob, root.faderAmount);
        unitSuper.value = a;
        meta.value = a;
    }

    onChoiceChanged: root.apply()
    onAmountChanged: root.dose()
    onFaderAmountChanged: root.dose()
    // Once the effects are up (they are read after the QML is loaded)
    Timer {
        interval: 1500
        running: true
        onTriggered: {
            root.ready = true;
            root.apply();
        }
    }

    Mixxx.ControlProxy {
        id: smartCfx

        group: "[Cutlab]"
        key: "smart_cfx"
    }
    Mixxx.ControlProxy {
        id: filterKnob

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
}
