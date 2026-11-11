import Mixxx 1.0 as Mixxx
import QtQuick

// The Stems pads of a deck.
// - Top row, Voz · Melodía · Bajo · Batería: tap turns the stem on or off,
//   hold turns it off only while held.
// - Bottom row, combinations: Acapella · Instrumental · Solo batería ·
//   Bajo+batería. Tap plays it (tap again: all the stems back), hold plays
//   it only while held.
// Gray, with "Separar", when the track has no stems.
Item {
    id: root

    required property string group
    property real spacing: 4

    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)
    readonly property var track: root.player ? root.player.currentTrack : null
    readonly property bool hasStems: trackLoaded.value > 0 && stemRepeater.count > 0
    readonly property string prefix: root.group.substr(0, root.group.length - 1)
    // A hold longer than this plays the pad only while held
    readonly property int holdMs: 300

    readonly property var singles: [
        {name: qsTr("Voz"), label: "Vocals", color: Style.stemVocals},
        {name: qsTr("Melodía"), label: "Other", color: Style.stemMusic},
        {name: qsTr("Bajo"), label: "Bass", color: "#2f63d6"},
        {name: qsTr("Batería"), label: "Drums", color: Style.stemDrums}
    ]
    readonly property var combos: [
        {name: qsTr("Acapella"), labels: ["Vocals"], color: Style.stemVocals},
        {name: qsTr("Instrumental"), labels: ["Other", "Bass", "Drums"], color: Style.stemMusic},
        {name: qsTr("Solo batería"), labels: ["Drums"], color: Style.stemDrums},
        {name: qsTr("Bajo+batería"), labels: ["Bass", "Drums"], color: "#2f63d6"}
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
    function mutes() {
        const list = [];
        for (let i = 0; i < stemRepeater.count; ++i) {
            const stem = stemRepeater.itemAt(i);
            list.push(stem ? stem.muted : false);
        }
        return list;
    }
    function setMutes(list) {
        for (let i = 0; i < stemRepeater.count; ++i) {
            const stem = stemRepeater.itemAt(i);
            if (stem) {
                stem.setMuted(i < list.length ? list[i] : false);
            }
        }
    }
    function isOn(label) {
        root.revision;
        const stem = root.stemOf(label);
        return !!stem && !stem.muted;
    }
    // Exactly these stems on (of the ones the track has)
    function comboOn(labels) {
        root.revision;
        let any = false;
        for (let i = 0; i < stemRepeater.count; ++i) {
            const stem = stemRepeater.itemAt(i);
            if (!stem) {
                continue;
            }
            const wanted = labels.indexOf(stem.label) >= 0;
            any = any || wanted;
            if (wanted === stem.muted) {
                return false;
            }
        }
        return any;
    }
    function playCombo(labels) {
        for (let i = 0; i < stemRepeater.count; ++i) {
            const stem = stemRepeater.itemAt(i);
            if (stem) {
                stem.setMuted(labels.indexOf(stem.label) < 0);
            }
        }
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

    Grid {
        id: pads

        anchors.fill: parent
        columns: 4
        rows: 2
        spacing: root.spacing
        enabled: root.hasStems

        // Top row: one stem each
        Repeater {
            model: root.singles

            Pad {
                id: single

                required property var modelData
                property var held: null
                readonly property bool on: root.hasStems && root.isOn(modelData.label)

                width: (pads.width - (pads.columns - 1) * pads.spacing) / pads.columns
                height: (pads.height - (pads.rows - 1) * pads.spacing) / pads.rows
                text: modelData.name
                padColor: modelData.color
                active: single.on
                dimmed: !single.on

                // Answers on touch down; a long hold goes back on release
                onPressedDown: {
                    const stem = root.stemOf(modelData.label);
                    if (!stem) {
                        return;
                    }
                    single.held = {stem: stem, was: stem.muted, at: Date.now()};
                    stem.setMuted(!stem.muted);
                }
                onReleased: {
                    const held = single.held;
                    single.held = null;
                    if (held && Date.now() - held.at >= root.holdMs) {
                        held.stem.setMuted(held.was);
                    }
                }
            }
        }
        // Bottom row: combinations
        Repeater {
            model: root.combos

            Pad {
                id: combo

                required property var modelData
                property var held: null
                readonly property bool on: root.hasStems && root.comboOn(modelData.labels)

                width: (pads.width - (pads.columns - 1) * pads.spacing) / pads.columns
                height: (pads.height - (pads.rows - 1) * pads.spacing) / pads.rows
                text: modelData.name
                padColor: modelData.color
                active: combo.on

                onPressedDown: {
                    combo.held = {was: root.mutes(), at: Date.now()};
                    if (combo.on) {
                        // All the stems back
                        root.setMutes([]);
                    } else {
                        root.playCombo(modelData.labels);
                    }
                }
                onReleased: {
                    const held = combo.held;
                    combo.held = null;
                    if (held && Date.now() - held.at >= root.holdMs) {
                        root.setMutes(held.was);
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
