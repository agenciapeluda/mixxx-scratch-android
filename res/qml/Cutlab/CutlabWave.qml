import ".." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick

// The scrolling waveform, in the colors picked in the settings: RGB Cutlab
// (bass, mids and highs in vivid colors, the default), the color of the
// deck, or Clásico (the colors of the type), from Style.waveColorSet. The type is always the one picked in
// the settings.
Skin.WaveformDisplay {
    id: root

    readonly property string colors: Style.waveColors

    readonly property var colorSet: Style.waveColorSet(root.colors, root.activeWaveformType, root.group)

    lowColor: root.colorSet.low
    midColor: root.colorSet.mid
    highColor: root.colorSet.high
    simpleColor: root.colorSet.simple
    axesColor: Qt.rgba(1, 1, 1, 0.06)
    // 1.26: a clearer grid (the beat lights are gone: the beats line up here)
    beatColor: Qt.rgba(1, 1, 1, 0.42)
    playMarkerColor: Style.playhead
    cueColor: Style.cue
    loopColor: Style.ok
    loopRangeColor: Qt.rgba(0.39, 0.36, 1, 0.35)

    onColorsChanged: Qt.callLater(root.rebuild)
}
