import Mixxx 1.0 as Mixxx
import QtQuick

// Loop rolls: the loop plays while the pad is held, then the track carries
// on where it would have been.
Grid {
    id: root

    required property string group
    readonly property var sizes: [0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8]

    columns: 4
    rows: 2
    spacing: 1

    function sizeText(size) {
        return size >= 1 ? String(size) : "1/" + Math.round(1 / size);
    }

    Repeater {
        model: root.sizes

        Pad {
            id: pad

            required property real modelData

            width: (root.width - (root.columns - 1) * root.spacing) / root.columns
            height: (root.height - (root.rows - 1) * root.spacing) / root.rows
            text: root.sizeText(modelData)
            tag: qsTr("Roll")
            active: pressed
            padColor: Style.loop

            onPressedDown: roll.value = 1
            onReleased: roll.value = 0

            Mixxx.ControlProxy {
                id: roll

                group: root.group
                key: `beatlooproll_${pad.modelData}_activate`
            }
        }
    }
}
