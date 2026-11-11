import Mixxx 1.0 as Mixxx
import QtQuick

// Loops of a deck: an auto loop with IN and OUT, or loop rolls. Locked
// while letsktch! plays on the deck (its roll is a loop).
Item {
    id: root

    required property string group
    property int mode: 0
    readonly property bool locked: scratchActive.value > 0

    Mixxx.ControlProxy {
        id: scratchActive

        group: "[Cutlab]"
        key: `scratch_active${root.group === "[Channel2]" ? 2 : 1}`
    }

    Row {
        id: tabs

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: 40
        spacing: 24
        enabled: !root.locked
        opacity: enabled ? 1 : 0.35

        Repeater {
            model: [qsTr("Auto"), qsTr("Roll")]

            Text {
                required property int index
                required property string modelData

                anchors.verticalCenter: parent.verticalCenter
                color: root.mode === index ? Style.accentText : Style.textSecondary
                font.family: Style.font
                font.pixelSize: 15
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
        enabled: !root.locked
        opacity: enabled ? 1 : 0.35

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

    Rectangle {
        anchors.centerIn: parent
        visible: root.locked
        width: lockText.implicitWidth + 32
        height: 40
        radius: 20
        color: Style.raised
        border.color: Style.deckColor(root.group)
        border.width: 1

        Text {
            id: lockText

            anchors.centerIn: parent
            color: Style.text
            font.family: Style.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            text: qsTr("Loop en uso por Scratch")
        }
    }
}
