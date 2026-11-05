import ".." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick

// The scrolling waveform. With "Colores Cutlab" (the default) it takes the
// colors of its deck, like the design: the body dark, the peaks light. With
// "Colores de la configuración" each type keeps its own colors (RGB in red,
// green and blue). The type is always the one picked in the settings.
Skin.WaveformDisplay {
    id: root

    readonly property bool cutlabColors: Style.cutlabWaveColors
    readonly property bool rgb: activeWaveformType === Mixxx.WaveformDisplay.Type.RGB

    lowColor: cutlabColors ? Style.deckDark(root.group) : (rgb ? "#ff3b30" : "#2a21d7")
    midColor: cutlabColors ? Style.deckColor(root.group) : (rgb ? "#34c759" : "#97632d")
    highColor: cutlabColors ? Style.deckLight(root.group) : (rgb ? "#3a8bff" : "#d5c2a2")
    simpleColor: cutlabColors ? Style.deckColor(root.group) : "#d5c2a2"
    axesColor: Qt.rgba(1, 1, 1, 0.06)
    beatColor: Qt.rgba(1, 1, 1, 0.18)
    playMarkerColor: Style.playhead
    cueColor: Style.cue
    loopColor: Style.ok
    loopRangeColor: Qt.rgba(0.39, 0.36, 1, 0.35)

    onCutlabColorsChanged: Qt.callLater(root.rebuild)
}
