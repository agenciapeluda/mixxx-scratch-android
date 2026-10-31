import ".." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick

// The scrolling waveform of a deck turned upright, like djay: what is
// coming next is below the red line and the track runs upwards. Drag it to scratch, pinch or use + and − to zoom.
Item {
    id: root

    required property string group
    property bool mirrored: false
    property int deckNumber: 1

    clip: true

    Rectangle {
        anchors.fill: parent
        color: "#1a1a1c"
    }

    // The horizontal waveform, turned a quarter to the right so the future
    // of the track comes from below
    Skin.WaveformDisplay {
        id: wave

        anchors.centerIn: parent
        width: root.height
        height: root.width
        rotation: 90
        group: root.group
        isTouchMode: true
        showHud: false
    }

    // Center line at the playhead, the waveform draws its own marker too
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 2
        color: Style.playhead
        opacity: 0.9
    }

    Text {
        anchors.top: parent.top
        anchors.topMargin: 10
        x: root.mirrored ? parent.width - width - 36 : 16
        color: Style.textSecondary
        font.family: Style.font
        font.pixelSize: 26
        text: String(root.deckNumber)
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        x: root.mirrored ? parent.width - width - 10 : 10
        spacing: 36

        CLControlButton {
            width: 40
            height: 40
            group: root.group
            key: "waveform_zoom_down"
            mode: "trigger"
            icon: "plus"
            iconSize: 20
            bordered: false
            fillColor: "transparent"
            lit: false
        }
        CLControlButton {
            width: 40
            height: 40
            group: root.group
            key: "waveform_zoom_up"
            mode: "trigger"
            icon: "minus"
            iconSize: 20
            bordered: false
            fillColor: "transparent"
            lit: false
        }
    }
}
