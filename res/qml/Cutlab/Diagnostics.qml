import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Window

// Measures how the app runs, to tune it with numbers: frames per second of
// the screen, latency of the audio (what DVS feels), how loaded the audio
// engine is and how many times it ran late (a click or a cut in the sound).
Rectangle {
    id: root

    property int frames: 0
    property int fps: 0
    // The longest gap between two frames in the last second, and how many
    // frames came late (more than one and a half frames of the screen)
    property real lastFrame: 0
    property real worstNow: 0
    property real worst: 0
    property int lateNow: 0
    property int late: 0
    readonly property real hz: root.Screen.refreshRate > 0 ? root.Screen.refreshRate : 60

    implicitWidth: column.implicitWidth + 20
    implicitHeight: column.implicitHeight + 14
    radius: 10
    color: Qt.rgba(0.03, 0.02, 0.06, 0.88)
    border.width: 1
    border.color: Style.buttonBorder

    Connections {
        target: root.Window.window
        enabled: root.visible

        function onFrameSwapped() {
            root.frames += 1;
            const now = Date.now();
            if (root.lastFrame > 0) {
                const gap = now - root.lastFrame;
                root.worstNow = Math.max(root.worstNow, gap);
                if (gap > 1.5 * 1000 / root.hz) {
                    root.lateNow += 1;
                }
            }
            root.lastFrame = now;
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: {
            root.fps = root.frames;
            root.frames = 0;
            root.worst = root.worstNow;
            root.worstNow = 0;
            root.late = root.lateNow;
            root.lateNow = 0;
        }
    }
    // Keeps the screen drawing so the count means something
    Rectangle {
        width: 4
        height: 4
        color: "transparent"
        RotationAnimation on rotation {
            running: root.visible
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1000
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
            model: [
                {label: qsTr("Pantalla"), value: root.fps + " fps · " + Math.round(root.hz) + " Hz", good: root.fps >= root.hz * 0.92},
                {label: qsTr("Peor cuadro"), value: Math.round(root.worst) + " ms", good: root.worst <= 1.6 * 1000 / root.hz},
                {label: qsTr("Cuadros tarde"), value: root.late + " /s", good: root.late < 1},
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
    }
}
