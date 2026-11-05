import Mixxx 1.0 as Mixxx
import QtQuick

// The outer column of a deck: sync, tempo, pitch fader with key lock, and
// the button that opens the deck's tools.
Rectangle {
    id: root

    required property string group
    property bool mirrored: false
    property bool toolsOpen: false

    signal toolsRequested

    color: Style.panel

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
        id: keylock

        group: root.group
        key: "keylock"
    }

    CLControlButton {
        id: syncButton

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        width: Math.min(parent.width - 16, 110)
        height: Math.max(44, Math.min(58, root.height * 0.14))
        group: root.group
        key: "sync_enabled"
        mode: "toggle"
        text: "SYNC"
        fontWeight: Font.Medium
        litColor: Style.accent
        highlighted: value > 0
        lit: false
        // Hold: sync off and back to the original tempo
        onPressAndHold: {
            syncOff.value = 0;
            rate.value = 0;
        }
    }
    Mixxx.ControlProxy {
        id: syncOff

        group: root.group
        key: "sync_enabled"
    }

    Column {
        id: tempo

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: syncButton.bottom
        anchors.topMargin: Math.round(root.height * 0.05)
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 12
            text: "BPM"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Style.text
            font.family: Style.mono
            font.weight: Font.Bold
            font.pixelSize: Math.max(16, Math.min(28, Math.round(root.height * 0.075)))
            text: bpm.value > 0 ? bpm.value.toFixed(1) : "--.-"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Math.abs(rate.value) < 0.0001 ? Style.textDim : Style.textSecondary
            font.family: Style.mono
            font.pixelSize: Math.max(11, Math.min(14, Math.round(root.height * 0.04)))
            text: (rateRatio.value >= 1 ? "+" : "−") + Math.abs((rateRatio.value - 1) * 100).toFixed(1) + "%"
        }
    }

    Item {
        id: pitchArea

        anchors.top: tempo.bottom
        anchors.topMargin: 8
        anchors.bottom: dvsButton.visible ? dvsButton.top : toolsButton.top
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right

        CLFader {
            id: pitchFader

            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            width: Math.min(68, parent.width * 0.55)
            group: root.group
            key: "rate"
            sensitivity: 0.5
            ticks: 5
        }

        // Key lock
        MouseArea {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: root.mirrored ? undefined : pitchFader.left
            anchors.left: root.mirrored ? pitchFader.right : undefined
            width: 36
            height: 48
            onClicked: keylock.value = keylock.value > 0 ? 0 : 1

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: "icons/keylock.svg"
                sourceSize.width: 48
                sourceSize.height: 48
                opacity: keylock.value > 0 ? 1 : 0.35
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 14
                height: 2
                radius: 1
                color: Style.accent
                visible: keylock.value > 0
            }
        }

        // Tempo back to the original, lit while it is there
        MouseArea {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: root.mirrored ? undefined : pitchFader.right
            anchors.right: root.mirrored ? pitchFader.left : undefined
            width: 36
            height: 48
            onClicked: rate.value = 0

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: Math.abs(rate.value) < 0.0001 ? Style.play : Style.tick
            }
        }
    }

    // The deck follows the turntable (DVS); the mode is on the dial
    CLControlButton {
        id: dvsButton

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: toolsButton.top
        anchors.bottomMargin: 8
        width: Math.min(parent.width - 16, 100)
        height: 44
        radius: 22
        group: root.group
        key: "vinylcontrol_enabled"
        mode: "toggle"
        text: "DVS"
        fontSize: 14
        litColor: Style.play
        visible: Mixxx.Application.vinylControlAvailable === true
    }

    CLButton {
        id: toolsButton

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: Math.max(48, Math.min(60, root.height * 0.16))
        height: width
        round: true
        icon: "mixer"
        iconSize: width * 0.42
        lit: root.toolsOpen
        onClicked: root.toolsRequested()
    }
}
