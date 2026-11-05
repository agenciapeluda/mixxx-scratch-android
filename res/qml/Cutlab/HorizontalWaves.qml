import ".." as Skin
import QtQuick

// Both scrolling waveforms one above the other, Serato style: the beats of
// the two decks line up under the playhead, and the four beat lights of
// each deck say on which beat of the bar it is.
Item {
    id: root

    property var sections1: null
    property var sections2: null

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Rectangle {
                id: lane

                required property string modelData
                required property int index

                width: parent.width
                height: (root.height - 12 - 6) / 2
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
                BeatLights {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    group: lane.modelData
                    trackSections: lane.index === 0 ? root.sections1 : root.sections2
                    lightWidth: 14
                    lightHeight: Math.max(8, Math.min(22, (lane.height - 40) / 5))
                }
                Rectangle {
                    x: 32
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
                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    CLControlButton {
                        width: 40
                        height: 40
                        group: lane.modelData
                        key: "waveform_zoom_down"
                        mode: "trigger"
                        icon: "plus"
                        iconSize: 18
                        bordered: false
                        fillColor: "transparent"
                        lit: false
                    }
                    CLControlButton {
                        width: 40
                        height: 40
                        group: lane.modelData
                        key: "waveform_zoom_up"
                        mode: "trigger"
                        icon: "minus"
                        iconSize: 18
                        bordered: false
                        fillColor: "transparent"
                        lit: false
                    }
                }
            }
        }
    }
}
