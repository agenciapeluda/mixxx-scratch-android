import "../Library" as LibraryComponent
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls

// The stems of the loaded track in three parts, the ones a DJ plays with:
// voice (the acapella), beat (drums) and music (bass and instruments). Tap
// a part to mute it, hold it to hear it alone, its fader sets its volume.
// With "separar el bajo" on in the settings, bass and melody come apart.
// Tracks without stems offer to separate them.
Item {
    id: root

    required property string group
    // letsktch! is on for this deck
    property bool letsktchOn: false
    readonly property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
    readonly property var currentTrack: deckPlayer ? deckPlayer.currentTrack : null
    readonly property bool hasStems: stemRepeater.count > 0
    readonly property bool splitBass: Mixxx.Application.configValue("[Cutlab]", "stems_split_bass", "0") === "1"
    readonly property var parts: root.splitBass ? [
        {name: qsTr("Voz"), labels: ["Vocals"], color: Style.stemVocals},
        {name: qsTr("Beat"), labels: ["Drums"], color: Style.stemDrums},
        {name: qsTr("Bajo"), labels: ["Bass"], color: "#2f63d6"},
        {name: qsTr("Melodía"), labels: ["Other"], color: Style.stemMusic}
    ] : [
        {name: qsTr("Voz"), labels: ["Vocals"], color: Style.stemVocals},
        {name: qsTr("Beat"), labels: ["Drums"], color: Style.stemDrums},
        {name: qsTr("Música"), labels: ["Bass", "Other"], color: Style.stemMusic}
    ]

    // The stems of the track behind a part
    function stemsOf(labels) {
        const result = [];
        for (let i = 0; i < stemRepeater.count; ++i) {
            const stem = stemRepeater.itemAt(i);
            if (stem && labels.indexOf(stem.label) >= 0) {
                result.push(stem);
            }
        }
        // Tracks with other stem names: spread them over the parts
        if (result.length === 0 && stemRepeater.count > 0) {
            const position = root.parts.findIndex(part => part.labels === labels);
            const stem = stemRepeater.itemAt(Math.min(stemRepeater.count - 1, Math.max(0, position)));
            if (stem) {
                result.push(stem);
            }
        }
        return result;
    }
    readonly property string groupPrefix: group.substr(0, group.length - 1)

    // The stems of the loaded track are ready: put them on the deck where it
    // was. Stopped, at once; playing, with the button (a reload stops it)
    readonly property bool stemsReady: !root.hasStems && trackLoaded.value > 0 && root.currentTrack
        && Mixxx.Stems.jobs !== undefined && Mixxx.Stems.hasStems(root.currentTrack.trackLocationUrl)
    function useStems() {
        if (!root.currentTrack) {
            return;
        }
        const position = playposition.value;
        const wasPlaying = playing.value > 0;
        restore.position = position;
        restore.play = wasPlaying;
        restore.tries = 0;
        root.deckPlayer.loadTrackFromLocationUrl(root.currentTrack.trackLocationUrl, false);
        restore.start();
    }
    onStemsReadyChanged: {
        if (root.stemsReady && playing.value <= 0) {
            Qt.callLater(root.useStems);
        }
    }
    Timer {
        id: restore

        property real position: 0
        property bool play: false
        property int tries: 0

        interval: 150
        repeat: true
        onTriggered: {
            if (root.hasStems && trackSamples.value > 0) {
                playposition.value = position;
                if (play) {
                    playing.value = 1;
                }
                stop();
            } else if (++tries > 80) {
                stop();
            }
        }
    }
    Mixxx.ControlProxy {
        id: playposition

        group: root.group
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: playing

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: trackSamples

        group: root.group
        key: "track_samples"
    }

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

    function soloPart(partIndex) {
        const target = root.stemsOf(root.parts[partIndex].labels);
        let othersMuted = true;
        for (let i = 0; i < stemRepeater.count; ++i) {
            const stem = stemRepeater.itemAt(i);
            if (stem && target.indexOf(stem) < 0 && !stem.muted) {
                othersMuted = false;
            }
        }
        for (let i = 0; i < stemRepeater.count; ++i) {
            const stem = stemRepeater.itemAt(i);
            if (stem) {
                stem.setMuted(othersMuted ? false : target.indexOf(stem) < 0);
            }
        }
    }

    signal letsktchRequested

    // The stems themselves, hidden: the parts below drive them
    Repeater {
        id: stemRepeater

        model: trackLoaded.value > 0 && root.currentTrack ? root.currentTrack.stemsModel : 0

        Item {
            id: stem

            required property int index
            required property string label
            readonly property string stemGroup: `${root.groupPrefix}_Stem${index + 1}]`
            readonly property bool muted: mute.value > 0
            property alias volume: volumeControl.value

            function setMuted(value) {
                mute.value = value ? 1 : 0;
            }

            visible: false

            Mixxx.ControlProxy {
                id: mute

                group: stem.stemGroup
                key: "mute"
            }
            Mixxx.ControlProxy {
                id: volumeControl

                group: stem.stemGroup
                key: "volume"
            }
        }
    }

    // letsktch!: scratch the voice over its own beat, on this deck
    CLButton {
        id: letsktchButton

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 4
        height: root.hasStems ? 44 : 0
        visible: root.hasStems
        radius: 22
        text: root.letsktchOn ? qsTr("letsktch!  ·  tocá para volver al tema") : qsTr("letsktch!  ·  voz al plato, beat en loop")
        fontSize: 14
        fontWeight: Font.Bold
        highlighted: root.letsktchOn
        litColor: Style.stemVocals
        textColor: root.letsktchOn ? Style.background : Style.stemVocals
        onClicked: root.letsktchRequested()
    }

    Row {
        anchors.top: letsktchButton.bottom
        anchors.topMargin: root.hasStems ? 6 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        spacing: 1
        visible: root.hasStems

        Repeater {
            id: partRepeater

            model: root.parts

            Item {
                id: part

                required property int index
                required property var modelData
                readonly property var stems: stemRepeater.count >= 0 ? root.stemsOf(modelData.labels) : []
                readonly property bool muted: stems.length > 0 && stems.every(stem => stem.muted)
                readonly property string faderGroup: stems.length > 0 ? stems[0].stemGroup : ""

                width: (parent.width - (root.parts.length - 1)) / root.parts.length
                height: parent.height

                Pad {
                    id: partPad

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.height * 0.55
                    text: part.modelData.name
                    padColor: part.modelData.color
                    active: !part.muted
                    dimmed: part.muted
                    onClicked: {
                        const mute = !part.muted;
                        for (const stem of part.stems) {
                            stem.setMuted(mute);
                        }
                    }
                    onPressAndHold: root.soloPart(part.index)
                }
                CLFader {
                    id: partFader

                    anchors.top: partPad.bottom
                    anchors.topMargin: 6
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(54, parent.width - 8)
                    group: part.faderGroup
                    key: "volume"
                    ticks: 3
                    handleColor: part.muted ? "#77777c" : part.modelData.color
                    visible: part.faderGroup !== ""
                }
                // The other stems of the part follow its fader
                Mixxx.ControlProxy {
                    group: part.faderGroup
                    key: "volume"
                    onValueChanged: {
                        for (let i = 1; i < part.stems.length; ++i) {
                            part.stems[i].volume = value;
                        }
                    }
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
                ? qsTr("Separando: %1% (%2 en la cola). Cuando termine pasa solo a los stems.").arg(Math.round(Mixxx.Stems.progress * 100)).arg(Mixxx.Stems.pendingCount)
                : qsTr("Separalo en voz, beat y música para mezclar cada parte por su lado.")
            wrapMode: Text.WordWrap
        }
        CLButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 220
            height: 46
            text: qsTr("Pasar a los stems")
            highlighted: true
            visible: root.stemsReady
            onClicked: root.useStems()
        }
        CLButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200
            height: 46
            text: qsTr("Separate stems")
            highlighted: true
            visible: trackLoaded.value > 0 && root.currentTrack && !root.stemsReady
            onClicked: stemsPopup.openFor(root.currentTrack.trackLocationUrl)
        }
    }

    LibraryComponent.StemsPopup {
        id: stemsPopup

        parent: Overlay.overlay
    }
}
