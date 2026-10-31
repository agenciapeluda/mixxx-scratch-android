import Mixxx 1.0 as Mixxx
import QtQuick

// The mixer between the two decks: filter, gain, level meters and channel
// faders, or the three EQ bands when EQ is on.
Rectangle {
    id: root

    property bool showEq: false
    readonly property var groups: ["[Channel1]", "[Channel2]"]

    color: Style.panel

    // Filter and gain, or EQ
    Item {
        id: topArea

        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.showEq ? parent.height - bottomRow.height - 20 : Math.min(76, parent.height * 0.3)

        // Filter knobs at the outer sides
        Repeater {
            model: root.showEq ? 0 : 2

            CLKnob {
                required property int index

                x: index === 0 ? 8 : topArea.width - width - 8
                width: Math.min(56, topArea.width * 0.3)
                height: topArea.height
                group: `[QuickEffectRack1_${root.groups[index]}]`
                key: "super1"
                label: qsTr("FILTER")
            }
        }

        // EQ: high, mid and low for each deck
        Repeater {
            model: root.showEq ? 2 : 0

            Column {
                id: eqColumn

                required property int index
                readonly property string eqGroup: `[EqualizerRack1_${root.groups[index]}_Effect1]`

                x: index === 0 ? 6 : topArea.width - width - 6
                width: Math.min(60, topArea.width * 0.32)
                height: topArea.height
                spacing: 2

                Repeater {
                    model: [{key: "parameter3", label: qsTr("HI")}, {key: "parameter2", label: qsTr("MID")}, {key: "parameter1", label: qsTr("LOW")}]

                    CLKnob {
                        required property var modelData

                        width: eqColumn.width
                        height: (eqColumn.height - 4) / 3
                        group: eqColumn.eqGroup
                        key: modelData.key
                        label: modelData.label
                    }
                }
            }
        }
    }

    // Gain, meters and faders
    Item {
        id: faders

        anchors.top: topArea.bottom
        anchors.topMargin: 4
        anchors.bottom: bottomRow.top
        anchors.bottomMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.showEq

        Repeater {
            model: 2

            Item {
                id: channel

                required property int index

                x: index === 0 ? 0 : faders.width / 2
                width: faders.width / 2
                height: faders.height

                CLKnob {
                    id: gain

                    anchors.top: parent.top
                    x: channel.index === 0 ? parent.width - width - 4 : 4
                    width: 30
                    height: 30
                    group: root.groups[channel.index]
                    key: "pregain"
                    arcColor: "#8e8e93"
                }
                VuBar {
                    anchors.top: gain.bottom
                    anchors.topMargin: 6
                    anchors.bottom: parent.bottom
                    x: gain.x + (gain.width - width) / 2
                    width: 7
                    group: root.groups[channel.index]
                    segments: 14
                }
                CLFader {
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    anchors.bottom: parent.bottom
                    x: channel.index === 0 ? 4 : parent.width - width - 4
                    width: Math.min(54, parent.width - 44)
                    group: root.groups[channel.index]
                    key: "volume"
                    ticks: 5
                }
            }
        }
    }

    Row {
        id: bottomRow

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        CLControlButton {
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 34
            group: "[Channel1]"
            key: "pfl"
            mode: "toggle"
            text: qsTr("CUE")
            fontSize: 12
        }
        CLButton {
            width: 48
            height: 48
            round: true
            text: qsTr("EQ")
            fontSize: 15
            lit: root.showEq
            onClicked: root.showEq = !root.showEq
        }
        CLControlButton {
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 34
            group: "[Channel2]"
            key: "pfl"
            mode: "toggle"
            text: qsTr("CUE")
            fontSize: 12
        }
    }
}
