import Mixxx 1.0 as Mixxx
import QtQuick

// Auto loop: halve, toggle a loop of the shown size, double.
Item {
    id: root

    required property string group
    property bool large: false

    implicitWidth: large ? 640 : 240
    implicitHeight: 48

    Mixxx.ControlProxy {
        id: loopSize

        group: root.group
        key: "beatloop_size"
    }
    Mixxx.ControlProxy {
        id: loopEnabled

        group: root.group
        key: "loop_enabled"
    }
    Mixxx.ControlProxy {
        id: beatloopActivate

        group: root.group
        key: "beatloop_activate"
    }
    Mixxx.ControlProxy {
        id: reloopToggle

        group: root.group
        key: "reloop_toggle"
    }
    Mixxx.ControlProxy {
        id: loopHalve

        group: root.group
        key: "loop_halve"
    }
    Mixxx.ControlProxy {
        id: loopDouble

        group: root.group
        key: "loop_double"
    }

    function sizeText(size) {
        if (size >= 1) {
            return Math.round(size).toString();
        }
        return "1/" + Math.round(1 / size);
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.large ? Style.button : "transparent"
        border.color: root.large ? Style.buttonBorder : "transparent"
        border.width: 1
    }

    Row {
        anchors.fill: parent

        CLButton {
            width: root.large ? root.width * 0.2 : root.width * 0.28
            height: root.height
            icon: "prev"
            iconSize: Math.min(22, height * 0.45)
            bordered: false
            fillColor: "transparent"
            onClicked: {
                loopHalve.value = 1;
                loopHalve.value = 0;
            }
        }
        Rectangle {
            width: 1
            height: root.height
            color: Style.buttonBorder
            visible: root.large
        }
        Item {
            width: root.large ? root.width * 0.6 - 2 : root.width * 0.44
            height: root.height

            Image {
                id: loopIcon

                anchors.centerIn: parent
                height: Math.min(root.height * 0.8, 44)
                width: height
                source: "icons/loop.svg"
                sourceSize.width: 96
                sourceSize.height: 96
                opacity: loopEnabled.value > 0 ? 0 : 1
            }
            Image {
                anchors.centerIn: parent
                height: loopIcon.height
                width: height
                source: "icons/loop_on.svg"
                sourceSize.width: 96
                sourceSize.height: 96
                visible: loopEnabled.value > 0
            }
            Text {
                anchors.centerIn: parent
                color: loopEnabled.value > 0 ? Style.loop : Style.text
                font.family: Style.font
                font.pixelSize: Math.max(10, loopIcon.height * 0.3)
                font.weight: Font.Medium
                text: root.sizeText(loopSize.value)
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (loopEnabled.value > 0) {
                        reloopToggle.value = 1;
                        reloopToggle.value = 0;
                    } else {
                        beatloopActivate.value = 1;
                        beatloopActivate.value = 0;
                    }
                }
            }
        }
        Rectangle {
            width: 1
            height: root.height
            color: Style.buttonBorder
            visible: root.large
        }
        CLButton {
            width: root.large ? root.width * 0.2 : root.width * 0.28
            height: root.height
            icon: "next"
            iconSize: Math.min(22, height * 0.45)
            bordered: false
            fillColor: "transparent"
            onClicked: {
                loopDouble.value = 1;
                loopDouble.value = 0;
            }
        }
    }
}
