import Mixxx 1.0 as Mixxx
import QtQuick

// The performance screen upright, built around the waveforms:
//  - on top both tracks and the Cutlab mark (the menu)
//  - the waveforms over most of the screen: upright side by side
//    ("Vertical", the default) or one above the other with both dials under
//    them ("Horizontal")
//  - the buttons of each deck (tools, PLAY, CUE, SYNC)
//  - the pads or the tools of a deck, only when asked: they take room from
//    the waveforms, they never cover them
//  - the crossfader at the bottom, with the button that shows the pads
Rectangle {
    id: root

    required property var host
    required property var sections1
    required property var sections2
    property bool recording: false

    readonly property bool horizontal: root.host.waveMode !== "vertical"
    readonly property bool turntables: root.host.deckLook === "platter"
    // The tools of one deck: the last opened
    readonly property string toolsGroup: {
        if (root.host.tools1 && root.host.tools2) {
            return root.host.lastTools === "[Channel2]" ? "[Channel2]" : "[Channel1]";
        }
        return root.host.tools1 ? "[Channel1]" : (root.host.tools2 ? "[Channel2]" : "");
    }
    readonly property bool panelOpen: root.toolsGroup !== "" || root.host.padsBig
    readonly property real gap: 8

    signal libraryRequested(string group)
    signal menuRequested

    color: Style.background

    // ===== Top: the two tracks and the mark =====
    Rectangle {
        id: topBar

        width: parent.width
        height: 104
        color: Style.topBar

        DeckHeader {
            width: parent.width - markBox.width - 8
            height: parent.height / 2
            group: "[Channel1]"
            onBrowseRequested: root.libraryRequested("[Channel1]")
        }
        Item {
            id: markBox

            x: parent.width - width - 4
            width: parent.height / 2
            height: parent.height / 2

            Image {
                anchors.centerIn: parent
                width: parent.height * 0.84
                height: width
                scale: markMouse.pressed ? 0.92 : 1
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
            y: parent.height / 2
            width: parent.width
            height: parent.height / 2
            group: "[Channel2]"
            coverOnRight: true
            onBrowseRequested: root.libraryRequested("[Channel2]")
        }
    }

    Item {
        id: area

        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.gap

        readonly property real rowHeight: 50
        readonly property real xfaderHeight: 52
        readonly property real panelHeight: root.panelOpen ? Math.round(height * 0.44) : 0
        readonly property real stageHeight: height - rowHeight - xfaderHeight - panelHeight - root.gap * (root.panelOpen ? 3 : 2)
        readonly property real dialSize: Math.min((width - root.gap) / 2, Math.round(stageHeight * 0.36))

        // ----- The waveforms (and the dials, horizontal) -----
        Item {
            id: stage

            width: area.width
            height: area.stageHeight

            Loader {
                anchors.fill: parent
                active: !root.horizontal
                sourceComponent: UprightWaves {
                    sections1: root.sections1
                    sections2: root.sections2
                }
            }
            Loader {
                width: parent.width
                height: parent.height - area.dialSize - root.gap
                active: root.horizontal
                sourceComponent: HorizontalWaves {
                    sections1: root.sections1
                    sections2: root.sections2
                }
            }

            LetsktchChip {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 6
                group: root.host.letsktchGroup
                onStopRequested: root.host.toggleLetsktch(group)
            }
            Repeater {
                model: root.horizontal ? ["[Channel1]", "[Channel2]"] : []

                Loader {
                    id: dial

                    required property string modelData
                    required property int index

                    x: index === 0 ? (area.width / 2 - width) / 2 : area.width / 2 + (area.width / 2 - width) / 2
                    y: stage.height - height
                    width: area.dialSize
                    height: area.dialSize
                    sourceComponent: root.turntables ? platterComponent : dialComponent

                    Component {
                        id: dialComponent

                        DeckDial {
                            group: dial.modelData
                            mirrored: dial.index === 1
                            trackSections: dial.index === 0 ? root.sections1 : root.sections2
                        }
                    }
                    Component {
                        id: platterComponent

                        Platter {
                            group: dial.modelData
                            mirrored: dial.index === 1
                            trackSections: dial.index === 0 ? root.sections1 : root.sections2
                        }
                    }
                }
            }
        }

        // ----- The buttons of each deck -----
        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            DeckRow {
                required property string modelData
                required property int index

                x: index === 0 ? 0 : area.width - width
                y: stage.height + root.gap
                width: (area.width - root.gap) / 2
                height: area.rowHeight
                group: modelData
                mirrored: index === 1
                toolsOpen: index === 0 ? root.host.tools1 : root.host.tools2
                onToolsRequested: root.host.toggleTools(modelData)
                onLoopToolRequested: root.host.openTool(modelData, 2)
            }
        }

        // ----- The pads or the tools, when asked -----
        Item {
            id: panel

            y: stage.height + area.rowHeight + root.gap * 2
            width: area.width
            height: area.panelHeight
            visible: root.panelOpen

            Loader {
                anchors.fill: parent
                active: root.toolsGroup !== ""
                sourceComponent: ToolPanel {
                    radius: 12
                    group: root.toolsGroup
                    tool: root.toolsGroup === "[Channel2]" ? root.host.tool2 : root.host.tool1
                    onToolChanged: root.host.setTool(root.toolsGroup, tool)
                    onCloseRequested: root.host.closeTools(root.toolsGroup)
                    letsktchOn: root.host.letsktchGroup === root.toolsGroup
                    onLetsktchRequested: root.host.toggleLetsktch(root.toolsGroup)
                }
            }
            Repeater {
                model: root.toolsGroup === "" && root.host.padsBig ? ["[Channel1]", "[Channel2]"] : []

                DeckPadArea {
                    id: pads

                    required property string modelData
                    required property int index

                    x: index === 0 ? 0 : panel.width - width
                    width: (panel.width - root.gap) / 2
                    height: panel.height
                    group: modelData
                    mirrored: index === 1
                    compact: true
                    mode: index === 0 ? root.host.padMode1 : root.host.padMode2
                    onModeChanged: {
                        if (pads.index === 0) {
                            root.host.padMode1 = mode;
                        } else {
                            root.host.padMode2 = mode;
                        }
                    }
                    onLoadSampleRequested: group => root.libraryRequested(group)
                }
            }
        }

        // ----- The crossfader, and the pads button -----
        Item {
            anchors.bottom: parent.bottom
            width: area.width
            height: area.xfaderHeight

            CLButton {
                id: padsButton

                anchors.verticalCenter: parent.verticalCenter
                width: 76
                height: 44
                radius: 22
                text: qsTr("PADS")
                fontSize: 13
                highlighted: root.host.padsBig
                onClicked: {
                    if (root.toolsGroup !== "") {
                        root.host.closeTools(root.toolsGroup);
                        root.host.padsBig = true;
                    } else {
                        root.host.padsBig = !root.host.padsBig;
                    }
                }
            }
            CLFader {
                anchors.left: padsButton.right
                anchors.leftMargin: root.gap
                anchors.right: parent.right
                height: parent.height
                vertical: false
                group: "[Master]"
                key: "crossfader"
                ticks: 7
                handleThickness: 40
            }
        }
    }
}
