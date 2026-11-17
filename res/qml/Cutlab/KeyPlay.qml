// [AI-generated text, Claude (Anthropic) — start]
// Cutlab 1.31: Key Shift and Pitch Play of a deck, for the pads in samples
// mode of the screen, the SAMPLER pads of the DDJ-REV1 and the KEY SHIFT
// and KEYBOARD pads of the DDJ-FLX4. All of them write [Cutlab] key_padN
// (counter * 100 + pad, 1-8, 11-18 with SHIFT); this plays it, so the
// screen and the controllers do exactly the same. One per deck, alive all
// the session (see DJView.qml).
//  - Key Shift: top row +1 to +4 semitones, bottom row -1 to -4, the key
//    of the track without changing the tempo; the pad already on goes
//    back to 0.
//  - Pitch Play: each pad plays the base hot cue (pitch_play_cueN) at
//    another semitone, like a keyboard: top row +1 to +4, bottom row -3
//    to 0. An empty base hot cue is set where the track is. SHIFT + pad
//    picks the base hot cue (pad 1-8 = hot cue 1-8).
// [AI-generated text, Claude (Anthropic) — end]
import Mixxx 1.0 as Mixxx
import QtQuick

QtObject {
    id: root

    required property string group
    readonly property int deck: group === "[Channel2]" ? 2 : 1
    // 0 samples, 1 Key Shift, 2 Pitch Play
    readonly property int mode: Math.round(sampleMode.value)
    readonly property int baseCue: Math.max(1, Math.min(8, Math.round(baseCueControl.value)))
    readonly property int semitones: Math.round(pitchAdjust.value)

    readonly property var keyShiftSteps: [1, 2, 3, 4, -1, -2, -3, -4]
    readonly property var pitchPlaySteps: [1, 2, 3, 4, -3, -2, -1, 0]

    // pad 0-7, top row first
    function keyShift(pad) {
        const step = root.keyShiftSteps[pad];
        pitchAdjust.value = root.semitones === step ? 0 : step;
    }
    function pitchPlay(pad) {
        const cue = root.baseCue;
        if (cueStatus.value <= 0) {
            cueSet.value = 1;
            cueSet.value = 0;
        }
        pitchAdjust.value = root.pitchPlaySteps[pad];
        cuePlay.value = 1;
        cuePlay.value = 0;
    }
    function pickBaseCue(pad) {
        baseCueControl.value = pad + 1;
    }
    // From the screen: the same path as the controllers
    function press(pad, shift) {
        const counter = (Math.floor(keyPad.value / 100) + 1) % 1000;
        keyPad.value = counter * 100 + pad + 1 + (shift ? 10 : 0);
    }
    function setMode(mode) {
        sampleMode.value = mode;
    }

    property Mixxx.ControlProxy keyPad: Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: `key_pad${root.deck}`
        onValueChanged: {
            const code = Math.round(value) % 100;
            if (value <= 0 || code < 1) {
                return;
            }
            const shift = code > 10;
            const pad = (shift ? code - 10 : code) - 1;
            if (pad < 0 || pad > 7) {
                return;
            }
            if (root.mode === 2) {
                if (shift) {
                    root.pickBaseCue(pad);
                } else {
                    root.pitchPlay(pad);
                }
            } else {
                // Key Shift, also when a controller sends it with the
                // screen in samples (the KEY SHIFT pads of the FLX4 set
                // the mode first)
                root.keyShift(pad);
            }
        }
    }
    property Mixxx.ControlProxy sampleMode: Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: `sample_mode${root.deck}`
    }
    property Mixxx.ControlProxy baseCueControl: Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: `pitch_play_cue${root.deck}`
    }
    property Mixxx.ControlProxy pitchAdjust: Mixxx.ControlProxy {
        group: root.group
        key: "pitch_adjust"
    }
    property Mixxx.ControlProxy cueStatus: Mixxx.ControlProxy {
        group: root.group
        key: `hotcue_${root.baseCue}_status`
    }
    property Mixxx.ControlProxy cueSet: Mixxx.ControlProxy {
        group: root.group
        key: `hotcue_${root.baseCue}_set`
    }
    property Mixxx.ControlProxy cuePlay: Mixxx.ControlProxy {
        group: root.group
        key: `hotcue_${root.baseCue}_gotoandplay`
    }
}
