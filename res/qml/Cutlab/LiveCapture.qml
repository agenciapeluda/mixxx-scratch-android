import Mixxx 1.0 as Mixxx
import QtQuick

// A music record on the turntable of a deck (1.30), kept alive in the
// performance screen for the whole session (one per deck, see DJView.qml):
//  - passthrough ([ChannelN] passthrough): what the turntable plays sounds
//    live through the channel, with its fader, crossfader, EQ, filter and
//    effects. Meanwhile the DVS of the deck waits (a music record has no
//    timecode) and SYNC stays off; the screen shows "En vivo" and locks
//    hot cues, loops and pads.
//  - "Capturar": a tap keeps the last 1, 2, 4 or 8 beats (at the tempo of
//    the other deck, else 120), held it keeps what played while held. The
//    WAV goes to Music/Cutlab/Capturas and loops on a sampler at once;
//    turning passthrough off moves the last capture to the deck, looped,
//    where loops, cues, sync and stems work.
//  - no preamp: a turntable plugged straight in (no RIAA) comes in low and
//    thin; the screen says so.
Item {
    id: root

    required property string group
    readonly property string otherGroup: group === "[Channel2]" ? "[Channel1]" : "[Channel2]"
    readonly property string samplerGroup: group === "[Channel2]" ? "[Sampler16]" : "[Sampler15]"
    readonly property bool live: passthrough.value > 0
    readonly property bool inputReady: inputConfigured.value > 0
    // Beats of a tap capture, kept
    property int beats: {
        const stored = parseInt(Mixxx.Application.configValue("[Cutlab]", "capture_beats", "4"));
        return [1, 2, 4, 8].indexOf(stored) >= 0 ? stored : 4;
    }
    // The tempo the capture is cut to: the other deck's, if it has one
    readonly property real referenceBpm: otherLoaded.value > 0 && otherBpm.value > 0 ? otherBpm.value : 0
    property bool busy: false
    property string status: ""
    property bool statusError: false
    property string lastUrl: ""
    property bool lastMoved: true
    readonly property bool samplerPlaying: samplerPlay.value > 0
    property bool noPreamp: false
    property int lowLevelTicks: 0
    property real pressedAt: 0
    property bool dvsBefore: false
    // The capture going to the deck: where the sampler was and whether it
    // played
    property var pendingDeck: null

    function setBeats(n) {
        root.beats = n;
        Mixxx.Application.setConfigValue("[Cutlab]", "capture_beats", String(n));
    }
    function toggle() {
        passthrough.value = root.live ? 0 : 1;
    }
    function pressCapture() {
        root.pressedAt = Date.now();
    }
    // A tap: the last beats; held: what played while held
    function releaseCapture() {
        if (root.busy || root.pressedAt <= 0) {
            return;
        }
        const heldSeconds = (Date.now() - root.pressedAt) / 1000;
        root.pressedAt = 0;
        const bpm = root.referenceBpm;
        let beats = root.beats;
        let seconds;
        if (heldSeconds < 0.4) {
            seconds = beats * 60 / (bpm > 0 ? bpm : 120);
        } else if (bpm > 0) {
            // Whole beats, so the loop stays in time
            beats = Math.max(1, Math.round(heldSeconds * bpm / 60));
            seconds = beats * 60 / bpm;
        } else {
            beats = 0;
            seconds = heldSeconds;
        }
        root.busy = true;
        root.statusError = false;
        root.status = qsTr("Capturando…");
        Mixxx.Cutlab.captureInput(root.group, seconds, bpm, beats);
    }
    function stopSampler() {
        samplerPlay.value = 0;
    }
    function urlOf(path) {
        return "file://" + path;
    }

    Connections {
        target: Mixxx.Cutlab

        function onCaptureFinished(group, path, bpm, beats, seconds, error) {
            if (group !== root.group) {
                return;
            }
            root.busy = false;
            if (error !== "") {
                root.statusError = true;
                root.status = error;
                return;
            }
            root.lastUrl = root.urlOf(path);
            root.lastMoved = false;
            root.statusError = false;
            root.status = beats > 0
                ? qsTr("Loop de %1 tiempos en el sampler · apagá EN VIVO y queda en el deck").arg(beats)
                : qsTr("Loop de %1 s en el sampler · apagá EN VIVO y queda en el deck").arg(seconds.toFixed(1));
            const sampler = Mixxx.PlayerManager.getPlayer(root.samplerGroup);
            if (sampler) {
                samplerRepeat.value = 1;
                sampler.loadTrackFromLocationUrl(root.lastUrl, true);
            }
        }
    }

    onLiveChanged: {
        if (root.live) {
            // The music record has no timecode: the DVS waits
            root.dvsBefore = vinylEnabled.value > 0;
            if (root.dvsBefore) {
                vinylEnabled.value = 0;
            }
            if (syncEnabled.value > 0) {
                syncEnabled.value = 0;
            }
            root.status = "";
            root.statusError = false;
            root.lowLevelTicks = 0;
            root.noPreamp = false;
            return;
        }
        root.noPreamp = false;
        if (root.lastUrl !== "" && !root.lastMoved) {
            // The last capture goes to the deck, looped, from where the
            // sampler was; the DVS stays off (the loop plays by itself)
            root.lastMoved = true;
            root.pendingDeck = {
                url: root.lastUrl,
                position: samplerPosition.value,
                play: samplerPlay.value > 0
            };
            samplerPlay.value = 0;
            const player = Mixxx.PlayerManager.getPlayer(root.group);
            if (player) {
                player.loadTrackFromLocationUrl(root.lastUrl, false);
                deckLoopTimer.tries = 0;
                deckLoopTimer.start();
            }
            return;
        }
        if (root.dvsBefore) {
            vinylEnabled.value = 1;
        }
    }
    // Once the capture is on the deck: the loop over all of it
    Timer {
        id: deckLoopTimer

        property int tries: 0

        interval: 100
        repeat: true
        onTriggered: {
            const player = Mixxx.PlayerManager.getPlayer(root.group);
            const track = player ? player.currentTrack : null;
            const pending = root.pendingDeck;
            if (!pending || ++tries > 60) {
                stop();
                return;
            }
            if (!track || track.trackLocationUrl.toString() !== pending.url || deckSamples.value <= 0) {
                return;
            }
            stop();
            loopStart.value = 0;
            loopEnd.value = deckSamples.value;
            if (loopEnabled.value <= 0) {
                reloop.value = 1;
                reloop.value = 0;
            }
            deckPosition.value = Math.max(0, Math.min(0.999, pending.position));
            if (pending.play) {
                deckPlay.value = 1;
            }
            root.pendingDeck = null;
            root.status = "";
        }
    }
    // SYNC follows a track the deck doesn't play: off while live
    Connections {
        target: syncEnabled

        function onValueChanged() {
            if (root.live && syncEnabled.value > 0) {
                syncEnabled.value = 0;
            }
        }
    }
    // No preamp: under -30 dBFS for 3 s while something plays
    Timer {
        interval: 500
        repeat: true
        running: root.live
        onTriggered: {
            const level = inputLevel.value;
            if (level > -70 && level < -30) {
                root.lowLevelTicks += 1;
            } else {
                root.lowLevelTicks = 0;
                if (level >= -30) {
                    root.noPreamp = false;
                }
            }
            if (root.lowLevelTicks >= 6) {
                root.noPreamp = true;
            }
        }
    }

    Mixxx.ControlProxy {
        id: passthrough

        group: root.group
        key: "passthrough"
    }
    Mixxx.ControlProxy {
        id: inputConfigured

        group: root.group
        key: "input_configured"
    }
    Mixxx.ControlProxy {
        id: vinylEnabled

        group: root.group
        key: "vinylcontrol_enabled"
    }
    Mixxx.ControlProxy {
        id: inputLevel

        group: root.group
        key: "vinylcontrol_input_level"
    }
    Mixxx.ControlProxy {
        id: syncEnabled

        group: root.group
        key: "sync_enabled"
    }
    Mixxx.ControlProxy {
        id: otherLoaded

        group: root.otherGroup
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: otherBpm

        group: root.otherGroup
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: samplerPlay

        group: root.samplerGroup
        key: "play"
    }
    Mixxx.ControlProxy {
        id: samplerRepeat

        group: root.samplerGroup
        key: "repeat"
    }
    Mixxx.ControlProxy {
        id: samplerPosition

        group: root.samplerGroup
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: deckSamples

        group: root.group
        key: "track_samples"
    }
    Mixxx.ControlProxy {
        id: deckPosition

        group: root.group
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: deckPlay

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: loopStart

        group: root.group
        key: "loop_start_position"
    }
    Mixxx.ControlProxy {
        id: loopEnd

        group: root.group
        key: "loop_end_position"
    }
    Mixxx.ControlProxy {
        id: loopEnabled

        group: root.group
        key: "loop_enabled"
    }
    Mixxx.ControlProxy {
        id: reloop

        group: root.group
        key: "reloop_toggle"
    }
}
