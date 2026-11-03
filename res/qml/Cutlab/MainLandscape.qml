import Mixxx 1.0 as Mixxx
import QtQuick

// The main screen held sideways, as in the design "Horizontal · mezcla y
// scratch": both decks on top with the whole track, both waveforms in
// parallel with the phase meter, the platters, hot cues and mixer, and what
// the controller buttons do at the bottom. The layout is the 1284 x 600
// design scaled to the screen.
Rectangle {
    id: root

    readonly property real u: Math.max(0.55, Math.min(width / 1284, height / 600))
    property bool recording: false
    // The light screen: no scrolling waveforms, the platters take the room
    property bool lite: false

    signal libraryRequested(string group)
    signal menuRequested(Item anchor)
    signal recordRequested
    signal fxRequested(string group)

    function px(value) {
        return Math.round(value * root.u);
    }

    color: Style.background

    // ---- Top bar: deck A · Cutlab · deck B ----
    Rectangle {
        id: topBar

        width: parent.width
        height: root.px(100)
        color: Style.panel

        DeckStrip {
            x: root.px(14)
            y: root.px(10)
            width: (parent.width - center.width - root.px(28) - root.px(24)) / 2
            height: parent.height - root.px(18)
            group: "[Channel1]"
            u: root.u
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
                width: root.px(40)
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
            y: root.px(10)
            width: (parent.width - center.width - root.px(28) - root.px(24)) / 2
            height: parent.height - root.px(18)
            group: "[Channel2]"
            mirrored: true
            u: root.u
            onBrowseRequested: root.libraryRequested("[Channel2]")
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }
    }

    // ---- Parallel waveforms, Serato style ----
    Item {
        id: waves

        anchors.top: topBar.bottom
        width: parent.width
        height: root.lite ? 0 : root.px(8 + 96 + 6 + 96 + 8)
        visible: !root.lite

        Column {
            x: root.px(14)
            y: root.px(8)
            width: parent.width - root.px(28)
            spacing: root.px(6)

            Repeater {
                model: ["[Channel1]", "[Channel2]"]

                Rectangle {
                    id: lane

                    required property string modelData

                    width: parent.width
                    height: root.px(96)
                    radius: root.px(8)
                    color: Style.panel
                    clip: true

                    CutlabWave {
                        anchors.fill: parent
                        group: lane.modelData
                        isTouchMode: true
                        showHud: false
                    }
                }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.px(4)
            width: 2
            height: parent.height - root.px(8)
            color: Style.playhead
        }
        PhaseMeter {
            anchors.centerIn: parent
            width: root.px(260)
        }
    }

    // ---- Platters · hot cues · mixer · hot cues · platters ----
    Item {
        id: deckRow

        anchors.top: waves.bottom
        anchors.topMargin: root.lite ? root.px(50) : 0
        anchors.bottom: hints.top
        x: root.px(14)
        width: parent.width - root.px(28)

        readonly property real dial: Math.min(root.px(root.lite ? 260 : 210), height - root.px(14))
        readonly property real mixer: root.px(300)
        readonly property real gap: root.px(14)
        readonly property real cues: (width - 2 * dial - mixer - 4 * gap) / 2

        TurntableDial {
            anchors.verticalCenter: parent.verticalCenter
            width: deckRow.dial
            height: deckRow.dial
            group: "[Channel1]"
        }
        CueColumn {
            anchors.verticalCenter: parent.verticalCenter
            x: deckRow.dial + deckRow.gap
            width: deckRow.cues
            group: "[Channel1]"
            u: root.u
        }
        MixerCard {
            anchors.verticalCenter: parent.verticalCenter
            x: deckRow.dial + deckRow.cues + 2 * deckRow.gap
            width: deckRow.mixer
            height: Math.min(parent.height - root.px(8), implicitHeight)
            u: root.u
            onFxRequested: group => root.fxRequested(group)
        }
        CueColumn {
            anchors.verticalCenter: parent.verticalCenter
            x: deckRow.dial + deckRow.cues + deckRow.mixer + 3 * deckRow.gap
            width: deckRow.cues
            group: "[Channel2]"
            mirrored: true
            u: root.u
        }
        TurntableDial {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: deckRow.dial
            height: deckRow.dial
            group: "[Channel2]"
        }
    }

    // The phase, on the light screen without the waveforms
    PhaseMeter {
        visible: root.lite
        anchors.horizontalCenter: parent.horizontalCenter
        y: topBar.height + root.px(10)
        width: root.px(300)
    }

    // ---- What the controller does ----
    HintsBar {
        id: hints

        anchors.bottom: parent.bottom
        width: parent.width
        height: root.px(30)
        u: root.u
        hints: [
            [qsTr("BROWSE"), qsTr("buscar")],
            [qsTr("LOAD A / B"), qsTr("cargar")],
            [qsTr("FX ON"), qsTr("abre el pad táctil")],
            [qsTr("SHIFT + SYNC"), qsTr("tempo original")]
        ]
    }
}
