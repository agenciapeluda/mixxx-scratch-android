import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Shapes

// A round knob with a value arc. Drag up or down to turn it, double tap to
// reset it. "bipolar" knobs (EQ, filter) draw their arc from the top.
Item {
    id: root

    required property string group
    required property string key
    property string label: ""
    property bool bipolar: true
    property color arcColor: Style.accent
    readonly property real parameter: control.parameter
    readonly property real knobSize: Math.min(width, height - (label !== "" ? labelText.height + 2 : 0))

    implicitWidth: 48
    implicitHeight: 48 + (label !== "" ? 16 : 0)

    Mixxx.ControlProxy {
        id: control

        group: root.group
        key: root.key
    }

    Item {
        id: dial

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.knobSize
        height: root.knobSize

        readonly property real startAngle: 135
        readonly property real sweep: 270
        readonly property real valueAngle: startAngle + sweep * control.parameter

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                strokeColor: Style.track
                strokeWidth: 3

                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.width / 2 - 2
                    radiusY: dial.height / 2 - 2
                    startAngle: dial.startAngle
                    sweepAngle: dial.sweep
                }
            }
            ShapePath {
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                strokeColor: root.arcColor
                strokeWidth: 3

                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.width / 2 - 2
                    radiusY: dial.height / 2 - 2
                    startAngle: root.bipolar ? 270 : dial.startAngle
                    sweepAngle: root.bipolar ? dial.valueAngle - 270 :dial.sweep * control.parameter
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: width
            radius: width / 2
            color: "#1f1f21"
            border.color: "#4c4c50"
            border.width: 1
            rotation: dial.valueAngle + 90

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 3
                width: 3
                height: parent.height * 0.32
                radius: 1.5
                color: Style.text
            }
        }
    }

    Text {
        id: labelText

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dial.bottom
        anchors.topMargin: 2
        color: Style.textSecondary
        font.family: Style.font
        font.pixelSize: 11
        font.weight: Font.Medium
        text: root.label
        visible: root.label !== ""
    }

    MouseArea {
        property real startParameter: 0
        property real startY: 0

        anchors.fill: parent
        preventStealing: true
        onPressed: m => {
            startParameter = control.parameter;
            startY = m.y;
        }
        onPositionChanged: m => {
            if (pressed) {
                const delta = (startY - m.y) / 160;
                control.parameter = Math.max(0, Math.min(1, startParameter + delta));
            }
        }
        onDoubleClicked: control.reset()
    }
}
