import QtQuick

// The 8 pads of a deck (2 rows of 4) with the button that picks what they
// do, on the outer side: hot cues, loop rolls, samples, Scratch (letsktch!)
// or Stems. It shows the current mode; a tap goes to the next one. Narrow
// (upright), the same box is a tab over the pads.
Item {
    id: root

    required property string group
    property bool mirrored: false
    property bool compact: false
    // letsktch! of the main screen (Letsktch)
    property var letsktch: null
    // 0 hot cues, 1 loop rolls, 2 samples, 3 Scratch, 4 Stems
    property int mode: 0
    readonly property var modes: [qsTr("HOT CUE"), qsTr("ROLL"), qsTr("SAMPLE"), qsTr("SCRATCH"), qsTr("STEMS")]

    signal loadSampleRequested(string group)

    Rectangle {
        id: picker

        x: root.compact ? 0 : (root.mirrored ? root.width - width : 0)
        width: root.compact ? root.width : Math.round(Math.max(54, Math.min(84, root.width * 0.16)))
        height: root.compact ? 26 : root.height
        radius: 10
        color: pickerMouse.pressed ? Style.buttonPressed : Style.raised

        // Sideways, like upright: a box with the current mode; a tap goes
        // to the next one
        Column {
            anchors.centerIn: parent
            width: picker.width - 8
            spacing: 6
            visible: !root.compact

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Style.textDim
                font.family: Style.font
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
                text: qsTr("PADS")
            }
            Text {
                width: parent.width
                height: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Style.text
                font.family: Style.font
                font.pixelSize: 12
                font.weight: Font.Bold
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 7
                elide: Text.ElideNone
                text: root.modes[root.mode]
            }
            // Where the mode is in the cycle
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Repeater {
                    model: root.modes.length

                    Rectangle {
                        required property int index

                        width: 5
                        height: 5
                        radius: 2.5
                        color: index === root.mode ? Style.text : Style.textDim
                        opacity: index === root.mode ? 1 : 0.5
                    }
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
            sourceComponent: [cues, rolls, samples, scratch, stems][root.mode]
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
        Component {
            id: scratch

            ScratchPads {
                group: root.group
                engine: root.letsktch ? root.letsktch.deckOf(root.group) : null
                spacing: 4
            }
        }
        Component {
            id: stems

            StemPads {
                group: root.group
                spacing: 4
            }
        }
    }
}
