import Mixxx 1.0 as Mixxx
import QtQuick

// Effects of a deck, on the effect unit of the same number.
//  - Pad: touch and drag; across sets the effect amount, up and down the
//    filter (high pass up, low pass down). Lifting the finger ends it.
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
    // The chain presets that can be loaded, without the empty one
    property var presets: []
    readonly property var presetModel: Mixxx.EffectsManager.standardChainPresetModel

    function readPresets() {
        const model = root.presetModel;
        if (!model) {
            root.presets = [];
            return;
        }
        const count = model.rowCount !== undefined ? model.rowCount() : model.count;
        const list = [];
        for (let i = 0; i < count; ++i) {
            const item = model.get(i);
            const name = (item.presetDisplay || item.name || "").toString().trim();
            if (name !== "" && name !== "---") {
                list.push({index: i, name: name});
            }
        }
        root.presets = list;
    }
    function presetPosition() {
        if (!root.unit) {
            return -1;
        }
        for (let i = 0; i < root.presets.length; ++i) {
            if (root.presets[i].index === root.unit.presetIndex) {
                return i;
            }
        }
        return -1;
    }
    function stepPreset(step) {
        if (root.presets.length === 0 || !root.unit) {
            return;
        }
        const position = root.presetPosition();
        const next = ((position < 0 ? 0 : position + step) + root.presets.length) % root.presets.length;
        root.unit.loadPreset(root.presets[next].index);
        root.activePreset = root.presets[next].index;
    }

    Component.onCompleted: readPresets()

    Connections {
        target: root.presetModel
        ignoreUnknownSignals: true

        function onModelReset() {
            root.readPresets();
        }
        function onRowsInserted() {
            root.readPresets();
        }
        function onRowsRemoved() {
            root.readPresets();
        }
    }

    Mixxx.ControlProxy {
        id: routing

        group: root.unitGroup
        key: `group_${root.group}_enable`
    }
    Mixxx.ControlProxy {
        id: unitSuper

        group: root.unitGroup
        key: "super1"
    }
    Mixxx.ControlProxy {
        id: quickFilter

        group: `[QuickEffectRack1_${root.group}]`
        key: "super1"
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
            color: root.hold ? Style.accentText : Style.textSecondary
            font.family: Style.font
            font.pixelSize: 13
            font.weight: Font.Medium
            text: qsTr("HOLD")
            visible: root.mode === 1

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
            model: [qsTr("Pad"), qsTr("Instant"), qsTr("Manual")]

            Text {
                required property int index
                required property string modelData

                anchors.verticalCenter: parent.verticalCenter
                color: root.mode === index ? Style.accentText : Style.textSecondary
                font.family: Style.font
                font.pixelSize: 15
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
        visible: root.mode === 1
        clip: true
        cellWidth: width / 4
        cellHeight: Math.max(56, height / 2)
        model: root.presets
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: cell

            required property var modelData
            readonly property int index: modelData.index
            readonly property string presetDisplay: modelData.name

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

    // Pad: the effect chain on top, the touch surface below
    Item {
        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.mode === 0

        Rectangle {
            id: presetBar

            width: parent.width
            height: 40
            color: "#3c3c3f"

            CLButton {
                anchors.left: parent.left
                height: parent.height
                width: 48
                icon: "prev"
                iconSize: 16
                bordered: false
                fillColor: "transparent"
                onClicked: root.stepPreset(-1)
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 110
                color: Style.text
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.family: Style.font
                font.pixelSize: 15
                font.weight: Font.Medium
                text: root.unit && root.unit.presetName !== "" && root.unit.presetName !== "---" ? root.unit.presetName : qsTr("Pick an effect")
            }
            CLButton {
                anchors.right: parent.right
                height: parent.height
                width: 48
                icon: "next"
                iconSize: 16
                bordered: false
                fillColor: "transparent"
                onClicked: root.stepPreset(1)
            }
        }

        XYSurface {
            anchors.top: presetBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            topLabel: qsTr("HP")
            bottomLabel: qsTr("LP")
            onTouched: (x, y) => {
                if (root.presetPosition() < 0) {
                    root.stepPreset(0);
                }
                unitEnabled.value = 1;
                routing.value = 1;
                unitSuper.parameter = x;
                quickFilter.parameter = y;
            }
            onReleased: {
                routing.value = 0;
                quickFilter.reset();
            }
        }
    }

    // Manual: the three effects of the unit
    Column {
        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.mode === 2

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
