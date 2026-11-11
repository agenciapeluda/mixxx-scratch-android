import QtQuick

// The bar of a deck, like djay: stems, hot cues, loops, FX and EQ. A tap opens that tool in the half of the deck.
Rectangle {
    id: root

    required property string group
    property bool mirrored: false
    readonly property var tools: ["stems", "hotcue", "loop", "fx", "eq"]

    signal toolRequested(int tool)

    color: Style.panel

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Style.divider
    }
    Row {
        anchors.centerIn: parent
        layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight
        spacing: 4

        Repeater {
            model: root.tools

            CLButton {
                required property int index
                required property string modelData

                width: Math.min(64, (root.width - 24) / root.tools.length - 4)
                height: root.height - 8
                icon: modelData
                iconSize: Math.min(30, height * 0.55)
                bordered: false
                fillColor: "transparent"
                onClicked: root.toolRequested(index)
            }
        }
    }
}
