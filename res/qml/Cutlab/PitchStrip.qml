import Mixxx 1.0 as Mixxx
import QtQuick

// Thin, next to the dial: the level of the deck and its pitch fader (double
// tap resets it; the dot lights green at the original tempo).
Item {
    id: root

    required property string group
    property bool mirrored: false

    Mixxx.ControlProxy {
        id: rate

        group: root.group
        key: "rate"
    }

    VuBar {
        id: vu

        x: root.mirrored ? 0 : root.width - width
        width: Math.max(4, Math.round(root.width * 0.16))
        height: root.height - 8
        anchors.verticalCenter: parent.verticalCenter
        group: root.group
        segments: 14
    }
    CLFader {
        x: root.mirrored ? vu.width + 2 : 0
        width: root.width - vu.width - 2
        height: root.height
        group: root.group
        key: "rate"
        sensitivity: 0.5
        ticks: 5
        handleLength: width * 0.9
        handleThickness: Math.max(18, Math.min(26, root.height * 0.12))
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: root.mirrored ? vu.width / 2 : -vu.width / 2
        anchors.bottom: parent.bottom
        width: 6
        height: 6
        radius: 3
        color: Math.abs(rate.value) < 0.0001 ? Style.play : Style.tick
    }
}
