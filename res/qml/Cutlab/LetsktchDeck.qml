import Mixxx 1.0 as Mixxx
import QtQuick

// letsktch! on one deck, played from the Scratch pads.
// - The deck itself keeps only the stem to scratch (the voice by default):
//   the record, the jog or the waveform move it by the normal way of the
//   deck, with its fader and the crossfader.
// - A hidden deck (3 for A, 4 for B) holds the same track, loaded and
//   paused as soon as it has stems, and plays the rest of the stems (the
//   beat) in a loop of the same beats, at the tempo of the deck, straight to
//   the output: neither the fader nor the crossfader of the deck touch it,
//   so the voice can be cut over it. It is never scratched.
// - A pad starts a loop of N beats from the beat before and the beat with
//   it; the same pad ends it like turning a loop off: the track carries on
//   from where it is, all the stems come back and the hidden deck stops.
//   The loop the deck had before comes back only as its in and out marks,
//   not active, so the track does not jump.
// - 8 slots per track, kept like the hot cues: an empty one keeps the place
//   and the beats and starts, a kept one jumps to its phrase and starts.
Item {
    id: root

    required property string group
    required property string helper
    readonly property int deckNumber: root.group === "[Channel2]" ? 2 : 1

    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)
    readonly property var track: root.player ? root.player.currentTrack : null
    readonly property string trackUrl: root.track && trackLoaded.value > 0 ? root.track.trackLocationUrl.toString() : ""
    readonly property bool hasStems: root.trackUrl !== "" && mainStems.count > 0
    // Looked up once the hidden decks exist
    property var helperPlayer: null
    readonly property var helperTrack: root.helperPlayer ? root.helperPlayer.currentTrack : null
    readonly property bool helperReady: root.hasStems && !!root.helperTrack && helperDeck.samples.value > 0 && helperStems.count > 0 && root.helperTrack.trackLocationUrl.toString() === root.trackUrl

    // The beats of a new slot and the stem to scratch, kept per deck
    property int beats: {
        const stored = Number(Mixxx.Application.configValue("[Cutlab]", `scratch_beats${root.deckNumber}`, "4"));
        return [1, 2, 4, 8].indexOf(stored) >= 0 ? stored : 4;
    }
    property string stem: Mixxx.Application.configValue("[Cutlab]", `scratch_stem${root.deckNumber}`, "Vocals")
    // The labels of the stems of the track ("Vocals", "Drums", "Bass", "Other")
    readonly property var stemLabels: {
        const list = [];
        for (let i = 0; i < mainStems.count; ++i) {
            const item = mainStems.itemAt(i);
            if (item) {
                list.push(item.label);
            }
        }
        return list;
    }
    // The stem it scratches: the one picked, else the voice, else the first
    readonly property string scratchStem: root.stemLabels.indexOf(root.stem) >= 0 ? root.stem : (root.stemLabels.indexOf("Vocals") >= 0 ? "Vocals" : (root.stemLabels.length > 0 ? root.stemLabels[0] : ""))

    // The 8 slots of the track: null or {s: start in samples, b: beats}
    property var slots: [null, null, null, null, null, null, null, null]
    property int activeSlot: -1
    readonly property bool active: root.activeSlot >= 0
    // The beat waits for the hidden deck (only right after a load)
    property bool beatPending: false
    // The loop marks of the deck before the pad
    property var before: null

    signal failed(string text)

    function stemName(label) {
        switch (label) {
        case "Vocals":
            return qsTr("Voz");
        case "Drums":
            return qsTr("Batería");
        case "Bass":
            return qsTr("Bajo");
        case "Other":
            return qsTr("Melodía");
        default:
            return label;
        }
    }
    function setBeats(value) {
        root.beats = value;
        Mixxx.Application.setConfigValue("[Cutlab]", `scratch_beats${root.deckNumber}`, String(value));
    }
    function setStem(label) {
        root.stem = label;
        Mixxx.Application.setConfigValue("[Cutlab]", `scratch_stem${root.deckNumber}`, label);
        if (root.active) {
            mainStems.muteAllBut(root.scratchStem);
            helperStems.muteOnly(root.scratchStem);
        }
    }
    // 0 empty, 1 kept, 2 playing
    function slotState(index) {
        if (index === root.activeSlot) {
            return 2;
        }
        return root.slots[index] ? 1 : 0;
    }

    // ---- The slots of the track, kept in the settings by track ----
    function slotsKey(url) {
        return Qt.md5(url);
    }
    function loadSlots() {
        let list = [];
        if (root.trackUrl !== "") {
            try {
                const stored = Mixxx.Application.configValue("[CutlabScratch]", root.slotsKey(root.trackUrl), "");
                list = stored ? JSON.parse(decodeURIComponent(stored)) : [];
            } catch (e) {
                list = [];
            }
        }
        list = Array.isArray(list) ? list.slice(0, 8) : [];
        while (list.length < 8) {
            list.push(null);
        }
        root.slots = list;
    }
    function saveSlots() {
        if (root.trackUrl === "") {
            return;
        }
        const empty = root.slots.every(slot => !slot);
        Mixxx.Application.setConfigValue("[CutlabScratch]", root.slotsKey(root.trackUrl), empty ? "" : encodeURIComponent(JSON.stringify(root.slots)));
    }

    // ---- Pads ----
    function press(index) {
        if (index < 0 || index > 7) {
            return;
        }
        if (root.active) {
            const same = index === root.activeSlot;
            root.exit();
            if (same) {
                return;
            }
        }
        if (!root.hasStems) {
            root.failed(qsTr("Scratch: separá el tema en stems para scratchear la voz."));
            return;
        }
        if (main.samples.value <= 0) {
            return;
        }
        if (!root.slots[index]) {
            // From the beat before the playhead (or the playhead without a
            // beat grid)
            const here = main.position.value * main.samples.value;
            const prev = main.beatPrev.value;
            let start = prev >= 0 && prev <= here + 2 ? prev : here;
            start = Math.max(0, Math.round(start / 2) * 2);
            const slots = root.slots.slice();
            slots[index] = {s: start, b: root.beats};
            root.slots = slots;
            root.saveSlots();
            root.activate(index, false);
        } else {
            root.activate(index, true);
        }
    }
    function clear(index) {
        if (index === root.activeSlot) {
            root.exit();
        }
        const slots = root.slots.slice();
        slots[index] = null;
        root.slots = slots;
        root.saveSlots();
    }
    // The first free slot (a controller button), else the first one
    function toggleFromController() {
        if (root.active) {
            root.exit();
            return;
        }
        const free = root.slots.findIndex(slot => !slot);
        root.press(free >= 0 ? free : 0);
    }

    function beatSamples() {
        const bpm = main.fileBpm.value > 0 ? main.fileBpm.value : (main.bpm.value > 0 ? main.bpm.value : 120);
        const rate = main.sampleRate.value > 0 ? main.sampleRate.value : 44100;
        return 60 / bpm * rate * 2;
    }

    function activate(index, jump) {
        const slot = root.slots[index];
        const total = main.samples.value;
        if (!slot || total <= 0) {
            return;
        }
        const start = slot.s;
        const end = Math.min(total, start + Math.round(slot.b * root.beatSamples() / 2) * 2);
        if (end <= start) {
            return;
        }
        root.before = {
            start: main.loopStart.value,
            end: main.loopEnd.value
        };
        // The loop of the pad replaces the one of the deck (kept as marks)
        if (main.loopEnabled.value > 0) {
            main.reloop.value = 1;
            main.reloop.value = 0;
        }
        // Both decks seek in the same turn, so they start together
        const here = jump ? start : main.position.value * total;
        main.position.value = here / total;
        main.loopStart.value = start;
        main.loopEnd.value = end;
        main.reloop.value = 1;
        main.reloop.value = 0;
        mainStems.muteAllBut(root.scratchStem);
        root.activeSlot = index;
        activeControl.value = 1;
        if (root.helperReady) {
            root.startBeat(start, end, here);
        } else {
            root.beatPending = true;
            root.preload();
        }
    }
    // The beat on the hidden deck: the same beats, same place, same tempo
    function startBeat(start, end, here) {
        root.beatPending = false;
        root.followTempo();
        helperDeck.play.value = 0;
        if (helperDeck.loopEnabled.value > 0) {
            helperDeck.reloop.value = 1;
            helperDeck.reloop.value = 0;
        }
        helperDeck.loopStart.value = start;
        helperDeck.loopEnd.value = end;
        helperDeck.reloop.value = 1;
        helperDeck.reloop.value = 0;
        helperDeck.position.value = here / Math.max(1, helperDeck.samples.value);
        // Straight to the output: full level, in the middle of the
        // crossfader, never in the headphones
        helperDeck.volume.value = 1;
        helperDeck.orientation.value = 1;
        helperDeck.pfl.value = 0;
        helperDeck.sync.value = 0;
        helperStems.muteOnly(root.scratchStem);
        helperDeck.play.value = main.play.value > 0 ? 1 : 0;
    }

    function exit() {
        if (!root.active) {
            return;
        }
        // The beat stops, always
        helperDeck.play.value = 0;
        if (helperDeck.loopEnabled.value > 0) {
            helperDeck.reloop.value = 1;
            helperDeck.reloop.value = 0;
        }
        root.beatPending = false;
        // Like turning a loop off: the track carries on from where it is
        if (main.loopEnabled.value > 0) {
            main.reloop.value = 1;
            main.reloop.value = 0;
        }
        const before = root.before;
        mainStems.muteAllBut("");
        root.activeSlot = -1;
        activeControl.value = 0;
        root.before = null;
        root.restoreMarks(before);
    }
    // The loop from before only as in and out marks, never active
    function restoreMarks(before) {
        if (main.loopEnabled.value > 0) {
            main.reloop.value = 1;
            main.reloop.value = 0;
        }
        if (before && before.start >= 0 && before.end > before.start) {
            main.loopStart.value = before.start;
            main.loopEnd.value = before.end;
        } else {
            main.loopStart.value = -1;
        }
        // Setting the marks never turns the loop on, but check anyway
        if (main.loopEnabled.value > 0) {
            main.reloop.value = 1;
            main.reloop.value = 0;
        }
    }

    // A new track on the deck: everything ends without touching it
    function reset() {
        if (root.active) {
            helperDeck.play.value = 0;
        }
        root.activeSlot = -1;
        root.beatPending = false;
        root.before = null;
        activeControl.value = 0;
    }
    onTrackUrlChanged: {
        root.reset();
        root.loadSlots();
        root.preload();
    }
    onHasStemsChanged: root.preload()
    onHelperReadyChanged: {
        if (root.helperReady && root.beatPending && root.active) {
            const slot = root.slots[root.activeSlot];
            if (slot) {
                const total = main.samples.value;
                const end = Math.min(total, slot.s + Math.round(slot.b * root.beatSamples() / 2) * 2);
                root.startBeat(slot.s, end, main.position.value * total);
            }
        }
    }
    Component.onCompleted: {
        activeControl.value = 0;
        root.loadSlots();
        root.preload();
    }

    // ---- The hidden deck: loaded and paused while the track has stems ----
    function preload() {
        preloadTimer.restart();
    }
    Timer {
        id: preloadTimer

        interval: 250
        repeat: true
        onTriggered: {
            if (!root.hasStems) {
                // Nothing to hold: free the hidden deck
                if (root.helperPlayer && root.helperTrack && !root.active) {
                    helperDeck.play.value = 0;
                    helperDeck.eject.value = 1;
                    helperDeck.eject.value = 0;
                }
                stop();
                return;
            }
            if (!root.helperPlayer) {
                root.helperPlayer = Mixxx.PlayerManager.getPlayer(root.helper);
            }
            if (!root.helperPlayer) {
                // The hidden decks come with 4 decks
                numDecks.value = Math.max(numDecks.value, 4);
                return;
            }
            if (!(root.helperTrack && root.helperTrack.trackLocationUrl.toString() === root.trackUrl)) {
                helperDeck.play.value = 0;
                root.helperPlayer.loadTrackFromLocationUrl(root.trackUrl, false);
            }
            stop();
        }
    }
    function followTempo() {
        helperDeck.rateRange.value = main.rateRange.value;
        helperDeck.rate.value = main.rate.value;
        helperDeck.keylock.value = main.keylock.value;
    }
    // The hidden deck always at the tempo of the deck, even when the pitch
    // moves while scratching
    Connections {
        target: root.helperPlayer ? main.rate : null
        function onValueChanged() {
            helperDeck.rate.value = main.rate.value;
        }
    }
    Connections {
        target: root.helperPlayer ? main.rateRange : null
        function onValueChanged() {
            helperDeck.rateRange.value = main.rateRange.value;
            helperDeck.rate.value = main.rate.value;
        }
    }
    Connections {
        target: root.helperPlayer ? main.keylock : null
        function onValueChanged() {
            helperDeck.keylock.value = main.keylock.value;
        }
    }
    Connections {
        target: root.helperReady ? helperDeck.samples : null
        function onValueChanged() {
            root.followTempo();
        }
    }
    // The beat plays and stops with the deck
    Connections {
        target: root.active && !root.beatPending ? main.play : null
        function onValueChanged() {
            helperDeck.play.value = main.play.value > 0 ? 1 : 0;
        }
    }

    // ---- Controllers ----
    // A pad in Scratch mode: counter * 100 + 1-8 (play) or 11-18 (clear)
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: `scratch_pad${root.deckNumber}`
        onValueChanged: {
            const code = Math.round(value) % 100;
            if (code >= 1 && code <= 8) {
                root.press(code - 1);
            } else if (code >= 11 && code <= 18) {
                root.clear(code - 11);
            }
        }
    }
    Mixxx.ControlProxy {
        id: activeControl

        group: "[Cutlab]"
        key: `scratch_active${root.deckNumber}`
    }
    // The state of each slot, for the lights of a controller
    Repeater {
        model: 8

        Item {
            id: slotLight

            required property int index
            readonly property int slotState: root.slotState(slotLight.index)

            onSlotStateChanged: slotControl.value = slotLight.slotState
            Component.onCompleted: slotControl.value = slotLight.slotState

            Mixxx.ControlProxy {
                id: slotControl

                group: "[Cutlab]"
                key: `scratch_slot${root.deckNumber}_${slotLight.index + 1}`
            }
        }
    }

    Mixxx.ControlProxy {
        id: numDecks

        group: "[App]"
        key: "num_decks"
    }
    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }

    component DeckControls: Item {
        id: deck

        required property string group
        property alias play: playProxy
        property alias position: positionProxy
        property alias samples: samplesProxy
        property alias sampleRate: sampleRateProxy
        property alias bpm: bpmProxy
        property alias fileBpm: fileBpmProxy
        property alias beatPrev: beatPrevProxy
        property alias loopEnabled: loopEnabledProxy
        property alias loopStart: loopStartProxy
        property alias loopEnd: loopEndProxy
        property alias reloop: reloopProxy
        property alias rate: rateProxy
        property alias rateRange: rateRangeProxy
        property alias keylock: keylockProxy
        property alias orientation: orientationProxy
        property alias volume: volumeProxy
        property alias pfl: pflProxy
        property alias sync: syncProxy
        property alias eject: ejectProxy

        Mixxx.ControlProxy {
            id: playProxy

            group: deck.group
            key: "play"
        }
        Mixxx.ControlProxy {
            id: positionProxy

            group: deck.group
            key: "playposition"
        }
        Mixxx.ControlProxy {
            id: samplesProxy

            group: deck.group
            key: "track_samples"
        }
        Mixxx.ControlProxy {
            id: sampleRateProxy

            group: deck.group
            key: "track_samplerate"
        }
        Mixxx.ControlProxy {
            id: bpmProxy

            group: deck.group
            key: "bpm"
        }
        Mixxx.ControlProxy {
            id: fileBpmProxy

            group: deck.group
            key: "file_bpm"
        }
        Mixxx.ControlProxy {
            id: beatPrevProxy

            group: deck.group
            key: "beat_prev"
        }
        Mixxx.ControlProxy {
            id: loopEnabledProxy

            group: deck.group
            key: "loop_enabled"
        }
        Mixxx.ControlProxy {
            id: loopStartProxy

            group: deck.group
            key: "loop_start_position"
        }
        Mixxx.ControlProxy {
            id: loopEndProxy

            group: deck.group
            key: "loop_end_position"
        }
        Mixxx.ControlProxy {
            id: reloopProxy

            group: deck.group
            key: "reloop_toggle"
        }
        Mixxx.ControlProxy {
            id: rateProxy

            group: deck.group
            key: "rate"
        }
        Mixxx.ControlProxy {
            id: rateRangeProxy

            group: deck.group
            key: "rateRange"
        }
        Mixxx.ControlProxy {
            id: keylockProxy

            group: deck.group
            key: "keylock"
        }
        Mixxx.ControlProxy {
            id: orientationProxy

            group: deck.group
            key: "orientation"
        }
        Mixxx.ControlProxy {
            id: volumeProxy

            group: deck.group
            key: "volume"
        }
        Mixxx.ControlProxy {
            id: pflProxy

            group: deck.group
            key: "pfl"
        }
        Mixxx.ControlProxy {
            id: syncProxy

            group: deck.group
            key: "sync_enabled"
        }
        Mixxx.ControlProxy {
            id: ejectProxy

            group: deck.group
            key: "eject"
        }
    }

    // The stems of a deck and their mutes
    component StemSet: Item {
        id: stemSet

        required property string group
        property var track: null
        readonly property string prefix: stemSet.group.substr(0, stemSet.group.length - 1)
        readonly property int count: stemRepeater.count

        function itemAt(index) {
            return stemRepeater.itemAt(index);
        }
        // All but `keep`; every stem back with ""
        function muteAllBut(keep) {
            for (let i = 0; i < stemRepeater.count; ++i) {
                const stem = stemRepeater.itemAt(i);
                if (stem) {
                    stem.setMuted(keep !== "" && stem.label !== keep);
                }
            }
        }
        // Only `label` muted
        function muteOnly(label) {
            for (let i = 0; i < stemRepeater.count; ++i) {
                const stem = stemRepeater.itemAt(i);
                if (stem) {
                    stem.setMuted(stem.label === label);
                }
            }
        }

        Repeater {
            id: stemRepeater

            model: stemSet.track ? stemSet.track.stemsModel : 0

            Item {
                id: stem

                required property int index
                required property string label

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
        id: main

        group: root.group
    }
    // Bound to the hidden deck once it exists, so its controls connect
    DeckControls {
        id: helperDeck

        group: root.helperPlayer ? root.helper : "[CutlabNone]"
    }
    StemSet {
        id: mainStems

        group: root.group
        track: trackLoaded.value > 0 ? root.track : null
    }
    StemSet {
        id: helperStems

        group: root.helper
        track: root.helperTrack
    }
}
