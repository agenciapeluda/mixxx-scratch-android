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
    // Held upright, the screen switches to the one hand layout
    readonly property bool portrait: height > width * 1.05
    // The decks as dials with the time and tempo, or as turntables
    property string deckStyle: Mixxx.Application.configValue("[Cutlab]", "deck_style", "dial")

    function setDeckStyle(style) {
        root.deckStyle = style;
        Mixxx.Application.setConfigValue("[Cutlab]", "deck_style", style);
    }
    readonly property real sideWidth: Math.round(Math.max(84, Math.min(130, width * 0.115)))

    signal settingsRequested
    signal autoDJRequested
    signal classicLayoutRequested
    signal xyPadRequested

    color: Style.background

    function openLibrary(group) {
        library.open(group);
    }
    function openQueue() {
        library.open("");
        library.showSection(3);
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
        visible: !root.portrait
        z: 2

        DeckHeader {
            anchors.left: parent.left
            anchors.right: libraryButton.left
            anchors.rightMargin: 14
            height: parent.height
            group: "[Channel1]"
            onBrowseRequested: root.openLibrary("[Channel1]")
        }

        // The Cutlab mark opens the library, red while recording
        Item {
            id: libraryButton

            anchors.centerIn: parent
            width: parent.height * 0.84
            height: width
            scale: libraryMouse.pressed ? 0.92 : 1

            Image {
                anchors.fill: parent
                source: recording.value > 0 ? "icons/cutlab_mark_rec.svg" : "icons/cutlab_mark.svg"
                sourceSize.width: 192
                sourceSize.height: 192
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
        visible: !root.portrait
        onStemsRequested: group => root.openTool(group, 0)
        onMenuRequested: moreMenu.popup(transport, transport.width / 2 - 100, -moreMenu.implicitHeight)
    }

    // Auto DJ, recording, effects pad, settings and layouts
    CLMenu {
        id: moreMenu

        CLMenuItem {
            text: qsTr("Auto DJ…")
            onTriggered: root.autoDJRequested()
        }
        CLMenuItem {
            text: recording.value > 0 ? qsTr("Stop recording") : qsTr("Record the mix")
            onTriggered: {
                toggleRecording.value = 1;
                toggleRecording.value = 0;
            }
        }
        CLMenuItem {
            text: qsTr("XY effects pad")
            onTriggered: root.xyPadRequested()
        }
        CLMenuItem {
            text: root.deckStyle === "dial" ? qsTr("Show turntables") : qsTr("Show tempo dials")
            onTriggered: root.setDeckStyle(root.deckStyle === "dial" ? "vinyl" : "dial")
        }
        CLMenuItem {
            text: qsTr("Settings")
            onTriggered: root.settingsRequested()
        }
    }

    // ===== Middle =====
    Item {
        id: middle

        visible: !root.portrait
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

                        Loader {
                            anchors.fill: parent
                            visible: !root.tools1
                            sourceComponent: root.deckStyle === "vinyl" ? vinyl1 : dial1

                            Component {
                                id: dial1

                                DeckDial {
                                    group: "[Channel1]"
                                }
                            }
                            Component {
                                id: vinyl1

                                Platter {
                                    group: "[Channel1]"
                                }
                            }
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

                        Loader {
                            anchors.fill: parent
                            visible: !root.tools2
                            sourceComponent: root.deckStyle === "vinyl" ? vinyl2 : dial2

                            Component {
                                id: dial2

                                DeckDial {
                                    group: "[Channel2]"
                                    mirrored: true
                                }
                            }
                            Component {
                                id: vinyl2

                                Platter {
                                    group: "[Channel2]"
                                    mirrored: true
                                }
                            }
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

    Loader {
        anchors.fill: parent
        active: root.portrait
        sourceComponent: PortraitView {
            recording: recording.value > 0
            onLibraryRequested: group => root.openLibrary(group)
            onStemsRequested: group => {
                stemsPopup.group = group;
                stemsPopup.open();
            }
            onMenuRequested: anchor => moreMenu.popup(anchor, 0, anchor.height)
        }
    }

    // The stems of a deck over the upright layout
    Popup {
        id: stemsPopup

        property string group: "[Channel1]"

        anchors.centerIn: parent
        width: parent.width - 24
        height: Math.min(parent.height * 0.6, 420)
        modal: true
        padding: 0
        background: Rectangle {
            color: Style.panel
            radius: 12
        }
        contentItem: StemsTool {
            group: stemsPopup.group
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
