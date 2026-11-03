import ".." as Skin
import QtQuick

// The scrolling waveform in the colors of its deck, like the design: the
// body dark, the peaks light, a soft beat grid and a white playhead.
Skin.WaveformDisplay {
    id: root

    lowColor: Style.deckDark(root.group)
    midColor: Style.deckColor(root.group)
    highColor: Style.deckLight(root.group)
    simpleColor: Style.deckColor(root.group)
    axesColor: Qt.rgba(1, 1, 1, 0.06)
    beatColor: Qt.rgba(1, 1, 1, 0.18)
    playMarkerColor: Style.playhead
    cueColor: Style.cue
    loopColor: Style.ok
    loopRangeColor: Qt.rgba(0.39, 0.36, 1, 0.35)
}
