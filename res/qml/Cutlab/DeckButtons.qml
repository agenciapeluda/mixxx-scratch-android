import Mixxx 1.0 as Mixxx
import QtQuick

// PLAY, CUE and SET of a deck for the bottom bar (mirrored on deck B).
// CUE works like a CDJ: stopped it sets the cue or goes back to it, held it
// plays while held. It blinks with the tempo of the track: on every beat
// while it plays, at half beats while stopped away from the cue, steady on
// the cue.
Row {
    id: root

    required property string group
    property bool mirrored: false
    property real unit: 56

    readonly property bool loaded: trackLoaded.value > 0
    readonly property bool playing: play.value > 0
    readonly property bool atCue: cueIndicator.value > 0
    readonly property bool cueLit: {
        if (!root.loaded) {
            return false;
        }
        if (root.playing) {
            return beatActive.value > 0;
        }
        return root.atCue || blink.on;
    }

    layoutDirection: mirrored ? Qt.RightToLeft : Qt.LeftToRight
    spacing: Math.round(unit * 0.16)

    Mixxx.ControlProxy {
        id: play

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: cueIndicator

        group: root.group
        key: "cue_indicator"
    }
    Mixxx.ControlProxy {
        id: beatActive

        group: root.group
        key: "beat_active"
    }
    Mixxx.ControlProxy {
        id: bpm

        group: root.group
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: cueDefault

        group: root.group
        key: "cue_default"
    }
    Mixxx.ControlProxy {
        id: cueSet

        group: root.group
        key: "cue_set"
    }
    // Stopped away from the cue: half a beat on, half off
    Timer {
        id: blink

        property bool on: false

        interval: Math.round(30000 / Math.max(60, bpm.value > 0 ? bpm.value : 120))
        repeat: true
        running: root.loaded && !root.playing && !root.atCue
        onRunningChanged: on = false
        onTriggered: on = !on
    }

    // PLAY / PAUSE
    Rectangle {
        width: Math.round(root.unit * 1.25)
        height: root.unit
        radius: Math.round(root.unit * 0.2)
        color: playMouse.pressed ? Style.buttonPressed : (root.playing ? Qt.rgba(0.17, 0.84, 0.48, 0.16) : Style.raised)
        border.width: root.playing ? 2 : 1
        border.color: root.playing ? Style.play : Style.buttonBorder

        Image {
            anchors.centerIn: parent
            width: Math.round(root.unit * 0.4)
            height: width
            source: root.playing ? "icons/pause_lit.svg" : "icons/play.svg"
            sourceSize.width: 64
            sourceSize.height: 64
        }
        MouseArea {
            id: playMouse

            anchors.fill: parent
            onClicked: play.value = root.playing ? 0 : 1
        }
    }
    // CUE
    Rectangle {
        width: Math.round(root.unit * 1.25)
        height: root.unit
        radius: Math.round(root.unit * 0.2)
        color: cueMouse.pressed ? Style.buttonPressed : (root.cueLit ? Qt.rgba(1, 0.71, 0.28, 0.2) : Style.raised)
        border.width: root.cueLit ? 2 : 1
        border.color: root.cueLit ? Style.cue : Style.buttonBorder

        Text {
            anchors.centerIn: parent
            color: root.cueLit ? Style.cue : Style.text
            font.family: Style.font
            font.weight: Font.Bold
            font.pixelSize: Math.max(11, Math.round(root.unit * 0.27))
            text: "CUE"
        }
        MouseArea {
            id: cueMouse

            anchors.fill: parent
            onPressed: cueDefault.value = 1
            onReleased: cueDefault.value = 0
            onCanceled: cueDefault.value = 0
        }
    }
    // SET: the cue goes here, playing or not
    Rectangle {
        width: Math.round(root.unit * 0.95)
        height: root.unit
        radius: Math.round(root.unit * 0.2)
        color: setMouse.pressed ? Style.buttonPressed : "transparent"
        border.width: 1
        border.color: Style.buttonBorder

        Text {
            anchors.centerIn: parent
            color: Style.textSecondary
            font.family: Style.font
            font.weight: Font.Bold
            font.pixelSize: Math.max(10, Math.round(root.unit * 0.22))
            text: "SET"
        }
        MouseArea {
            id: setMouse

            anchors.fill: parent
            onClicked: {
                cueSet.value = 1;
                cueSet.value = 0;
            }
        }
    }
}
