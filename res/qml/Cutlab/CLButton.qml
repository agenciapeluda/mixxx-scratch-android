import QtQuick

// A flat rounded button: text, icon or both. "highlighted" fills it with
// the accent color, "lit" only colors its border and label.
Item {
    id: root

    property string text: ""
    property string icon: ""
    property real iconSize: Math.min(width, height) * 0.46
    property bool highlighted: false
    property bool lit: false
    property color litColor: Style.accent
    property color fillColor: Style.button
    property color textColor: Style.text
    property real radius: 8
    property bool bordered: true
    // Whether being lit also colors the border, or only the label
    property bool litBorder: true
    property int fontSize: Math.max(11, Math.min(18, Math.round(height * 0.32)))
    property int fontWeight: Font.Medium
    property bool round: false
    readonly property alias pressed: mouse.pressed

    signal clicked
    signal pressAndHold
    signal pressedDown
    signal released

    implicitHeight: 44
    implicitWidth: Math.max(44, label.implicitWidth + 24)
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: background

        anchors.fill: parent
        radius: root.round ? Math.min(width, height) / 2 : root.radius
        color: root.highlighted ? root.litColor : (mouse.pressed ? Style.buttonPressed : root.fillColor)
        border.width: root.lit && root.litBorder ? 2 : (root.bordered ? 1 : 0)
        border.color: root.lit && root.litBorder ? root.litColor : Style.buttonBorder
    }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Image {
            anchors.verticalCenter: parent.verticalCenter
            height: root.iconSize
            width: root.iconSize
            source: root.icon === "" ? "" : (root.lit && !root.highlighted ? `icons/${root.icon}_lit.svg` : `icons/${root.icon}.svg`)
            sourceSize.height: 64
            sourceSize.width: 64
            visible: root.icon !== ""
            opacity: root.lit || root.highlighted || mouse.pressed ? 1 : 0.92
        }
        Text {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            color: root.lit && !root.highlighted ? root.litColor : root.textColor
            font.family: Style.font
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
            text: root.text
            visible: root.text !== ""
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        onClicked: root.clicked()
        onPressAndHold: root.pressAndHold()
        onPressed: root.pressedDown()
        onReleased: root.released()
        onCanceled: root.released()
    }
}
