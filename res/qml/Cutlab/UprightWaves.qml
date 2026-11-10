import QtQuick

// Both waveforms upright side by side, like djay: the track runs upwards,
// what is coming is below the line. Between them the four beat lights of
// each deck. A deck whose tools are open hides its lane, so the other one
// keeps the room.
Item {
    id: root

    property var sections1: null
    property var sections2: null
    property bool show1: true
    property bool show2: true

    readonly property real lightsWidth: Math.round(Math.max(64, Math.min(92, width * 0.11)))
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
    Row {
        id: lights

        x: (root.show1 ? 4 + root.laneWidth + 2 : 4) + (root.lightsWidth - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        BeatLights {
            group: "[Channel1]"
            trackSections: root.sections1
            lightWidth: Math.round((root.lightsWidth - 10) / 2)
            lightHeight: Math.round(Math.max(30, Math.min(60, root.height * 0.1)))
        }
        BeatLights {
            group: "[Channel2]"
            trackSections: root.sections2
            lightWidth: Math.round((root.lightsWidth - 10) / 2)
            lightHeight: Math.round(Math.max(30, Math.min(60, root.height * 0.1)))
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
