import "../Library" as LibraryComponent
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

    // Effect unit 1 plays on deck 1 and unit 2 on deck 2, like the FX of
    // djay: an effect is heard as soon as it is on, from the screen or from
    // a controller
    Component.onCompleted: {
        fxRoute1.value = 1;
        fxRoute2.value = 1;
        fxMix1.value = 1;
        fxMix2.value = 1;
        Shots.deck1 = shots1;
        Shots.deck2 = shots2;
        if (Mixxx.Application.configValue("[Cutlab]", "folders_done", "0") !== "1") {
            firstRun.start();
        }
    }

    // The one shot effects of each deck, fired from the FX pad or from the
    // pads of a controller
    OneShots {
        id: shots1

        group: "[Channel1]"
    }
    OneShots {
        id: shots2

        group: "[Channel2]"
    }

    // On the first start, pick the music folders
    Timer {
        id: firstRun

        interval: 1500
        onTriggered: folderSetup.open()
    }

    // Turning the browse knob of a controller opens the library; LOAD
    // loads and closes it
    LibraryComponent.Control {
        enabled: !library.visible && !folderSetup.visible

        onMoveVertical: offset => library.open("")
        onLoadSelectedTrack: (group, play) => {}
        onLoadSelectedTrackIntoNextAvailableDeck: play => {}
    }

    // An effect turned on from a controller opens the FX pad of its deck,
    // and it closes again a moment after all its effects are off
    // Effects switched on while the app starts don't open the pad
    property bool fxArmed: false
    Timer {
        interval: 4000
        running: true
        onTriggered: root.fxArmed = true
    }
    property bool fxAuto1: false
    property bool fxAuto2: false
    function fxStateChanged(deck) {
        if (!root.fxArmed) {
            return;
        }
        const on = deck === 1
            ? [fxSlot11, fxSlot12, fxSlot13].some(c => c.value > 0)
            : [fxSlot21, fxSlot22, fxSlot23].some(c => c.value > 0);
        const group = deck === 1 ? "[Channel1]" : "[Channel2]";
        const open = deck === 1 ? (root.tools1 && root.tool1 === 3) : (root.tools2 && root.tool2 === 3);
        if (on) {
            (deck === 1 ? fxClose1 : fxClose2).stop();
            if (!open && !root.portrait) {
                root.openTool(group, 3);
                if (deck === 1) {
                    root.fxAuto1 = true;
                } else {
                    root.fxAuto2 = true;
                }
            } else if (root.portrait && !toolsSheet.visible) {
                toolsSheet.group = group;
                toolsSheet.open();
            }
        } else if (deck === 1 ? root.fxAuto1 : root.fxAuto2) {
            (deck === 1 ? fxClose1 : fxClose2).restart();
        }
    }
    Timer {
        id: fxClose1

        interval: 2500
        onTriggered: {
            if (root.fxAuto1) {
                root.tools1 = false;
                root.fxAuto1 = false;
            }
        }
    }
    Timer {
        id: fxClose2

        interval: 2500
        onTriggered: {
            if (root.fxAuto2) {
                root.tools2 = false;
                root.fxAuto2 = false;
            }
        }
    }
    Mixxx.ControlProxy {
        id: fxSlot11

        group: "[EffectRack1_EffectUnit1_Effect1]"
        key: "enabled"
        onValueChanged: root.fxStateChanged(1)
    }
    Mixxx.ControlProxy {
        id: fxSlot12

        group: "[EffectRack1_EffectUnit1_Effect2]"
        key: "enabled"
        onValueChanged: root.fxStateChanged(1)
    }
    Mixxx.ControlProxy {
        id: fxSlot13

        group: "[EffectRack1_EffectUnit1_Effect3]"
        key: "enabled"
        onValueChanged: root.fxStateChanged(1)
    }
    Mixxx.ControlProxy {
        id: fxSlot21

        group: "[EffectRack1_EffectUnit2_Effect1]"
        key: "enabled"
        onValueChanged: root.fxStateChanged(2)
    }
    Mixxx.ControlProxy {
        id: fxSlot22

        group: "[EffectRack1_EffectUnit2_Effect2]"
        key: "enabled"
        onValueChanged: root.fxStateChanged(2)
    }
    Mixxx.ControlProxy {
        id: fxSlot23

        group: "[EffectRack1_EffectUnit2_Effect3]"
        key: "enabled"
        onValueChanged: root.fxStateChanged(2)
    }
    // The FX button of the Mixtour turns the quick effect of its channel on
    function quickFxChanged(deck, on) {
        if (!root.fxArmed) {
            return;
        }
        const group = deck === 1 ? "[Channel1]" : "[Channel2]";
        if (on) {
            if (!root.portrait) {
                root.openTool(group, 3);
                if (deck === 1) {
                    root.fxAuto1 = true;
                } else {
                    root.fxAuto2 = true;
                }
            }
        } else {
            root.fxStateChanged(deck);
        }
    }
    Mixxx.ControlProxy {
        group: "[QuickEffectRack1_[Channel1]]"
        key: "enabled"
        onValueChanged: root.quickFxChanged(1, value > 0)
    }
    Mixxx.ControlProxy {
        group: "[QuickEffectRack1_[Channel2]]"
        key: "enabled"
        onValueChanged: root.quickFxChanged(2, value > 0)
    }
    // A mapping can also ask for the pad directly
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: "fx_open1"
        onValueChanged: {
            if (value > 0) {
                root.openTool("[Channel1]", 3);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: "fx_open2"
        onValueChanged: {
            if (value > 0) {
                root.openTool("[Channel2]", 3);
            }
        }
    }
    property bool showDiagnostics: Mixxx.Application.configValue("[Cutlab]", "diagnostics", "0") === "1"
    Mixxx.ControlProxy {
        id: fxRoute1

        group: "[EffectRack1_EffectUnit1]"
        key: "group_[Channel1]_enable"
    }
    Mixxx.ControlProxy {
        id: fxRoute2

        group: "[EffectRack1_EffectUnit2]"
        key: "group_[Channel2]_enable"
    }
    Mixxx.ControlProxy {
        id: fxMix1

        group: "[EffectRack1_EffectUnit1]"
        key: "mix"
    }
    Mixxx.ControlProxy {
        id: fxMix2

        group: "[EffectRack1_EffectUnit2]"
        key: "mix"
    }

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
            text: root.deckStyle === "dial" ? qsTr("Show turntables") : qsTr("Show tempo dials")
            onTriggered: root.setDeckStyle(root.deckStyle === "dial" ? "vinyl" : "dial")
        }
        CLMenuItem {
            text: qsTr("Elegir mis carpetas de música…")
            onTriggered: folderSetup.open()
        }
        CLMenuItem {
            text: root.showDiagnostics ? qsTr("Ocultar el diagnóstico") : qsTr("Mostrar el diagnóstico")
            onTriggered: {
                root.showDiagnostics = !root.showDiagnostics;
                Mixxx.Application.setConfigValue("[Cutlab]", "diagnostics", root.showDiagnostics ? "1" : "0");
            }
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
                            visible: !root.tools1 || root.tool1 === 3
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
                            active: root.tools1 && root.tool1 !== 3
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
                            visible: !root.tools2 || root.tool2 === 3
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
                            active: root.tools2 && root.tool2 !== 3
                            sourceComponent: ToolPanel {
                                group: "[Channel2]"
                                tool: root.tool2
                                onToolChanged: root.tool2 = tool
                                onCloseRequested: root.tools2 = false
                            }
                        }
                    }
                }

                // ----- Both waveforms and the phase meter -----
                Loader {
                    anchors.fill: parent
                    active: root.view === 1
                    sourceComponent: HorizontalWaves {}
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

    // The FX pad of a deck over its half of the screen, big enough to play
    // with the hand; the other deck keeps running on the other half
    Repeater {
        model: ["[Channel1]", "[Channel2]"]

        Loader {
            id: fxHalf

            required property string modelData
            required property int index
            readonly property bool open: (index === 0 ? root.tools1 && root.tool1 === 3 : root.tools2 && root.tool2 === 3)
                && !root.portrait

            x: index === 0 ? 0 : root.width / 2
            y: topBar.height
            width: root.width / 2
            height: root.height - topBar.height
            z: 5
            active: open
            sourceComponent: Rectangle {
                color: Style.panel
                border.width: 1
                border.color: Style.divider

                Rectangle {
                    id: fxHeader

                    width: parent.width
                    height: 34
                    color: Style.panelDark

                    Rectangle {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 18
                        radius: 4
                        color: Style.deckColor(fxHalf.modelData)

                        Text {
                            anchors.centerIn: parent
                            color: Style.background
                            font.family: Style.mono
                            font.weight: Font.Bold
                            font.pixelSize: 11
                            text: Style.deckLetter(fxHalf.modelData)
                        }
                    }
                    Text {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        color: Style.text
                        font.family: Style.font
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        text: qsTr("FX %1").arg(fxHalf.index + 1)
                    }
                    CLButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 34
                        icon: "close"
                        iconSize: 16
                        bordered: false
                        fillColor: "transparent"
                        onClicked: {
                            if (fxHalf.index === 0) {
                                root.tools1 = false;
                                root.fxAuto1 = false;
                            } else {
                                root.tools2 = false;
                                root.fxAuto2 = false;
                            }
                        }
                    }
                }
                FxPad {
                    anchors.top: fxHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    group: fxHalf.modelData
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
            onToolsRequested: group => {
                toolsSheet.group = group;
                toolsSheet.open();
            }
            onMenuRequested: anchor => moreMenu.popup(anchor, 0, anchor.height)
        }
    }

    // All the tools of a deck (FX first) over the upright layout
    Popup {
        id: toolsSheet

        property string group: "[Channel1]"

        x: 0
        y: parent.height - height
        width: parent.width
        height: Math.min(parent.height * 0.62, 520)
        modal: true
        padding: 0
        background: Rectangle {
            color: Style.panel
            radius: 16
        }
        contentItem: ToolPanel {
            group: toolsSheet.group
            tool: 3
            onCloseRequested: toolsSheet.close()
        }
    }

    LibraryBrowser {
        id: library

        anchors.fill: parent
        visible: false
        z: 10
        onCloseRequested: visible = false
        onFoldersRequested: folderSetup.open()
        onSettingsRequested: {
            visible = false;
            root.settingsRequested();
        }
        onAutoDJRequested: root.autoDJRequested()
    }

    FolderSetup {
        id: folderSetup

        anchors.fill: parent
        visible: false
        z: 20
        onDone: library.showSection(0)
    }

    Diagnostics {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        visible: root.showDiagnostics
        z: 30
    }
}
