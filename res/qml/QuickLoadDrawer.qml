import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "Theme"
import "." as Skin
import "Library/Streaming" as StreamingComponent

Popup {
    id: root

    property string targetDeck: "[Channel1]"
    property int activeTab: 0 // 0: Local Library, 1: Streaming Hub

    readonly property bool isDeck1: targetDeck === "[Channel1]"
    readonly property color deckColor: isDeck1 ? "#837cff" : "#ff7a3d"
    readonly property color deckBgColor: isDeck1 ? "#332cb8" : "#bf360c"
    readonly property string deckName: isDeck1 ? "DECK 1" : "DECK 2"

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    dim: true

    background: Rectangle {
        color: "#171717"
        border.color: root.deckColor
        border.width: 2
        radius: 8

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onWheel: function(wheel) { wheel.accepted = true; }
        }
    }

    Overlay.modal: Rectangle {
        color: "#b0000000"

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onClicked: root.close()
        }
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ================= TOP DRAWER HEADER =================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#1f1f1f"
            border.color: "#343434"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                // Deck target pill
                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 80
                    radius: 4
                    color: root.deckBgColor
                    border.color: root.deckColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.deckName
                        color: "#ffffff"
                        font.weight: Font.DemiBold
                        font.pixelSize: 12
                        font.letterSpacing: 1
                    }
                }

                Text {
                    text: qsTr("Load track into %1").arg(root.deckName)
                    color: "#ffffff"
                    font.weight: Font.DemiBold
                    font.pixelSize: 14
                }

                // Switch deck button
                Skin.Button {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 130
                    activeColor: root.isDeck1 ? "#ff7a3d" : "#837cff"
                    backgroundColor: "#2b2b2b"
                    normalColor: root.isDeck1 ? "#f7c86a" : "#ada9ff"
                    font.weight: Font.DemiBold
                    font.pixelSize: 10
                    text: root.isDeck1 ? qsTr("GO TO DECK 2") : qsTr("GO TO DECK 1")
                    onClicked: {
                        root.targetDeck = root.isDeck1 ? "[Channel2]" : "[Channel1]";
                    }
                }

                Item { Layout.fillWidth: true }

                // Source Tabs
                Skin.Button {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 110
                    activeColor: "#837cff"
                    backgroundColor: root.activeTab === 0 ? "#333333" : "#212121"
                    normalColor: root.activeTab === 0 ? "#837cff" : "#969696"
                    font.weight: Font.DemiBold
                    font.pixelSize: 10
                    text: qsTr("LOCAL MUSIC")
                    onClicked: root.activeTab = 0
                }

                Skin.Button {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 120
                    activeColor: "#00ffff"
                    backgroundColor: root.activeTab === 1 ? "#123a2a" : "#212121"
                    normalColor: root.activeTab === 1 ? "#00ffff" : "#ada9ff"
                    font.weight: Font.DemiBold
                    font.pixelSize: 10
                    text: qsTr("STREAMING HUB")
                    onClicked: root.activeTab = 1
                }

                // Close Button
                Skin.Button {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 72
                    activeColor: "#ff5d6c"
                    backgroundColor: "#b71c1c"
                    normalColor: "#ffffff"
                    font.weight: Font.DemiBold
                    font.pixelSize: 10
                    text: qsTr("CLOSE")
                    onClicked: root.close()
                }
            }
        }

        // ================= DRAWER CONTENT =================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 1. LOCAL LIBRARY VIEW IN DRAWER
            Item {
                anchors.fill: parent
                visible: root.activeTab === 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: qsTr("Local track collection")
                            color: "#bebebe"
                            font.weight: Font.DemiBold
                            font.pixelSize: 12
                        }

                        Item { Layout.fillWidth: true }

                        Skin.Button {
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: 210
                            activeColor: "#837cff"
                            backgroundColor: "#2a2a2a"
                            normalColor: "#ada9ff"
                            font.weight: Font.DemiBold
                            font.pixelSize: 11
                            text: qsTr("Open full library view")
                            onClicked: {
                                root.close();
                                if (typeof root.parent?.viewMode !== "undefined") {
                                    root.parent.viewMode = 2;
                                }
                            }
                        }
                    }

                    // Embedded Local Library
                    Skin.Library {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }

            // 2. STREAMING HUB IN DRAWER
            StreamingComponent.StreamingHub {
                anchors.fill: parent
                targetDeck: root.targetDeck
                visible: root.activeTab === 1
            }
        }
    }
}
