import QtQuick

// The tools of a deck, shown instead of its turntable: stems, hot cues,
// loops, effects and EQ, picked in the bar at the bottom.
Rectangle {
    id: root

    required property string group
    // 0 stems, 1 hot cues, 2 loops, 3 effects, 4 EQ
    property int tool: 1
    readonly property var tools: [
        {icon: "stems", name: qsTr("Stems")},
        {icon: "hotcue", name: qsTr("Cues")},
        {icon: "loop", name: qsTr("Loop")},
        {icon: "fx", name: qsTr("FX")},
        {icon: "eq", name: qsTr("EQ")}
    ]

    signal closeRequested

    color: Style.panel

    Item {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: toolbar.top

        Loader {
            anchors.fill: parent
            sourceComponent: [stemsTool, cuesTool, loopTool, fxTool, eqTool][root.tool]
        }
    }

    Component {
        id: stemsTool

        StemsTool {
            group: root.group
        }
    }
    Component {
        id: cuesTool

        HotcuePads {
            group: root.group
        }
    }
    Component {
        id: loopTool

        LoopTool {
            group: root.group
        }
    }
    Component {
        id: fxTool

        FxTool {
            group: root.group
        }
    }
    Component {
        id: eqTool

        EqTool {
            group: root.group
        }
    }

    Rectangle {
        id: toolbar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(48, Math.min(64, root.height * 0.2))
        color: Style.panel
        border.color: Style.divider
        border.width: 1

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: closeButton.left
            anchors.rightMargin: 12
            spacing: 4

            Repeater {
                model: root.tools

                CLButton {
                    required property int index
                    required property var modelData

                    width: Math.min(52, (toolbar.width - 80) / 5)
                    height: toolbar.height - 8
                    icon: modelData.icon
                    iconSize: Math.min(30, height * 0.55)
                    bordered: false
                    litBorder: false
                    fillColor: "transparent"
                    lit: root.tool === index
                    onClicked: root.tool = index
                }
            }
        }
        CLButton {
            id: closeButton

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: toolbar.height - 10
            height: width
            round: true
            icon: "close"
            iconSize: width * 0.4
            lit: true
            onClicked: root.closeRequested()
        }
    }
}
