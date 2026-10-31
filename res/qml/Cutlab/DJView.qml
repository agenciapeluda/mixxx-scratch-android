import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls

// The Cutlab performance screen: both tracks at the top, the decks with
// their tempo columns on the sides, three views in the middle (turntables
// and mixer, upright waveforms, pads) and play, cue and crossfader at the
// bottom. The library opens over everything.
Rectangle {
    id: root

    // 0 turntables and mixer, 1 waveforms, 2 pads
    property int view: 0
    property bool tools1: false
    property bool tools2: false
    property int tool1: 1
    property int tool2: 1
    readonly property bool libraryOpen: library.visible
    readonly property real sideWidth: Math.round(Math.max(84, Math.min(130, width * 0.115)))

    signal settingsRequested
    signal autoDJRequested
    signal classicLayoutRequested
    signal xyPadRequested

    color: Style.background

    function openLibrary(group) {
        library.open(group);
    }
    function toggleLibrary() {
        if (library.visible) {
            library.close();
        } else {
            library.open("");
        }
    }
    function openTool(group, tool) {
        if (root.view !== 0) {
            root.view = 0;
        }
        if (group === "[Channel1]") {
            root.tool1 = tool;
            root.tools1 = true;
        } else {
            root.tool2 = tool;
            root.tools2 = true;
        }
    }

    Mixxx.ControlProxy {
        id: recording

        group: "[Recording]"
        key: "status"
    }
    Mixxx.ControlProxy {
        id: toggleRecording

        group: "[Recording]"
        key: "toggle_recording"
    }

    // ===== Top: the two tracks =====
    Rectangle {
        id: topBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round(Math.max(54, Math.min(78, root.height * 0.15)))
        color: Style.topBar
        z: 2

        DeckHeader {
            anchors.left: parent.left
            anchors.right: libraryButton.left
            anchors.rightMargin: 14
            height: parent.height
            group: "[Channel1]"
            onBrowseRequested: root.openLibrary("[Channel1]")
        }

        // Opens the library, red while recording
        Item {
            id: libraryButton

            anchors.centerIn: parent
            width: parent.height * 0.82
            height: width

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: libraryMouse.pressed ? "#2a2a2c" : "transparent"
                border.color: recording.value > 0 ? Style.danger : Style.text
                border.width: 3
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.32
                height: width
                radius: width / 2
                color: recording.value > 0 ? Style.danger : Style.cue
            }
            MouseArea {
                id: libraryMouse

                anchors.fill: parent
                onClicked: root.toggleLibrary()
            }
        }

        DeckHeader {
            anchors.left: libraryButton.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            height: parent.height
            group: "[Channel2]"
            coverOnRight: true
            onBrowseRequested: root.openLibrary("[Channel2]")
        }
    }

    // ===== Bottom: transport and crossfader =====
    TransportBar {
        id: transport

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(Math.max(58, Math.min(84, root.height * 0.17)))
        onStemsRequested: group => root.openTool(group, 0)
        onMenuRequested: moreMenu.popup(transport.width / 2 - 100, -moreMenu.implicitHeight)

        Menu {
            id: moreMenu

            MenuItem {
                text: qsTr("Auto DJ…")
                onTriggered: root.autoDJRequested()
            }
            MenuItem {
                text: recording.value > 0 ? qsTr("Stop recording") : qsTr("Record the mix")
                onTriggered: {
                    toggleRecording.value = 1;
                    toggleRecording.value = 0;
                }
            }
            MenuItem {
                text: qsTr("XY effects pad")
                onTriggered: root.xyPadRequested()
            }
            MenuItem {
                text: qsTr("Settings")
                onTriggered: root.settingsRequested()
            }
            MenuSeparator {
            }
            MenuItem {
                text: qsTr("Classic layout")
                onTriggered: root.classicLayoutRequested()
            }
        }
    }

    // ===== Middle =====
    Item {
        id: middle

        anchors.top: topBar.bottom
        anchors.bottom: transport.top
        anchors.left: parent.left
        anchors.right: parent.right

        SideColumn {
            id: side1

            anchors.left: parent.left
            width: root.sideWidth
            height: parent.height
            group: "[Channel1]"
            toolsOpen: root.tools1 && root.view === 0
            onToolsRequested: {
                if (root.view === 0 && root.tools1 && root.tool1 === 4) {
                    root.tools1 = false;
                } else {
                    root.openTool("[Channel1]", 4);
                }
            }
        }
        SideColumn {
            id: side2

            anchors.right: parent.right
            width: root.sideWidth
            height: parent.height
            group: "[Channel2]"
            mirrored: true
            toolsOpen: root.tools2 && root.view === 0
            onToolsRequested: {
                if (root.view === 0 && root.tools2 && root.tool2 === 4) {
                    root.tools2 = false;
                } else {
                    root.openTool("[Channel2]", 4);
                }
            }
        }

        Item {
            id: center

            anchors.left: side1.right
            anchors.right: side2.left
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            height: parent.height

            readonly property real mixerWidth: Math.round(Math.max(150, Math.min(260, width * 0.3)))
            readonly property real deckWidth: (width - mixerWidth - 2) / 2

            // Loops of each deck around the view switch
            Rectangle {
                id: header

                width: parent.width
                height: Math.round(Math.max(40, Math.min(54, middle.height * 0.15)))
                color: Style.panel
                visible: !(root.view === 0 && root.tools1 && root.tools2)

                LoopControl {
                    anchors.verticalCenter: parent.verticalCenter
                    x: (viewSwitch.x - width) / 2
                    width: Math.min(180, viewSwitch.x - 12)
                    height: parent.height - 4
                    group: "[Channel1]"
                }
                Row {
                    id: viewSwitch

                    anchors.centerIn: parent
                    height: parent.height - 6
                    spacing: 4

                    Repeater {
                        model: ["mixer", "wave", "pads"]

                        CLButton {
                            required property int index
                            required property string modelData

                            width: Math.round(header.height * 1.45)
                            height: viewSwitch.height
                            radius: 6
                            icon: modelData
                            iconSize: height * 0.62
                            bordered: false
                            fillColor: "transparent"
                            highlighted: root.view === index
                            onClicked: root.view = index
                        }
                    }
                }
                LoopControl {
                    anchors.verticalCenter: parent.verticalCenter
                    x: viewSwitch.x + viewSwitch.width + (header.width - viewSwitch.x - viewSwitch.width - width) / 2
                    width: Math.min(180, header.width - viewSwitch.x - viewSwitch.width - 12)
                    height: parent.height - 4
                    group: "[Channel2]"
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Style.divider
                }
            }

            Item {
                id: body

                anchors.top: header.visible ? header.bottom : parent.top
                anchors.bottom: parent.bottom
                width: parent.width

                // ----- Turntables and mixer -----
                Item {
                    anchors.fill: parent
                    visible: root.view === 0

                    Item {
                        id: deck1Area

                        width: center.deckWidth
                        height: parent.height

                        Platter {
                            anchors.fill: parent
                            group: "[Channel1]"
                            visible: !root.tools1
                        }
                        Loader {
                            anchors.fill: parent
                            active: root.tools1
                            sourceComponent: ToolPanel {
                                group: "[Channel1]"
                                tool: root.tool1
                                onToolChanged: root.tool1 = tool
                                onCloseRequested: root.tools1 = false
                            }
                        }
                    }
                    MixerPanel {
                        x: deck1Area.width + 1
                        width: center.mixerWidth
                        height: parent.height
                    }
                    Item {
                        anchors.right: parent.right
                        width: center.deckWidth
                        height: parent.height

                        Platter {
                            anchors.fill: parent
                            group: "[Channel2]"
                            mirrored: true
                            visible: !root.tools2
                        }
                        Loader {
                            anchors.fill: parent
                            active: root.tools2
                            sourceComponent: ToolPanel {
                                group: "[Channel2]"
                                tool: root.tool2
                                onToolChanged: root.tool2 = tool
                                onCloseRequested: root.tools2 = false
                            }
                        }
                    }
                }

                // ----- Upright waveforms -----
                Loader {
                    anchors.fill: parent
                    active: root.view === 1
                    sourceComponent: Row {
                        spacing: 2

                        VerticalWave {
                            width: (body.width - 2) / 2
                            height: body.height
                            group: "[Channel1]"
                            deckNumber: 1
                        }
                        VerticalWave {
                            width: (body.width - 2) / 2
                            height: body.height
                            group: "[Channel2]"
                            deckNumber: 2
                            mirrored: true
                        }
                    }
                }

                // ----- Pads -----
                Loader {
                    anchors.fill: parent
                    active: root.view === 2
                    sourceComponent: PadsTab {
                        onLoadSampleRequested: group => root.openLibrary(group)
                    }
                }
            }
        }
    }

    LibraryBrowser {
        id: library

        anchors.fill: parent
        visible: false
        z: 10
        onCloseRequested: visible = false
        onSettingsRequested: {
            visible = false;
            root.settingsRequested();
        }
        onAutoDJRequested: root.autoDJRequested()
    }
}
