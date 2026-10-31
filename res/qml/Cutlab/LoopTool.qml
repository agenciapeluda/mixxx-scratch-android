import QtQuick

// Loops of a deck: an auto loop with IN and OUT, or loop rolls.
Item {
    id: root

    required property string group
    property int mode: 0

    Row {
        id: tabs

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: 40
        spacing: 24

        Repeater {
            model: [qsTr("Auto"), qsTr("Roll")]

            Text {
                required property int index
                required property string modelData

                anchors.verticalCenter: parent.verticalCenter
                color: root.mode === index ? Style.accent : Style.textSecondary
                font.family: Style.font
                font.pixelSize: 17
                text: modelData

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: root.mode = parent.index
                }
            }
        }
    }

    Item {
        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.mode === 0

        LoopControl {
            id: autoLoop

            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.12
            width: Math.min(parent.width - 40, 420)
            height: Math.min(70, parent.height * 0.36)
            group: root.group
            large: true
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: autoLoop.bottom
            anchors.topMargin: parent.height * 0.1
            width: autoLoop.width
            height: autoLoop.height

            CLControlButton {
                width: parent.width / 2
                height: parent.height
                radius: 10
                group: root.group
                key: "loop_in"
                mode: "push"
                text: qsTr("IN")
                fontSize: 18
                litKey: "loop_enabled"
                lit: false
            }
            CLControlButton {
                width: parent.width / 2
                height: parent.height
                radius: 10
                group: root.group
                key: "loop_out"
                mode: "push"
                text: qsTr("OUT")
                fontSize: 18
                lit: false
            }
        }
    }

    RollPads {
        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        group: root.group
        visible: root.mode === 1
    }
}
