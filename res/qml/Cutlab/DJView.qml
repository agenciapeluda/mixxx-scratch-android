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

    signal settingsRequested
    signal autoDJRequested
    signal classicLayoutRequested
    signal xyPadRequested

    color: Style.background

    // Where the focus goes back when a menu, a sheet or the library closes.
    // Without it Qt gives it back to the last field that had it, the hidden
    // search of the library, and Android opens the keyboard.
    Item {
        id: focusSink

        focus: true
    }
    function releaseFocus() {
        focusSink.forceActiveFocus();
        Qt.inputMethod.hide();
    }

    // Effect unit 1 plays on deck 1 and unit 2 on deck 2, like the FX of
    // djay: an effect is heard as soon as it is on, from the screen or from
    // a controller
    Component.onCompleted: {
        // RGB waveforms once, as the new default (after that, what you pick
        // in the settings stays)
        if (Mixxx.Application.configValue("[Cutlab]", "rgb_default", "0") !== "1") {
            Mixxx.Config.waveformType = Mixxx.WaveformDisplay.Type.RGB;
            Mixxx.Application.setConfigValue("[Cutlab]", "rgb_default", "1");
        }
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
    // Never while a deck plays: it waits until both are stopped
    Timer {
        interval: 60000
        repeat: true
        running: Mixxx.Application.configValue("[Cutlab]", "auto_analyze", "1") === "1"
        onTriggered: {
            if (playing1.value <= 0 && playing2.value <= 0) {
                Mixxx.Cutlab.analyzeMissing();
                stop();
            }
        }
    }
    Mixxx.ControlProxy {
        id: playing1

        group: "[Channel1]"
        key: "play_latched"
    }
    Mixxx.ControlProxy {
        id: playing2

        group: "[Channel2]"
        key: "play_latched"
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

    // ---- Keylock on by default: changing the tempo keeps the key
    // (time-stretching), like djay and Serato. KEY next to the hot cues
    // turns it off
    Repeater {
        model: Mixxx.Application.configValue("[Cutlab]", "keylock_default", "1") === "1" ? ["[Channel1]", "[Channel2]"] : []

        Item {
            id: keylockDefault

            required property string modelData

            Mixxx.ControlProxy {
                id: keylock

                group: keylockDefault.modelData
                key: "keylock"
            }
            Component.onCompleted: keylock.value = 1
        }
    }

    // ---- The light screen, for phones that lag: no scrolling waveforms,
    // bigger platters, fewer animations
    // The look of the main screen: "onda" like djay (the waveforms upright
    // in the middle) or "dial" like Serato (big dials, the waveforms one
    // above the other). Only the one on screen is loaded. Upright, Dial is
    // the light screen (platters, no scrolling waveforms).
    property string mainView: Mixxx.Application.configValue("[Cutlab]", "main_view", "onda") === "dial" ? "dial" : "onda"
    readonly property bool lite: root.mainView === "dial"
    function setMainView(look) {
        root.mainView = look;
        Mixxx.Application.setConfigValue("[Cutlab]", "main_view", look);
    }
    function setView(index) {
        root.view = index;
    }

    // The tools of a deck open in its half (FX too): the waveforms stay
    function toggleTools(group) {
        const open = group === "[Channel2]" ? root.tools2 : root.tools1;
        if (open) {
            root.closeTools(group);
        } else {
            root.openTool(group, group === "[Channel2]" ? root.tool2 : root.tool1);
        }
    }
    function setTool(group, tool) {
        if (group === "[Channel2]") {
            root.tool2 = tool;
        } else {
            root.tool1 = tool;
        }
    }
    function closeTools(group) {
        if (group === "[Channel2]") {
            root.tools2 = false;
            root.fxAuto2 = false;
        } else {
            root.tools1 = false;
            root.fxAuto1 = false;
        }
    }

    // On the first start, pick the music folders
    Timer {
        id: firstRun

        interval: 1500
        onTriggered: folderSetup.open()
    }

    // Turning the browse knob of a controller opens the library; LOAD
    // loads and closes it
    // The browse knob with the library closed: in the menu it moves and
    // picks, in the music folders it moves and LOAD builds the library,
    // elsewhere it opens the library. The settings handle it themselves.
    Mixxx.ControlProxy {
        id: modalOpen

        group: "[Cutlab]"
        key: "modal_open"
    }
    LibraryComponent.Control {
        enabled: !library.visible && modalOpen.value <= 0

        onMoveVertical: offset => {
            if (mainMenu.opened) {
                mainMenu.move(offset > 0 ? 1 : -1);
            } else if (folderSetup.visible) {
                folderSetup.knobMove(offset);
            } else {
                root.openLibrary("");
            }
        }
        onLoadSelectedTrack: (group, play) => {
            if (mainMenu.opened) {
                mainMenu.close();
            } else if (folderSetup.visible) {
                folderSetup.apply();
            }
        }
        onLoadSelectedTrackIntoNextAvailableDeck: play => {
            if (folderSetup.visible) {
                folderSetup.apply();
            }
        }
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
            if (modalOpen.value > 0) {
                return;
            }
            if (mainMenu.opened) {
                mainMenu.activate();
            } else if (folderSetup.visible) {
                folderSetup.knobPress();
            } else if (library.visible) {
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
        // Upright, the tools come up from below
        if (root.portrait) {
            root.openToolsSheet(group, tool);
            return;
        }
        if (root.view === 2) {
            root.view = 1;
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

    // ---- The structure of the track on each deck (drops, breaks), read
    // once per track and shared by the top bar, the platters and the beat
    // lights
    TrackSections {
        id: sectionsA

        group: "[Channel1]"
    }
    TrackSections {
        id: sectionsB

        group: "[Channel2]"
    }

    // ---- Hot cues in the Cutlab colors, one per number
    HotcueColors {
        group: "[Channel1]"
    }
    HotcueColors {
        group: "[Channel2]"
    }

    // ---- Recientes: a track that sounds for 30 seconds goes to the history
    // (and its play count goes up), once per load
    Repeater {
        model: ["[Channel1]", "[Channel2]"]

        Item {
            id: playedLog

            required property string modelData
            property int seconds: 0
            property bool logged: false

            Mixxx.ControlProxy {
                id: logLoaded

                group: playedLog.modelData
                key: "track_loaded"
                onValueChanged: {
                    playedLog.seconds = 0;
                    playedLog.logged = false;
                }
            }
            Mixxx.ControlProxy {
                id: logPlay

                group: playedLog.modelData
                key: "play"
            }
            Mixxx.ControlProxy {
                id: logVolume

                group: playedLog.modelData
                key: "volume"
            }
            Timer {
                interval: 1000
                repeat: true
                running: !playedLog.logged && logLoaded.value > 0 && logPlay.value > 0 && logVolume.value > 0.05
                onTriggered: {
                    playedLog.seconds += 1;
                    if (playedLog.seconds >= 30) {
                        playedLog.logged = Mixxx.Cutlab.markPlayed(playedLog.modelData);
                        if (!playedLog.logged) {
                            playedLog.seconds = 0;
                        }
                    }
                }
            }
        }
    }

    // ===== The main screen held sideways =====
    Loader {
        id: mainLandscape

        anchors.fill: parent
        active: !root.portrait
        sourceComponent: MainLandscape {
            host: root
            recording: recording.value > 0
            sections1: sectionsA
            sections2: sectionsB
            onLibraryRequested: group => root.openLibrary(group)
            onMenuRequested: mainMenu.open()
        }
    }

    // Pads, hot cues, rolls and the Scratch Bank over the whole screen
    Rectangle {
        id: padsOverlay

        anchors.fill: parent
        visible: false
        z: 6
        color: Style.background
        onVisibleChanged: root.releaseFocus()

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

    // The menu of the mark: the look of the screen and big tiles
    MainMenu {
        id: mainMenu

        recording: recording.value > 0
        mainView: root.mainView
        stemsAuto: root.stemsAuto
        diagnostics: root.showDiagnostics
        onClosed: root.releaseFocus()
        onPicked: key => {
            if (key === "view_onda" || key === "view_dial") {
                root.setMainView(key === "view_dial" ? "dial" : "onda");
            } else if (key === "autodj") {
                root.autoDJRequested();
            } else if (key === "record") {
                toggleRecording.value = 1;
                toggleRecording.value = 0;
            } else if (key === "pads") {
                if (root.portrait) {
                    root.padsMode = 0;
                    padsOverlay.visible = true;
                } else {
                    root.setView(2);
                }
            } else if (key === "library") {
                root.openLibrary("");
            } else if (key === "stems") {
                root.setStemsAuto(!root.stemsAuto);
            } else if (key === "folders") {
                folderSetup.open();
            } else if (key === "diagnostics") {
                root.showDiagnostics = !root.showDiagnostics;
                Mixxx.Application.setConfigValue("[Cutlab]", "diagnostics", root.showDiagnostics ? "1" : "0");
            } else if (key === "settings") {
                root.settingsRequested();
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
            onMenuRequested: anchor => mainMenu.open()
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

        onClosed: root.releaseFocus()

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
        onCloseRequested: {
            visible = false;
            root.releaseFocus();
        }
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
