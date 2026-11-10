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

    implicitWidth: column.implicitWidth + 20
    implicitHeight: column.implicitHeight + 14
    radius: 10
    color: Qt.rgba(0.03, 0.02, 0.06, 0.88)
    border.width: 1
    border.color: Style.buttonBorder

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

    Column {
        id: column

        x: 10
        y: 7
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
                {label: qsTr("Latencia del audio"), value: Math.round(latency.value) + " ms", good: latency.value <= 25},
                {label: qsTr("Carga del audio"), value: Math.round(usage.value) + " %", good: usage.value < 70},
                {label: qsTr("Cortes de audio"), value: String(Math.round(overloads.value)), good: overloads.value < 1}
            ]

            Row {
                required property var modelData

                spacing: 10

                Text {
                    width: 128
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
        Text {
            width: 230
            color: Style.textDim
            font.family: Style.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            text: qsTr("Tiempos: promedio / peor del último segundo. Quieto, la pantalla descansa y los fps bajan: es normal.")
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
}
