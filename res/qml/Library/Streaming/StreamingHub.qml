import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "../../Theme"
import "../.." as Skin
import "../../Cutlab" as Cutlab

Item {
    id: root

    property string targetDeck: "[Channel1]"
    property int activePlatform: 0 // 0: Navidrome, 1: Audius, 2: URL

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Sources as text tabs, and the deck that gets the track
        Rectangle {
            id: sourceBar

            // Narrow (phone upright): the deck buttons go on a second line
            readonly property bool narrow: root.width < 720

            Layout.fillWidth: true
            Layout.preferredHeight: narrow ? 96 : 50
            color: Cutlab.Style.topBar

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.top: parent.top
                height: 50
                spacing: 22

                Repeater {
                    model: ["Navidrome / Subsonic", "Audius", qsTr("Link / radio")]

                    Item {
                        required property int index
                        required property string modelData

                        width: tabText.implicitWidth
                        height: parent.height

                        Text {
                            id: tabText

                            anchors.centerIn: parent
                            color: root.activePlatform === parent.index ? Cutlab.Style.accentText : Cutlab.Style.text
                            font.family: Cutlab.Style.font
                            font.pixelSize: 16
                            text: parent.modelData
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 3
                            radius: 1.5
                            color: Cutlab.Style.accent
                            visible: root.activePlatform === parent.index
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.activePlatform = parent.index
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: sourceBar.narrow ? 54 : 8
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 4
                    color: Cutlab.Style.textSecondary
                    font.family: Cutlab.Style.font
                    font.pixelSize: 13
                    text: qsTr("Load into")
                }
                Repeater {
                    model: ["[Channel1]", "[Channel2]"]

                    Cutlab.CLButton {
                        required property int index
                        required property string modelData

                        width: 40
                        height: 34
                        text: String(index + 1)
                        fontSize: 15
                        highlighted: root.targetDeck === modelData
                        onClicked: root.targetDeck = modelData
                    }
                }
            }
        }

        // ================= PLATFORM VIEWS CONTAINER =================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            SubsonicView {
                anchors.fill: parent
                visible: root.activePlatform === 0
            }

            OnlineStreamView {
                anchors.fill: parent
                visible: root.activePlatform === 1
            }

            CustomUrlView {
                anchors.fill: parent
                targetDeck: root.targetDeck
                visible: root.activePlatform === 2
            }
        }
    }
}
