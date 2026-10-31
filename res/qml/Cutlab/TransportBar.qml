import Mixxx 1.0 as Mixxx
import QtQuick

// The bottom bar: play, cue and stems of each deck around the crossfader.
Rectangle {
    id: root

    signal stemsRequested(string group)
    signal menuRequested

    color: Style.panelDark

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Style.divider
    }

    DeckTransport {
        id: left

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        group: "[Channel1]"
        unit: root.height - 16
        onStemsRequested: root.stemsRequested(group)
    }
    DeckTransport {
        id: right

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        group: "[Channel2]"
        mirrored: true
        unit: root.height - 16
        onStemsRequested: root.stemsRequested(group)
    }

    Item {
        anchors.left: left.right
        anchors.right: right.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        CLFader {
            id: crossfader

            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, (parent.width - width) / 2 - 22)
            width: Math.min(parent.width - 52, 320)
            height: parent.height - 10
            vertical: false
            group: "[Master]"
            key: "crossfader"
            ticks: 7
            handleThickness: height * 0.95
        }
        CLButton {
            anchors.left: crossfader.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            round: true
            bordered: false
            fillColor: "#48484b"
            icon: "chevron_down"
            iconSize: 18
            onClicked: root.menuRequested()
        }
    }
}
