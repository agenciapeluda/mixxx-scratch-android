import ".." as Skin
import QtQuick

// Both scrolling waveforms one above the other, Serato style: the beats of
// the two decks line up under the playhead, and the four beat lights of
// each deck say on which beat of the bar it is.
Item {
    id: root

    property var sections1: null
    property var sections2: null

    // The beat bar between the lanes: deck A's four lights above, deck
    // B's below, wide and in the deck colors. Lined up, they light
    // together.
    readonly property real barHeight: Math.round(Math.max(22, Math.min(40, height * 0.12)))

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

                Item {
                    // Under lane A: the bar
                    visible: laneBlock.index === 1
                    width: parent.width
                    height: visible ? root.barHeight : 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: [{group: "[Channel1]", sections: root.sections1}, {group: "[Channel2]", sections: root.sections2}]

                            BeatLights {
                                required property var modelData

                                horizontal: true
                                group: modelData.group
                                trackSections: modelData.sections
                                lightWidth: Math.round(Math.min(110, Math.max(44, root.width * 0.09)))
                                lightHeight: Math.round((root.barHeight - 2) / 2)
                            }
                        }
                    }
                }
            Rectangle {
                id: lane

                readonly property string modelData: laneBlock.modelData
                readonly property int index: laneBlock.index

                width: parent.width
                height: (root.height - 12 - 3 * 4 - root.barHeight) / 2
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
            }
            }
        }
    }
}
