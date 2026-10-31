import Mixxx 1.0 as Mixxx
import QtQuick

// Shown while a deck follows a turntable (DVS): the mode, tap to switch
// ABS, REL and INT, and a light for the timecode signal.
Rectangle {
    id: root

    required property string group
    readonly property bool active: enabledControl.value > 0
    readonly property var modes: ["ABS", "REL", "INT"]

    visible: active
    width: row.implicitWidth + 18
    height: 28
    radius: 14
    color: "#1c1c1e"
    border.color: statusColor()
    border.width: 1

    function statusColor() {
        switch (Math.round(status.value)) {
        case 1:
            return Style.play;
        case 2:
            return Style.cue;
        case 3:
            return Style.danger;
        default:
            return Style.buttonBorder;
        }
    }

    Mixxx.ControlProxy {
        id: enabledControl

        group: root.group
        key: "vinylcontrol_enabled"
    }
    Mixxx.ControlProxy {
        id: mode

        group: root.group
        key: "vinylcontrol_mode"
    }
    Mixxx.ControlProxy {
        id: status

        group: root.group
        key: "vinylcontrol_status"
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: root.statusColor()
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Style.text
            font.family: Style.font
            font.pixelSize: 12
            font.weight: Font.Medium
            text: "DVS " + root.modes[Math.max(0, Math.min(2, Math.round(mode.value)))]
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        onClicked: mode.value = (Math.round(mode.value) + 1) % 3
    }
}
