import Mixxx 1.0 as Mixxx
import QtQuick

// Effects of a deck, on the effect unit of the same number.
//  - Instant: a pad per effect chain preset, on while held (or latched
//    with HOLD)
//  - Manual: the three effects of the unit, each with ON and its knob
Item {
    id: root

    required property string group
    readonly property int unitNumber: group === "[Channel2]" ? 2 : 1
    readonly property string unitGroup: `[EffectRack1_EffectUnit${unitNumber}]`
    readonly property var unit: Mixxx.EffectsManager.getEffectUnit(unitNumber)
    property int mode: 0
    property bool hold: false
    property int activePreset: -1

    Mixxx.ControlProxy {
        id: routing

        group: root.unitGroup
        key: `group_${root.group}_enable`
    }
    Mixxx.ControlProxy {
        id: unitEnabled

        group: root.unitGroup
        key: "enabled"
    }

    function startPreset(index) {
        if (root.activePreset !== index && root.unit) {
            root.unit.loadPreset(index);
        }
        root.activePreset = index;
        unitEnabled.value = 1;
        routing.value = 1;
    }
    function stopPreset() {
        routing.value = 0;
        root.activePreset = -1;
    }

    // Mode tabs
    Row {
        id: tabs

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: 40
        spacing: 18

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.hold ? Style.accent : Style.textSecondary
            font.family: Style.font
            font.pixelSize: 13
            font.weight: Font.Medium
            text: qsTr("HOLD")
            visible: root.mode === 0

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                onClicked: {
                    root.hold = !root.hold;
                    if (!root.hold) {
                        root.stopPreset();
                    }
                }
            }
        }
        Repeater {
            model: [qsTr("Instant"), qsTr("Manual")]

            Text {
                required property int index
                required property string modelData

                anchors.verticalCenter: parent.verticalCenter
                color: root.mode === index ? Style.accent : Style.textSecondary
                font.family: Style.font
                font.pixelSize: 17
                text: modelData

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: root.mode = parent.index
                }
            }
        }
    }

    // Instant: chain presets as pads
    GridView {
        id: presetGrid

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.mode === 0
        clip: true
        cellWidth: width / 4
        cellHeight: Math.max(56, height / 2)
        model: Mixxx.EffectsManager.standardChainPresetModel
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: cell

            required property int index
            required property string presetDisplay

            width: presetGrid.cellWidth
            height: presetGrid.cellHeight

            Pad {
                anchors.fill: parent
                anchors.margins: 0.5
                tag: "FX"
                text: cell.presetDisplay
                active: root.activePreset === cell.index
                padColor: Style.accent

                onPressedDown: {
                    if (root.hold && root.activePreset === cell.index) {
                        root.stopPreset();
                    } else {
                        root.startPreset(cell.index);
                    }
                }
                onReleased: {
                    if (!root.hold) {
                        root.stopPreset();
                    }
                }
            }
        }
    }

    // Manual: the three effects of the unit
    Column {
        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.mode === 1

        Repeater {
            model: 3

            Rectangle {
                id: slotRow

                required property int index
                readonly property string slotGroup: `[EffectRack1_EffectUnit${root.unitNumber}_Effect${index + 1}]`
                readonly property var effectSlot: Mixxx.EffectsManager.getEffectSlot(root.unitNumber, index + 1)

                width: parent.width
                height: parent.height / 3
                color: index % 2 ? Style.panel : "#3c3c3f"
                border.color: Style.divider
                border.width: 1

                Mixxx.ControlProxy {
                    id: slotEnabled

                    group: slotRow.slotGroup
                    key: "enabled"
                }
                Mixxx.ControlProxy {
                    id: nextEffect

                    group: slotRow.slotGroup
                    key: "next_effect"
                }
                Mixxx.ControlProxy {
                    id: prevEffect

                    group: slotRow.slotGroup
                    key: "prev_effect"
                }

                CLButton {
                    id: onButton

                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(48, parent.height - 10)
                    height: width
                    round: true
                    text: qsTr("ON")
                    fontSize: 13
                    lit: slotEnabled.value > 0
                    onClicked: {
                        slotEnabled.value = slotEnabled.value > 0 ? 0 : 1;
                        if (slotEnabled.value > 0) {
                            unitEnabled.value = 1;
                            routing.value = 1;
                        }
                    }
                }
                CLButton {
                    id: prevButton

                    anchors.left: onButton.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    icon: "prev"
                    iconSize: 16
                    bordered: false
                    fillColor: "transparent"
                    onClicked: {
                        prevEffect.value = 1;
                        prevEffect.value = 0;
                    }
                }
                Text {
                    anchors.left: prevButton.right
                    anchors.right: nextButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.text
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Style.font
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    text: slotRow.effectSlot && slotRow.effectSlot.effectName !== "" ? slotRow.effectSlot.effectName : qsTr("No effect")
                }
                CLButton {
                    id: nextButton

                    anchors.right: metaKnob.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    icon: "next"
                    iconSize: 16
                    bordered: false
                    fillColor: "transparent"
                    onClicked: {
                        nextEffect.value = 1;
                        nextEffect.value = 0;
                    }
                }
                CLKnob {
                    id: metaKnob

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(40, parent.height - 10)
                    height: width
                    group: slotRow.slotGroup
                    key: "meta"
                    bipolar: false
                }
            }
        }
    }
}
