import Mixxx 1.0 as Mixxx
import QtQuick

// The structure of the track loaded on a deck (intro, breaks, pauses,
// drops, outro), worked out from its waveform and beat grid once the
// analysis is done, and how many bars are left to the next drop.
Item {
    id: root

    required property string group
    property var sections: []
    // Bars to the start of the next drop, -1 without one ahead
    readonly property int barsToDrop: {
        if (!loaded.value || bpm.value <= 0 || duration.value <= 0) {
            return -1;
        }
        const position = playPosition.value;
        for (let i = 0; i < root.sections.length; ++i) {
            const section = root.sections[i];
            if (section.type === "drop" && section.start > position) {
                const seconds = (section.start - position) * duration.value;
                return Math.ceil(seconds / (240 / bpm.value));
            }
        }
        return -1;
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
    property int tries: 0

    function refresh() {
        root.sections = Mixxx.Cutlab.sections(root.group);
    }

    Mixxx.ControlProxy {
        id: loaded

        group: root.group
        key: "track_loaded"
        onValueChanged: {
            root.sections = [];
            root.tries = 0;
            if (value > 0) {
                retry.restart();
            }
        }
    }
    Mixxx.ControlProxy {
        id: playPosition

        group: root.group
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: duration

        group: root.group
        key: "duration"
    }
    Mixxx.ControlProxy {
        id: bpm

        group: root.group
        key: "file_bpm"
        onValueChanged: retry.restart()
    }
    // The waveform summary and the beat grid arrive a moment after the
    // track: try again until the analysis gives sections
    Timer {
        id: retry

        interval: 1500
        repeat: true
        onTriggered: {
            root.refresh();
            root.tries += 1;
            if (root.sections.length > 0 || root.tries > 40) {
                stop();
            }
        }
    }
    Component.onCompleted: {
        if (loaded.value > 0) {
            retry.restart();
        }
    }
}
