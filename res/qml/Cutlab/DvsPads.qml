// [AI-generated text, Claude (Anthropic) — start]
// Cutlab 1.31: the DVS pad mode of a deck. One row: DVS on/off, ABS, REL,
// INT (constant mode) and THRU (the turntable plays through the channel,
// the EN VIVO of 1.30). What is on is lit with the color of the deck.
// [AI-generated text, Claude (Anthropic) — end]
import Mixxx 1.0 as Mixxx
import QtQuick

Item {
    id: root

    required property string group
    property real spacing: 4
    readonly property color deckColor: Style.deckColor(root.group)
    readonly property bool dvsOn: enabledControl.value > 0
    readonly property int mode: Math.round(modeControl.value)
    readonly property var live: Live.forGroup(root.group)
    readonly property bool thru: !!root.live && root.live.live
    // 0 to 4 bars: how well the timecode is read
    readonly property int bars: Math.round(Math.max(0, Math.min(1, quality.value)) * 4)

    Mixxx.ControlProxy {
        id: enabledControl

        group: root.group
        key: "vinylcontrol_enabled"
    }
    Mixxx.ControlProxy {
        id: modeControl

        group: root.group
        key: "vinylcontrol_mode"
    }
    Mixxx.ControlProxy {
        id: quality

        group: root.group
        key: "vinylcontrol_quality"
    }

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            // key, label
            model: [["dvs", "DVS"], ["abs", "ABS"], ["rel", "REL"], ["int", "INT"], ["thru", "THRU"]]

            Rectangle {
                id: button

                required property var modelData
                readonly property string kind: modelData[0]
                readonly property bool on: {
                    switch (kind) {
                    case "dvs":
                        return root.dvsOn;
                    case "abs":
                        return root.dvsOn && root.mode === 0;
                    case "rel":
                        return root.dvsOn && root.mode === 1;
                    case "int":
                        return root.dvsOn && root.mode === 2;
                    default:
                        return root.thru;
                    }
                }
                readonly property bool usable: kind === "dvs" || kind === "thru" ? true : root.dvsOn

                width: (root.width - 4 * root.spacing) / 5
                height: root.height
                radius: 10
                color: on ? Qt.darker(root.deckColor, 1.5) : (mouse.pressed ? Style.buttonPressed : Style.raised)
                border.width: on ? 2 : 1
                border.color: on ? root.deckColor : Style.buttonBorder
                opacity: usable ? 1 : 0.4

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: button.on ? "#ffffff" : Style.text
                        font.family: Style.font
                        font.pixelSize: Math.max(11, Math.min(18, button.width * 0.2))
                        font.weight: Font.Bold
                        text: button.modelData[1]
                    }
                    // How well the timecode is read, under DVS
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        visible: button.kind === "dvs" && root.dvsOn

                        Repeater {
                            model: 4

                            Rectangle {
                                required property int index

                                anchors.bottom: parent.bottom
                                width: 3
                                height: 4 + 2 * index
                                radius: 1
                                color: index < root.bars ? "#ffffff" : Qt.rgba(1, 1, 1, 0.25)
                            }
                        }
                    }
                }
                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    onClicked: {
                        switch (button.kind) {
                        case "dvs":
                            enabledControl.value = root.dvsOn ? 0 : 1;
                            break;
                        case "abs":
                        case "rel":
                        case "int":
                            if (root.dvsOn) {
                                modeControl.value = ["abs", "rel", "int"].indexOf(button.kind);
                            }
                            break;
                        default:
                            if (root.live) {
                                root.live.toggle();
                            }
                            break;
                        }
                    }
                }
            }
        }
    }
}
