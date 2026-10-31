import QtQuick

// A touch surface for effects: a dotted field with a glowing point under
// the finger. Reports the position from 0 to 1, left to right and bottom
// to top, while touched.
Rectangle {
    id: root

    property string topLabel: ""
    property string bottomLabel: ""
    readonly property bool active: touch.pressed

    signal touched(real x, real y)
    signal released

    color: "#2a2a2c"
    clip: true

    // The dot grid
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "#4a4a4e";
            const step = 14;
            for (let y = step / 2; y < height; y += step) {
                for (let x = step / 2; x < width; x += step) {
                    ctx.fillRect(x, y, 2, 2);
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 14
        color: Style.textSecondary
        font.family: Style.font
        font.pixelSize: 18
        font.weight: Font.Medium
        text: root.topLabel
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        color: Style.textSecondary
        font.family: Style.font
        font.pixelSize: 18
        font.weight: Font.Medium
        text: root.bottomLabel
    }

    // Where the effect rests
    Rectangle {
        x: 20
        y: root.height / 2 - height / 2
        width: 12
        height: 12
        radius: 6
        color: Style.textSecondary
        visible: !root.active
    }

    // The finger
    Rectangle {
        id: point

        width: 56
        height: 56
        radius: 28
        color: Qt.rgba(0.39, 0.36, 1.0, 0.35)
        border.color: Style.accentText
        border.width: 2
        visible: root.active
        x: Math.max(0, Math.min(root.width, touch.mouseX)) - width / 2
        y: Math.max(0, Math.min(root.height, touch.mouseY)) - height / 2

        Rectangle {
            anchors.centerIn: parent
            width: 14
            height: 14
            radius: 7
            color: Style.text
        }
    }

    MouseArea {
        id: touch

        function report() {
            const x = Math.max(0, Math.min(1, mouseX / Math.max(1, width)));
            const y = Math.max(0, Math.min(1, 1 - mouseY / Math.max(1, height)));
            root.touched(x, y);
        }

        anchors.fill: parent
        preventStealing: true
        onPressed: report()
        onPositionChanged: report()
        onReleased: root.released()
        onCanceled: root.released()
    }
}
