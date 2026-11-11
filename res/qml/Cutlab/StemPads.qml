import Mixxx 1.0 as Mixxx
import QtQuick

// The Stems pads of a deck: one row of 4 big pads over the whole height,
// Voz · Batería · Melodía · Bajo+Batería.
// - Tap turns it on or off; hold turns it off only while held.
// - Bajo+Batería turns the bass and the drums on or off together.
// Gray, with "Separar", when the track has no stems.
Item {
    id: root

    required property string group
    property real spacing: 4

    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)
    readonly property var track: root.player ? root.player.currentTrack : null
    readonly property bool hasStems: trackLoaded.value > 0 && stemRepeater.count > 0
    readonly property string prefix: root.group.substr(0, root.group.length - 1)
    // A hold longer than this turns it off only while held
    readonly property int holdMs: 300

    readonly property var pads: [
        {name: qsTr("Voz"), labels: ["Vocals"], color: Style.stemVocals},
        {name: qsTr("Batería"), labels: ["Drums"], color: Style.stemDrums},
        {name: qsTr("Melodía"), labels: ["Other"], color: Style.stemMusic},
        {name: qsTr("Bajo + Batería"), labels: ["Bass", "Drums"], color: "#2f63d6"}
    ]
    // Bumped when a mute changes, so the pads read them again
    property int revision: 0

    function stemOf(label) {
        for (let i = 0; i < stemRepeater.count; ++i) {
            const stem = stemRepeater.itemAt(i);
            if (stem && stem.label === label) {
                return stem;
            }
        }
        return null;
    }
    // The stems of a pad the track has
    function stemsOf(labels) {
        const list = [];
        for (let i = 0; i < labels.length; ++i) {
            const stem = root.stemOf(labels[i]);
            if (stem) {
                list.push(stem);
            }
        }
        return list;
    }
    // On when all its stems play
    function padOn(labels) {
        root.revision;
        const stems = root.stemsOf(labels);
        return stems.length > 0 && stems.every(stem => !stem.muted);
    }

    Repeater {
        id: stemRepeater

        model: trackLoaded.value > 0 && root.track ? root.track.stemsModel : 0

        Item {
            id: stem

            required property int index
            required property string label
            readonly property bool muted: mute.value > 0

            function setMuted(value) {
                mute.value = value ? 1 : 0;
            }
            onMutedChanged: ++root.revision

            Mixxx.ControlProxy {
                id: mute

                group: `${root.prefix}_Stem${stem.index + 1}]`
                key: "mute"
            }
        }
    }

    Row {
        id: row

        anchors.fill: parent
        spacing: root.spacing
        enabled: root.hasStems

        Repeater {
            model: root.pads

            Pad {
                id: pad

                required property var modelData
                property var held: null
                readonly property bool on: root.hasStems && root.padOn(modelData.labels)
                readonly property bool present: root.hasStems && root.stemsOf(modelData.labels).length > 0

                width: (row.width - 3 * row.spacing) / 4
                height: row.height
                text: modelData.name
                padColor: modelData.color
                active: pad.on
                dimmed: !pad.on
                enabled: pad.present

                // Answers on touch down; a long hold goes back on release
                onPressedDown: {
                    const stems = root.stemsOf(modelData.labels);
                    if (stems.length === 0) {
                        return;
                    }
                    const was = stems.map(stem => stem.muted);
                    const mute = pad.on;
                    stems.forEach(stem => stem.setMuted(mute));
                    pad.held = {stems: stems, was: was, at: Date.now()};
                }
                onReleased: {
                    const held = pad.held;
                    pad.held = null;
                    if (held && Date.now() - held.at >= root.holdMs) {
                        held.stems.forEach((stem, i) => stem.setMuted(held.was[i]));
                    }
                }
            }
        }
    }

    StemsMissing {
        anchors.fill: parent
        visible: !root.hasStems
        group: root.group
    }

    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }
}
