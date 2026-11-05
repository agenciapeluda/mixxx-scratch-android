import Mixxx 1.0 as Mixxx
import QtQuick

// The mixer of one deck: its volume fader with the level, headphones (PFL),
// gain, the three EQ bands with their kills and the filter.
Item {
    id: root

    required property string group

    Mixxx.ControlProxy {
        id: pfl

        group: root.group
        key: "pfl"
    }

    Item {
        id: faderArea

        x: 8
        width: Math.max(60, Math.min(96, root.width * 0.2))
        height: root.height

        VuBar {
            id: vu

            x: 0
            width: 6
            height: fader.height - 12
            y: fader.y + 6
            group: root.group
            segments: 14
        }
        CLFader {
            id: fader

            x: vu.width + 6
            y: 10
            width: faderArea.width - vu.width - 6
            height: faderArea.height - headphones.height - 30
            group: root.group
            key: "volume"
            ticks: 5
            handleColor: Style.deckColor(root.group)
        }
        CLButton {
            id: headphones

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            x: fader.x
            width: fader.width
            height: 40
            text: qsTr("CUE")
            fontSize: 12
            lit: pfl.value > 0
            litColor: Style.cue
            onClicked: pfl.value = pfl.value > 0 ? 0 : 1
        }
    }
    EqTool {
        anchors.left: faderArea.right
        anchors.right: parent.right
        height: parent.height
        group: root.group
    }
}
