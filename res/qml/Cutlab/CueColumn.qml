import Mixxx 1.0 as Mixxx
import QtQuick

// Next to the platter, as in the design: HOT CUES of the deck (tap an empty
// one to set it, a set one to jump, hold to clear) in one color per number,
// the toggles of the deck (SYNC, KEY, Q quantize, SLIP) and the loop
// length. Deck B is mirrored.
Column {
    id: root

    required property string group
    property bool mirrored: false
    // Only the four pads (the upright screen)
    property bool compact: false
    property real u: 1
    // 4 or 8 hot cues, in rows of 4
    property int count: 4
    // The toggles under the pads
    property var toggles: [{label: "SYNC", key: "sync_enabled"}, {label: "KEY", key: "keylock"}]

    function fs(px) {
        return Math.max(9, Math.round(px * root.u));
    }

    spacing: Math.round(8 * u)

    Text {
        visible: !root.compact
        width: parent.width
        horizontalAlignment: root.mirrored ? Text.AlignRight : Text.AlignLeft
        color: Style.textSecondary
        font.family: Style.font
        font.weight: Font.DemiBold
        font.pixelSize: root.fs(11)
        font.letterSpacing: 0.5
        text: qsTr("HOT CUES · %1").arg(Style.deckLetter(root.group))
    }
    Grid {
        width: parent.width
        columns: 4
        spacing: Math.round((root.compact ? 4 : 6) * root.u)

        Repeater {
            model: root.count

            Rectangle {
                id: cue

                required property int index
                readonly property int number: index + 1
                readonly property bool isSet: status.value !== 0
                readonly property color setColor: Style.cueColor(cue.number, colorControl.value)

                width: (root.width - 3 * parent.spacing) / 4
                height: Math.round((root.count > 4 ? 40 : 44) * root.u)
                radius: Math.round(8 * root.u)
                color: isSet ? setColor : Style.raised
                border.width: isSet ? 0 : 1
                border.color: Qt.rgba(1, 1, 1, 0.1)
                scale: cueMouse.pressed ? 0.94 : 1

                Text {
                    anchors.centerIn: parent
                    color: cue.isSet ? Style.background : Style.textDim
                    font.family: Style.mono
                    font.weight: Font.Bold
                    font.pixelSize: root.fs(13)
                    text: String(cue.number)
                }
                MouseArea {
                    id: cueMouse

                    anchors.fill: parent
                    onPressed: activate.value = 1
                    onReleased: activate.value = 0
                    onCanceled: activate.value = 0
                    onPressAndHold: {
                        activate.value = 0;
                        clear.value = 1;
                        clear.value = 0;
                    }
                }
                Mixxx.ControlProxy {
                    id: status

                    group: root.group
                    key: `hotcue_${cue.number}_status`
                }
                Mixxx.ControlProxy {
                    id: colorControl

                    group: root.group
                    key: `hotcue_${cue.number}_color`
                }
                Mixxx.ControlProxy {
                    id: activate

                    group: root.group
                    key: `hotcue_${cue.number}_activate`
                }
                Mixxx.ControlProxy {
                    id: clear

                    group: root.group
                    key: `hotcue_${cue.number}_clear`
                }
            }
        }
    }
    Item {
        visible: !root.compact
        width: parent.width
        height: Math.round(36 * root.u)

        Row {
            x: root.mirrored ? parent.width - width : 0
            height: parent.height
            layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight
            spacing: Math.round(6 * root.u)

            Repeater {
                model: root.toggles

                Rectangle {
                    id: toggle

                    required property var modelData
                    readonly property bool on: control.value > 0

                    width: Math.max(Math.round(44 * root.u), label.implicitWidth + Math.round(20 * root.u))
                    height: parent.height
                    radius: Math.round(8 * root.u)
                    color: on ? Style.accent : "transparent"
                    border.width: 1
                    border.color: on ? Style.accent : Qt.rgba(1, 1, 1, 0.12)

                    Text {
                        id: label

                        anchors.centerIn: parent
                        color: toggle.on ? "#ffffff" : Style.text
                        font.family: Style.font
                        font.weight: Font.DemiBold
                        font.pixelSize: root.fs(12)
                        text: toggle.modelData.label
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: control.value = toggle.on ? 0 : 1
                    }
                    Mixxx.ControlProxy {
                        id: control

                        group: root.group
                        key: toggle.modelData.key
                    }
                }
            }
        }
        // The loop: its length, tap to set 4 beats or leave it
        Text {
            x: root.mirrored ? 0 : parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            color: loopEnabled.value > 0 ? Style.ok : Style.textSecondary
            font.family: Style.mono
            font.weight: Font.Medium
            font.pixelSize: root.fs(12)
            text: "LOOP " + (loopEnabled.value > 0 ? Style.beatsText(loopSize.value) : "—")

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                onClicked: {
                    if (loopEnabled.value > 0) {
                        reloop.value = 1;
                        reloop.value = 0;
                    } else {
                        beatloop.value = 1;
                        beatloop.value = 0;
                    }
                }
            }
        }
    }

    Mixxx.ControlProxy {
        id: loopEnabled

        group: root.group
        key: "loop_enabled"
    }
    Mixxx.ControlProxy {
        id: loopSize

        group: root.group
        key: "beatloop_size"
    }
    Mixxx.ControlProxy {
        id: beatloop

        group: root.group
        key: "beatloop_activate"
    }
    Mixxx.ControlProxy {
        id: reloop

        group: root.group
        key: "reloop_toggle"
    }
}
