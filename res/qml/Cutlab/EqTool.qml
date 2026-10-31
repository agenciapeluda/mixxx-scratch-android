import Mixxx 1.0 as Mixxx
import QtQuick

// EQ of one deck: high, mid and low with their kills, filter and gain.
Item {
    id: root

    required property string group
    readonly property string eqGroup: `[EqualizerRack1_${group}_Effect1]`
    readonly property var bands: [
        {key: "parameter3", kill: "button_parameter3", label: qsTr("HI")},
        {key: "parameter2", kill: "button_parameter2", label: qsTr("MID")},
        {key: "parameter1", kill: "button_parameter1", label: qsTr("LOW")}
    ]

    readonly property real knobWidth: Math.max(36, Math.min(64, (width - 6 * 6) / 5))

    Row {
        anchors.centerIn: parent
        height: parent.height - 20
        spacing: Math.max(6, (root.width - 5 * root.knobWidth) / 6)

        CLKnob {
            width: root.knobWidth
            height: Math.min(parent.height, root.knobWidth + 26)
            anchors.verticalCenter: parent.verticalCenter
            group: root.group
            key: "pregain"
            label: qsTr("GAIN")
            arcColor: "#8e8e93"
        }
        Repeater {
            model: root.bands

            Column {
                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                CLKnob {
                    width: root.knobWidth
                    height: root.knobWidth + 18
                    group: root.eqGroup
                    key: modelData.key
                    label: modelData.label
                }
                CLControlButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(54, root.knobWidth)
                    height: 30
                    group: root.eqGroup
                    key: modelData.kill
                    mode: "toggle"
                    text: qsTr("KILL")
                    fontSize: 11
                    litColor: Style.danger
                }
            }
        }
        CLKnob {
            width: root.knobWidth
            height: Math.min(parent.height, root.knobWidth + 26)
            anchors.verticalCenter: parent.verticalCenter
            group: `[QuickEffectRack1_${root.group}]`
            key: "super1"
            label: qsTr("FILTER")
        }
    }
}
