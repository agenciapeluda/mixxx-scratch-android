import Mixxx 1.0 as Mixxx
import QtQuick

// The outer column of a deck, like djay: SYNC and the BPM on top, then the
// long pitch fader. Hold SYNC to turn it off and go back to the original
// tempo; double tap the fader to reset it; tap the range to change it
// (±8, ±16, ±50).
Rectangle {
    id: root

    required property string group
    property bool mirrored: false
    property real u: 1

    readonly property real pitchPercent: (rateRatio.value - 1) * 100
    readonly property bool loaded: trackLoaded.value > 0

    function fs(px) {
        return Math.max(9, Math.round(px * root.u));
    }

    radius: Math.round(14 * u)
    color: Style.panel
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.07)

    Mixxx.ControlProxy {
        id: bpm

        group: root.group
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: rate

        group: root.group
        key: "rate"
    }
    Mixxx.ControlProxy {
        id: rateRatio

        group: root.group
        key: "rate_ratio"
    }
    Mixxx.ControlProxy {
        id: rateRange

        group: root.group
        key: "rateRange"
    }
    Mixxx.ControlProxy {
        id: sync

        group: root.group
        key: "sync_enabled"
    }
    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }

    // SYNC
    Rectangle {
        id: syncButton

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(8 * root.u)
        width: parent.width - Math.round(14 * root.u)
        height: Math.round(44 * root.u)
        radius: Math.round(10 * root.u)
        color: sync.value > 0 ? Style.accent : (syncMouse.pressed ? Style.buttonPressed : "transparent")
        border.width: 1
        border.color: sync.value > 0 ? Style.accent : Qt.rgba(1, 1, 1, 0.14)

        Text {
            anchors.centerIn: parent
            color: sync.value > 0 ? "#ffffff" : Style.text
            font.family: Style.font
            font.weight: Font.Bold
            font.pixelSize: root.fs(13)
            text: "SYNC"
        }
        MouseArea {
            id: syncMouse

            anchors.fill: parent
            onClicked: sync.value = sync.value > 0 ? 0 : 1
            onPressAndHold: {
                sync.value = 0;
                rate.value = 0;
            }
        }
    }
    // BPM and pitch
    Column {
        id: tempo

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: syncButton.bottom
        anchors.topMargin: Math.round(8 * root.u)
        spacing: Math.round(2 * root.u)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Style.text
            font.family: Style.mono
            font.weight: Font.Bold
            font.pixelSize: root.fs(19)
            text: root.loaded && bpm.value > 0 ? bpm.value.toFixed(1) : "—"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Math.abs(rate.value) < 0.0001 ? Style.textDim : Style.textSecondary
            font.family: Style.mono
            font.pixelSize: root.fs(11)
            text: (root.pitchPercent >= 0 ? "+" : "−") + Math.abs(root.pitchPercent).toFixed(1) + "%"
        }
        // The range: tap to change it
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: rangeText.implicitWidth + Math.round(14 * root.u)
            height: rangeText.implicitHeight + Math.round(6 * root.u)
            radius: height / 2
            color: rangeMouse.pressed ? Style.buttonPressed : Style.raised

            Text {
                id: rangeText

                anchors.centerIn: parent
                color: Style.textSecondary
                font.family: Style.mono
                font.weight: Font.Bold
                font.pixelSize: root.fs(10)
                text: "±" + Math.round(rateRange.value * 100)
            }
            MouseArea {
                id: rangeMouse

                anchors.fill: parent
                anchors.margins: -8
                onClicked: {
                    const ranges = [0.08, 0.16, 0.5];
                    const at = ranges.findIndex(r => Math.abs(r - rateRange.value) < 0.005);
                    rateRange.value = ranges[(at + 1) % ranges.length];
                }
            }
        }
    }
    // The long pitch fader
    CLFader {
        anchors.top: tempo.bottom
        anchors.topMargin: Math.round(10 * root.u)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(12 * root.u)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - Math.round(16 * root.u), Math.round(56 * root.u))
        group: root.group
        key: "rate"
        sensitivity: 0.5
        ticks: 9
        handleColor: Style.text
        handleLength: Math.min(width * 0.9, Math.round(50 * root.u))
        handleThickness: Math.round(26 * root.u)
    }
    // The middle of the fader, where the tempo is the original
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: root.mirrored ? -Math.round(30 * root.u) : Math.round(30 * root.u)
        y: tempo.y + tempo.height + Math.round(10 * root.u) + (parent.height - tempo.y - tempo.height - Math.round(22 * root.u)) / 2 - height / 2
        width: Math.round(6 * root.u)
        height: width
        radius: width / 2
        color: Math.abs(rate.value) < 0.0001 ? Style.play : Style.tick
    }
}
