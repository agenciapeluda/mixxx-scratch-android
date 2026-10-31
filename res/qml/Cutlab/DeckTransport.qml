import Mixxx 1.0 as Mixxx
import QtQuick

// Play, cue and stems of one deck, for the bottom bar.
Row {
    id: transport

    required property string group
    property bool mirrored: false
    property real unit: 48

    signal stemsRequested

    layoutDirection: mirrored ? Qt.RightToLeft : Qt.LeftToRight
    spacing: Math.max(8, unit * 0.2)

    Mixxx.ControlProxy {
        id: play

        group: transport.group
        key: "play"
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
            litKey: "cue_indicator"
            litColor: Style.cue
        }
    }
    CLButton {
        anchors.verticalCenter: parent.verticalCenter
        width: transport.unit * 0.8
        height: width
        round: true
        icon: "stems"
        iconSize: width * 0.44
        onClicked: transport.stemsRequested()
    }
}
