import ".." as Skin
import "../Theme"

Skin.ControlButton {
    id: root

    property bool minimized: false

    activeColor: "#7fe6f2"
    key: "cue_default"
    text: "CUE"
    font.weight: Font.DemiBold
}
