import Mixxx 1.0 as Mixxx
import QtQuick

// The bottom bar: play, SET and CUE of each deck around the crossfader
// (stems and the other tools are in the bar of each deck).
Rectangle {
    id: root

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
        showTools: false
    }
    DeckTransport {
        id: right

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        group: "[Channel2]"
        mirrored: true
        unit: root.height - 16
        showTools: false
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
            x: Math.max(0, (parent.width - width) / 2)
            width: Math.min(parent.width - 60, 420)
            height: parent.height - 10
            vertical: false
            group: "[Master]"
            key: "crossfader"
            ticks: 7
            handleThickness: height * 0.95
        }
    }
}
