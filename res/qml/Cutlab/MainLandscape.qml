import Mixxx 1.0 as Mixxx
import QtQuick

// The main screen held sideways, as it was in 1.17 and big enough to play
// with the fingers: both tracks on top; on each side SYNC, the BPM, the long
// pitch fader and DVS; in the middle the loops of each deck around the view
// switch (mixer, waveforms, pads); play, SET, CUE and the crossfader at the
// bottom.
// Two looks, picked in the menu of the mark:
//  - Onda (djay): turntables around the mixer, the waveforms upright over
//    the whole middle
//  - Dial (Serato): big dials with the tempo and the time, the waveforms
//    one above the other between them
// The tools of a deck (stems, cues, loops, FX, EQ, Scratch Bank) open in its
// own half and the waveforms stay on screen. What is not on screen is not
// loaded.
Rectangle {
    id: root

    // The performance screen: tools, view and look
    required property var host
    required property var sections1
    required property var sections2
    property bool recording: false

    readonly property bool dial: root.host.mainView === "dial"
    readonly property int view: root.host.view
    readonly property real sideWidth: Math.round(Math.max(96, Math.min(150, width * 0.12)))

    signal libraryRequested(string group)
    signal menuRequested

    function sectionsOf(group) {
        return group === "[Channel2]" ? root.sections2 : root.sections1;
    }

    color: Style.background

    // ===== Top: the two tracks and the mark =====
    Rectangle {
        id: topBar

        width: parent.width
        height: Math.round(Math.max(58, Math.min(84, root.height * 0.15)))
        color: Style.topBar
        z: 2

        DeckHeader {
            anchors.left: parent.left
            anchors.right: mark.left
            anchors.rightMargin: 14
            height: parent.height
            group: "[Channel1]"
            onBrowseRequested: root.libraryRequested("[Channel1]")
        }
        // The Cutlab mark opens the menu, red while recording
        Item {
            id: mark

            anchors.centerIn: parent
            width: parent.height * 0.84
            height: width
            scale: markMouse.pressed ? 0.92 : 1

            Image {
                anchors.fill: parent
                source: root.recording ? "icons/cutlab_mark_rec.svg" : "icons/cutlab_mark.svg"
                sourceSize.width: 192
                sourceSize.height: 192
            }
            MouseArea {
                id: markMouse

                anchors.fill: parent
                onClicked: root.menuRequested()
            }
        }
        DeckHeader {
            anchors.left: mark.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            height: parent.height
            group: "[Channel2]"
            coverOnRight: true
            onBrowseRequested: root.libraryRequested("[Channel2]")
        }
    }

    // ===== Bottom: play, SET, CUE and the crossfader =====
    TransportBar {
        id: transport

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(Math.max(66, Math.min(96, root.height * 0.18)))
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
            toolsOpen: root.host.tools1
            onToolsRequested: root.host.toggleTools("[Channel1]")
        }
        SideColumn {
            id: side2

            anchors.right: parent.right
            width: root.sideWidth
            height: parent.height
            group: "[Channel2]"
            mirrored: true
            toolsOpen: root.host.tools2
            onToolsRequested: root.host.toggleTools("[Channel2]")
        }

        Item {
            id: center

            anchors.left: side1.right
            anchors.right: side2.left
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            height: parent.height

            // Loops of each deck around the view switch
            Rectangle {
                id: header

                width: parent.width
                height: Math.round(Math.max(48, Math.min(64, middle.height * 0.15)))
                color: Style.panel

                LoopControl {
                    anchors.verticalCenter: parent.verticalCenter
                    x: (viewSwitch.x - width) / 2
                    width: Math.min(200, viewSwitch.x - 12)
                    height: parent.height - 4
                    group: "[Channel1]"
                }
                Row {
                    id: viewSwitch

                    anchors.centerIn: parent
                    height: parent.height - 8
                    spacing: 4

                    Repeater {
                        model: ["mixer", "wave", "pads"]

                        CLButton {
                            required property int index
                            required property string modelData

                            width: Math.round(header.height * 1.5)
                            height: viewSwitch.height
                            radius: 8
                            icon: modelData
                            iconSize: height * 0.6
                            bordered: false
                            fillColor: "transparent"
                            highlighted: root.view === index
                            onClicked: root.host.setView(index)
                        }
                    }
                }
                LoopControl {
                    anchors.verticalCenter: parent.verticalCenter
                    x: viewSwitch.x + viewSwitch.width + (header.width - viewSwitch.x - viewSwitch.width - width) / 2
                    width: Math.min(200, header.width - viewSwitch.x - viewSwitch.width - 12)
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

                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                width: parent.width

                readonly property real mixerWidth: Math.round(Math.max(170, Math.min(280, width * 0.3)))
                // Room for each deck: around the mixer, around the waveforms
                // in the Dial look, and only with its tools open over the
                // upright waveforms of the Onda look
                readonly property bool decksAlways: root.view === 0 || root.dial
                readonly property real deckWidth: root.view === 0 ? (width - mixerWidth - 2) / 2
                    : (root.dial ? Math.round(width * 0.3) : Math.round(width * 0.42))
                readonly property bool show1: root.view !== 2 && (decksAlways || root.host.tools1)
                readonly property bool show2: root.view !== 2 && (decksAlways || root.host.tools2)
                readonly property real middleLeft: show1 ? deckWidth + 1 : 0
                readonly property real middleRight: show2 ? deckWidth + 1 : 0

                // ----- Each deck: its dial or turntable with its bar, or its
                // tools
                Repeater {
                    model: ["[Channel1]", "[Channel2]"]

                    Loader {
                        id: deckArea

                        required property string modelData
                        required property int index
                        readonly property bool toolsOpen: index === 0 ? root.host.tools1 : root.host.tools2

                        x: index === 0 ? 0 : body.width - width
                        width: body.deckWidth
                        height: body.height
                        active: index === 0 ? body.show1 : body.show2
                        sourceComponent: toolsOpen ? toolsComponent : deckComponent

                        Component {
                            id: toolsComponent

                            ToolPanel {
                                group: deckArea.modelData
                                tool: deckArea.index === 0 ? root.host.tool1 : root.host.tool2
                                onToolChanged: root.host.setTool(deckArea.modelData, tool)
                                onCloseRequested: root.host.closeTools(deckArea.modelData)
                            }
                        }
                        Component {
                            id: deckComponent

                            Item {
                                Loader {
                                    anchors.top: parent.top
                                    anchors.bottom: toolbar.top
                                    width: parent.width
                                    sourceComponent: root.dial ? dialComponent : platterComponent
                                }
                                Component {
                                    id: dialComponent

                                    DeckDial {
                                        group: deckArea.modelData
                                        mirrored: deckArea.index === 1
                                        trackSections: root.sectionsOf(deckArea.modelData)
                                    }
                                }
                                Component {
                                    id: platterComponent

                                    Platter {
                                        group: deckArea.modelData
                                        mirrored: deckArea.index === 1
                                        trackSections: root.sectionsOf(deckArea.modelData)
                                    }
                                }
                                DeckToolbar {
                                    id: toolbar

                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.round(Math.max(56, Math.min(68, parent.height * 0.18)))
                                    group: deckArea.modelData
                                    mirrored: deckArea.index === 1
                                    onToolRequested: tool => root.host.openTool(deckArea.modelData, tool)
                                }
                            }
                        }
                    }
                }

                // ----- Between the decks -----
                Item {
                    x: body.middleLeft
                    width: body.width - body.middleLeft - body.middleRight
                    height: body.height
                    visible: root.view !== 2

                    Loader {
                        anchors.fill: parent
                        active: root.view === 0
                        sourceComponent: MixerPanel {}
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.view === 1 && root.dial
                        sourceComponent: HorizontalWaves {
                            sections1: root.sections1
                            sections2: root.sections2
                        }
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.view === 1 && !root.dial
                        sourceComponent: UprightWaves {
                            sections1: root.sections1
                            sections2: root.sections2
                        }
                    }
                }

                // ----- Pads over the whole middle -----
                Loader {
                    anchors.fill: parent
                    active: root.view === 2
                    sourceComponent: PadsTab {
                        mode: root.host.padsMode
                        onModeChanged: root.host.padsMode = mode
                        onLoadSampleRequested: group => root.libraryRequested(group)
                    }
                }
            }
        }
    }
}
