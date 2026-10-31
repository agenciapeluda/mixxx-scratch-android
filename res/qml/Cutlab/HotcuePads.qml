import Mixxx 1.0 as Mixxx
import QtQuick

// Hot cues 1-8 of a deck: tap an empty pad to set it, tap a set pad to
// jump to it (and play while held when stopped), hold it to clear it.
Grid {
    id: root

    required property string group
    property int count: 8

    columns: 4
    rows: Math.ceil(count / columns)
    spacing: 1

    Repeater {
        model: root.count

        Pad {
            id: pad

            required property int index
            readonly property int number: index + 1
            readonly property bool isSet: status.value !== 0

            width: (root.width - (root.columns - 1) * root.spacing) / root.columns
            height: (root.height - (root.rows - 1) * root.spacing) / root.rows
            text: isSet ? qsTr("Cue %1").arg(number) : ""
            tag: isSet ? "" : String(number)
            padColor: isSet ? (colorControl.value < 0 ? Style.cue : "#" + Math.round(colorControl.value).toString(16).padStart(6, "0")) : "transparent"
            active: isSet && pressed

            onPressedDown: activate.value = 1
            onReleased: activate.value = 0
            onPressAndHold: {
                activate.value = 0;
                clear.value = 1;
                clear.value = 0;
            }

            Mixxx.ControlProxy {
                id: status

                group: root.group
                key: `hotcue_${pad.number}_status`
            }
            Mixxx.ControlProxy {
                id: colorControl

                group: root.group
                key: `hotcue_${pad.number}_color`
            }
            Mixxx.ControlProxy {
                id: activate

                group: root.group
                key: `hotcue_${pad.number}_activate`
            }
            Mixxx.ControlProxy {
                id: clear

                group: root.group
                key: `hotcue_${pad.number}_clear`
            }
        }
    }
}
