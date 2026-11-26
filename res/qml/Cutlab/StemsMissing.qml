import "../Library" as LibraryComponent
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls

// Over gray pads when the track of the deck has no stems: "Separar"; while
// it separates only the progress ("Separando: 86%"); once done "Usar stems".
Item {
    id: root

    required property string group
    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)
    readonly property var track: root.player ? root.player.currentTrack : null
    readonly property bool loaded: trackLoaded.value > 0 && !!root.track
    readonly property bool ready: root.loaded && Mixxx.Stems.jobs !== undefined && Mixxx.Stems.hasStems(root.track.trackLocationUrl)
    // The job of this track: "" none, "queued" or "running"
    readonly property string job: {
        if (!root.loaded || root.ready) {
            return "";
        }
        const url = root.track.trackLocationUrl.toString();
        let path = url;
        try {
            path = decodeURIComponent(url.replace(/^file:\/\//, ""));
        } catch (e) {
            path = url;
        }
        const jobs = Mixxx.Stems.jobs || [];
        for (let i = 0; i < jobs.length; ++i) {
            const job = jobs[i];
            if ((job.location === path || job.location === url) && (job.state === "queued" || job.state === "running")) {
                return job.state;
            }
        }
        return "";
    }

    // The stems are made: load them where the track is
    function useStems() {
        if (!root.track) {
            return;
        }
        restore.position = playposition.value;
        restore.play = playing.value > 0;
        restore.tries = 0;
        root.player.loadTrackFromLocationUrl(root.track.trackLocationUrl, false);
        restore.start();
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: "#b0141418"
    }
    Column {
        anchors.centerIn: parent
        width: parent.width - 24
        spacing: 8

        Text {
            width: parent.width
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: !root.loaded ? qsTr("Cargá un tema")
                : root.ready ? qsTr("Stems listos")
                : root.job === "running" ? qsTr("Separando: %1%").arg(Math.round(Mixxx.Stems.progress * 100))
                : root.job === "queued" ? qsTr("En cola para separar…")
                : qsTr("Este tema no tiene stems")
        }
        // While it separates only the progress: no button
        CLButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.loaded && root.job === ""
            width: Math.min(parent.width, 180)
            height: 40
            radius: 20
            text: root.ready ? qsTr("Usar stems") : qsTr("Separar")
            highlighted: true
            onClicked: root.ready ? root.useStems() : stemsPopup.openFor(root.track.trackLocationUrl)
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
            if (stemCount.value > 0 && trackSamples.value > 0) {
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
        id: trackLoaded

        group: root.group
        key: "track_loaded"
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
        id: stemCount

        group: root.group
        key: "stem_count"
    }

    LibraryComponent.StemsPopup {
        id: stemsPopup

        parent: Overlay.overlay
    }
}
