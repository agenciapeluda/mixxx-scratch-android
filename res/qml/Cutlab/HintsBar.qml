import QtQuick

// The bar at the bottom of a screen: what each controller button does there.
Rectangle {
    id: root

    // [[button, what it does], …]
    property var hints: []
    property real u: 1

    color: Style.panel

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.07)
    }
    Row {
        anchors.centerIn: parent
        spacing: Math.round(22 * root.u)

        Repeater {
            model: root.hints

            Text {
                required property var modelData

                color: Style.textSecondary
                font.family: Style.font
                font.weight: Font.Medium
                font.pixelSize: Math.max(9, Math.round(12 * root.u))
                textFormat: Text.StyledText
                text: `<b><font color="${Style.text}">${modelData[0]}</font></b> ${modelData[1]}`
            }
        }
    }
}
