import ".." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick

// The performance screen held upright, for one hand: both tracks, their
// waveforms one above the other, the two dials side by side, transport,
// hot cues, channel faders and the crossfader.
Rectangle {
    id: root

    property bool recording: false

    signal libraryRequested(string group)
    signal menuRequested(Item anchor)
    signal toolsRequested(string group)

    color: Style.background

    readonly property real unit: Math.max(40, Math.min(56, width * 0.12))

    // Logo, library and menu
    Rectangle {
        id: topBar

        width: parent.width
        height: 48
        color: Style.topBar

        Image {
            id: mark

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            source: root.recording ? "icons/cutlab_mark_rec.svg" : "icons/cutlab_mark.svg"
            sourceSize.width: 96
            sourceSize.height: 96
        }
        Text {
            anchors.left: mark.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Style.text
            font.family: Style.font
            font.pixelSize: 18
            font.weight: Font.Medium
            text: "Cutlab"
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            CLButton {
                width: 44
                height: 44
                icon: "search"
                iconSize: 22
                bordered: false
                fillColor: "transparent"
                onClicked: root.libraryRequested("")
            }
            CLButton {
                id: menuButton

                width: 44
                height: 44
                icon: "more"
                iconSize: 22
                bordered: false
                fillColor: "transparent"
                onClicked: root.menuRequested(menuButton)
            }
        }
    }

    Column {
        id: headers

        anchors.top: topBar.bottom
        width: parent.width

        DeckHeader {
            width: parent.width
            height: 54
            group: "[Channel1]"
            onBrowseRequested: root.libraryRequested("[Channel1]")
        }
        DeckHeader {
            width: parent.width
            height: 54
            group: "[Channel2]"
            onBrowseRequested: root.libraryRequested("[Channel2]")
        }
    }

    // Scrolling waveforms, one above the other
    Column {
        id: waves

        anchors.top: headers.bottom
        width: parent.width
        spacing: 1

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Item {
                required property string modelData

                width: waves.width
                height: Math.round(root.height * 0.085)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: "#161617"
                }
                Skin.WaveformDisplay {
                    anchors.fill: parent
                    group: parent.modelData
                    isTouchMode: true
                    showHud: false
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 2
                    height: parent.height
                    color: Style.playhead
                }
            }
        }
    }

    // Dials and their controls
    Row {
        id: decks

        anchors.top: waves.bottom
        anchors.topMargin: 6
        width: parent.width

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Column {
                id: deckColumn

                required property int index
                required property string modelData

                width: decks.width / 2
                spacing: 6

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    CLControlButton {
                        width: root.unit * 1.1
                        height: root.unit * 0.64
                        radius: height / 2
                        group: deckColumn.modelData
                        key: "sync_enabled"
                        mode: "toggle"
                        text: "SYNC"
                        fontSize: 11
                        highlighted: value > 0
                        lit: false
                    }
                    // Turntable control of this deck
                    CLControlButton {
                        width: root.unit * 0.95
                        height: root.unit * 0.64
                        radius: height / 2
                        group: deckColumn.modelData
                        key: "vinylcontrol_enabled"
                        mode: "toggle"
                        text: "DVS"
                        fontSize: 11
                        litColor: Style.play
                        visible: Mixxx.Application.vinylControlAvailable === true
                    }
                    LoopControl {
                        width: Math.max(80, deckColumn.width - root.unit * 2.05 - 40)
                        height: root.unit * 0.64
                        group: deckColumn.modelData
                    }
                }

                DeckDial {
                    width: parent.width
                    height: Math.min(parent.width, root.height * 0.27)
                    group: deckColumn.modelData
                    mirrored: deckColumn.index === 1
                }

                // Pitch
                CLFader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 24
                    height: 34
                    vertical: false
                    invert: false
                    group: deckColumn.modelData
                    key: "rate"
                    sensitivity: 0.5
                    ticks: 5
                    handleThickness: 34
                }

                DeckTransport {
                    anchors.horizontalCenter: parent.horizontalCenter
                    group: deckColumn.modelData
                    unit: Math.min(root.unit, (deckColumn.width - 40) / 4.5)
                    mirrored: deckColumn.index === 1
                    toolsIcon: "fx"
                    onStemsRequested: root.toolsRequested(group)
                }
            }
        }
    }

    // Hot cues with the channel faders on the outside
    Item {
        id: padsRow

        anchors.top: decks.bottom
        anchors.topMargin: 8
        anchors.bottom: crossfaderRow.top
        anchors.bottomMargin: 6
        width: parent.width

        CLFader {
            id: volume1

            anchors.left: parent.left
            anchors.leftMargin: 4
            width: 44
            height: parent.height
            group: "[Channel1]"
            key: "volume"
        }
        HotcuePads {
            anchors.left: volume1.right
            anchors.leftMargin: 4
            width: (parent.width - 2 * 52 - 6) / 2
            height: parent.height
            group: "[Channel1]"
            count: 4
            columns: 2
        }
        HotcuePads {
            anchors.right: volume2.left
            anchors.rightMargin: 4
            width: (parent.width - 2 * 52 - 6) / 2
            height: parent.height
            group: "[Channel2]"
            count: 4
            columns: 2
        }
        CLFader {
            id: volume2

            anchors.right: parent.right
            anchors.rightMargin: 4
            width: 44
            height: parent.height
            group: "[Channel2]"
            key: "volume"
        }
    }

    Rectangle {
        id: crossfaderRow

        anchors.bottom: parent.bottom
        width: parent.width
        height: 56
        color: Style.panelDark

        CLFader {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 320)
            height: parent.height - 8
            vertical: false
            group: "[Master]"
            key: "crossfader"
            ticks: 7
            handleThickness: height * 0.95
        }
    }
}
