import Mixxx 1.0 as Mixxx
import QtQuick

// A segmented level meter, green to red from the bottom.
Item {
    id: root

    required property string group
    property string key: "vu_meter"
    property int segments: 16
    readonly property real level: control.parameter

    implicitWidth: 8
    implicitHeight: 120

    Mixxx.ControlProxy {
        id: control

        group: root.group
        key: root.key
    }

    Column {
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: root.segments

            Rectangle {
                required property int index
                // Index 0 is the top segment
                readonly property real threshold: (root.segments - index) / root.segments
                readonly property bool on: root.level >= threshold - 0.5 / root.segments

                width: root.width
                height: (root.height - (root.segments - 1) * 2) / root.segments
                radius: 1
                color: on ? (threshold > 0.9 ? Style.danger : (threshold > 0.75 ? Style.cue : Style.play)) : "#232325"
            }
        }
    }
}
