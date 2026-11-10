import Mixxx 1.0 as Mixxx
import QtQuick

// The screen held upright, as in the design "Vertical · mezcla": the mark,
// REC and the library on top; both decks as cards; both waveforms upright
// side by side (the track runs upwards, what comes is below the line) with
// the phase between them; SYNC, DVS and FX of each deck; four hot cues each;
// the crossfader. Tap a deck card to play or pause, hold it to load.
Rectangle {
    id: root

    property bool recording: false
    // The light screen: platters instead of the scrolling waveforms
    property bool lite: false
    readonly property real u: Math.max(0.85, Math.min(1.2, width / 390))

    signal libraryRequested(string group)
    signal menuRequested(Item anchor)
    signal toolsRequested(string group)

    function px(value) {
        return Math.round(value * root.u);
    }

    color: Style.background

    // ---- Mark, REC, library ----
    Item {
        id: header

        width: parent.width
        height: root.px(60)

        Row {
            x: root.px(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.px(8)

            Image {
                id: mark

                anchors.verticalCenter: parent.verticalCenter
                width: root.px(30)
                height: width
                source: root.recording ? "icons/cutlab_mark_rec.svg" : "icons/cutlab_mark.svg"
                sourceSize.width: 96
                sourceSize.height: 96

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    onClicked: root.menuRequested(mark)
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Style.text
                font.family: Style.font
                font.weight: Font.Bold
                font.pixelSize: root.px(15)
                font.letterSpacing: -0.2
                text: "cutlab"
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.px(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.px(8)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: recText.implicitWidth + root.px(24)
                height: root.px(32)
                radius: height / 2
                color: root.recording ? Style.danger : "transparent"
                border.width: 1
                border.color: root.recording ? Style.danger : Qt.rgba(1, 1, 1, 0.12)

                Text {
                    id: recText

                    anchors.centerIn: parent
                    color: Style.text
                    font.family: Style.font
                    font.weight: Font.DemiBold
                    font.pixelSize: root.px(12)
                    text: "REC"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        toggleRecording.value = 1;
                        toggleRecording.value = 0;
                    }
                }
            }
            CLButton {
                width: root.px(44)
                height: width
                radius: root.px(10)
                icon: "list"
                iconSize: root.px(18)
                fillColor: "transparent"
                onClicked: root.libraryRequested("")
            }
        }
    }
    Mixxx.ControlProxy {
        id: toggleRecording

        group: "[Recording]"
        key: "toggle_recording"
    }

    // ---- Deck cards ----
    Row {
        id: cards

        anchors.top: header.bottom
        x: root.px(12)
        width: parent.width - 2 * x
        spacing: root.px(8)

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Rectangle {
                id: card

                required property string modelData
                readonly property var player: Mixxx.PlayerManager.getPlayer(modelData)
                readonly property var track: player ? player.currentTrack : null
                readonly property bool loaded: loadedControl.value > 0
                readonly property real remaining: Math.max(0, duration.value * (1 - position.value)) / Math.max(0.01, rate.value)

                width: (cards.width - cards.spacing) / 2
                height: cardColumn.implicitHeight + root.px(16) + 3
                radius: root.px(12)
                color: cardMouse.pressed ? Style.raised : Style.panel
                clip: true

                Rectangle {
                    width: parent.width
                    height: 3
                    color: Style.deckColor(card.modelData)
                }
                Column {
                    id: cardColumn

                    x: root.px(10)
                    y: 3 + root.px(8)
                    width: parent.width - 2 * x
                    spacing: root.px(3)

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        color: Style.text
                        font.family: Style.font
                        font.weight: Font.DemiBold
                        font.pixelSize: root.px(13)
                        text: card.loaded && card.track ? card.track.title : qsTr("Tocá para cargar")
                        opacity: card.loaded ? 1 : 0.55
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        color: Style.textSecondary
                        font.family: Style.font
                        font.pixelSize: root.px(11)
                        text: card.loaded && card.track ? card.track.artist : " "
                    }
                    Item {
                        width: parent.width
                        height: cardBpm.implicitHeight

                        Row {
                            spacing: root.px(6)

                            Text {
                                id: cardBpm

                                color: Style.text
                                font.family: Style.mono
                                font.weight: Font.Bold
                                font.pixelSize: root.px(18)
                                text: card.loaded && bpm.value > 0 ? bpm.value.toFixed(1) : "—"
                            }
                            Rectangle {
                                anchors.verticalCenter: cardBpm.verticalCenter
                                visible: card.loaded && Mixxx.KeyUtils.keyIsValid(keyControl.value)
                                width: cardKey.implicitWidth + 8
                                height: cardKey.implicitHeight
                                radius: 3
                                color: Style.keyChip

                                Text {
                                    id: cardKey

                                    anchors.centerIn: parent
                                    color: Style.background
                                    font.family: Style.mono
                                    font.weight: Font.Bold
                                    font.pixelSize: root.px(10)
                                    text: Mixxx.KeyUtils.keyIsValid(keyControl.value) ? Mixxx.KeyUtils.keyToString(keyControl.value) : ""
                                }
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            color: play.value > 0 ? Style.text : Style.textSecondary
                            font.family: Style.mono
                            font.pixelSize: root.px(13)
                            text: card.loaded ? "-" + Style.formatTime(card.remaining) : ""
                        }
                    }
                }
                MouseArea {
                    id: cardMouse

                    anchors.fill: parent
                    onClicked: {
                        if (!card.loaded) {
                            root.libraryRequested(card.modelData);
                        } else if (dvs.value <= 0) {
                            play.value = play.value > 0 ? 0 : 1;
                        }
                    }
                    onPressAndHold: root.libraryRequested(card.modelData)
                }

                Mixxx.ControlProxy {
                    id: loadedControl

                    group: card.modelData
                    key: "track_loaded"
                }
                Mixxx.ControlProxy {
                    id: duration

                    group: card.modelData
                    key: "duration"
                }
                // The shared position reader (15 times a second)
                QtObject {
                    id: position

                    readonly property real value: Clock.position(card.modelData)
                }
                Mixxx.ControlProxy {
                    id: rate

                    group: card.modelData
                    key: "rate_ratio"
                }
                Mixxx.ControlProxy {
                    id: bpm

                    group: card.modelData
                    key: "bpm"
                }
                Mixxx.ControlProxy {
                    id: keyControl

                    group: card.modelData
                    key: "key"
                }
                Mixxx.ControlProxy {
                    id: play

                    group: card.modelData
                    key: "play"
                }
                Mixxx.ControlProxy {
                    id: dvs

                    group: card.modelData
                    key: "vinylcontrol_enabled"
                }
            }
        }
    }

    // ---- Both waveforms upright ----
    Item {
        id: waves

        anchors.top: cards.bottom
        anchors.topMargin: root.px(8)
        anchors.bottom: buttons.top
        anchors.bottomMargin: root.px(10)
        x: root.px(12)
        width: parent.width - 2 * x

        Row {
            anchors.fill: parent
            spacing: root.px(8)
            visible: root.lite

            Repeater {
                model: root.lite ? ["[Channel1]", "[Channel2]"] : []

                TurntableDial {
                    required property string modelData

                    width: (waves.width - root.px(8)) / 2
                    height: waves.height
                    group: modelData
                }
            }
        }
        Row {
            anchors.fill: parent
            spacing: root.px(8)
            visible: !root.lite

            Repeater {
                model: root.lite ? [] : ["[Channel1]", "[Channel2]"]

                Rectangle {
                    required property string modelData

                    width: (waves.width - root.px(8)) / 2
                    height: waves.height
                    radius: root.px(12)
                    color: Style.panel
                    clip: true

                    CutlabWave {
                        anchors.centerIn: parent
                        width: parent.height
                        height: parent.width
                        rotation: 90
                        group: parent.modelData
                        isTouchMode: true
                        showHud: false
                    }
                }
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.lite
            width: parent.width
            height: 2
            color: Style.playhead
        }
        // The phase: EN FASE, or how far B is from A
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: root.lite ? undefined : parent.verticalCenter
            anchors.bottom: root.lite ? parent.bottom : undefined
            visible: phase.active
            width: phaseText.implicitWidth + root.px(14)
            height: phaseText.implicitHeight + 4
            radius: height / 2
            color: Style.background
            border.width: 1
            border.color: phaseText.color

            Text {
                id: phaseText

                anchors.centerIn: parent
                color: phase.inPhase ? Style.ok : (Math.abs(phase.offsetMs) < 40 ? Style.cue : Style.danger)
                font.family: Style.mono
                font.weight: Font.Bold
                font.pixelSize: root.px(10)
                text: phase.inPhase ? qsTr("EN FASE") : qsTr("B %1%2 ms").arg(phase.offsetMs > 0 ? "+" : "−").arg(Math.round(Math.abs(phase.offsetMs)))
            }
        }
        PhaseMeter {
            id: phase

            visible: false
        }
    }

    // ---- SYNC, DVS, FX of each deck ----
    Row {
        id: buttons

        anchors.bottom: cues.top
        anchors.bottomMargin: root.px(8)
        x: root.px(12)
        width: parent.width - 2 * x
        spacing: root.px(8)

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Row {
                id: deckButtons

                required property string modelData
                required property int index

                width: (buttons.width - buttons.spacing) / 2
                layoutDirection: index === 1 ? Qt.RightToLeft : Qt.LeftToRight
                spacing: root.px(6)

                Repeater {
                    model: ["sync", "dvs", "fx"]

                    Rectangle {
                        id: deckButton

                        required property string modelData
                        readonly property bool on: modelData === "sync" ? sync.value > 0 : modelData === "dvs" ? dvsOn.value > 0 : false
                        readonly property color onColor: modelData === "dvs" ? Style.ok : Style.accent

                        width: (deckButtons.width - 2 * deckButtons.spacing) / 3
                        height: root.px(44)
                        radius: root.px(10)
                        color: on && modelData === "sync" ? Style.accent : (buttonMouse.pressed ? Style.raised : "transparent")
                        border.width: 1
                        border.color: on ? onColor : Qt.rgba(1, 1, 1, 0.12)

                        Text {
                            anchors.centerIn: parent
                            color: deckButton.on ? (deckButton.modelData === "sync" ? "#ffffff" : Style.ok) : Style.text
                            font.family: Style.font
                            font.weight: Font.Bold
                            font.pixelSize: root.px(12)
                            text: deckButton.modelData === "sync" ? "SYNC"
                                : deckButton.modelData === "fx" ? "FX"
                                : (dvsOn.value > 0 ? "DVS " + ["ABS", "REL", "INT"][Math.max(0, Math.min(2, Math.round(dvsMode.value)))] : "DVS")
                        }
                        MouseArea {
                            id: buttonMouse

                            anchors.fill: parent
                            onClicked: {
                                if (deckButton.modelData === "sync") {
                                    sync.value = sync.value > 0 ? 0 : 1;
                                } else if (deckButton.modelData === "dvs") {
                                    dvsOn.value = dvsOn.value > 0 ? 0 : 1;
                                } else {
                                    root.toolsRequested(deckButtons.modelData);
                                }
                            }
                            onPressAndHold: {
                                if (deckButton.modelData === "dvs" && dvsOn.value > 0) {
                                    dvsMode.value = (Math.round(dvsMode.value) + 1) % 3;
                                }
                            }
                        }
                    }
                }
                Mixxx.ControlProxy {
                    id: sync

                    group: deckButtons.modelData
                    key: "sync_enabled"
                }
                Mixxx.ControlProxy {
                    id: dvsOn

                    group: deckButtons.modelData
                    key: "vinylcontrol_enabled"
                }
                Mixxx.ControlProxy {
                    id: dvsMode

                    group: deckButtons.modelData
                    key: "vinylcontrol_mode"
                }
            }
        }
    }

    // ---- Hot cues ----
    Row {
        id: cues

        anchors.bottom: fader.top
        anchors.bottomMargin: root.px(10)
        x: root.px(12)
        width: parent.width - 2 * x
        spacing: root.px(8)

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            CueColumn {
                required property string modelData

                width: (cues.width - cues.spacing) / 2
                group: modelData
                compact: true
                u: root.u
            }
        }
    }

    // ---- Crossfader ----
    Column {
        id: fader

        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.px(14)
        x: root.px(12)
        width: parent.width - 2 * x
        spacing: root.px(4)

        Item {
            width: parent.width
            height: xfLabel.implicitHeight

            Text {
                color: Style.textSecondary
                font.family: Style.font
                font.weight: Font.DemiBold
                font.pixelSize: root.px(10)
                text: "A"
            }
            Text {
                id: xfLabel

                anchors.horizontalCenter: parent.horizontalCenter
                color: Style.textSecondary
                font.family: Style.font
                font.weight: Font.DemiBold
                font.pixelSize: root.px(10)
                font.letterSpacing: 0.5
                text: qsTr("CROSSFADER")
            }
            Text {
                anchors.right: parent.right
                color: Style.textSecondary
                font.family: Style.font
                font.weight: Font.DemiBold
                font.pixelSize: root.px(10)
                text: "B"
            }
        }
        Item {
            id: xfTrack

            width: parent.width
            height: root.px(24)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: root.px(8)
                radius: height / 2
                color: Style.track
            }
            Rectangle {
                id: xfHandle

                anchors.verticalCenter: parent.verticalCenter
                x: (crossfader.value + 1) / 2 * (xfTrack.width - width)
                width: root.px(10)
                height: root.px(22)
                radius: 3
                color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -10
                anchors.bottomMargin: -10
                preventStealing: true
                function set(x) {
                    crossfader.value = Math.max(-1, Math.min(1, (x - xfHandle.width / 2) / (xfTrack.width - xfHandle.width) * 2 - 1));
                }
                onPressed: mouse => set(mouse.x)
                onPositionChanged: mouse => set(mouse.x)
                onDoubleClicked: crossfader.value = 0
            }
        }
        Mixxx.ControlProxy {
            id: crossfader

            group: "[Master]"
            key: "crossfader"
        }
    }
}
