import Mixxx 1.0 as Mixxx
import QtQuick

// A CLButton that drives a Mixxx control.
//  - "toggle": every tap flips the control
//  - "push": 1 while held, 0 on release (cue, hotcues, rolls...)
//  - "trigger": a short press of the control on tap
CLButton {
    id: root

    required property string group
    required property string key
    property string mode: "push"
    // The control that lights the button, the same one by default
    property string litKey: key
    readonly property alias value: control.value

    lit: litControl.value > 0

    onClicked: {
        if (mode === "toggle") {
            control.value = control.value > 0 ? 0 : 1;
        } else if (mode === "trigger") {
            control.value = 1;
            control.value = 0;
        }
    }
    onPressedDown: {
        if (mode === "push") {
            control.value = 1;
        }
    }
    onReleased: {
        if (mode === "push") {
            control.value = 0;
        }
    }

    Mixxx.ControlProxy {
        id: control

        group: root.group
        key: root.key
    }
    Mixxx.ControlProxy {
        id: litControl

        group: root.group
        key: root.litKey
    }
}
