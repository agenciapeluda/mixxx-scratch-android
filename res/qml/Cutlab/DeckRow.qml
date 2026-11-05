import Mixxx 1.0 as Mixxx
import QtQuick

// The buttons of a deck over its pads: its tools (mixer, FX, stems...),
// PLAY, CUE, SYNC and the loop. Deck B is mirrored. CUE blinks with the
// tempo: on every beat while playing, at half beats while stopped away from
// the cue, steady on the cue. Hold SYNC to go back to the original tempo;
// hold the loop to change its length.
Row {
    id: root

    required property string group
    property bool mirrored: false
    property bool toolsOpen: false
    // How many buttons fit: 5, or 4 without the loop
    readonly property bool withLoop: width >= 5 * 48
    readonly property real buttonWidth: (width - spacing * ((withLoop ? 5 : 4) - 1)) / (withLoop ? 5 : 4)

    readonly property bool loaded: trackLoaded.value > 0
    readonly property bool playing: play.value > 0
    readonly property bool cueLit: {
        if (!root.loaded) {
            return false;
        }
        if (root.playing) {
            return beatActive.value > 0;
        }
        return cueIndicator.value > 0 || blink.on;
    }

    signal toolsRequested
    signal loopToolRequested

    layoutDirection: mirrored ? Qt.RightToLeft : Qt.LeftToRight
    spacing: 6

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
        id: cueDefault

        group: root.group
        key: "cue_default"
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
        id: sync

        group: root.group
        key: "sync_enabled"
    }
    Mixxx.ControlProxy {
        id: rate

        group: root.group
        key: "rate"
    }
    Mixxx.ControlProxy {
        id: loopEnabled

        group: root.group
        key: "loop_enabled"
    }
    Mixxx.ControlProxy {
        id: loopSize

        group: root.group
        key: "beatloop_size"
    }
    Mixxx.ControlProxy {
        id: loopActivate

        group: root.group
        key: "beatloop_activate"
    }
    Mixxx.ControlProxy {
        id: reloop

        group: root.group
        key: "reloop_toggle"
    }
    Timer {
        id: blink

        property bool on: false

        interval: Math.round(30000 / Math.max(60, bpm.value > 0 ? bpm.value : 120))
        repeat: true
        running: root.loaded && !root.playing && cueIndicator.value <= 0
        onRunningChanged: on = false
        onTriggered: on = !on
    }

    // The tools of the deck
    CLButton {
        width: root.buttonWidth
        height: root.height
        radius: height / 2
        icon: "mixer"
        iconSize: Math.min(22, height * 0.46)
        lit: root.toolsOpen
        onClicked: root.toolsRequested()
    }
    // PLAY / PAUSE
    CLButton {
        width: root.buttonWidth
        height: root.height
        radius: height / 2
        icon: root.playing ? "pause" : "play"
        iconSize: Math.min(22, height * 0.46)
        fillColor: root.playing ? Style.accent : "#1d1b33"
        highlighted: root.playing
        onClicked: play.value = root.playing ? 0 : 1
    }
    // CUE, like a CDJ
    CLButton {
        width: root.buttonWidth
        height: root.height
        radius: height / 2
        text: "CUE"
        fontSize: Math.max(11, Math.min(14, height * 0.3))
        lit: root.cueLit
        litColor: Style.cue
        onPressedDown: cueDefault.value = 1
        onReleased: cueDefault.value = 0
    }
    // SYNC
    CLButton {
        width: root.buttonWidth
        height: root.height
        radius: height / 2
        text: "SYNC"
        fontSize: Math.max(11, Math.min(14, height * 0.3))
        highlighted: sync.value > 0
        onClicked: sync.value = sync.value > 0 ? 0 : 1
        onPressAndHold: {
            sync.value = 0;
            rate.value = 0;
        }
    }
    // The loop of the length picked
    CLButton {
        visible: root.withLoop
        width: root.buttonWidth
        height: root.height
        radius: height / 2
        text: "LOOP " + Style.beatsText(loopSize.value)
        fontSize: Math.max(11, Math.min(14, height * 0.3))
        lit: loopEnabled.value > 0
        litColor: Style.ok
        onClicked: {
            if (loopEnabled.value > 0) {
                reloop.value = 1;
                reloop.value = 0;
            } else {
                loopActivate.value = 1;
                loopActivate.value = 0;
            }
        }
        onPressAndHold: root.loopToolRequested()
    }
}
