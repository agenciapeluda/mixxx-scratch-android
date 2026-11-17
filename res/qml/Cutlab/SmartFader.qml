// [AI-generated text, Claude (Anthropic) — start]
// Cutlab 1.31: Smart Fader. With it on, moving the crossfader (from the
// screen or any controller) mixes for you:
//  - the track that comes in moves its BPM gradually to the BPM of the one
//    that goes out, reaching it at the middle of the crossfader; the one
//    that goes out keeps its tempo;
//  - the bass (LOW of the EQ) goes gradually from one track to the other,
//    in a straight line along the crossfader;
//  - the volume follows a linear curve (constant power mode with a straight
//    transform: the gains are a straight line).
// Which track comes in is decided by the way the crossfader moves. Turning
// it off brings the bass and the crossfader curve back as they were; the
// tempo stays where it is.
// [AI-generated text, Claude (Anthropic) — end]
import Mixxx 1.0 as Mixxx
import QtQuick

Item {
    id: root

    readonly property bool on: smartFader.value > 0
    // The deck that comes in: 1 or 2, 0 none yet
    property int incoming: 0
    property real lastPosition: crossfader.value
    // BPM of the incoming track when its move started
    property real startBpm: 0
    // The LOW of each deck when Smart Fader took it
    property real low1: 1
    property real low2: 1
    // The crossfader curve before Smart Fader
    property real savedMode: 0
    property real savedCurve: 0
    property real savedCalibration: 0
    property bool engaged: false

    function engage() {
        if (root.engaged) {
            return;
        }
        root.savedMode = xMode.value;
        root.savedCurve = xCurve.value;
        root.savedCalibration = xCalibration.value;
        root.low1 = low1Control.value;
        root.low2 = low2Control.value;
        xMode.value = 1;
        xCurve.value = 1;
        xCalibration.value = 0.5;
        root.incoming = 0;
        root.lastPosition = crossfader.value;
        root.engaged = true;
    }
    function release() {
        if (!root.engaged) {
            return;
        }
        root.engaged = false;
        xMode.value = root.savedMode;
        xCurve.value = root.savedCurve;
        xCalibration.value = root.savedCalibration;
        low1Control.value = root.low1;
        low2Control.value = root.low2;
        root.incoming = 0;
    }
    function moved(position) {
        if (!root.engaged) {
            return;
        }
        const delta = position - root.lastPosition;
        root.lastPosition = position;
        if (Math.abs(delta) < 0.0001) {
            return;
        }
        // Towards B (+1) B comes in, towards A (-1) A comes in
        const comingIn = delta > 0 ? 2 : 1;
        if (comingIn !== root.incoming) {
            root.incoming = comingIn;
            root.startBpm = comingIn === 1 ? bpm1.value : bpm2.value;
        }
        // 0 where the incoming track is silent, 1 where only it plays
        const progress = comingIn === 2 ? (position + 1) / 2 : (1 - position) / 2;
        const p = Math.max(0, Math.min(1, progress));

        // Bass: from the outgoing track to the incoming one, in a line
        const lowIn = (comingIn === 1 ? root.low1 : root.low2) * p;
        const lowOut = (comingIn === 1 ? root.low2 : root.low1) * (1 - p);
        if (comingIn === 1) {
            low1Control.value = lowIn;
            low2Control.value = lowOut;
        } else {
            low2Control.value = lowIn;
            low1Control.value = lowOut;
        }

        // Tempo: the incoming track reaches the BPM of the outgoing one at
        // the middle of the crossfader
        const outBpm = comingIn === 1 ? bpm2.value : bpm1.value;
        const loadedIn = comingIn === 1 ? loaded1.value > 0 : loaded2.value > 0;
        const loadedOut = comingIn === 1 ? loaded2.value > 0 : loaded1.value > 0;
        if (!loadedIn || !loadedOut || root.startBpm <= 0 || outBpm <= 0) {
            return;
        }
        // Far apart tempos (more than 20 %) are not touched
        if (Math.abs(outBpm - root.startBpm) / outBpm > 0.2) {
            return;
        }
        const f = Math.min(1, p * 2);
        const target = root.startBpm + (outBpm - root.startBpm) * f;
        if (comingIn === 1) {
            bpm1.value = target;
        } else {
            bpm2.value = target;
        }
    }

    onOnChanged: root.on ? root.engage() : root.release()
    Component.onCompleted: {
        if (root.on) {
            root.engage();
        }
    }

    Mixxx.ControlProxy {
        id: smartFader

        group: "[Cutlab]"
        key: "smart_fader"
    }
    Mixxx.ControlProxy {
        id: crossfader

        group: "[Master]"
        key: "crossfader"
        onValueChanged: root.moved(value)
    }
    Mixxx.ControlProxy {
        id: xMode

        group: "[Mixer Profile]"
        key: "xFaderMode"
    }
    Mixxx.ControlProxy {
        id: xCurve

        group: "[Mixer Profile]"
        key: "xFaderCurve"
    }
    Mixxx.ControlProxy {
        id: xCalibration

        group: "[Mixer Profile]"
        key: "xFaderCalibration"
    }
    Mixxx.ControlProxy {
        id: low1Control

        group: "[EqualizerRack1_[Channel1]_Effect1]"
        key: "parameter1"
    }
    Mixxx.ControlProxy {
        id: low2Control

        group: "[EqualizerRack1_[Channel2]_Effect1]"
        key: "parameter1"
    }
    Mixxx.ControlProxy {
        id: bpm1

        group: "[Channel1]"
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: bpm2

        group: "[Channel2]"
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: loaded1

        group: "[Channel1]"
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: loaded2

        group: "[Channel2]"
        key: "track_loaded"
    }
}
