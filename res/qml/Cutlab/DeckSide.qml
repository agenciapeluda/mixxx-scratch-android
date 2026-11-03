import Mixxx 1.0 as Mixxx
import QtQuick

// The other deck while an FX pad takes most of the screen, as in the design:
// it keeps running, reduced: cover and title, BPM, pitch, key and time, its
// waveform, the DVS mode and what its FX does.
Rectangle {
    id: root

    required property string group
    property real u: 1
    readonly property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
    readonly property var currentTrack: deckPlayer ? deckPlayer.currentTrack : null
    readonly property bool loaded: trackLoaded.value > 0
    readonly property real remaining: Math.max(0, duration.value * (1 - playPosition.value)) / Math.max(0.01, rateRatio.value)
    readonly property real pitchPercent: (rateRatio.value - 1) * 100
    readonly property int unit: group === "[Channel2]" ? 2 : 1

    function fs(px) {
        return Math.max(9, Math.round(px * root.u));
    }

    color: Style.background

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
        id: dvs

        group: root.group
        key: "vinylcontrol_enabled"
    }
    Mixxx.ControlProxy {
        id: dvsMode

        group: root.group
        key: "vinylcontrol_mode"
    }
    Mixxx.ControlProxy {
        id: fxOn

        group: `[EffectRack1_EffectUnit${root.unit}_Effect1]`
        key: "enabled"
    }

    Column {
        id: top

        x: Math.round(16 * root.u)
        y: Math.round(16 * root.u)
        width: parent.width - 2 * x
        spacing: Math.round(12 * root.u)

        Row {
            width: parent.width
            spacing: Math.round(10 * root.u)

            Rectangle {
                width: Math.round(48 * root.u)
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
            }
            Column {
                width: parent.width - Math.round(48 * root.u) - letter.width - 2 * parent.spacing
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    color: Style.text
                    font.family: Style.font
                    font.weight: Font.DemiBold
                    font.pixelSize: root.fs(16)
                    text: root.loaded && root.currentTrack ? root.currentTrack.title : qsTr("Sin tema")
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    color: Style.textSecondary
                    font.family: Style.font
                    font.pixelSize: root.fs(13)
                    text: root.loaded && root.currentTrack ? root.currentTrack.artist : ""
                }
            }
            Rectangle {
                id: letter

                anchors.verticalCenter: parent.verticalCenter
                width: letterText.implicitWidth + Math.round(14 * root.u)
                height: letterText.implicitHeight + 4
                radius: 4
                color: Style.deckColor(root.group)

                Text {
                    id: letterText

                    anchors.centerIn: parent
                    color: Style.background
                    font.family: Style.mono
                    font.weight: Font.Bold
                    font.pixelSize: root.fs(11)
                    text: Style.deckLetter(root.group)
                }
            }
        }
        Item {
            width: parent.width
            height: bpmText.implicitHeight

            Row {
                spacing: Math.round(14 * root.u)

                Text {
                    id: bpmText

                    color: Style.text
                    font.family: Style.mono
                    font.weight: Font.Bold
                    font.pixelSize: root.fs(30)
                    text: root.loaded && bpm.value > 0 ? bpm.value.toFixed(1) : "—"
                }
                Text {
                    anchors.baseline: bpmText.baseline
                    color: Style.textSecondary
                    font.family: Style.mono
                    font.pixelSize: root.fs(13)
                    text: (root.pitchPercent >= 0 ? "+" : "") + root.pitchPercent.toFixed(1) + "%"
                }
                Rectangle {
                    anchors.verticalCenter: bpmText.verticalCenter
                    visible: root.loaded && Mixxx.KeyUtils.keyIsValid(keyControl.value)
                    width: keyText.implicitWidth + 10
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
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                color: Style.text
                font.family: Style.mono
                font.pixelSize: root.fs(22)
                text: root.loaded ? "-" + Style.formatTime(root.remaining) : ""
            }
        }
    }

    Rectangle {
        id: wave

        x: top.x
        anchors.top: top.bottom
        anchors.topMargin: Math.round(12 * root.u)
        anchors.bottom: footer.top
        anchors.bottomMargin: Math.round(12 * root.u)
        width: top.width
        radius: Math.round(10 * root.u)
        color: Style.panel
        clip: true

        CutlabWave {
            anchors.fill: parent
            group: root.group
            isTouchMode: true
            showHud: false
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            width: 2
            height: parent.height - 12
            color: Style.playhead
        }
    }

    Column {
        id: footer

        x: top.x
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(16 * root.u)
        width: top.width
        spacing: Math.round(12 * root.u)

        Row {
            spacing: Math.round(8 * root.u)

            Repeater {
                model: [
                    {text: "DVS " + ["ABS", "REL", "INT"][Math.max(0, Math.min(2, Math.round(dvsMode.value)))], color: Style.ok, show: dvs.value > 0},
                    {text: qsTr("FX %1 %2").arg(root.unit).arg(fxOn.value > 0 ? qsTr("sonando") : qsTr("apagado")), color: fxOn.value > 0 ? Style.deckColor(root.group) : Style.textSecondary, show: true}
                ]

                Rectangle {
                    required property var modelData

                    visible: modelData.show
                    width: chipText.implicitWidth + Math.round(20 * root.u)
                    height: chipText.implicitHeight + Math.round(8 * root.u)
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: modelData.color === Style.textSecondary ? Qt.rgba(1, 1, 1, 0.12) : modelData.color

                    Text {
                        id: chipText

                        anchors.centerIn: parent
                        color: parent.modelData.color
                        font.family: Style.font
                        font.weight: Font.Bold
                        font.pixelSize: root.fs(11)
                        text: parent.modelData.text
                    }
                }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            lineHeight: 1.2
            color: Style.textSecondary
            font.family: Style.font
            font.weight: Font.Medium
            font.pixelSize: root.fs(12)
            text: qsTr("Las perillas del FX en la controladora siguen mandando: el pad solo suma la mano. Con FX ON del deck %1, este lado se convierte en su pad.").arg(Style.deckLetter(root.group))
        }
    }
}
