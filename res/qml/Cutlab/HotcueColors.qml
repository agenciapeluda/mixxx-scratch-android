import Mixxx 1.0 as Mixxx
import QtQuick

// Gives the hot cues of a deck the Cutlab color of their number when they
// only have an automatic color, so the pads, the waveform marks and the
// lights of the controller all agree. A color of its own (picked by hand or
// imported from Serato or Rekordbox) stays.
Item {
    id: root

    required property string group
    property int count: 8

    Repeater {
        model: root.count

        Item {
            id: cue

            required property int index
            readonly property int number: index + 1

            function check() {
                if (status.value !== 0 && Style.isAutoCueColor(colorControl.value)) {
                    colorControl.value = Style.hexToRgb(Style.hotcueColor(cue.number));
                }
            }

            Mixxx.ControlProxy {
                id: status

                group: root.group
                key: `hotcue_${cue.number}_status`
                onValueChanged: Qt.callLater(cue.check)
            }
            Mixxx.ControlProxy {
                id: colorControl

                group: root.group
                key: `hotcue_${cue.number}_color`
                onValueChanged: Qt.callLater(cue.check)
            }
            Component.onCompleted: Qt.callLater(cue.check)
        }
    }
}
