import QtQuick

// The 8 pads of a deck (2 rows of 4) with the button that picks what they
// do, on the outer side: hot cues, loop rolls or samples. Tap it to go to
// the next mode. Narrow (upright), the mode is a tab over the pads.
Item {
    id: root

    required property string group
    property bool mirrored: false
    property bool compact: false
    // 0 hot cues, 1 loop rolls, 2 samples
    property int mode: 0
    readonly property var modes: [qsTr("HOT CUES"), qsTr("ROLLS"), qsTr("SAMPLES")]

    signal loadSampleRequested(string group)

    Rectangle {
        id: picker

        x: root.compact ? 0 : (root.mirrored ? root.width - width : 0)
        width: root.compact ? root.width : Math.round(Math.max(54, Math.min(84, root.width * 0.16)))
        height: root.compact ? 26 : root.height
        radius: 10
        color: pickerMouse.pressed ? Style.buttonPressed : Style.raised

        Column {
            anchors.centerIn: parent
            spacing: 2
            visible: !root.compact

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Style.textDim
                font.family: Style.font
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
                text: qsTr("PADS")
            }
            Repeater {
                model: root.modes

                Text {
                    required property string modelData
                    required property int index

                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root.mode === index ? Style.text : Style.textDim
                    font.family: Style.font
                    font.pixelSize: 10
                    font.weight: root.mode === index ? Font.Bold : Font.Medium
                    text: modelData
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: root.compact
            color: Style.text
            font.family: Style.font
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.6
            text: qsTr("PADS · %1").arg(root.modes[root.mode])
        }
        MouseArea {
            id: pickerMouse

            anchors.fill: parent
            onClicked: root.mode = (root.mode + 1) % root.modes.length
        }
    }

    Item {
        id: pads

        x: root.compact ? 0 : (root.mirrored ? 0 : picker.width + 6)
        y: root.compact ? picker.height + 4 : 0
        width: root.compact ? root.width : root.width - picker.width - 6
        height: root.compact ? root.height - picker.height - 4 : root.height

        Loader {
            anchors.fill: parent
            sourceComponent: [cues, rolls, samples][root.mode]
        }
        Component {
            id: cues

            HotcuePads {
                group: root.group
                spacing: 4
            }
        }
        Component {
            id: rolls

            RollPads {
                group: root.group
                spacing: 4
            }
        }
        Component {
            id: samples

            SamplePads {
                spacing: 4
                onLoadRequested: group => root.loadSampleRequested(group)
            }
        }
    }
}
