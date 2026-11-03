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
    // The waveforms by default, like djay; the last one picked is kept
    property int view: parseInt(Mixxx.Application.configValue("[Cutlab]", "view", "1"))
    onViewChanged: Mixxx.Application.setConfigValue("[Cutlab]", "view", root.view.toString())
    property bool tools1: false
    // The mode of the pads view: 0 samples, 1 hot cues, 2 rolls, 3 Scratch Bank
    property int padsMode: 0
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

    // BPM, key and waveform of the tracks never played, in the background a
    // while after the start, so the library shows them without playing them
    Timer {
        interval: 20000
        running: Mixxx.Application.configValue("[Cutlab]", "auto_analyze", "1") === "1"
        onTriggered: Mixxx.Cutlab.analyzeMissing()
    }

    // ---- Stems by themselves: every track loaded on a deck is separated in
    // the background (on the phone, without internet) when it has no stems
    property bool stemsAuto: Mixxx.Application.configValue("[Cutlab]", "stems_auto", "0") === "1"
    function setStemsAuto(on) {
        root.stemsAuto = on;
        Mixxx.Application.setConfigValue("[Cutlab]", "stems_auto", on ? "1" : "0");
    }
    function stemModel() {
        return Mixxx.Stems.defaultModel === "htdemucs" && Mixxx.Stems.htdemucsInstalled ? "htdemucs" : "spleeter";
    }
    function separateLoaded(group) {
        const player = Mixxx.PlayerManager.getPlayer(group);
        const track = player ? player.currentTrack : null;
        if (!root.stemsAuto || !track || !Mixxx.Stems.spleeterInstalled && root.stemModel() === "spleeter") {
            return;
        }
        const url = track.trackLocationUrl;
        if (url.toString() !== "" && !Mixxx.Stems.hasStems(url)) {
            Mixxx.Stems.separateTrack(url, root.stemModel(), false);
        }
    }
    Repeater {
        model: ["[Channel1]", "[Channel2]"]

        Item {
            id: autoStems

            required property string modelData

            Mixxx.ControlProxy {
                group: autoStems.modelData
                key: "track_loaded"
                onValueChanged: {
                    if (value > 0) {
                        // Once the deck has its track
                        Qt.callLater(root.separateLoaded, autoStems.modelData);
                    }
                }
            }
        }
    }

    // ---- The light screen, for phones that lag: no scrolling waveforms,
    // bigger platters, fewer animations
    property bool lite: Mixxx.Application.configValue("[Cutlab]", "lite", "0") === "1"
    function setLite(on) {
        root.lite = on;
        Mixxx.Application.setConfigValue("[Cutlab]", "lite", on ? "1" : "0");
        Mixxx.Application.setConfigValue("[Cutlab]", "fx_visuals_lite", on ? "1" : "0");
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

        onMoveVertical: offset => root.openLibrary("")
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
        if (folderSetup.visible) {
            return;
        }
        if (Mixxx.Application.configValue("[Cutlab]", "folders_done", "0") !== "1") {
            folderSetup.open();
            return;
        }
        if (library.visible) {
            library.targetGroup = group || "";
            return;
        }
        library.open(group);
    }
    // FX SLOT 1, 2, 3 of a controller pick the effect of the FX pad and the
    // BEAT FX lever plays it; both open the pad of the deck
    Repeater {
        model: 2

        Item {
            id: fxControls

            required property int index
            readonly property string group: index === 0 ? "[Channel1]" : "[Channel2]"

            Mixxx.ControlProxy {
                group: "[Cutlab]"
                key: `fx_select${fxControls.index + 1}`
                onValueChanged: {
                    if (value <= 0) {
                        return;
                    }
                    Shots.selectBank(fxControls.group, Math.floor(value / 1000) - 1);
                    root.showFxPad(fxControls.group);
                }
            }
            Mixxx.ControlProxy {
                group: "[Cutlab]"
                key: `fx_on${fxControls.index + 1}`
                onValueChanged: {
                    const on = value > 0;
                    if (fxControls.index === 0) {
                        Shots.engaged1 = on;
                    } else {
                        Shots.engaged2 = on;
                    }
                    if (on) {
                        root.showFxPad(fxControls.group);
                    }
                }
            }
        }
    }
    function showFxPad(group) {
        const deck = group === "[Channel2]" ? 2 : 1;
        (deck === 1 ? fxClose1 : fxClose2).stop();
        if (root.portrait) {
            if (!toolsSheet.visible) {
                toolsSheet.group = group;
                toolsSheet.open();
            }
            return;
        }
        const open = deck === 1 ? (root.tools1 && root.tool1 === 3) : (root.tools2 && root.tool2 === 3);
        if (!open) {
            root.openTool(group, 3);
            if (deck === 1) {
                root.fxAuto1 = true;
            } else {
                root.fxAuto2 = true;
            }
        }
    }

    // The browse knob of a controller was pressed
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: "browse_press"
        onValueChanged: {
            if (library.visible) {
                library.browsePress();
            } else {
                root.openLibrary("");
            }
        }
    }
    function openQueue() {
        library.open("");
        library.showSection(3);
    }
    function toggleLibrary() {
        if (library.visible) {
            library.close();
        } else {
            root.openLibrary("");
        }
    }
    function openToolsSheet(group, tool) {
        toolsSheet.group = group;
        toolsSheet.tool = tool;
        toolsSheet.open();
    }
    function openTool(group, tool) {
        // Only the FX pad opens over the screen; stems, cues, loops and EQ
        // come up from below
        if (tool !== 3) {
            root.openToolsSheet(group, tool);
            return;
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

    // ===== The main screen held sideways, as in the design =====
    Loader {
        id: mainLandscape

        anchors.fill: parent
        active: !root.portrait
        sourceComponent: MainLandscape {
            recording: recording.value > 0
            lite: root.lite
            onLibraryRequested: group => root.openLibrary(group)
            onMenuRequested: anchor => moreMenu.popup(anchor, 0, anchor.height)
            onRecordRequested: {
                toggleRecording.value = 1;
                toggleRecording.value = 0;
            }
            onFxRequested: group => root.showFxPad(group)
        }
    }

    // Pads, hot cues, rolls and the Scratch Bank over the whole screen
    Rectangle {
        id: padsOverlay

        anchors.fill: parent
        visible: false
        z: 6
        color: Style.background

        Loader {
            anchors.fill: parent
            anchors.topMargin: 48
            active: padsOverlay.visible
            sourceComponent: PadsTab {
                mode: root.padsMode
                onModeChanged: root.padsMode = mode
                onLoadSampleRequested: group => root.openLibrary(group)
            }
        }
        Text {
            x: 16
            y: 14
            color: Style.text
            font.family: Style.font
            font.pixelSize: 18
            font.weight: Font.Bold
            text: qsTr("Pads")
        }
        CLButton {
            anchors.right: parent.right
            anchors.rightMargin: 8
            y: 2
            width: 44
            height: 44
            icon: "close"
            iconSize: 18
            bordered: false
            fillColor: "transparent"
            onClicked: padsOverlay.visible = false
        }
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
            text: qsTr("Scratch Bank")
            onTriggered: {
                root.padsMode = 3;
                padsOverlay.visible = true;
            }
        }
        CLMenuItem {
            text: qsTr("Pads, samples y rolls")
            onTriggered: {
                root.padsMode = 0;
                padsOverlay.visible = true;
            }
        }
        CLMenuItem {
            text: qsTr("Stems, EQ y loops de A")
            onTriggered: root.openToolsSheet("[Channel1]", 0)
        }
        CLMenuItem {
            text: qsTr("Stems, EQ y loops de B")
            onTriggered: root.openToolsSheet("[Channel2]", 0)
        }
        CLMenuItem {
            text: root.stemsAuto ? qsTr("Separar stems solos: prendido") : qsTr("Separar stems solos: apagado")
            onTriggered: root.setStemsAuto(!root.stemsAuto)
        }
        CLMenuItem {
            text: root.lite ? qsTr("Pantalla liviana: prendida") : qsTr("Pantalla liviana: apagada")
            onTriggered: root.setLite(!root.lite)
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

    // The FX pad of a deck, as in the design: it takes most of the screen on
    // the side of its deck and the other deck keeps running, reduced, on the
    // other side; with both pads open each one takes half
    readonly property bool fxOpen1: root.tools1 && root.tool1 === 3 && !root.portrait
    readonly property bool fxOpen2: root.tools2 && root.tool2 === 3 && !root.portrait
    readonly property real fxU: Math.max(0.55, Math.min(root.width / 1284, root.height / 600))
    Item {
        id: fxScreen

        anchors.fill: parent
        visible: root.fxOpen1 || root.fxOpen2
        z: 5

        readonly property real padWidth: root.fxOpen1 && root.fxOpen2 ? width / 2 : Math.round(width * 820 / 1284)

        MouseArea {
            anchors.fill: parent
        }
        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Loader {
                id: fxHalf

                required property string modelData
                required property int index
                readonly property bool open: index === 0 ? root.fxOpen1 : root.fxOpen2
                readonly property bool otherOpen: index === 0 ? root.fxOpen2 : root.fxOpen1

                x: index === 0 ? 0 : fxScreen.width - width
                width: open ? fxScreen.padWidth : fxScreen.width - fxScreen.padWidth
                height: fxScreen.height
                active: open || otherOpen
                sourceComponent: open ? padComponent : sideComponent

                Component {
                    id: sideComponent

                    DeckSide {
                        group: fxHalf.modelData
                        u: root.fxU
                    }
                }
                Component {
                    id: padComponent

                    Rectangle {
                        color: Style.panel

                        Rectangle {
                            anchors.right: fxHalf.index === 0 ? parent.right : undefined
                            width: 1
                            height: parent.height
                            color: Qt.rgba(1, 1, 1, 0.07)
                        }
                        Item {
                            id: fxHeader

                            x: Math.round(16 * root.fxU)
                            y: Math.round(12 * root.fxU)
                            width: parent.width - 2 * x
                            height: Math.round(44 * root.fxU)

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Math.round(10 * root.fxU)

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: fxLetter.implicitWidth + 14
                                    height: fxLetter.implicitHeight + 4
                                    radius: 4
                                    color: Style.deckColor(fxHalf.modelData)

                                    Text {
                                        id: fxLetter

                                        anchors.centerIn: parent
                                        color: Style.background
                                        font.family: Style.mono
                                        font.weight: Font.Bold
                                        font.pixelSize: Math.max(9, Math.round(11 * root.fxU))
                                        text: Style.deckLetter(fxHalf.modelData)
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Style.text
                                    font.family: Style.font
                                    font.weight: Font.Bold
                                    font.pixelSize: Math.max(12, Math.round(20 * root.fxU))
                                    text: qsTr("FX %1").arg(fxHalf.index + 1)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Style.textSecondary
                                    font.family: Style.font
                                    font.pixelSize: Math.max(9, Math.round(13 * root.fxU))
                                    text: (fxHalf.index === 0 ? root.fxAuto1 : root.fxAuto2)
                                        ? qsTr("Lo abriste con FX ON · se cierra al apagarlo") : qsTr("Tocá y arrastrá en el pad")
                                }
                            }
                            CLButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(44 * root.fxU)
                                height: width
                                radius: Math.round(10 * root.fxU)
                                icon: "close"
                                iconSize: width * 0.4
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
                            anchors.leftMargin: Math.round(8 * root.fxU)
                            anchors.rightMargin: Math.round(8 * root.fxU)
                            anchors.bottomMargin: Math.round(8 * root.fxU)
                            group: fxHalf.modelData
                            u: root.fxU
                        }
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
            lite: root.lite
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
        property int tool: 3

        contentItem: ToolPanel {
            group: toolsSheet.group
            tool: toolsSheet.tool
            onToolChanged: toolsSheet.tool = tool
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
