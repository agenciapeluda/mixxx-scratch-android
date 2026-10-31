import "../Library" as LibraryComponent
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls

// The stems of the loaded track: tap a stem to mute it, hold it to hear it
// alone, its fader sets its volume. Tracks without stems offer to separate
// them.
Item {
    id: root

    required property string group
    readonly property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
    readonly property var currentTrack: deckPlayer ? deckPlayer.currentTrack : null
    readonly property bool hasStems: stemRepeater.count > 0
    readonly property string groupPrefix: group.substr(0, group.length - 1)

    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }

    function stemName(label) {
        switch (label) {
        case "Drums":
            return qsTr("Drums");
        case "Bass":
            return qsTr("Bass");
        case "Vocals":
            return qsTr("Vocals");
        case "Other":
            return qsTr("Melody");
        default:
            return label;
        }
    }

    function soloStem(index) {
        let othersMuted = true;
        for (let i = 0; i < stemRepeater.count; ++i) {
            const stem = stemRepeater.itemAt(i);
            if (i !== index && stem && !stem.muted) {
                othersMuted = false;
            }
        }
        for (let i = 0; i < stemRepeater.count; ++i) {
            const stem = stemRepeater.itemAt(i);
            if (stem) {
                stem.setMuted(othersMuted ? false : i !== index);
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 1
        spacing: 1
        visible: root.hasStems

        Repeater {
            id: stemRepeater

            model: trackLoaded.value > 0 && root.currentTrack ? root.currentTrack.stemsModel : 0

            Item {
                id: stem

                required property int index
                required property color color
                required property string label
                readonly property string stemGroup: `${root.groupPrefix}_Stem${index + 1}]`
                readonly property bool muted: mute.value > 0

                function setMuted(value) {
                    mute.value = value ? 1 : 0;
                }

                width: (parent.width - (stemRepeater.count - 1)) / Math.max(1, stemRepeater.count)
                height: parent.height

                Mixxx.ControlProxy {
                    id: mute

                    group: stem.stemGroup
                    key: "mute"
                }

                Pad {
                    id: stemPad

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.height * 0.55
                    text: root.stemName(stem.label)
                    padColor: stem.color
                    active: !stem.muted
                    dimmed: stem.muted
                    onClicked: stem.setMuted(!stem.muted)
                    onPressAndHold: root.soloStem(stem.index)
                }
                CLFader {
                    anchors.top: stemPad.bottom
                    anchors.topMargin: 6
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(54, parent.width - 8)
                    group: stem.stemGroup
                    key: "volume"
                    ticks: 3
                    handleColor: stem.muted ? "#77777c" : "#d7d7db"
                }
            }
        }
    }

    // No stems yet
    Column {
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 14
        visible: !root.hasStems

        Text {
            width: parent.width
            color: Style.text
            font.family: Style.font
            font.pixelSize: 17
            horizontalAlignment: Text.AlignHCenter
            text: trackLoaded.value > 0 ? qsTr("This track has no stems yet") : qsTr("Load a track to use its stems")
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            text: Mixxx.Stems.pendingCount > 0
                ? qsTr("Separating: %1% (%2 in the queue). Load the track again when it is done.").arg(Math.round(Mixxx.Stems.progress * 100)).arg(Mixxx.Stems.pendingCount)
                : qsTr("Separate it into vocals, drums, bass and melody to mix each part on its own.")
            wrapMode: Text.WordWrap
        }
        CLButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200
            height: 46
            text: qsTr("Separate stems")
            highlighted: true
            visible: trackLoaded.value > 0 && root.currentTrack
            onClicked: stemsPopup.openFor(root.currentTrack.trackLocationUrl)
        }
    }

    LibraryComponent.StemsPopup {
        id: stemsPopup

        parent: Overlay.overlay
    }
}
