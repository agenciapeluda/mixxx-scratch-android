import ".." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick

// The scrolling waveform, in the colors picked in the settings: RGB Cutlab
// (bass, mids and highs in vivid colors, the default), the color of the
// deck, or the colors of the type. The type is always the one picked in
// the settings.
Skin.WaveformDisplay {
    id: root

    readonly property string colors: Style.waveColors
    readonly property bool rgb: activeWaveformType === Mixxx.WaveformDisplay.Type.RGB

    lowColor: colors === "rgb" ? Style.waveLow : (colors === "deck" ? Style.deckDark(root.group) : (rgb ? "#ff3b30" : "#2a21d7"))
    midColor: colors === "rgb" ? Style.waveMid : (colors === "deck" ? Style.deckColor(root.group) : (rgb ? "#34c759" : "#97632d"))
    highColor: colors === "rgb" ? Style.waveHigh : (colors === "deck" ? Style.deckLight(root.group) : (rgb ? "#3a8bff" : "#d5c2a2"))
    simpleColor: colors === "deck" ? Style.deckColor(root.group) : (colors === "rgb" ? Style.waveHigh : "#d5c2a2")
    axesColor: Qt.rgba(1, 1, 1, 0.06)
    // 1.26: a clearer grid (the beat lights are gone: the beats line up here)
    beatColor: Qt.rgba(1, 1, 1, 0.42)
    playMarkerColor: Style.playhead
    cueColor: Style.cue
    loopColor: Style.ok
    loopRangeColor: Qt.rgba(0.39, 0.36, 1, 0.35)

    onColorsChanged: Qt.callLater(root.rebuild)
}
