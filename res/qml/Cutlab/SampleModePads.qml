// [AI-generated text, Claude (Anthropic) — start]
// Cutlab 1.31: the pads of a deck in samples mode, with a selector on top:
// Samples / Key Shift / Pitch Play. With Pitch Play a second row picks the
// base hot cue (1-8). What they do is played by the KeyPlay of the deck,
// the same as the SAMPLER pads of the REV1 and the KEY SHIFT / KEYBOARD
// pads of the FLX4.
// [AI-generated text, Claude (Anthropic) — end]
import Mixxx 1.0 as Mixxx
import QtQuick

Item {
    id: root

    required property string group
    property real spacing: 4
    readonly property var engine: Shots.keyPlayFor(root.group)
    readonly property int mode: root.engine ? root.engine.mode : 0
    readonly property color deckColor: Style.deckColor(root.group)

    signal loadRequested(string group)

    Column {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 3

        Row {
            width: parent.width
            height: 24
            spacing: 4

            Repeater {
                model: [qsTr("Samples"), qsTr("Key Shift"), qsTr("Pitch Play")]

                Rectangle {
                    required property int index
                    required property string modelData
                    readonly property bool on: root.mode === index

                    width: (parent.width - 8) / 3
                    height: parent.height
                    radius: 0
                    color: on ? Qt.darker(root.deckColor, 1.5) : "transparent"
                    border.width: 1
                    border.color: on ? root.deckColor : Qt.rgba(1, 1, 1, 0.14)

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 8
                        color: parent.on ? "#ffffff" : Style.textSecondary
                        font.family: Style.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        text: parent.modelData
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        onClicked: if (root.engine) root.engine.setMode(parent.index)
                    }
                }
            }
        }
        // The base hot cue of Pitch Play
        Row {
            width: parent.width
            height: 22
            spacing: 3
            visible: root.mode === 2

            Text {
                id: baseLabel

                anchors.verticalCenter: parent.verticalCenter
                color: Style.textDim
                font.family: Style.font
                font.pixelSize: 10
                font.weight: Font.DemiBold
                text: qsTr("CUE")
            }
            Repeater {
                model: 8

                Rectangle {
                    required property int index
                    readonly property bool on: root.engine && root.engine.baseCue === index + 1

                    width: (parent.width - baseLabel.width - 8 * 3) / 8
                    height: parent.height
                    radius: 0
                    color: on ? Style.cueColor(index + 1, cueColor.value) : Style.raised
                    border.width: 1
                    border.color: on ? "#ffffff" : Style.buttonBorder

                    Mixxx.ControlProxy {
                        id: cueColor

                        group: root.group
                        key: `hotcue_${parent.index + 1}_color`
                    }
                    Text {
                        anchors.centerIn: parent
                        color: parent.on ? "#000000" : Style.text
                        font.family: Style.font
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        text: parent.index + 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (root.engine) root.engine.pickBaseCue(parent.index)
                    }
                }
            }
        }
    }

    Item {
        anchors.top: header.bottom
        anchors.topMargin: root.spacing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        SamplePads {
            anchors.fill: parent
            visible: root.mode === 0
            spacing: root.spacing
            onLoadRequested: group => root.loadRequested(group)
        }
        Grid {
            id: keyPads

            anchors.fill: parent
            visible: root.mode !== 0
            columns: 4
            rows: 2
            spacing: root.spacing

            Repeater {
                model: 8

                Pad {
                    required property int index
                    readonly property int step: !root.engine ? 0 : (root.mode === 2 ? root.engine.pitchPlaySteps[index] : root.engine.keyShiftSteps[index])

                    width: (keyPads.width - 3 * keyPads.spacing) / 4
                    height: (keyPads.height - keyPads.spacing) / 2
                    text: (step > 0 ? "+" : step < 0 ? "−" : "") + Math.abs(step)
                    tag: root.mode === 2 && root.engine ? qsTr("cue %1").arg(root.engine.baseCue) : qsTr("key")
                    padColor: root.deckColor
                    active: !!root.engine && root.engine.semitones === step && (root.mode === 2 || step !== 0)
                    onPressedDown: if (root.engine) root.engine.press(index, false)
                }
            }
        }
    }
}
