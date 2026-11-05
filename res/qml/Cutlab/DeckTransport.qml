import Mixxx 1.0 as Mixxx
import QtQuick

// Play, cue and stems of one deck, for the bottom bar.
Row {
    id: transport

    required property string group
    property bool mirrored: false
    property real unit: 48
    // The round button after cue: stems on the wide screen, all the deck
    // tools (FX, stems, loops, cues, EQ) on the upright one
    property string toolsIcon: "stems"
    // The tools are in the deck on the wide screen: no button here
    property bool showTools: true

    // CUE blinks with the tempo: on every beat while playing, at half beats
    // while stopped away from the cue, steady on the cue
    readonly property bool loaded: trackLoaded.value > 0
    readonly property bool cueLit: {
        if (!transport.loaded) {
            return false;
        }
        if (play.value > 0) {
            return beatActive.value > 0;
        }
        return cueIndicator.value > 0 || blink.on;
    }

    signal stemsRequested

    layoutDirection: mirrored ? Qt.RightToLeft : Qt.LeftToRight
    spacing: Math.max(8, unit * 0.2)

    Mixxx.ControlProxy {
        id: play

        group: transport.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: trackLoaded

        group: transport.group
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: cueIndicator

        group: transport.group
        key: "cue_indicator"
    }
    Mixxx.ControlProxy {
        id: beatActive

        group: transport.group
        key: "beat_active"
    }
    Mixxx.ControlProxy {
        id: bpm

        group: transport.group
        key: "bpm"
    }
    Timer {
        id: blink

        property bool on: false

        interval: Math.round(30000 / Math.max(60, bpm.value > 0 ? bpm.value : 120))
        repeat: true
        running: transport.loaded && play.value <= 0 && cueIndicator.value <= 0
        onRunningChanged: on = false
        onTriggered: on = !on
    }

    // Play / pause, ringed in green while playing
    CLButton {
        width: transport.unit
        height: transport.unit
        round: true
        icon: play.value > 0 ? "pause" : "play"
        iconSize: transport.unit * 0.36
        fillColor: "#222224"
        lit: play.value > 0
        litColor: Style.play
        onClicked: play.value = play.value > 0 ? 0 : 1
    }
    // SET stores the cue point, the arrow returns to it (and plays
    // while held, like a CDJ)
    Row {
        anchors.verticalCenter: parent.verticalCenter
        layoutDirection: Qt.LeftToRight

        CLControlButton {
            width: transport.unit * 1.35
            height: transport.unit * 0.92
            radius: 8
            group: transport.group
            key: "cue_set"
            mode: "trigger"
            text: "SET"
            fontSize: Math.round(transport.unit * 0.27)
            lit: false
        }
        CLControlButton {
            width: transport.unit * 1.35
            height: transport.unit * 0.92
            radius: 8
            group: transport.group
            key: "cue_default"
            mode: "push"
            icon: "cue"
            iconSize: transport.unit * 0.42
            lit: transport.cueLit
            litColor: Style.cue
        }
    }
    CLButton {
        visible: transport.showTools
        anchors.verticalCenter: parent.verticalCenter
        width: transport.unit * 0.8
        height: width
        round: true
        icon: transport.toolsIcon
        iconSize: width * 0.44
        onClicked: transport.stemsRequested()
    }
}
