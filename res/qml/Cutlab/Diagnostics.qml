import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Window

// Measures how the app runs, to tune it with numbers: frames per second of
// the screen, latency of the audio (what DVS feels), how loaded the audio
// engine is and how many times it ran late (a click or a cut in the sound).
Rectangle {
    id: root

    // Measured by the app for each frame (Cutlab.watchFrames), once a
    // second; also written to the log
    property var stats: ({})
    readonly property real hz: stats.hz > 0 ? stats.hz : (root.Screen.refreshRate > 0 ? root.Screen.refreshRate : 60)
    readonly property real frameMs: 1000 / root.hz
    function n(key) {
        return root.stats[key] !== undefined ? Number(root.stats[key]) : 0;
    }

    // Cutlab 1.32.0: the X in the corner closes it
    signal closeRequested()

    implicitWidth: column.implicitWidth + 20
    implicitHeight: column.implicitHeight + 51
    radius: 10
    color: Qt.rgba(0.03, 0.02, 0.06, 0.88)
    border.width: 1
    border.color: Style.buttonBorder

    // [AI-generated text, Claude (Anthropic) — start]
    // 1.31: the device of the main output, and whether it is Bluetooth:
    // 150-250 ms late, the jog wheel and the pads feel detached
    property string mainOutput: ""
    readonly property bool bluetooth: root.mainOutput.endsWith(": Bluetooth")
    function readMainOutput() {
        const manager = Mixxx.SoundManager;
        if (!manager) {
            return;
        }
        const devices = manager.availableOutputDevices(manager.getAPI()) || [];
        for (const device of devices) {
            const connections = device.connections(manager) || [];
            for (const connection of connections) {
                // 0: Main
                if (connection.type === 0) {
                    root.mainOutput = device.displayName;
                    return;
                }
            }
        }
        root.mainOutput = "";
    }
    Timer {
        interval: 3000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.readMainOutput()
    }
    // [AI-generated text, Claude (Anthropic) — end]
    onVisibleChanged: Mixxx.Cutlab.watchFrames(root.Window.window, root.visible)
    Component.onCompleted: if (root.visible) Mixxx.Cutlab.watchFrames(root.Window.window, true)
    Connections {
        target: Mixxx.Cutlab

        function onFrameStats(stats) {
            root.stats = stats;
        }
    }

    Mixxx.ControlProxy {
        id: latency

        group: "[App]"
        key: "output_latency_ms"
    }
    Mixxx.ControlProxy {
        id: usage

        group: "[App]"
        key: "audio_latency_usage"
    }
    Mixxx.ControlProxy {
        id: overloads

        group: "[App]"
        key: "audio_latency_overload_count"
    }

    // ---- Cuts of the audio, counted one by one (1.30) ----
    // Every late buffer ([App] cutlab_xruns) and every short input of the
    // DVS (cutlab_input_xruns), and how they split: right after loading a
    // track (5 s), with the DVS on or off, with or without stems on a deck.
    // Counted from "Poner en cero" (or the start).
    property real xrunBase: 0
    property real inputBase: 0
    property int xrunsAfterLoad: 0
    property int xrunsDvsOn: 0
    property int xrunsDvsOff: 0
    property int xrunsStems: 0
    property int xrunsNoStems: 0
    property real lastLoadAt: 0
    readonly property int xruns: Math.max(0, Math.round(xrunCount.value - root.xrunBase))
    readonly property int inputXruns: Math.max(0, Math.round(inputXrunCount.value - root.inputBase))
    readonly property bool dvsOn: dvs1.value > 0 || dvs2.value > 0
    readonly property bool stemsLoaded: stems1.value > 0 || stems2.value > 0
    function resetXruns() {
        root.xrunBase = xrunCount.value;
        root.inputBase = inputXrunCount.value;
        root.xrunsAfterLoad = 0;
        root.xrunsDvsOn = 0;
        root.xrunsDvsOff = 0;
        root.xrunsStems = 0;
        root.xrunsNoStems = 0;
    }
    function countCut() {
        if (Date.now() - root.lastLoadAt < 5000) {
            root.xrunsAfterLoad += 1;
        }
        if (root.dvsOn) {
            root.xrunsDvsOn += 1;
        } else {
            root.xrunsDvsOff += 1;
        }
        if (root.stemsLoaded) {
            root.xrunsStems += 1;
        } else {
            root.xrunsNoStems += 1;
        }
    }
    Mixxx.ControlProxy {
        id: xrunCount

        group: "[App]"
        key: "cutlab_xruns"
        onValueChanged: root.countCut()
    }
    Mixxx.ControlProxy {
        id: inputXrunCount

        group: "[App]"
        key: "cutlab_input_xruns"
        onValueChanged: root.countCut()
    }
    Mixxx.ControlProxy {
        id: dvs1

        group: "[Channel1]"
        key: "vinylcontrol_enabled"
    }
    Mixxx.ControlProxy {
        id: dvs2

        group: "[Channel2]"
        key: "vinylcontrol_enabled"
    }
    Mixxx.ControlProxy {
        id: stems1

        group: "[Channel1]"
        key: "stem_count"
    }
    Mixxx.ControlProxy {
        id: stems2

        group: "[Channel2]"
        key: "stem_count"
    }
    Mixxx.ControlProxy {
        group: "[Channel1]"
        key: "track_loaded"
        onValueChanged: if (value > 0) root.lastLoadAt = Date.now()
    }
    Mixxx.ControlProxy {
        group: "[Channel2]"
        key: "track_loaded"
        onValueChanged: if (value > 0) root.lastLoadAt = Date.now()
    }

    Column {
        id: column

        x: 10
        // Cutlab 1.32.0: below the close button
        y: 44
        spacing: 2

        Repeater {
            // Frames: what the screen got; then where the time of a frame
            // goes: the interface thread (QML) blocked, syncing, recording
            // the frame, and presenting it (waiting for the GPU)
            model: [
                {label: qsTr("Pantalla"), value: root.n("fps") + " fps · " + Math.round(root.hz) + " Hz", good: root.n("fps") >= root.hz * 0.9},
                {label: qsTr("Peor cuadro"), value: root.n("worstMs").toFixed(1) + " ms", good: root.n("worstMs") <= 1.6 * root.frameMs},
                {label: qsTr("Cuadros tarde"), value: root.n("late") + " /s", good: root.n("late") < 1},
                {label: qsTr("Interfaz trabada"), value: root.n("guiStallMs").toFixed(1) + " ms", good: root.n("guiStallMs") <= root.frameMs},
                {label: qsTr("Sincronizar"), value: root.n("syncMs").toFixed(1) + " / " + root.n("syncMaxMs").toFixed(1) + " ms", good: root.n("syncMaxMs") <= root.frameMs * 0.3},
                {label: qsTr("Dibujar"), value: root.n("renderMs").toFixed(1) + " / " + root.n("renderMaxMs").toFixed(1) + " ms", good: root.n("renderMaxMs") <= root.frameMs * 0.5},
                {label: qsTr("Presentar (GPU)"), value: root.n("presentMs").toFixed(1) + " / " + root.n("presentMaxMs").toFixed(1) + " ms", good: root.n("presentMs") <= root.frameMs},
                {label: qsTr("Resolución"), value: root.stats.pixels || "", good: true},
                {label: qsTr("Análisis"), value: root.stats.analyzing ? (root.stats.analysisHeld ? qsTr("en pausa") : qsTr("corriendo")) : qsTr("no"), good: !root.stats.analyzing || root.stats.analysisHeld},
                {label: qsTr("Salida"), value: root.bluetooth ? qsTr("Bluetooth: +150-250 ms, la rueda se siente despegada") : (root.mainOutput !== "" ? root.mainOutput : "—"), good: !root.bluetooth},
                {label: qsTr("Latencia del audio"), value: Math.round(latency.value) + " ms", good: latency.value <= 25},
                {label: qsTr("Carga del audio"), value: Math.round(usage.value) + " %", good: usage.value < 70},
                {label: qsTr("Cortes de audio"), value: String(root.xruns) + (root.inputXruns > 0 ? " · " + qsTr("entrada %1").arg(root.inputXruns) : ""), good: root.xruns + root.inputXruns < 1},
                {label: qsTr("Al cargar (5 s)"), value: String(root.xrunsAfterLoad), good: root.xrunsAfterLoad < 1},
                {label: qsTr("DVS prendido / apagado"), value: root.xrunsDvsOn + " / " + root.xrunsDvsOff, good: root.xrunsDvsOn + root.xrunsDvsOff < 1},
                {label: qsTr("Con stems / sin"), value: root.xrunsStems + " / " + root.xrunsNoStems, good: root.xrunsStems + root.xrunsNoStems < 1}
            ]

            Row {
                required property var modelData

                spacing: 10

                Text {
                    width: 150
                    color: Style.textSecondary
                    font.family: Style.font
                    font.pixelSize: 12
                    text: modelData.label
                }
                Text {
                    color: modelData.good ? Style.ok : Style.cue
                    font.family: Style.mono
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    text: modelData.value
                }
            }
        }
        // Frames per screen since the diagnostics opened: the worst one and
        // the share that came late
        Text {
            visible: (root.stats.screens || []).length > 0
            topPadding: 4
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 11
            font.weight: Font.DemiBold
            text: qsTr("POR PANTALLA · peor cuadro · tarde")
        }
        Repeater {
            model: root.stats.screens || []

            Row {
                required property var modelData

                spacing: 10

                Text {
                    width: 150
                    color: modelData.name === root.stats.screen ? Style.text : Style.textSecondary
                    font.family: Style.font
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    text: modelData.name
                }
                Text {
                    color: modelData.worstMs <= 1.6 * root.frameMs ? Style.ok : Style.cue
                    font.family: Style.mono
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    text: Number(modelData.worstMs).toFixed(1) + " ms · " + Number(modelData.latePct).toFixed(1) + " %"
                }
            }
        }
        Text {
            width: 230
            color: Style.textDim
            font.family: Style.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            text: qsTr("Tiempos: promedio / peor del último segundo. Quieto, la pantalla descansa y los fps bajan: es normal.")
        }
        Rectangle {
            width: zeroLabel.implicitWidth + 24
            height: 32
            radius: 8
            color: zeroMouse.pressed ? Style.buttonPressed : Style.raised

            Text {
                id: zeroLabel

                anchors.centerIn: parent
                color: Style.text
                font.family: Style.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                text: qsTr("Poner en cero los cortes")
            }
            MouseArea {
                id: zeroMouse

                anchors.fill: parent
                onClicked: root.resetXruns()
            }
        }
        Rectangle {
            width: shareLabel.implicitWidth + 24
            height: 32
            radius: 8
            color: shareMouse.pressed ? Style.accentDark : Style.accent

            Text {
                id: shareLabel

                anchors.centerIn: parent
                color: "#ffffff"
                font.family: Style.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                text: shareMouse.failed ? qsTr("No hay log para compartir") : qsTr("Compartir log")
            }
            MouseArea {
                id: shareMouse

                property bool failed: false

                anchors.fill: parent
                onClicked: failed = !Mixxx.Cutlab.shareLog()
            }
        }
    }

    // Cutlab 1.32.0: close
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: 44
        height: 44
        color: closeMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
        z: 5

        Image {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: "icons/close.svg"
            sourceSize.width: 40
            sourceSize.height: 40
        }
        MouseArea {
            id: closeMouse

            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }
}
