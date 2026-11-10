import Mixxx 1.0 as Mixxx
import QtQuick

// The performance screen, sideways or upright, in one responsive layout:
//  - on top both tracks and the Cutlab mark (the menu)
//  - the stage: the dial (or turntable) of each deck with its level and a
//    thin pitch fader, the waveforms between them (upright side by side,
//    one above the other, or extended over the whole width) and the
//    crossfader
//  - below, for each deck: its buttons (tools, PLAY, CUE, SYNC, loop) and
//    its 8 pads; ▲ in the middle makes the pads big
// The tools of a deck (mixer, FX, stems, cues, loops, Scratch) open in
// the room of its dial and pads: the waveforms stay on screen. Upright they
// take the room of the pads. What is not on screen is not loaded.
Rectangle {
    id: root

    // The performance screen: tools, looks and pads
    required property var host
    required property var sections1
    required property var sections2
    property bool recording: false
    property bool portrait: false

    readonly property string waveMode: root.host.waveMode
    readonly property bool extended: root.waveMode === "extended"
    readonly property bool turntables: root.host.deckLook === "platter"
    readonly property bool padsBig: root.host.padsBig && !root.extended
    // Extended waveforms (sideways): the pads can hide, hidden by default;
    // then each deck shows its info strip (what the dial shows) under its
    // buttons and the waveforms take the room
    readonly property bool padsHidden: root.extended && !root.portrait && root.host.padsHiddenOnda
    readonly property bool tools1: root.host.tools1
    readonly property bool tools2: root.host.tools2
    readonly property real gap: 8
    readonly property real centerGap: root.portrait ? 0 : 64

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
        height: root.portrait ? 104 : Math.round(Math.max(54, Math.min(76, root.height * 0.14)))
        color: Style.topBar
        z: 2

        DeckHeader {
            x: 0
            y: 0
            width: root.portrait ? parent.width - markBox.width - 8 : (parent.width - markBox.width) / 2 - 10
            height: root.portrait ? parent.height / 2 : parent.height
            group: "[Channel1]"
            onBrowseRequested: root.libraryRequested("[Channel1]")
        }
        Item {
            id: markBox

            x: root.portrait ? parent.width - width - 4 : (parent.width - width) / 2
            y: root.portrait ? 0 : 0
            width: root.portrait ? parent.height / 2 : parent.height * 0.84
            height: root.portrait ? parent.height / 2 : parent.height

            Image {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.84
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
            x: root.portrait ? 0 : markBox.x + markBox.width + 10
            y: root.portrait ? parent.height / 2 : 0
            width: root.portrait ? parent.width : parent.width - x
            height: root.portrait ? parent.height / 2 : parent.height
            group: "[Channel2]"
            coverOnRight: true
            onBrowseRequested: root.libraryRequested("[Channel2]")
        }
    }

    // ===== The zones =====
    Item {
        id: area

        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.gap

        readonly property real xfaderHeight: root.portrait ? 48 : Math.round(Math.max(36, Math.min(48, height * 0.12)))
        // The buttons of a deck
        readonly property real deckRowHeight: Math.round(Math.max(38, Math.min(52, height * 0.12)))
        readonly property real infoHeight: Math.round(Math.max(54, Math.min(72, height * 0.16)))
        // The pads and buttons; big pads take the stage, hidden pads leave
        // the buttons and the info strip
        readonly property real controlsHeight: root.padsHidden ? deckRowHeight + root.gap + infoHeight
            : root.padsBig ? height - (root.portrait ? xfaderHeight + root.gap : 0)
            : Math.round(height * (root.portrait ? 0.44 : 0.42))
        readonly property real stageHeight: root.padsBig ? 0 : height - controlsHeight - root.gap - (root.portrait ? xfaderHeight + root.gap : 0)
        readonly property real controlsY: height - controlsHeight
        // Each half below the stage
        readonly property real halfWidth: (width - root.centerGap) / 2
        // The block of a deck on the stage: pitch strip and dial
        readonly property real pitchWidth: root.portrait ? 0 : Math.round(Math.max(30, Math.min(42, width * 0.04)))
        readonly property real dialSize: root.extended ? 0 : Math.min(stageHeight, Math.round(width * (root.portrait ? 0.27 : 0.25)))
        readonly property real deckBlock: pitchWidth + (root.extended ? 0 : dialSize + root.gap)
        // Where the waveforms go, between what is on each side
        readonly property real wavesLeft: root.tools1 && !root.portrait ? halfWidth + root.gap : deckBlock
        readonly property real wavesRight: root.tools2 && !root.portrait ? halfWidth + root.gap : deckBlock
        readonly property real wavesHeight: stageHeight - (root.portrait ? 0 : xfaderHeight + root.gap)

        // ----- The stage: each deck -----
        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Item {
                id: deckStage

                required property string modelData
                required property int index
                readonly property bool mirrored: index === 1

                x: mirrored ? area.width - width : 0
                width: area.deckBlock
                height: area.stageHeight
                visible: !root.padsBig && (root.portrait || !(mirrored ? root.tools2 : root.tools1))

                PitchStrip {
                    visible: area.pitchWidth > 0
                    x: deckStage.mirrored ? deckStage.width - width : 0
                    width: area.pitchWidth
                    height: parent.height
                    group: deckStage.modelData
                    mirrored: deckStage.mirrored
                }
                Loader {
                    x: deckStage.mirrored ? 0 : area.pitchWidth + root.gap
                    width: area.dialSize
                    height: parent.height
                    active: area.dialSize > 0 && deckStage.visible
                    sourceComponent: root.turntables ? platterComponent : dialComponent

                    Component {
                        id: dialComponent

                        DeckDial {
                            group: deckStage.modelData
                            mirrored: deckStage.mirrored
                            trackSections: root.sectionsOf(deckStage.modelData)
                        }
                    }
                    Component {
                        id: platterComponent

                        Platter {
                            group: deckStage.modelData
                            mirrored: deckStage.mirrored
                            trackSections: root.sectionsOf(deckStage.modelData)
                        }
                    }
                }
            }
        }

        // ----- The stage: the waveforms -----
        Item {
            id: waves

            x: area.wavesLeft
            width: area.width - area.wavesLeft - area.wavesRight
            height: area.wavesHeight
            visible: !root.padsBig

            Loader {
                anchors.fill: parent
                active: waves.visible && root.waveMode === "vertical"
                sourceComponent: UprightWaves {
                    sections1: root.sections1
                    sections2: root.sections2
                }
            }
            Loader {
                anchors.fill: parent
                active: waves.visible && root.waveMode !== "vertical"
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
                busy: root.host.letsktchEngine.busy
                stepText: root.host.letsktchEngine.stepText
                onStopRequested: root.host.toggleLetsktch(group)
            }
        }

        // ----- The crossfader: under the waveforms, or its own row
        // upright (with ▲ for the big pads) -----
        Item {
            id: xfaderRow

            x: root.portrait ? 0 : waves.x
            y: root.portrait ? area.stageHeight + (root.padsBig ? 0 : root.gap) : waves.height + root.gap
            width: root.portrait ? area.width : waves.width
            height: area.xfaderHeight
            visible: root.portrait || !root.padsBig

            CLButton {
                id: bigPadsUpright

                visible: root.portrait
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 48 : 0
                height: 40
                radius: 20
                text: root.padsBig ? "▼" : "▲"
                fontSize: 14
                highlighted: root.padsBig
                onClicked: root.host.padsBig = !root.host.padsBig
            }
            CLFader {
                anchors.left: bigPadsUpright.right
                anchors.leftMargin: root.portrait ? root.gap : 0
                anchors.right: parent.right
                height: parent.height
                vertical: false
                group: "[Master]"
                key: "crossfader"
                ticks: 7
                handleThickness: Math.min(height * 0.95, 40)
            }
        }

        // ----- Below: the buttons and pads of each deck -----
        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Item {
                id: deckControls

                required property string modelData
                required property int index
                readonly property bool mirrored: index === 1
                readonly property bool toolsOpen: mirrored ? root.tools2 : root.tools1

                x: mirrored ? area.width - width : 0
                y: area.controlsY
                width: root.portrait ? (area.width - root.gap) / 2 : area.halfWidth
                height: area.controlsHeight
                visible: !toolsOpen && !(root.portrait && (root.tools1 || root.tools2))

                DeckRow {
                    id: deckRow

                    width: parent.width
                    height: area.deckRowHeight
                    group: deckControls.modelData
                    mirrored: deckControls.mirrored
                    toolsOpen: deckControls.toolsOpen
                    onToolsRequested: root.host.toggleTools(deckControls.modelData)
                    onLoopToolRequested: root.host.openTool(deckControls.modelData, 2)
                }
                DeckInfoStrip {
                    anchors.top: deckRow.bottom
                    anchors.topMargin: root.gap
                    anchors.bottom: parent.bottom
                    width: parent.width
                    visible: root.padsHidden
                    group: deckControls.modelData
                    mirrored: deckControls.mirrored
                }
                DeckPadArea {
                    visible: !root.padsHidden
                    anchors.top: deckRow.bottom
                    anchors.topMargin: root.gap
                    anchors.bottom: parent.bottom
                    width: parent.width
                    group: deckControls.modelData
                    mirrored: deckControls.mirrored
                    compact: root.portrait
                    mode: deckControls.index === 0 ? root.host.padMode1 : root.host.padMode2
                    onModeChanged: {
                        if (deckControls.index === 0) {
                            root.host.padMode1 = mode;
                        } else {
                            root.host.padMode2 = mode;
                        }
                    }
                    onLoadSampleRequested: group => root.libraryRequested(group)
                }
            }
        }

        // ▲ between the pads, sideways: makes them big; with the extended
        // waveforms it shows and hides them
        CLButton {
            visible: !root.portrait
            x: (area.width - width) / 2
            y: area.controlsY + (area.controlsHeight - height) / 2
            width: Math.min(root.centerGap - 12, area.controlsHeight - 8)
            height: width
            round: true
            text: root.extended ? (root.padsHidden ? "▲" : "▼") : (root.padsBig ? "▼" : "▲")
            fontSize: 16
            highlighted: root.padsBig
            onClicked: {
                if (root.extended) {
                    root.host.setPadsHiddenOnda(!root.host.padsHiddenOnda);
                } else {
                    root.host.padsBig = !root.host.padsBig;
                }
            }
        }

        // ----- The tools of a deck, in its room -----
        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Loader {
                id: toolsArea

                required property string modelData
                required property int index
                readonly property bool open: index === 0 ? root.tools1 : root.tools2
                // Upright only one: the last one opened
                readonly property bool shown: open && (!root.portrait || (index === 0 ? !root.tools2 || root.host.lastTools === "[Channel1]" : !root.tools1 || root.host.lastTools === "[Channel2]"))

                x: root.portrait ? 0 : (index === 0 ? 0 : area.width - width)
                y: root.portrait ? area.controlsY : 0
                width: root.portrait ? area.width : area.halfWidth
                height: root.portrait ? area.controlsHeight : area.height
                z: 3
                active: shown
                sourceComponent: ToolPanel {
                    radius: 12
                    group: toolsArea.modelData
                    tool: toolsArea.index === 0 ? root.host.tool1 : root.host.tool2
                    onToolChanged: root.host.setTool(toolsArea.modelData, tool)
                    onCloseRequested: root.host.closeTools(toolsArea.modelData)
                    scratch: root.host.scratchEngine
                    letsktch: root.host.letsktchEngine
                }
            }
        }
    }
}
