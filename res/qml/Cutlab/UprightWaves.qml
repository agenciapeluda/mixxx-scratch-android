import QtQuick

// Both waveforms upright side by side, like djay: the track runs upwards,
// what is coming is below the line. A deck whose tools are open hides its lane, so the other one
// keeps the room.
Item {
    id: root

    property var sections1: null
    property var sections2: null
    property bool show1: true
    property bool show2: true

    // A thin gap between the lanes (the beat lights are gone: the beats
    // line up on the waveforms)
    readonly property real lightsWidth: 6
    readonly property int lanes: (show1 ? 1 : 0) + (show2 ? 1 : 0)
    readonly property real laneWidth: (width - lightsWidth - 12) / Math.max(1, lanes)

    // Not shown, not loaded: a hidden lane draws nothing
    Loader {
        active: root.show1
        x: 4
        width: root.laneWidth
        height: root.height
        sourceComponent: VerticalWave {
            group: "[Channel1]"
        }
    }
    Loader {
        active: root.show2
        x: root.width - width - 4
        width: root.laneWidth
        height: root.height
        sourceComponent: VerticalWave {
            group: "[Channel2]"
            mirrored: true
        }
    }
}
