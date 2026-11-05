import Mixxx 1.0 as Mixxx
import QtQuick

// The Scratch tool without its screen: lives as long as the main screen, so
// closing the tool keeps the phrases and the way back to the track.
// - 8 slots of short phrases of your tracks (an "ahh", a "fresh", a horn)
// - capture: always the chosen 1/2/4/8 beats, from the start of the loop if
//   one runs, else from the playhead
// - fire: loads the phrase on the deck of the open tool, looped, only the
//   voice when "Voz" is on and the track has stems
// - back to the track: the same track, place, loop and stems as before the
//   first phrase
Item {
    id: root

    // The deck whose Scratch tool is open ("" none): SHIFT + pad fires there
    property string toolGroup: ""
    // letsktch! (stopped before a phrase goes to its deck)
    property var letsktch: null

    property real captureBeats: {
        const stored = Number(Mixxx.Application.configValue("[Cutlab]", "scratch_beats", "2"));
        return [1, 2, 4, 8].indexOf(stored) >= 0 ? stored : 2;
    }
    property bool voiceOnly: Mixxx.Application.configValue("[Cutlab]", "scratch_voice", "1") !== "0"
    property var slots: []
    // A phrase waiting for its track to load: {group, slot}
    property var pending: null
    // The slot last sent to each deck, -1 none
    property int fired1: -1
    property int fired2: -1
    // What each deck played before its first phrase: {url, position,
    // loop, loopStart, loopEnd, mutes}; null when there is nothing to go back
    property var saved1: null
    property var saved2: null
    // Going back: {group, state} until the track is loaded again
    property var restoring: null
    readonly property bool hasPhrase: root.slots.some(slot => !!slot)

    signal failed(string text)

    function deckOf(group) {
        return group === "[Channel2]" ? deck2 : deck1;
    }
    function stemsOf(group) {
        return group === "[Channel2]" ? stems2 : stems1;
    }
    function savedOf(group) {
        return group === "[Channel2]" ? root.saved2 : root.saved1;
    }
    function setSaved(group, state) {
        if (group === "[Channel2]") {
            root.saved2 = state;
        } else {
            root.saved1 = state;
        }
    }
    function firedOf(group) {
        return group === "[Channel2]" ? root.fired2 : root.fired1;
    }
    function setFired(group, index) {
        if (group === "[Channel2]") {
            root.fired2 = index;
        } else {
            root.fired1 = index;
        }
    }

    function setCaptureBeats(beats) {
        root.captureBeats = beats;
        Mixxx.Application.setConfigValue("[Cutlab]", "scratch_beats", String(beats));
    }
    // "Voz" is a switch: on the deck with a phrase it takes effect at once,
    // and off brings all the stems back
    function setVoiceOnly(on, group) {
        root.voiceOnly = on;
        Mixxx.Application.setConfigValue("[Cutlab]", "scratch_voice", on ? "1" : "0");
        if (group !== "" && root.firedOf(group) >= 0) {
            root.stemsOf(group).muteAllBut(on ? "Vocals" : "");
        }
    }

    function save() {
        Mixxx.Application.setConfigValue("[Cutlab]", "scratch_bank", encodeURIComponent(JSON.stringify(root.slots)));
    }
    Component.onCompleted: {
        let list = [];
        try {
            const stored = decodeURIComponent(Mixxx.Application.configValue("[Cutlab]", "scratch_bank", ""));
            list = stored ? JSON.parse(stored) : [];
        } catch (e) {
            list = [];
        }
        list = Array.isArray(list) ? list.slice(0, 8) : [];
        while (list.length < 8) {
            list.push(null);
        }
        root.slots = list;
    }

    // The chosen beats of what plays on a deck
    function capture(group, slotIndex) {
        const deck = root.deckOf(group);
        const player = Mixxx.PlayerManager.getPlayer(group);
        const track = player ? player.currentTrack : null;
        if (!track || deck.samples.value <= 0 || deck.duration.value <= 0) {
            root.failed(qsTr("Scratch: cargá un tema en el deck %1 para capturar.").arg(Style.deckLetter(group)));
            return;
        }
        const total = deck.samples.value;
        // The beats of the file, not of the pitch fader: the length is in
        // the track's own time
        const bpm = deck.fileBpm.value > 0 ? deck.fileBpm.value : (deck.bpm.value > 0 ? deck.bpm.value : 120);
        const length = root.captureBeats * 60 / bpm / deck.duration.value;
        let start = deck.position.value;
        if (deck.loopEnabled.value > 0 && deck.loopStart.value >= 0 && deck.loopEnd.value > deck.loopStart.value) {
            start = deck.loopStart.value / total;
        }
        start = Math.max(0, Math.min(start, 1 - length));
        let index = slotIndex;
        if (index < 0) {
            index = root.slots.findIndex(slot => !slot);
            if (index < 0) {
                index = 0;
            }
        }
        const slots = root.slots.slice();
        slots[index] = {
            url: track.trackLocationUrl.toString(),
            title: track.title || decodeURIComponent(track.trackLocationUrl.toString().split("/").pop()),
            artist: track.artist || "",
            start: start,
            end: start + length,
            beats: root.captureBeats
        };
        root.slots = slots;
        root.save();
    }
    function clear(index) {
        const slots = root.slots.slice();
        slots[index] = null;
        root.slots = slots;
        root.save();
        for (const group of ["[Channel1]", "[Channel2]"]) {
            if (root.firedOf(group) === index) {
                root.setFired(group, -1);
            }
        }
    }

    // Load the phrase of a slot on a deck
    function fire(index, group) {
        const slot = root.slots[index];
        const player = Mixxx.PlayerManager.getPlayer(group);
        if (!slot || !player) {
            return;
        }
        if (root.letsktch && root.letsktch.group === group) {
            root.letsktch.stop();
        }
        // The way back: only before the first phrase on this deck
        if (!root.savedOf(group) && player.currentTrack && root.firedOf(group) < 0) {
            const deck = root.deckOf(group);
            root.setSaved(group, {
                url: player.currentTrack.trackLocationUrl.toString(),
                title: player.currentTrack.title || "",
                position: deck.position.value,
                loop: deck.loopEnabled.value > 0,
                loopStart: deck.loopStart.value,
                loopEnd: deck.loopEnd.value,
                mutes: root.stemsOf(group).mutes()
            });
        }
        root.restoring = null;
        root.setFired(group, index);
        root.pending = {group: group, slot: slot};
        const current = player.currentTrack;
        if (current && current.trackLocationUrl.toString() === slot.url) {
            Qt.callLater(root.placePending);
        } else {
            player.loadTrackFromLocationUrl(slot.url, false);
        }
        placeTimer.tries = 0;
        placeTimer.start();
    }
    // Loop on [start, end] of the track on a deck
    function setLoop(deck, start, end) {
        if (deck.loopEnabled.value > 0) {
            deck.reloopToggle.value = 1;
            deck.reloopToggle.value = 0;
        }
        deck.loopStart.value = start;
        deck.loopEnd.value = end;
        deck.reloopToggle.value = 1;
        deck.reloopToggle.value = 0;
    }
    function placePending() {
        const pending = root.pending;
        if (!pending) {
            return true;
        }
        const deck = root.deckOf(pending.group);
        const player = Mixxx.PlayerManager.getPlayer(pending.group);
        const track = player ? player.currentTrack : null;
        if (!track || track.trackLocationUrl.toString() !== pending.slot.url || deck.samples.value <= 0) {
            return false;
        }
        const stems = root.stemsOf(pending.group);
        // Wait a little for the stems, the voice needs them
        if (root.voiceOnly && stems.count === 0 && placeTimer.tries < 20) {
            return false;
        }
        const total = deck.samples.value;
        // Stereo samples, on even numbers
        const startSample = Math.round(pending.slot.start * total / 2) * 2;
        const endSample = Math.round(pending.slot.end * total / 2) * 2;
        root.setLoop(deck, startSample, endSample);
        deck.position.value = pending.slot.start;
        stems.muteAllBut(root.voiceOnly ? "Vocals" : "");
        root.pending = null;
        return true;
    }

    // Back to the track as it was before the first phrase
    function returnToTrack(group) {
        const state = root.savedOf(group);
        const player = Mixxx.PlayerManager.getPlayer(group);
        if (!state || !player) {
            return;
        }
        root.pending = null;
        root.restoring = {group: group, state: state};
        const current = player.currentTrack;
        if (!current || current.trackLocationUrl.toString() !== state.url) {
            player.loadTrackFromLocationUrl(state.url, false);
        }
        placeTimer.tries = 0;
        placeTimer.start();
    }
    function placeRestoring() {
        const restoring = root.restoring;
        if (!restoring) {
            return true;
        }
        const group = restoring.group;
        const state = restoring.state;
        const deck = root.deckOf(group);
        const player = Mixxx.PlayerManager.getPlayer(group);
        const track = player ? player.currentTrack : null;
        if (!track || track.trackLocationUrl.toString() !== state.url || deck.samples.value <= 0) {
            return false;
        }
        const stems = root.stemsOf(group);
        if (state.mutes.length > 0 && stems.count === 0 && placeTimer.tries < 20) {
            return false;
        }
        if (state.loop && state.loopEnd > state.loopStart) {
            root.setLoop(deck, state.loopStart, state.loopEnd);
        } else if (deck.loopEnabled.value > 0) {
            deck.reloopToggle.value = 1;
            deck.reloopToggle.value = 0;
        }
        deck.position.value = state.position;
        stems.setMutes(state.mutes);
        root.setSaved(group, null);
        root.setFired(group, -1);
        root.restoring = null;
        return true;
    }
    Timer {
        id: placeTimer

        property int tries: 0

        // Up to 30 s: a big stem file on a slow phone
        interval: 150
        repeat: true
        onTriggered: {
            const done = root.restoring ? root.placeRestoring() : root.placePending();
            if (done) {
                stop();
            } else if (++tries > 200) {
                stop();
                root.failed(root.restoring ? qsTr("Scratch: no se pudo volver a cargar el tema.") : qsTr("Scratch: no se pudo cargar la frase en el deck."));
                root.pending = null;
                root.restoring = null;
            }
        }
    }

    // A new track loaded by hand forgets the phrase (not the way back)
    Connections {
        target: deck1.loadedProxy
        function onValueChanged() {
            if (!root.pending && !root.restoring) {
                root.fired1 = -1;
            }
        }
    }
    Connections {
        target: deck2.loadedProxy
        function onValueChanged() {
            if (!root.pending && !root.restoring) {
                root.fired2 = -1;
            }
        }
    }

    component DeckControls: Item {
        id: deckControls

        required property string group
        property alias samples: samplesProxy
        property alias duration: durationProxy
        property alias position: positionProxy
        property alias bpm: bpmProxy
        property alias fileBpm: fileBpmProxy
        property alias loopEnabled: loopEnabledProxy
        property alias loopStart: loopStartProxy
        property alias loopEnd: loopEndProxy
        property alias reloopToggle: reloopToggleProxy
        property alias loadedProxy: loadedControl

        Mixxx.ControlProxy {
            id: samplesProxy

            group: deckControls.group
            key: "track_samples"
        }
        Mixxx.ControlProxy {
            id: durationProxy

            group: deckControls.group
            key: "duration"
        }
        Mixxx.ControlProxy {
            id: positionProxy

            group: deckControls.group
            key: "playposition"
        }
        Mixxx.ControlProxy {
            id: bpmProxy

            group: deckControls.group
            key: "bpm"
        }
        Mixxx.ControlProxy {
            id: fileBpmProxy

            group: deckControls.group
            key: "file_bpm"
        }
        Mixxx.ControlProxy {
            id: loopEnabledProxy

            group: deckControls.group
            key: "loop_enabled"
        }
        Mixxx.ControlProxy {
            id: loopStartProxy

            group: deckControls.group
            key: "loop_start_position"
        }
        Mixxx.ControlProxy {
            id: loopEndProxy

            group: deckControls.group
            key: "loop_end_position"
        }
        Mixxx.ControlProxy {
            id: reloopToggleProxy

            group: deckControls.group
            key: "reloop_toggle"
        }
        Mixxx.ControlProxy {
            id: loadedControl

            group: deckControls.group
            key: "track_loaded"
        }
    }

    // The stems of the track on a deck: read and set their mutes
    component StemSet: Item {
        id: stemSet

        required property string group
        readonly property var player: Mixxx.PlayerManager.getPlayer(stemSet.group)
        readonly property var track: stemSet.player ? stemSet.player.currentTrack : null
        readonly property string prefix: stemSet.group.substr(0, stemSet.group.length - 1)
        readonly property int count: stemRepeater.count

        function mutes() {
            const list = [];
            for (let i = 0; i < stemRepeater.count; ++i) {
                list.push(stemRepeater.itemAt(i).muted);
            }
            return list;
        }
        function setMutes(list) {
            for (let i = 0; i < stemRepeater.count; ++i) {
                stemRepeater.itemAt(i).setMuted(i < list.length ? list[i] : false);
            }
        }
        // All but `keep` ("Vocals"); every stem back with ""; nothing
        // muted when the track has no such stem
        function muteAllBut(keep) {
            let found = false;
            for (let i = 0; i < stemRepeater.count; ++i) {
                found = found || stemRepeater.itemAt(i).label === keep;
            }
            for (let i = 0; i < stemRepeater.count; ++i) {
                const stem = stemRepeater.itemAt(i);
                stem.setMuted(keep !== "" && found && stem.label !== keep);
            }
        }

        Repeater {
            id: stemRepeater

            model: stemSet.track ? stemSet.track.stemsModel : 0

            Item {
                id: stem

                required property int index
                required property string label
                readonly property bool muted: mute.value > 0

                function setMuted(value) {
                    mute.value = value ? 1 : 0;
                }

                Mixxx.ControlProxy {
                    id: mute

                    group: `${stemSet.prefix}_Stem${stem.index + 1}]`
                    key: "mute"
                }
            }
        }
    }

    DeckControls {
        id: deck1

        group: "[Channel1]"
    }
    DeckControls {
        id: deck2

        group: "[Channel2]"
    }
    StemSet {
        id: stems1

        group: "[Channel1]"
    }
    StemSet {
        id: stems2

        group: "[Channel2]"
    }

    // SHIFT + a pad of a controller fires a slot ([Cutlab] scratch_bank set
    // to the slot number) on the deck of the open Scratch tool
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: "scratch_bank"
        onValueChanged: {
            const index = Math.round(value) % 100 - 1;
            if (index >= 0 && index < 8 && root.toolGroup !== "") {
                root.fire(index, root.toolGroup);
            }
        }
    }
}
