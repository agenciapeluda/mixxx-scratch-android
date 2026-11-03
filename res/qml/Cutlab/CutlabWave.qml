import ".." as Skin
import QtQuick

// The scrolling waveform with the Cutlab colors: the bass in the color of
// the deck, the mids pink like the voices of the stems, the highs white, a
// soft beat grid and a white playhead.
Skin.WaveformDisplay {
    id: root

    lowColor: Style.deckColor(root.group)
    midColor: Style.stemVocals
    highColor: "#f4f5fb"
    simpleColor: Style.deckColor(root.group)
    axesColor: Qt.rgba(1, 1, 1, 0.08)
    beatColor: Qt.rgba(1, 1, 1, 0.22)
    playMarkerColor: Style.playhead
    cueColor: Style.cue
    loopColor: Style.ok
    loopRangeColor: Qt.rgba(0.39, 0.36, 1, 0.35)
}
