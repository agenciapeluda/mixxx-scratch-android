import Mixxx 1.0 as Mixxx
import QtQuick

// The structure of the track loaded on a deck (intro, breaks, pauses,
// drops, outro), worked out from its waveform and beat grid once the
// analysis is done, how many bars are left to the next drop, and where the
// beat grid starts (for the beat lights).
// One per deck, made by the performance screen and shared by everything
// that shows it. It reads the track again when the analysis ends or the
// tempo changes, plus at most three late tries (2, 5 and 12 s): no polling
// while the deck plays or is scratched.
Item {
    id: root

    required property string group
    property var sections: []
    // Seconds to the first beat of the grid, -1 without a grid
    property real firstBeat: -1
    readonly property bool loaded: loadedControl.value > 0
    readonly property real duration: durationControl.value
    readonly property real bpm: bpmControl.value
    // Bars to the start of the next drop, -1 without one ahead
    readonly property int barsToDrop: {
        if (!root.loaded || root.bpm <= 0 || root.duration <= 0 || root.nextDropStart < 0) {
            return -1;
        }
        const seconds = (root.nextDropStart - playPosition.value) * root.duration;
        return Math.ceil(seconds / (240 / root.bpm));
    }
    // Where the next drop starts, from 0 to 1, -1 without one ahead
    readonly property real nextDropStart: {
        const position = playPosition.value;
        for (let i = 0; i < root.sections.length; ++i) {
            if (root.sections[i].type === "drop" && root.sections[i].start > position) {
                return root.sections[i].start;
            }
        }
        return -1;
    }
    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)
    property int tries: 0
    readonly property var retryDelays: [2000, 5000, 12000]

    function refresh() {
        if (!root.loaded) {
            root.sections = [];
            root.firstBeat = -1;
            return;
        }
        root.sections = Mixxx.Cutlab.sections(root.group);
        root.firstBeat = Mixxx.Cutlab.firstBeat(root.group);
        if (root.sections.length === 0 && root.tries < root.retryDelays.length) {
            retry.interval = root.retryDelays[root.tries];
            root.tries += 1;
            retry.restart();
        }
    }
    // Once the burst of changes of a load or an analysis is over
    function refreshSoon() {
        settle.restart();
    }

    Mixxx.ControlProxy {
        id: loadedControl

        group: root.group
        key: "track_loaded"
        onValueChanged: {
            root.sections = [];
            root.firstBeat = -1;
            root.tries = 0;
            retry.stop();
            if (value > 0) {
                root.refreshSoon();
            }
        }
    }
    Mixxx.ControlProxy {
        id: playPosition

        group: root.group
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: durationControl

        group: root.group
        key: "duration"
    }
    Mixxx.ControlProxy {
        id: bpmControl

        group: root.group
        key: "file_bpm"
        onValueChanged: {
            if (root.loaded) {
                root.tries = 0;
                root.refreshSoon();
            }
        }
    }
    // The analysis of the loaded track is over: its waveform and grid are in
    Connections {
        target: root.player

        function onAnalyzerProgressChanged() {
            if (root.player && root.player.analyzerProgress >= 1) {
                root.tries = 0;
                root.refreshSoon();
            }
        }
    }
    Timer {
        id: settle

        interval: 400
        onTriggered: root.refresh()
    }
    Timer {
        id: retry

        onTriggered: root.refresh()
    }
    Component.onCompleted: {
        if (root.loaded) {
            root.refreshSoon();
        }
    }
}
