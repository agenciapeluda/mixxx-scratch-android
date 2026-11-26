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
        anchors.top: parent.top
        anchors.bottom: smartCfxRow.top
        group: root.group
    }
    // [AI-generated text, Claude (Anthropic) — start]
    // 1.31: Smart CFX, the effect that goes with the filter knob of both
    // decks (from the screen, the FILTER of the REV1 and the Mixtour, the
    // CFX of the FLX4, whose SMART CFX button turns it on and off)
    Mixxx.ControlProxy {
        id: smartCfx

        group: "[Cutlab]"
        key: "smart_cfx"
    }
    Row {
        id: smartCfxRow

        anchors.left: faderArea.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        height: 30
        spacing: 4

        Text {
            id: smartLabel

            anchors.verticalCenter: parent.verticalCenter
            color: Style.textDim
            font.family: Style.font
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
            text: qsTr("SMART CFX")
        }
        Repeater {
            model: [qsTr("Off"), qsTr("Echo"), qsTr("Reverb"), qsTr("Flanger")]

            Rectangle {
                required property int index
                required property string modelData
                readonly property bool on: Math.round(smartCfx.value) === index

                anchors.verticalCenter: parent.verticalCenter
                width: (smartCfxRow.width - smartLabel.width - 4 * smartCfxRow.spacing) / 4
                height: 26
                radius: 0
                color: on ? Style.neutralDark : "transparent"
                border.width: 1
                border.color: on ? Style.neutral : Qt.rgba(1, 1, 1, 0.14)

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 6
                    horizontalAlignment: Text.AlignHCenter
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 8
                    color: parent.on ? Style.text : Style.textSecondary
                    font.family: Style.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    text: parent.modelData
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    onClicked: smartCfx.value = parent.index
                }
            }
        }
    }
    // [AI-generated text, Claude (Anthropic) — end]
}
