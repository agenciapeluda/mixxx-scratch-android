import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.12
import Mixxx 1.0 as Mixxx
import "." as Setting
import ".." as Skin
import "../Theme"

Category {
    id: root

    label: qsTr("About")
    selectedIndex: 0

    Flickable {
        anchors.fill: parent
        contentHeight: aboutColumn.implicitHeight + 30
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: aboutColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 12

            // App identity
            Rectangle {
                Layout.fillWidth: true
                radius: 12
                color: "#12151C"
                border.color: "#232836"
                border.width: 1
                implicitHeight: identityCol.implicitHeight + 32

                ColumnLayout {
                    id: identityCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Image {
                            source: Qt.resolvedUrl("../images/cutlab_logo.svg")
                            sourceSize.width: 40
                            sourceSize.height: 40
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                        }
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: "Cutlab"
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                                color: "#E8EAF0"
                            }
                            Text {
                                text: `v${Mixxx.MobileApp.packageVersion} · Mixxx ${Mixxx.Application.version}`
                                font.pixelSize: 11
                                color: "#8A91A3"
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        text: qsTr("Open source DJ software for Android: DVS, DJ controllers and a touch interface.")
                        font.pixelSize: 12
                        color: "#B4B9C7"
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ================= UPDATES =================
            Rectangle {
                Layout.fillWidth: true
                radius: 8
                color: "#12151c"
                border.color: "#232836"
                border.width: 1
                implicitHeight: updatesCol.implicitHeight + 24

                ColumnLayout {
                    id: updatesCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        Text {
                            text: qsTr("UPDATES")
                            font.weight: Font.DemiBold
                            font.pixelSize: 12
                            color: "#7c8cff"
                            font.letterSpacing: 0.5
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Skin.AppUpdateStatusText {
                            Layout.fillWidth: true
                            font.pixelSize: 12
                        }

                        Skin.Button {
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 150
                            visible: [Mixxx.AppUpdate.Idle, Mixxx.AppUpdate.UpToDate].includes(Mixxx.AppUpdate.state) || (Mixxx.AppUpdate.state === Mixxx.AppUpdate.Failed && Mixxx.AppUpdate.latestVersion === "")
                            text: qsTr("CHECK NOW")
                            onClicked: Mixxx.AppUpdate.check()
                        }
                        Skin.Button {
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 150
                            visible: Mixxx.AppUpdate.state === Mixxx.AppUpdate.Available || (Mixxx.AppUpdate.state === Mixxx.AppUpdate.Failed && Mixxx.AppUpdate.latestVersion !== "")
                            activeColor: "#7c8cff"
                            backgroundColor: "#0d3640"
                            normalColor: "#a9b3ff"
                            font.weight: Font.DemiBold
                            text: qsTr("DOWNLOAD")
                            onClicked: Mixxx.AppUpdate.download()
                        }
                        Skin.Button {
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 150
                            visible: Mixxx.AppUpdate.state === Mixxx.AppUpdate.Downloading
                            text: qsTr("Cancel")
                            onClicked: Mixxx.AppUpdate.cancelDownload()
                        }
                        Skin.Button {
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 150
                            visible: Mixxx.AppUpdate.state === Mixxx.AppUpdate.Downloaded
                            activeColor: "#7c8cff"
                            backgroundColor: "#0d3640"
                            normalColor: "#a9b3ff"
                            font.weight: Font.DemiBold
                            text: qsTr("INSTALL")
                            onClicked: updateInstallPopup.open()
                        }
                    }

                    // Download progress
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        visible: Mixxx.AppUpdate.state === Mixxx.AppUpdate.Downloading
                        radius: 3
                        color: "#0b0d12"
                        border.color: "#232836"
                        border.width: 1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * Mixxx.AppUpdate.progress
                            radius: 3
                            color: "#7c8cff"
                        }
                    }

                    // What's new
                    Text {
                        Layout.fillWidth: true
                        visible: Mixxx.AppUpdate.releaseNotes !== "" && [Mixxx.AppUpdate.Available, Mixxx.AppUpdate.Downloading, Mixxx.AppUpdate.Verifying, Mixxx.AppUpdate.Downloaded].includes(Mixxx.AppUpdate.state)
                        text: Mixxx.AppUpdate.releaseNotes
                        textFormat: Text.MarkdownText
                        font.pixelSize: 11
                        color: "#b4b9c7"
                        linkColor: "#a9b3ff"
                        wrapMode: Text.WordWrap
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Switch {
                            id: autoCheckSwitch

                            checked: Mixxx.AppUpdate.autoCheck
                            onToggled: Mixxx.AppUpdate.autoCheck = checked

                            // The Basic style is grey on and off
                            indicator: Rectangle {
                                x: autoCheckSwitch.leftPadding
                                y: (autoCheckSwitch.height - height) / 2
                                implicitWidth: 48
                                implicitHeight: 26
                                radius: 13
                                color: autoCheckSwitch.checked ? "#0d3640" : "#161922"
                                border.color: autoCheckSwitch.checked ? "#7c8cff" : "#5a6072"
                                border.width: 1

                                Rectangle {
                                    x: autoCheckSwitch.checked ? parent.width - width - 3 : 3
                                    y: 3
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: autoCheckSwitch.checked ? "#7c8cff" : "#6e7587"
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Look for updates when the app starts (once a day at most). Nothing is downloaded without asking.")
                            font.pixelSize: 10
                            color: "#8a91a3"
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Skin.AppUpdateInstallPopup {
                    id: updateInstallPopup
                }
            }

            // Credits and license
            Rectangle {
                Layout.fillWidth: true
                radius: 12
                color: "#12151C"
                border.color: "#232836"
                border.width: 1
                implicitHeight: creditsCol.implicitHeight + 32

                ColumnLayout {
                    id: creditsCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6

                    Text {
                        text: qsTr("Credits")
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#E8EAF0"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Based on Mixxx (mixxx.org) and on the Android port by JaviLabarumDJ and Angelos Exarchos. Free software under the GNU GPL v2 or later. Stem separation: Spleeter (Deezer) and HTDemucs (Meta), MIT license.")
                        font.pixelSize: 11
                        color: "#8A91A3"
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "<a href=\"https://github.com/agenciapeluda/mixxx-scratch-android\">github.com/agenciapeluda/mixxx-scratch-android</a>"
                        textFormat: Text.RichText
                        font.pixelSize: 11
                        color: "#8A91A3"
                        linkColor: "#7C8CFF"
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
            }
        }
    }
}
