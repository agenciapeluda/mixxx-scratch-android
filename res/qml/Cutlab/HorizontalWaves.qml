import ".." as Skin
import QtQuick

// Both scrolling waveforms one above the other, Serato style: the beats of
// the two decks line up under the playhead and the phase meter between
// them says how far apart they are.
Item {
    id: root

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

    Rectangle {
        anchors.centerIn: parent
        width: phase.width + 20
        height: phase.height + 8
        radius: 12
        color: Style.background
        opacity: 0.92

        PhaseMeter {
            id: phase

            anchors.centerIn: parent
            width: Math.min(300, root.width * 0.4)
        }
    }
}
