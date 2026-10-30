import ".." as Skin
import "../Theme"

Skin.ControlButton {
    id: root

    property bool minimized: false

    activeColor: "#ff8f57"
    key: "cue_default"
    text: "CUE"
    font.weight: Font.DemiBold
}
