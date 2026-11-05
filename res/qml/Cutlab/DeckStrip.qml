import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick

// A deck in the top bar, as in the design: cover, letter, title and artist;
// BPM, pitch, key, the drop countdown, the time left and the DVS mode; the
// whole track below with its breaks, pauses and drops. Deck B is mirrored.
Item {
    id: root

    required property string group
    property bool mirrored: false
    // Scale of the design (1 = 1284 x 600)
    property real u: 1

    readonly property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
    readonly property var currentTrack: deckPlayer ? deckPlayer.currentTrack : null
    readonly property bool loaded: trackLoaded.value > 0
    readonly property real remaining: Math.max(0, duration.value * (1 - playPosition.value)) / Math.max(0.01, rateRatio.value)
    readonly property real pitchPercent: (rateRatio.value - 1) * 100

    signal browseRequested

    function fs(px) {
        return Math.max(9, Math.round(px * root.u));
    }

    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: duration

        group: root.group
        key: "duration"
    }
    Mixxx.ControlProxy {
        id: playPosition

        group: root.group
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: rateRatio

        group: root.group
        key: "rate_ratio"
    }
    Mixxx.ControlProxy {
        id: bpm

        group: root.group
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: keyControl

        group: root.group
        key: "key"
    }
    Mixxx.ControlProxy {
        id: beatActive

        group: root.group
        key: "beat_active"
    }
    Mixxx.ControlProxy {
        id: endOfTrack

        group: root.group
        key: "end_of_track"
    }
    Mixxx.ControlProxy {
        id: dvsEnabled

        group: root.group
        key: "vinylcontrol_enabled"
    }
    Mixxx.ControlProxy {
        id: dvsMode

        group: root.group
        key: "vinylcontrol_mode"
    }
    Mixxx.ControlProxy {
        id: dvsStatus

        group: root.group
        key: "vinylcontrol_status"
    }
    TrackSections {
        id: trackSections

        group: root.group
    }

    // ---- Cover ----
    Rectangle {
        id: cover

        x: root.mirrored ? root.width - width : 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(52 * root.u)
        height: width
        radius: Math.round(10 * root.u)
        color: Style.deckShade(root.group)
        clip: true

        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: root.loaded && root.currentTrack ? root.currentTrack.coverArtUrl : ""
            visible: status === Image.Ready
        }
        Text {
            anchors.centerIn: parent
            visible: !root.loaded || !root.currentTrack || root.currentTrack.coverArtUrl.toString() === ""
            color: Style.deckColor(root.group)
            font.family: Style.mono
            font.weight: Font.Bold
            font.pixelSize: root.fs(11)
            text: Style.deckLetter(root.group)
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.browseRequested()
        }
    }

    Item {
        id: info

        x: root.mirrored ? 0 : cover.width + Math.round(12 * root.u)
        width: root.width - cover.width - Math.round(12 * root.u)
        height: root.height

        // Title row
        Row {
            id: titleRow

            y: Math.round(2 * root.u)
            layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight
            width: parent.width
            spacing: Math.round(8 * root.u)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: letter.implicitWidth + Math.round(12 * root.u)
                height: letter.implicitHeight + 2
                radius: 4
                color: Style.deckColor(root.group)

                Text {
                    id: letter

                    anchors.centerIn: parent
                    color: Style.background
                    font.family: Style.mono
                    font.weight: Font.Bold
                    font.pixelSize: root.fs(11)
                    text: Style.deckLetter(root.group)
                }
            }
            Text {
                id: titleText

                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, titleRow.width - artistText.implicitWidth - letter.implicitWidth - 40 * root.u)
                color: Style.text
                elide: Text.ElideRight
                font.family: Style.font
                font.pixelSize: root.fs(17)
                font.weight: Font.DemiBold
                text: root.loaded && root.currentTrack ? root.currentTrack.title : qsTr("Tocá para cargar un tema")
                opacity: root.loaded ? 1 : 0.55
            }
            Text {
                id: artistText

                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, titleRow.width * 0.35)
                color: Style.textSecondary
                elide: Text.ElideRight
                font.family: Style.font
                font.pixelSize: root.fs(14)
                text: root.loaded && root.currentTrack ? root.currentTrack.artist : ""
            }
        }
        MouseArea {
            anchors.fill: titleRow
            onClicked: root.browseRequested()
        }

        // Numbers row
        Item {
            id: numbers

            anchors.top: titleRow.bottom
            anchors.topMargin: Math.round(3 * root.u)
            width: parent.width
            height: Math.round(24 * root.u)

            Row {
                id: leftNumbers

                x: root.mirrored ? parent.width - width : 0
                anchors.verticalCenter: parent.verticalCenter
                layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight
                spacing: Math.round(10 * root.u)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.text
                    font.family: Style.mono
                    font.weight: Font.Bold
                    font.pixelSize: root.fs(20)
                    text: root.loaded && bpm.value > 0 ? bpm.value.toFixed(1) : "—"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.textSecondary
                    font.family: Style.mono
                    font.pixelSize: root.fs(12)
                    text: (root.pitchPercent >= 0 ? "+" : "") + root.pitchPercent.toFixed(1) + "%"
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.loaded && Mixxx.KeyUtils.keyIsValid(keyControl.value)
                    width: keyText.implicitWidth + Math.round(10 * root.u)
                    height: keyText.implicitHeight + 2
                    radius: 4
                    color: Style.keyChip

                    Text {
                        id: keyText

                        anchors.centerIn: parent
                        color: Style.background
                        font.family: Style.mono
                        font.weight: Font.Bold
                        font.pixelSize: root.fs(12)
                        text: Mixxx.KeyUtils.keyIsValid(keyControl.value) ? Mixxx.KeyUtils.keyToString(keyControl.value) : ""
                    }
                }
            }
            Row {
                x: root.mirrored ? 0 : parent.width - width
                anchors.verticalCenter: parent.verticalCenter
                layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight
                spacing: Math.round(10 * root.u)

                // DROP EN n: red, glowing and blinking on the beat close to it
                Rectangle {
                    readonly property int bars: trackSections.barsToDrop
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.loaded && bars > 0 && bars <= 16
                    width: dropText.implicitWidth + Math.round(18 * root.u)
                    height: dropText.implicitHeight + 4
                    radius: height / 2
                    color: Style.danger
                    opacity: bars <= 4 && beatActive.value > 0 ? 0.45 : 1

                    Text {
                        id: dropText

                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.family: Style.mono
                        font.weight: Font.Bold
                        font.pixelSize: root.fs(11)
                        text: qsTr("DROP EN %1").arg(parent.bars)
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // The last seconds blink on the beat, like Rekordbox
                    color: endOfTrack.value > 0 ? Style.danger : Style.text
                    opacity: endOfTrack.value > 0 && beatActive.value > 0 ? 0.35 : 1
                    font.family: Style.mono
                    font.weight: Font.Medium
                    font.pixelSize: root.fs(18)
                    text: root.loaded ? "-" + Style.formatTime(root.remaining) : ""
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: dvsEnabled.value > 0
                    width: dvsText.implicitWidth + Math.round(16 * root.u)
                    height: dvsText.implicitHeight + 2
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: dvsText.color

                    Text {
                        id: dvsText

                        anchors.centerIn: parent
                        color: Math.round(dvsStatus.value) === 3 ? Style.danger : (Math.round(dvsStatus.value) === 2 ? Style.cue : Style.ok)
                        font.family: Style.mono
                        font.weight: Font.Bold
                        font.pixelSize: root.fs(11)
                        text: "DVS " + ["ABS", "REL", "INT"][Math.max(0, Math.min(2, Math.round(dvsMode.value)))]
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: dvsMode.value = (Math.round(dvsMode.value) + 1) % 3
                    }
                }
            }
        }

        // The whole track
        Rectangle {
            id: overview

            anchors.top: numbers.bottom
            anchors.topMargin: Math.round(4 * root.u)
            anchors.bottom: parent.bottom
            width: parent.width
            radius: Math.round(6 * root.u)
            color: Style.panelDark
            clip: true

            MixxxControls.WaveformOverview {
                anchors.fill: parent
                visible: root.loaded
                group: root.group
                channels: Mixxx.WaveformOverview.Channels.BothChannels
                renderer: Mixxx.WaveformOverview.Renderer.Filtered
                normalized: true
                stereo: false
                minuteMarkers: false
                colorLow: Style.stemDrums
                colorMid: Style.stemMusic
                colorHigh: Style.stemVocals
            }
            // What already played is dimmed
            Rectangle {
                width: parent.width * playPosition.value
                height: parent.height
                color: Style.panelDark
                opacity: 0.55
                visible: root.loaded
            }
            SectionMarks {
                anchors.fill: parent
                visible: root.loaded
                sections: trackSections.sections
                barsToDrop: trackSections.barsToDrop
                nextDropStart: trackSections.nextDropStart
                beat: beatActive.value > 0
            }
            Rectangle {
                x: parent.width * playPosition.value - 1
                width: 2
                height: parent.height
                color: Style.playhead
                visible: root.loaded
            }
            // Tap the overview to jump there
            MouseArea {
                anchors.fill: parent
                enabled: root.loaded && dvsEnabled.value <= 0
                onClicked: mouse => playPosition.value = Math.max(0, Math.min(1, mouse.x / width))
            }
        }
    }
}
