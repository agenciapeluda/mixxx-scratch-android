import ".." as Skin
import QtQuick

// Both scrolling waveforms one above the other, Serato style: the beats of
// the two decks line up under the playhead, and the four beat lights of
// each deck say on which beat of the bar it is.
Item {
    id: root

    property var sections1: null
    property var sections2: null
    // The DVS badge of each deck on its lane (the extended view has no dials)
    property bool showDvs: false

    // No beat bar between the lanes: the beats line up on the waveforms
    readonly property real barHeight: 0

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Column {
                id: laneBlock

                required property string modelData
                required property int index

                width: parent.width
                spacing: 4

            Rectangle {
                id: lane

                readonly property string modelData: laneBlock.modelData
                readonly property int index: laneBlock.index

                width: parent.width
                height: (root.height - 12 - 4) / 2
                radius: 10
                color: Style.panel
                clip: true

                CutlabWave {
                    anchors.fill: parent
                    group: lane.modelData
                    isTouchMode: true
                    showHud: false
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 2
                    height: parent.height
                    color: Style.playhead
                }
                Rectangle {
                    x: 10
                    y: 8
                    width: 24
                    height: 20
                    radius: 4
                    color: Style.deckColor(lane.modelData)

                    Text {
                        anchors.centerIn: parent
                        color: Style.background
                        font.family: Style.mono
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        text: Style.deckLetter(lane.modelData)
                    }
                }
                DvsBadge {
                    x: 42
                    y: 4
                    visible: root.showDvs && active
                    group: lane.modelData
                }
            }
            }
        }
    }
}
