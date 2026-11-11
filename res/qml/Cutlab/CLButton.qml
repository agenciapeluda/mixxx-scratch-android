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
    property int fontSize: Math.max(11, Math.min(16, Math.round(height * 0.28)))
    property int fontWeight: Font.Medium
    property bool round: false
    readonly property alias pressed: touch.pressed

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
        color: root.highlighted ? root.litColor : (touch.pressed ? Style.buttonPressed : root.fillColor)
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
            opacity: root.lit || root.highlighted || touch.pressed ? 1 : 0.92
        }
        Text {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            color: root.lit && !root.highlighted ? (root.litColor === Style.accent ? Style.accentText : root.litColor) : root.textColor
            font.family: Style.font
            // Never wider than the button: a long label shrinks to fit
            // instead of spilling over its neighbours
            width: Math.max(0, Math.min(label.implicitWidth, root.width - 8 - (root.icon !== "" ? root.iconSize + 6 : 0)))
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 7
            text: root.text
            visible: root.text !== ""
        }
    }

    // A pointer handler: each button takes its own finger (CUE on both decks
    // at once); dragging away cancels it, so lists still scroll
    TapHandler {
        id: touch

        longPressThreshold: 0.6
        onPressedChanged: pressed ? root.pressedDown() : root.released()
        onTapped: root.clicked()
        onLongPressed: root.pressAndHold()
    }
}
