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
//  - 1.32.4: with an effect chosen in Smart CFX (echo, reverb, flanger),
//    the track that goes out takes it, more and more as it leaves, all of
//    it from three quarters of the way on;
// Which track comes in is decided by the way the crossfader moves. Turning
// it off brings the bass and the crossfader curve back as they were; the
// tempo stays where it is.
// [AI-generated text, Claude (Anthropic) — end]
import Mixxx 1.0 as Mixxx
import QtQuick

Item {
    id: root

    // 1.32.5: Auto DJ mixes with it too
    readonly property bool on: smartFader.value > 0 || autoDj.value > 0
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
    // The Smart CFX of each deck (SmartCfx items), for the transition effect
    property var cfx1: null
    property var cfx2: null

    function setFx(deck, amount) {
        const cfx = deck === 1 ? root.cfx1 : root.cfx2;
        if (cfx) {
            cfx.faderAmount = amount;
        }
    }

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
        if (!root.finished) {
            root.restoreOutgoing();
            root.finished = true;
        }
        returnTimer.stop();
        root.setFx(1, 0);
        root.setFx(2, 0);
        root.incoming = 0;
    }
    // [AI-generated text, Claude (Anthropic) — start]
    // 1.32.5: one transition, from the first move of the crossfader towards
    // a deck until it reaches the other end (or comes back):
    //  - tempo: at the start, while the incoming track is still silent, it
    //    takes the BPM of the outgoing one (or its double or half: 85 with
    //    170 mix) and its beat is put in phase with it;
    //  - at the end it goes back to its own BPM, little by little, along 16
    //    bars, so a set does not stay on the tempo of its first track;
    //  - style ([Cutlab] transition_style): 1 blend (bass swap), 2 filter
    //    (and the outgoing track sweeps up its high pass filter), 3 cut (at
    //    the middle the outgoing track is cut on the spot), 0 varied (a
    //    different one each time).
    // [AI-generated text, Claude (Anthropic) — end]
    property int outDeck: 0
    property real targetBpm: 0
    property real ownBpm: 0
    property bool tempoDone: false
    property bool phaseDone: false
    property bool cutDone: false
    property bool finished: true
    property int style: 1
    property int lastStyle: 0
    property real savedFilterOut: 0.5
    property real savedMidOut: 1
    property real savedHighOut: 1
    property real savedLowOut: 1

    function deckBpm(deck) {
        return deck === 1 ? bpm1.value : bpm2.value;
    }
    function setDeckBpm(deck, value) {
        if (deck === 1) {
            bpm1.value = value;
        } else {
            bpm2.value = value;
        }
    }
    function deckPlaying(deck) {
        return deck === 1 ? play1.value > 0 : play2.value > 0;
    }
    // The BPM the incoming track takes: the outgoing one, or its double or
    // half when that is closer; 0 when none is within 20 %
    function matchBpm(inBpm, outBpm) {
        if (inBpm <= 0 || outBpm <= 0) {
            return 0;
        }
        let best = 0;
        let bestGap = 0.2;
        for (const factor of [1, 2, 0.5]) {
            const candidate = outBpm * factor;
            const gap = Math.abs(inBpm - candidate) / candidate;
            if (gap <= bestGap) {
                best = candidate;
                bestGap = gap;
            }
        }
        return best;
    }
    function alignPhase(deck) {
        if (root.phaseDone || !root.deckPlaying(deck) || !root.deckPlaying(root.outDeck)) {
            return;
        }
        root.phaseDone = true;
        if (deck === 1) {
            phase1.value = 1;
            phase1.value = 0;
        } else {
            phase2.value = 1;
            phase2.value = 0;
        }
    }
    // What the outgoing track had before the transition comes back once it
    // is silent (or when the transition is undone)
    function restoreOutgoing() {
        if (root.outDeck === 0) {
            return;
        }
        const d = root.outDeck;
        if (root.style === 2) {
            (d === 1 ? filter1 : filter2).value = root.savedFilterOut;
        }
        if (root.style === 3 && root.cutDone) {
            (d === 1 ? mid1 : mid2).value = root.savedMidOut;
            (d === 1 ? high1 : high2).value = root.savedHighOut;
        }
        root.setFx(d, 0);
    }
    function begin(comingIn) {
        if (!root.finished) {
            root.restoreOutgoing();
        }
        returnTimer.stop();
        root.incoming = comingIn;
        root.outDeck = comingIn === 1 ? 2 : 1;
        root.finished = false;
        root.tempoDone = false;
        root.phaseDone = false;
        root.cutDone = false;
        const loadedIn = comingIn === 1 ? loaded1.value > 0 : loaded2.value > 0;
        const loadedOut = root.outDeck === 1 ? loaded1.value > 0 : loaded2.value > 0;
        const fileBpm = comingIn === 1 ? fileBpm1.value : fileBpm2.value;
        root.ownBpm = fileBpm > 0 ? fileBpm : root.deckBpm(comingIn);
        root.targetBpm = loadedIn && loadedOut ? root.matchBpm(root.deckBpm(comingIn), root.deckBpm(root.outDeck)) : 0;
        const choice = parseInt(Mixxx.Application.configValue("[Cutlab]", "transition_style", "0")) || 0;
        if (choice >= 1 && choice <= 3) {
            root.style = choice;
        } else {
            // Varied: any but the last one
            const options = [1, 2, 3].filter(x => x !== root.lastStyle);
            root.style = options[Math.floor(Math.random() * options.length)];
        }
        root.lastStyle = root.style;
        const d = root.outDeck;
        root.savedFilterOut = (d === 1 ? filter1 : filter2).value;
        root.savedMidOut = (d === 1 ? mid1 : mid2).value;
        root.savedHighOut = (d === 1 ? high1 : high2).value;
    }
    function finish() {
        root.finished = true;
        root.restoreOutgoing();
        // Back to its own BPM along 16 bars
        const deck = root.incoming;
        const from = root.deckBpm(deck);
        if (root.tempoDone && root.ownBpm > 0 && Math.abs(from - root.ownBpm) > 0.05) {
            returnTimer.deck = deck;
            returnTimer.from = from;
            returnTimer.to = root.ownBpm;
            returnTimer.duration = 16 * 4 * 60000 / root.ownBpm;
            returnTimer.started = Date.now();
            returnTimer.start();
        }
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
        // 0 where the incoming track is silent, 1 where only it plays
        const progress = comingIn === 2 ? (position + 1) / 2 : (1 - position) / 2;
        const p = Math.max(0, Math.min(1, progress));
        if (comingIn !== root.incoming || (root.finished && p < 0.5)) {
            root.begin(comingIn);
        }
        if (root.finished) {
            return;
        }

        // Tempo and phase, at once, while the incoming track is quiet
        if (!root.tempoDone && root.targetBpm > 0) {
            root.tempoDone = true;
            root.setDeckBpm(comingIn, root.targetBpm);
        }
        if (root.tempoDone) {
            root.alignPhase(comingIn);
        }

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

        const d = root.outDeck;
        // Effect: on the outgoing track, growing as it leaves; none on the
        // incoming one
        root.setFx(d, p >= 0.999 || p <= 0.001 ? 0 : Math.min(1, p / 0.75));
        root.setFx(comingIn, 0);

        if (root.style === 2) {
            // Filter: the high pass of the outgoing track opens up to 0.95
            const sweep = Math.min(1, p / 0.85);
            (d === 1 ? filter1 : filter2).value = root.savedFilterOut + (0.95 - root.savedFilterOut) * sweep;
        } else if (root.style === 3 && !root.cutDone && p >= 0.5) {
            // Cut: the outgoing track goes silent on the spot
            root.cutDone = true;
            (d === 1 ? mid1 : mid2).value = 0;
            (d === 1 ? high1 : high2).value = 0;
            (d === 1 ? low1Control : low2Control).value = 0;
            (comingIn === 1 ? low1Control : low2Control).value = comingIn === 1 ? root.low1 : root.low2;
        }
        if (root.style === 3 && root.cutDone) {
            // The bass stays swapped after the cut
            (d === 1 ? low1Control : low2Control).value = 0;
            (comingIn === 1 ? low1Control : low2Control).value = comingIn === 1 ? root.low1 : root.low2;
        }

        if (p >= 0.999) {
            root.finish();
        }
    }

    Timer {
        id: returnTimer

        property int deck: 0
        property real from: 0
        property real to: 0
        property real duration: 1
        property real started: 0

        interval: 100
        repeat: true
        onTriggered: {
            const loaded = deck === 1 ? loaded1.value > 0 : loaded2.value > 0;
            if (!loaded) {
                stop();
                return;
            }
            const f = Math.min(1, (Date.now() - started) / duration);
            // Smooth at both ends
            const e = f * f * (3 - 2 * f);
            root.setDeckBpm(deck, from + (to - from) * e);
            if (f >= 1) {
                stop();
            }
        }
    }
    Connections {
        target: play1
        function onValueChanged() {
            if (play1.value > 0 && root.incoming === 1 && !root.finished && root.tempoDone) {
                root.alignPhase(1);
            }
        }
    }
    Connections {
        target: play2
        function onValueChanged() {
            if (play2.value > 0 && root.incoming === 2 && !root.finished && root.tempoDone) {
                root.alignPhase(2);
            }
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
    Mixxx.ControlProxy {
        id: play1

        group: "[Channel1]"
        key: "play"
    }
    Mixxx.ControlProxy {
        id: phase1

        group: "[Channel1]"
        key: "beatsync_phase"
    }
    Mixxx.ControlProxy {
        id: fileBpm1

        group: "[Channel1]"
        key: "file_bpm"
    }
    Mixxx.ControlProxy {
        id: filter1

        group: "[QuickEffectRack1_[Channel1]]"
        key: "super1"
    }
    Mixxx.ControlProxy {
        id: mid1

        group: "[EqualizerRack1_[Channel1]_Effect1]"
        key: "parameter2"
    }
    Mixxx.ControlProxy {
        id: high1

        group: "[EqualizerRack1_[Channel1]_Effect1]"
        key: "parameter3"
    }
    Mixxx.ControlProxy {
        id: play2

        group: "[Channel2]"
        key: "play"
    }
    Mixxx.ControlProxy {
        id: phase2

        group: "[Channel2]"
        key: "beatsync_phase"
    }
    Mixxx.ControlProxy {
        id: fileBpm2

        group: "[Channel2]"
        key: "file_bpm"
    }
    Mixxx.ControlProxy {
        id: filter2

        group: "[QuickEffectRack1_[Channel2]]"
        key: "super1"
    }
    Mixxx.ControlProxy {
        id: mid2

        group: "[EqualizerRack1_[Channel2]_Effect1]"
        key: "parameter2"
    }
    Mixxx.ControlProxy {
        id: high2

        group: "[EqualizerRack1_[Channel2]_Effect1]"
        key: "parameter3"
    }
    Mixxx.ControlProxy {
        id: autoDj

        group: "[AutoDJ]"
        key: "enabled"
    }
}
