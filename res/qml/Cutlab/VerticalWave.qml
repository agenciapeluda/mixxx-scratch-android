import Mixxx 1.0 as Mixxx
import QtQuick

// The scrolling waveform of a deck turned upright, like djay: the track
// runs upwards and what is coming is below the white line. Drag it to
// scratch, pinch or use + and − to zoom.
Rectangle {
    id: root

    required property string group
    property bool mirrored: false
    property real u: 1

    radius: Math.round(10 * u)
    color: Style.panel
    clip: true

    // The horizontal waveform, turned a quarter to the right so the future
    // of the track comes from below
    CutlabWave {
        id: wave

        anchors.centerIn: parent
        width: root.height
        height: root.width
        rotation: 90
        group: root.group
        isTouchMode: true
        showHud: false
    }

    // The playhead
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 2
        color: Style.playhead
    }

    // The deck letter
    Rectangle {
        x: root.mirrored ? parent.width - width - Math.round(8 * root.u) : Math.round(8 * root.u)
        y: Math.round(8 * root.u)
        width: letter.implicitWidth + Math.round(12 * root.u)
        height: letter.implicitHeight + 2
        radius: 4
        color: Style.deckColor(root.group)

        Text {
            id: letter

            anchors.centerIn: parent
            color: Style.background
            font.family: Style.mono
            font.weight: Font.Bold
            font.pixelSize: Math.max(9, Math.round(11 * root.u))
            text: Style.deckLetter(root.group)
        }
    }

    // Zoom, at the bottom corner away from the middle
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(4 * root.u)
        x: root.mirrored ? parent.width - width - Math.round(2 * root.u) : Math.round(2 * root.u)
        spacing: 0

        Repeater {
            model: [{icon: "plus", key: "waveform_zoom_down"}, {icon: "minus", key: "waveform_zoom_up"}]

            CLControlButton {
                required property var modelData

                width: Math.round(40 * root.u)
                height: width
                group: root.group
                key: modelData.key
                mode: "trigger"
                icon: modelData.icon
                iconSize: width * 0.42
                bordered: false
                fillColor: "transparent"
                lit: false
            }
        }
    }
}
