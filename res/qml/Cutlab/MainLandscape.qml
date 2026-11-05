import Mixxx 1.0 as Mixxx
import QtQuick

// The main screen held sideways, like djay: both decks on top with the
// whole track; a long pitch fader on each side with SYNC and the BPM on
// top; in the middle both waveforms upright side by side with the beat
// lights of each deck between them; next to them the small platter, the FX,
// the hot cues and the toggles of each deck; at the bottom PLAY, CUE and
// SET of each deck around the volume faders and the crossfader; what the
// controller buttons do below. The layout is a 1284 x 600 design scaled to
// the screen.
Rectangle {
    id: root

    readonly property real u: Math.max(0.55, Math.min(width / 1284, height / 600))
    property bool recording: false
    // The light screen: no scrolling waveforms, big platters in the middle
    property bool lite: false
    // The sections of the track on each deck (TrackSections), shared
    required property var sections1
    required property var sections2

    signal libraryRequested(string group)
    signal menuRequested(Item anchor)
    signal recordRequested
    signal fxRequested(string group)

    function px(value) {
        return Math.round(value * root.u);
    }
    function sectionsOf(group) {
        return group === "[Channel2]" ? root.sections2 : root.sections1;
    }

    color: Style.background

    // ---- Top bar: deck A · Cutlab · deck B ----
    Rectangle {
        id: topBar

        width: parent.width
        height: root.px(92)
        color: Style.panel

        DeckStrip {
            x: root.px(14)
            y: root.px(8)
            width: (parent.width - center.width - root.px(28) - root.px(24)) / 2
            height: parent.height - root.px(14)
            group: "[Channel1]"
            u: root.u
            trackSections: root.sections1
            showTempo: false
            onBrowseRequested: root.libraryRequested("[Channel1]")
        }
        Column {
            id: center

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: root.px(150)
            spacing: root.px(6)

            Image {
                id: mark

                anchors.horizontalCenter: parent.horizontalCenter
                width: root.px(38)
                height: width
                source: root.recording ? "icons/cutlab_mark_rec.svg" : "icons/cutlab_mark.svg"
                sourceSize.width: 128
                sourceSize.height: 128

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    onClicked: root.menuRequested(mark)
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.px(6)

                Repeater {
                    model: [qsTr("REC"), qsTr("Biblioteca")]

                    Rectangle {
                        id: pill

                        required property string modelData
                        required property int index
                        readonly property bool lit: index === 0 && root.recording

                        width: pillText.implicitWidth + root.px(20)
                        height: root.px(26)
                        radius: height / 2
                        color: lit ? Style.danger : (pillMouse.pressed ? Style.buttonPressed : "transparent")
                        border.width: 1
                        border.color: lit ? Style.danger : Qt.rgba(1, 1, 1, 0.12)

                        Text {
                            id: pillText

                            anchors.centerIn: parent
                            color: Style.text
                            font.family: Style.font
                            font.weight: Font.DemiBold
                            font.pixelSize: Math.max(9, root.px(11))
                            text: pill.modelData
                        }
                        MouseArea {
                            id: pillMouse

                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: pill.index === 0 ? root.recordRequested() : root.libraryRequested("")
                        }
                    }
                }
            }
        }
        DeckStrip {
            anchors.right: parent.right
            anchors.rightMargin: root.px(14)
            y: root.px(8)
            width: (parent.width - center.width - root.px(28) - root.px(24)) / 2
            height: parent.height - root.px(14)
            group: "[Channel2]"
            mirrored: true
            u: root.u
            trackSections: root.sections2
            showTempo: false
            onBrowseRequested: root.libraryRequested("[Channel2]")
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }
    }

    // ---- The long pitch faders, on the outside ----
    readonly property real pitchWidth: root.px(88)
    readonly property real margin: root.px(14)
    readonly property real gap: root.px(12)

    Repeater {
        model: ["[Channel1]", "[Channel2]"]

        PitchColumn {
            required property string modelData
            required property int index

            x: index === 0 ? root.margin : root.width - root.margin - width
            y: topBar.height + root.px(8)
            width: root.pitchWidth
            height: hints.y - y - root.px(8)
            group: modelData
            mirrored: index === 1
            u: root.u
        }
    }

    // ---- Between the pitch faders ----
    Item {
        id: inner

        x: root.margin + root.pitchWidth + root.gap
        y: topBar.height + root.px(8)
        width: root.width - 2 * x
        height: hints.y - y - root.px(8)

        readonly property real deckWidth: Math.round(width * 0.28)
        readonly property real centerWidth: width - 2 * deckWidth - 2 * root.gap
        readonly property real bottomHeight: root.px(84)
        readonly property real bodyHeight: height - bottomHeight - root.px(8)

        // Each deck: platter and FX, hot cues, toggles
        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Item {
                id: deckPanel

                required property string modelData
                required property int index
                readonly property bool mirrored: index === 1

                x: mirrored ? inner.width - width : 0
                width: inner.deckWidth
                height: inner.bodyHeight

                Item {
                    id: platterRow

                    width: parent.width
                    height: Math.min(root.px(170), parent.height - cues.implicitHeight - root.px(10))

                    TurntableDial {
                        id: platter

                        visible: !root.lite
                        x: deckPanel.mirrored ? parent.width - width : 0
                        width: root.lite ? 0 : parent.height
                        height: parent.height
                        group: deckPanel.modelData
                        trackSections: root.sectionsOf(deckPanel.modelData)
                        showBpm: false
                    }
                    FxChip {
                        x: deckPanel.mirrored ? 0 : platter.width + root.gap
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - platter.width - root.gap
                        group: deckPanel.modelData
                        u: root.u
                        onRequested: root.fxRequested(deckPanel.modelData)
                    }
                }
                CueColumn {
                    id: cues

                    anchors.bottom: parent.bottom
                    width: parent.width
                    group: deckPanel.modelData
                    mirrored: deckPanel.mirrored
                    count: 8
                    toggles: [{label: "KEY", key: "keylock"}, {label: "Q", key: "quantize"}, {label: "SLIP", key: "slip_enabled"}]
                    u: root.u
                }
            }
        }

        // The middle: both waveforms upright with the beat lights between
        // them, or both platters big on the light screen
        Item {
            id: middle

            x: inner.deckWidth + root.gap
            width: inner.centerWidth
            height: inner.bodyHeight

            readonly property real lightsWidth: root.px(48)
            readonly property real laneWidth: (width - lightsWidth) / 2

            Repeater {
                model: root.lite ? [] : ["[Channel1]", "[Channel2]"]

                VerticalWave {
                    required property string modelData
                    required property int index

                    x: index === 0 ? 0 : middle.width - width
                    width: middle.laneWidth
                    height: middle.height
                    group: modelData
                    mirrored: index === 1
                    u: root.u
                }
            }
            Repeater {
                model: root.lite ? ["[Channel1]", "[Channel2]"] : []

                TurntableDial {
                    required property string modelData
                    required property int index

                    x: index === 0 ? 0 : middle.width - width
                    anchors.verticalCenter: parent.verticalCenter
                    width: middle.laneWidth
                    height: Math.min(middle.height, middle.laneWidth)
                    group: modelData
                    trackSections: root.sectionsOf(modelData)
                }
            }
            Row {
                anchors.centerIn: parent
                spacing: root.px(4)

                Repeater {
                    model: ["[Channel1]", "[Channel2]"]

                    BeatLights {
                        required property string modelData

                        group: modelData
                        trackSections: root.sectionsOf(modelData)
                        lightWidth: root.px(18)
                        lightHeight: root.px(22)
                    }
                }
            }
        }

        // ---- Bottom: PLAY CUE SET · volume · crossfader · volume · SET CUE PLAY ----
        Item {
            id: bottomBar

            anchors.bottom: parent.bottom
            width: parent.width
            height: inner.bottomHeight

            DeckButtons {
                anchors.verticalCenter: parent.verticalCenter
                group: "[Channel1]"
                unit: Math.min(root.px(58), parent.height)
            }
            MixerStrip {
                x: middle.x - root.px(20)
                width: middle.width + root.px(40)
                height: parent.height
                u: root.u
            }
            DeckButtons {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                group: "[Channel2]"
                mirrored: true
                unit: Math.min(root.px(58), parent.height)
            }
        }
    }

    // ---- What the controller does ----
    HintsBar {
        id: hints

        anchors.bottom: parent.bottom
        width: parent.width
        height: root.px(26)
        u: root.u
        hints: [
            [qsTr("BROWSE"), qsTr("buscar")],
            [qsTr("LOAD A / B"), qsTr("cargar")],
            [qsTr("FX ON"), qsTr("abre el pad táctil")],
            [qsTr("SHIFT + SYNC"), qsTr("tempo original")]
        ]
    }
}
