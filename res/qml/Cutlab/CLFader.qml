import Mixxx 1.0 as Mixxx
import QtQuick

// A fader with tick marks and a rounded handle, driving the parameter of a
// control. Dragging is relative to where the finger lands, so touching the
// handle never makes the value jump; a double tap resets it.
Item {
    id: root

    required property string group
    required property string key
    property bool vertical: true
    property bool invert: false
    property int ticks: 5
    property real handleLength: vertical ? Math.min(width * 0.9, 46) : 22
    property real handleThickness: vertical ? 22 : Math.min(height * 0.9, 56)
    property color handleColor: "#d7d7db"
    // Stays put while dragging slowly, for fine pitch changes
    property real sensitivity: 1.0
    readonly property real parameter: control.parameter
    readonly property real position: invert ? 1 - control.parameter : control.parameter

    implicitWidth: vertical ? 48 : 200
    implicitHeight: vertical ? 200 : 48

    Mixxx.ControlProxy {
        id: control

        group: root.group
        key: root.key
    }

    // The slot
    Rectangle {
        anchors.centerIn: parent
        color: Style.track
        radius: 3
        width: root.vertical ? 6 : parent.width - root.handleLength / 2
        height: root.vertical ? parent.height - root.handleThickness / 2 : 6
    }

    // Tick marks on both sides
    Repeater {
        model: root.ticks

        Item {
            required property int index
            readonly property real t: root.ticks > 1 ? index / (root.ticks - 1) : 0.5

            x: root.vertical ? 0 : root.handleLength / 2 + t * (root.width - root.handleLength) - width / 2
            y: root.vertical ? root.handleThickness / 2 + t * (root.height - root.handleThickness) - height / 2 : 0
            width: root.vertical ? root.width : 2
            height: root.vertical ? 2 : root.height

            Rectangle {
                color: Style.tick
                width: root.vertical ? parent.width * 0.28 : 1.5
                height: root.vertical ? 1.5 : parent.height * 0.28
                anchors.left: parent.left
                anchors.top: parent.top
            }
            Rectangle {
                color: Style.tick
                width: root.vertical ? parent.width * 0.28 : 1.5
                height: root.vertical ? 1.5 : parent.height * 0.28
                anchors.right: parent.right
                anchors.bottom: parent.bottom
            }
        }
    }

    Rectangle {
        id: handle

        readonly property real travel: root.vertical ? root.height - height : root.width - width

        color: root.handleColor
        radius: root.vertical ? height / 2 : width / 2
        border.color: "#ffffff"
        border.width: mouse.pressed ? 2 : 0
        width: root.vertical ? root.handleLength : root.handleThickness * 0.5
        height: root.vertical ? root.handleThickness : root.handleThickness
        x: root.vertical ? (root.width - width) / 2 : root.position * travel
        y: root.vertical ? (1 - root.position) * travel : (root.height - height) / 2

        // The grip line
        Rectangle {
            anchors.centerIn: parent
            color: "#8c8c92"
            radius: 1
            width: root.vertical ? parent.width * 0.62 : 2
            height: root.vertical ? 2 : parent.height * 0.62
        }
    }

    MouseArea {
        id: mouse

        property real startParameter: 0
        property real startPosition: 0

        function touchPosition(m) {
            const travel = root.vertical ? root.height - handle.height : root.width - handle.width;
            const pos = root.vertical ? 1 - m.y / Math.max(1, travel) : m.x / Math.max(1, travel);
            return root.invert ? -pos : pos;
        }

        anchors.fill: parent
        preventStealing: true
        onPressed: m => {
            startParameter = control.parameter;
            startPosition = touchPosition(m);
        }
        onPositionChanged: m => {
            if (pressed) {
                const delta = (touchPosition(m) - startPosition) * root.sensitivity;
                control.parameter = Math.max(0, Math.min(1, startParameter + delta));
            }
        }
        onDoubleClicked: control.reset()
    }
}
