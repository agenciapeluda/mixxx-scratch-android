import Mixxx 1.0 as Mixxx
import QtQuick

// Four lights per deck, one under the other like Serato's beat counter: the
// beat of the bar the deck is on, counted from the beat grid. The first beat
// of the bar is the brightest. Two of them side by side show at a glance
// whether both decks land on the same beat. Plain rectangles that change
// color four times a bar: nothing animates. horizontal: side by side, for
// the bar between the waveforms one above the other.
Grid {
    id: root

    property bool horizontal: false

    required property string group
    // The sections of the track (TrackSections), for where the grid starts
    property var trackSections: null
    property real lightWidth: 22
    property real lightHeight: 22

    readonly property bool ready: trackLoaded.value > 0 && fileBpm.value > 0 && duration.value > 0
    readonly property real gridStart: root.trackSections && root.trackSections.firstBeat >= 0 ? root.trackSections.firstBeat : 0
    // 0 to 3, -1 before the grid or without it
    readonly property int beatInBar: {
        if (!root.ready) {
            return -1;
        }
        const seconds = playPosition.value * duration.value - root.gridStart;
        // A hair early, so the light changes on the beat and not after it
        const beats = Math.floor(seconds * fileBpm.value / 60 + 0.02);
        if (beats < 0) {
            return -1;
        }
        return beats % 4;
    }

    columns: root.horizontal ? 4 : 1
    spacing: Math.round((root.horizontal ? lightWidth : lightHeight) * (root.horizontal ? 0.12 : 0.3))

    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: fileBpm

        group: root.group
        key: "file_bpm"
    }
    Mixxx.ControlProxy {
        id: duration

        group: root.group
        key: "duration"
    }
    Mixxx.ControlProxy {
        id: playPosition

        group: root.group
        key: "playposition"
    }

    Repeater {
        model: 4

        Rectangle {
            required property int index
            readonly property bool on: root.beatInBar === index

            width: root.lightWidth
            height: root.lightHeight
            radius: Math.round(root.lightHeight * 0.22)
            // Always the color of the deck; the first beat of the bar
            // brighter, with a white edge
            color: on ? (index === 0 ? Style.deckLight(root.group) : Style.deckColor(root.group)) : Style.raised
            border.width: on && index === 0 ? 2 : 1
            border.color: on ? (index === 0 ? Style.text : "transparent") : Qt.rgba(1, 1, 1, 0.1)
            opacity: root.ready ? 1 : 0.4
        }
    }
}
