// [AI-generated text, Claude (Anthropic) — start]
// Cutlab 1.32.0: the "LETRA" pad mode of a deck. The line that plays,
// bright and big, the one before dim above and the next ones below, like
// Spotify. It follows the position of the track (pitch, scratch, loops and
// jumps included), not a clock. The lyrics come from Mixxx.Cutlab.
// fetchLyrics: an .lrc next to the file, the ones saved before or LRCLIB.
// [AI-generated text, Claude (Anthropic) — end]
import Mixxx 1.0 as Mixxx
import QtQuick

Item {
    id: root

    required property string group
    property real spacing: 4
    readonly property color deckColor: Style.deckColor(root.group)

    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)
    readonly property string location: root.player && root.player.currentTrack ? root.player.currentTrack.trackLocationUrl.toString() : ""
    property var lines: []
    property bool synced: false
    property string source: ""
    // "loading", "none", "offline", "error", "" when there are lines
    property string status: "loading"

    // The playing line: the last whose time has passed
    readonly property real seconds: position.value * duration.value
    readonly property int current: {
        if (!root.synced) {
            return -1;
        }
        let lo = 0;
        let hi = root.lines.length - 1;
        let found = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (root.lines[mid].time <= root.seconds + 0.15) {
                found = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return found;
    }

    function load() {
        root.lines = [];
        root.synced = false;
        root.source = "";
        if (root.location === "") {
            root.status = "none";
            return;
        }
        root.status = "loading";
        const track = root.player.currentTrack;
        Mixxx.Cutlab.fetchLyricsFor(root.group, root.location, track.artist, track.title, track.duration);
    }
    onLocationChanged: root.load()
    Component.onCompleted: root.load()

    Connections {
        target: Mixxx.Cutlab

        function onLyricsReady(group, location, lines, synced, source, status) {
            // An answer for a track this deck no longer shows
            if (group !== root.group || location !== root.location) {
                return;
            }
            root.lines = lines;
            root.synced = synced;
            root.source = source;
            root.status = lines.length > 0 ? "" : status;
        }
    }

    Mixxx.ControlProxy {
        id: position

        group: root.group
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: duration

        group: root.group
        key: "duration"
    }

    Rectangle {
        anchors.fill: parent
        color: Style.panelDark
        radius: 10
        border.width: 1
        border.color: Style.divider
        clip: true

        // No lyrics: why
        Text {
            anchors.centerIn: parent
            width: parent.width - 24
            visible: root.lines.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: Math.max(12, Math.min(18, parent.height * 0.12))
            text: root.status === "loading" ? qsTr("Buscando la letra…")
                : root.status === "offline" ? qsTr("Sin letra guardada (Modo show: no busca en internet)")
                : root.status === "error" ? qsTr("No se pudo buscar la letra (¿sin internet?)")
                : qsTr("Sin letra para este tema")
        }

        // Synced: the line that plays in the middle
        Column {
            id: syncedView

            anchors.verticalCenter: parent.verticalCenter
            x: 12
            width: parent.width - 24
            spacing: Math.max(2, parent.height * 0.03)
            visible: root.synced && root.lines.length > 0

            readonly property real big: Math.max(14, Math.min(30, root.height * 0.2))
            readonly property real small: Math.max(11, syncedView.big * 0.6)

            Repeater {
                // One before, the one playing, two after
                model: [-1, 0, 1, 2]

                Text {
                    required property int modelData
                    readonly property int line: root.current + modelData

                    width: syncedView.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: modelData === 0 ? 2 : 1
                    wrapMode: Text.WordWrap
                    color: modelData === 0 ? root.deckColor : (modelData < 0 ? Style.textDim : Style.textSecondary)
                    opacity: modelData === 0 ? 1 : (modelData === 2 ? 0.5 : 0.75)
                    font.family: Style.font
                    font.weight: modelData === 0 ? Font.Bold : Font.Medium
                    font.pixelSize: modelData === 0 ? syncedView.big : syncedView.small
                    text: line >= 0 && line < root.lines.length ? (root.lines[line].text !== "" ? root.lines[line].text : "♪")
                        : (modelData === 0 && root.current < 0 ? "♪" : " ")
                }
            }
        }

        // Without times: the text to scroll
        Flickable {
            anchors.fill: parent
            anchors.margins: 12
            visible: !root.synced && root.lines.length > 0
            contentHeight: plainText.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: plainText

                width: parent.width
                wrapMode: Text.WordWrap
                color: Style.textSecondary
                font.family: Style.font
                font.pixelSize: Math.max(12, Math.min(16, root.height * 0.1))
                lineHeight: 1.2
                text: root.lines.map(line => line.text).join("\n")
            }
        }

        // Where they come from
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            visible: root.source !== ""
            color: Style.textDim
            font.family: Style.font
            font.pixelSize: 9
            text: root.source === "lrclib" ? "LRCLIB" : (root.source === "file" ? ".lrc" : qsTr("guardada"))
        }
    }
}
