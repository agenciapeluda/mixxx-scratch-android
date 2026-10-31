import QtQuick

// A performance pad: a big rounded square with a name, an optional detail
// in the corner and a colored stripe when it holds something.
Rectangle {
    id: root

    property string text: ""
    property string detail: ""
    property string tag: ""
    property color padColor: "transparent"
    property bool active: false
    property bool dimmed: false
    readonly property alias pressed: mouse.pressed

    signal pressedDown
    signal released
    signal clicked
    signal pressAndHold

    radius: 4
    color: active ? Qt.darker(padColor.a > 0 ? padColor : Style.accent, 1.6) : (mouse.pressed ? Style.buttonPressed : "#454548")
    border.color: active ? (padColor.a > 0 ? padColor : Style.accent) : "#2c2c2e"
    border.width: active ? 2 : 1

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 4
        radius: 2
        color: root.padColor
        visible: root.padColor.a > 0 && !root.active
    }
    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 8
        color: Style.textSecondary
        font.family: Style.font
        font.italic: true
        font.pixelSize: Math.max(10, Math.min(16, root.height * 0.16))
        font.weight: Font.Medium
        text: root.tag
        visible: text !== ""
    }
    Text {
        anchors.centerIn: parent
        width: parent.width - 12
        color: root.dimmed ? Style.textDim : Style.text
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 10
        font.family: Style.font
        font.pixelSize: Math.max(11, Math.min(18, root.height * 0.18, root.width * 0.18))
        text: root.text
    }
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 8
        color: Style.textSecondary
        font.family: Style.font
        font.pixelSize: Math.max(10, Math.min(18, root.height * 0.16))
        text: root.detail
        visible: text !== ""
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        onPressed: root.pressedDown()
        onReleased: root.released()
        onCanceled: root.released()
        onClicked: root.clicked()
        onPressAndHold: root.pressAndHold()
    }
}
