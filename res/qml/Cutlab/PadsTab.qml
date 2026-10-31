import QtQuick

// Performance pads over the whole width: samples, or the hot cues or loop
// rolls of both decks side by side.
Rectangle {
    id: root

    property int mode: 0

    signal loadSampleRequested(string group)

    color: Style.panelDark

    Item {
        id: pads

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: modeBar.top

        SamplePads {
            anchors.fill: parent
            visible: root.mode === 0
            onLoadRequested: group => root.loadSampleRequested(group)
        }

        Row {
            anchors.fill: parent
            spacing: 6
            visible: root.mode !== 0

            Repeater {
                model: ["[Channel1]", "[Channel2]"]

                Loader {
                    id: deckPads

                    required property string modelData

                    width: (pads.width - 6) / 2
                    height: pads.height
                    sourceComponent: root.mode === 1 ? cues : rolls

                    Component {
                        id: cues

                        HotcuePads {
                            group: deckPads.modelData
                        }
                    }
                    Component {
                        id: rolls

                        RollPads {
                            group: deckPads.modelData
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: modeBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(44, Math.min(56, root.height * 0.18))
        color: Style.panel
        border.color: Style.divider
        border.width: 1

        Row {
            anchors.centerIn: parent
            spacing: 28

            Repeater {
                model: [qsTr("Samples"), qsTr("Hot cues"), qsTr("Loop rolls")]

                Text {
                    required property int index
                    required property string modelData

                    color: root.mode === index ? Style.accentText : Style.textSecondary
                    font.family: Style.font
                    font.pixelSize: 17
                    text: modelData

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -12
                        onClicked: root.mode = parent.index
                    }
                }
            }
        }
    }
}
