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
        id: keylock

        group: root.group
        key: "keylock"
    }

    CLControlButton {
        id: syncButton

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        width: Math.min(parent.width - 16, 96)
        height: Math.max(34, Math.min(46, root.height * 0.13))
        group: root.group
        key: "sync_enabled"
        mode: "toggle"
        text: "SYNC"
        fontWeight: Font.Medium
        litColor: Style.accent
        highlighted: value > 0
        lit: false
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
            font.family: Style.font
            font.pixelSize: Math.max(14, Math.min(20, Math.round(root.height * 0.06)))
            text: bpm.value > 0 ? bpm.value.toFixed(1) : "--.-"
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
            width: Math.min(56, parent.width * 0.5)
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
            width: 30
            height: 40
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
            width: 30
            height: 40
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
        width: Math.min(parent.width - 20, 80)
        height: 30
        radius: 15
        group: root.group
        key: "vinylcontrol_enabled"
        mode: "toggle"
        text: "DVS"
        fontSize: 12
        litColor: Style.play
        visible: Mixxx.Application.vinylControlAvailable === true
    }

    CLButton {
        id: toolsButton

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: Math.max(40, Math.min(52, root.height * 0.15))
        height: width
        round: true
        icon: "mixer"
        iconSize: width * 0.42
        lit: root.toolsOpen
        onClicked: root.toolsRequested()
    }
}
