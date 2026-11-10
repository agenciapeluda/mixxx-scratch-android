import Mixxx 1.0 as Mixxx
import QtQuick

// What the dial shows, in a strip, for the extended waveforms with the pads
// hidden: the BPM as it plays (big), the track's own BPM and the pitch, the
// key, the time left, and whether loop and sync are on. Deck B is
// mirrored. The numbers are read 10 times a second, not on every frame.
Rectangle {
    id: root

    required property string group
    property bool mirrored: false

    readonly property bool loaded: trackLoaded.value > 0
    // Read by the timer
    property real bpmNow: 0
    property real bpmFile: 0
    property real pitch: 0
    property real remaining: 0
    readonly property real u: Math.max(0.7, Math.min(1.3, height / 64))

    radius: 10
    color: Style.raised

    function read() {
        root.bpmNow = bpm.value;
        root.bpmFile = fileBpm.value;
        root.pitch = (rateRatio.value - 1) * 100;
        root.remaining = Math.max(0, duration.value * (1 - Clock.position(root.group))) / Math.max(0.01, rateRatio.value);
    }
    // With the shared position reader, 15 times a second
    Connections {
        target: Clock
        enabled: root.visible && root.loaded

        function onTick() {
            root.read();
        }
    }
    onLoadedChanged: root.read()

    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: bpm

        group: root.group
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: fileBpm

        group: root.group
        key: "file_bpm"
    }
    Mixxx.ControlProxy {
        id: rateRatio

        group: root.group
        key: "rate_ratio"
    }
    Mixxx.ControlProxy {
        id: duration

        group: root.group
        key: "duration"
    }
    Mixxx.ControlProxy {
        id: keyControl

        group: root.group
        key: "key"
    }
    Mixxx.ControlProxy {
        id: loopEnabled

        group: root.group
        key: "loop_enabled"
    }
    Mixxx.ControlProxy {
        id: syncEnabled

        group: root.group
        key: "sync_enabled"
    }
    Mixxx.ControlProxy {
        id: endOfTrack

        group: root.group
        key: "end_of_track"
    }

    Row {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.mirrored ? undefined : parent.left
        anchors.right: root.mirrored ? parent.right : undefined
        anchors.leftMargin: Math.round(12 * root.u)
        anchors.rightMargin: Math.round(12 * root.u)
        layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight
        spacing: Math.round(18 * root.u)

        // BPM now, big; below the track's own and the pitch
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            Row {
                anchors.left: root.mirrored ? undefined : parent.left
                anchors.right: root.mirrored ? parent.right : undefined
                spacing: 4

                Text {
                    id: bpmText

                    color: Style.text
                    font.family: Style.mono
                    font.pixelSize: Math.round(28 * root.u)
                    font.weight: Font.Bold
                    text: root.loaded && root.bpmNow > 0 ? root.bpmNow.toFixed(1) : "--"
                }
                Text {
                    anchors.baseline: bpmText.baseline
                    color: Style.textDim
                    font.family: Style.font
                    font.pixelSize: Math.round(11 * root.u)
                    font.weight: Font.DemiBold
                    text: "BPM"
                }
            }
            Text {
                anchors.left: root.mirrored ? undefined : parent.left
                anchors.right: root.mirrored ? parent.right : undefined
                color: Math.abs(root.pitch) >= 0.05 ? Style.accentText : Style.textSecondary
                font.family: Style.mono
                font.pixelSize: Math.round(12 * root.u)
                text: root.loaded && root.bpmFile > 0
                    ? qsTr("orig. %1 · %2%3%").arg(root.bpmFile.toFixed(1)).arg(root.pitch >= 0 ? "+" : "").arg(root.pitch.toFixed(1))
                    : ""
            }
        }

        // Key
        Rectangle {
            readonly property string keyText: root.loaded && Mixxx.KeyUtils.keyIsValid(keyControl.value) ? Mixxx.KeyUtils.keyToString(keyControl.value) : ""

            anchors.verticalCenter: parent.verticalCenter
            visible: keyText !== ""
            width: keyLabel.implicitWidth + Math.round(16 * root.u)
            height: Math.round(28 * root.u)
            radius: height / 2
            color: "transparent"
            border.width: 1.5
            border.color: Style.keyColor(keyText)

            Text {
                id: keyLabel

                anchors.centerIn: parent
                color: Style.keyColor(parent.keyText)
                font.family: Style.font
                font.pixelSize: Math.round(15 * root.u)
                font.weight: Font.Bold
                text: parent.keyText
            }
        }

        // Time left
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: endOfTrack.value > 0 ? Style.danger : Style.text
            font.family: Style.mono
            font.pixelSize: Math.round(22 * root.u)
            font.weight: Font.Bold
            text: root.loaded ? "-" + Style.formatTime(root.remaining) : ""
        }

        // Loop and sync, only while on
        Row {
            anchors.verticalCenter: parent.verticalCenter
            layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight
            spacing: 6

            Repeater {
                model: [
                    {text: qsTr("LOOP"), on: loopEnabled.value > 0, color: Style.loop},
                    {text: qsTr("SYNC"), on: syncEnabled.value > 0, color: Style.accent}
                ]

                Rectangle {
                    required property var modelData

                    visible: modelData.on
                    width: badge.implicitWidth + Math.round(14 * root.u)
                    height: Math.round(24 * root.u)
                    radius: 6
                    color: modelData.color

                    Text {
                        id: badge

                        anchors.centerIn: parent
                        color: Style.background
                        font.family: Style.font
                        font.pixelSize: Math.round(12 * root.u)
                        font.weight: Font.Bold
                        text: parent.modelData.text
                    }
                }
            }
        }
    }
}
