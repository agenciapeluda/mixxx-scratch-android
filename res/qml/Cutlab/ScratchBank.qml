import Mixxx 1.0 as Mixxx
import QtQuick

// Scratch Bank: short phrases of your tracks (an "ahh", a "fresh", a horn)
// kept in 8 slots. Capture one from what plays on a deck (the loop if there
// is one, else from the playhead), then tap a slot to load it on the deck
// you scratch with: at its start, looped, and only the voice when the track
// has stems. With DVS the record plays it under your hand.
Rectangle {
    id: root

    // The deck the phrases go to: the one with the control vinyl, else B
    property string target: dvs1.value > 0 && dvs2.value <= 0 ? "[Channel1]" : "[Channel2]"
    property real captureBeats: 2
    property bool voiceOnly: true
    property var slots: []
    // A phrase waiting for its track to load: {group, slot}
    property var pending: null

    color: Style.panelDark

    function save() {
        Mixxx.Application.setConfigValue("[Cutlab]", "scratch_bank", encodeURIComponent(JSON.stringify(root.slots)));
    }
    Component.onCompleted: {
        try {
            const stored = decodeURIComponent(Mixxx.Application.configValue("[Cutlab]", "scratch_bank", ""));
            const list = stored ? JSON.parse(stored) : [];
            root.slots = Array.isArray(list) ? list : [];
        } catch (e) {
            root.slots = [];
        }
        while (root.slots.length < 8) {
            root.slots = root.slots.concat([null]);
        }
    }

    // The phrase on a deck: its loop, else the next beats from the playhead
    function capture(group, slotIndex) {
        const deck = group === "[Channel2]" ? deck2 : deck1;
        const player = Mixxx.PlayerManager.getPlayer(group);
        const track = player ? player.currentTrack : null;
        if (!track || deck.samples.value <= 0) {
            return;
        }
        const total = deck.samples.value;
        let start;
        let end;
        if (deck.loopEnabled.value > 0 && deck.loopStart.value >= 0 && deck.loopEnd.value > deck.loopStart.value) {
            start = deck.loopStart.value / total;
            end = deck.loopEnd.value / total;
        } else {
            const bpm = deck.bpm.value > 0 ? deck.bpm.value : 120;
            const seconds = root.captureBeats * 60 / bpm;
            start = deck.position.value;
            end = Math.min(1, start + seconds / Math.max(1, deck.duration.value));
        }
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
            title: track.title || track.trackLocationUrl.toString().split("/").pop(),
            artist: track.artist || "",
            start: start,
            end: end,
            beats: Math.round((end - start) * deck.duration.value * Math.max(1, deck.bpm.value) / 60 * 4) / 4
        };
        root.slots = slots;
        root.save();
    }
    function clear(index) {
        const slots = root.slots.slice();
        slots[index] = null;
        root.slots = slots;
        root.save();
    }
    // Load the phrase on the scratch deck
    function fire(index) {
        const slot = root.slots[index];
        if (!slot) {
            return;
        }
        const player = Mixxx.PlayerManager.getPlayer(root.target);
        if (!player) {
            return;
        }
        root.pending = {group: root.target, slot: slot};
        const current = player.currentTrack;
        if (current && current.trackLocationUrl.toString() === slot.url) {
            // Already there: only jump and loop
            Qt.callLater(root.placePending);
        } else {
            player.loadTrackFromLocationUrl(slot.url, false);
            placeTimer.tries = 0;
            placeTimer.start();
        }
    }
    function placePending() {
        const pending = root.pending;
        if (!pending) {
            return true;
        }
        const deck = pending.group === "[Channel2]" ? deck2 : deck1;
        const player = Mixxx.PlayerManager.getPlayer(pending.group);
        const track = player ? player.currentTrack : null;
        if (!track || track.trackLocationUrl.toString() !== pending.slot.url || deck.samples.value <= 0) {
            return false;
        }
        const total = deck.samples.value;
        // Stereo samples, on even numbers
        const startSample = Math.round(pending.slot.start * total / 2) * 2;
        const endSample = Math.round(pending.slot.end * total / 2) * 2;
        deck.loopStart.value = startSample;
        deck.loopEnd.value = endSample;
        deck.position.value = pending.slot.start;
        if (deck.loopEnabled.value <= 0) {
            deck.reloopToggle.value = 1;
        }
        if (root.voiceOnly) {
            soloVoice.group = pending.group;
            soloVoice.apply();
        }
        root.pending = null;
        return true;
    }
    Timer {
        id: placeTimer

        property int tries: 0

        interval: 150
        repeat: true
        onTriggered: {
            if (root.placePending() || ++tries > 60) {
                stop();
            }
        }
    }

    // Mutes all but the voice of the stems of a deck
    Item {
        id: soloVoice

        property string group: "[Channel2]"
        readonly property var player: Mixxx.PlayerManager.getPlayer(group)
        readonly property var track: player ? player.currentTrack : null
        readonly property string prefix: group.substr(0, group.length - 1)

        function apply() {
            let hasVoice = false;
            for (let i = 0; i < stems.count; ++i) {
                hasVoice = hasVoice || stems.itemAt(i).label === "Vocals";
            }
            for (let i = 0; i < stems.count; ++i) {
                const stem = stems.itemAt(i);
                stem.setMuted(hasVoice && stem.label !== "Vocals");
            }
        }

        Repeater {
            id: stems

            model: soloVoice.track ? soloVoice.track.stemsModel : 0

            Item {
                id: stem

                required property int index
                required property string label

                function setMuted(value) {
                    mute.value = value ? 1 : 0;
                }

                Mixxx.ControlProxy {
                    id: mute

                    group: `${soloVoice.prefix}_Stem${stem.index + 1}]`
                    key: "mute"
                }
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
        property alias loopEnabled: loopEnabledProxy
        property alias loopStart: loopStartProxy
        property alias loopEnd: loopEndProxy
        property alias reloopToggle: reloopToggleProxy

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
    }
    DeckControls {
        id: deck1

        group: "[Channel1]"
    }
    DeckControls {
        id: deck2

        group: "[Channel2]"
    }
    Mixxx.ControlProxy {
        id: dvs1

        group: "[Channel1]"
        key: "vinylcontrol_enabled"
    }
    Mixxx.ControlProxy {
        id: dvs2

        group: "[Channel2]"
        key: "vinylcontrol_enabled"
    }
    // SHIFT + a pad of a controller can fire a slot: [Cutlab] scratch_bank
    // set to the slot number
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: "scratch_bank"
        onValueChanged: {
            const index = Math.round(value) % 100 - 1;
            if (index >= 0 && index < 8) {
                root.fire(index);
            }
        }
    }

    // ---- Capture ----
    Row {
        id: captureRow

        x: 10
        y: 10
        width: parent.width - 20
        height: 44
        spacing: 8

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            CLButton {
                required property string modelData

                width: Math.min(170, (captureRow.width - 8 * 6) / 4)
                height: captureRow.height
                radius: 10
                text: qsTr("Capturar de %1").arg(Style.deckLetter(modelData))
                fontSize: 13
                fontWeight: Font.DemiBold
                litColor: Style.deckColor(modelData)
                lit: true
                onClicked: root.capture(modelData, -1)
            }
        }
        Repeater {
            model: [1, 2, 4, 8]

            CLButton {
                required property real modelData

                width: 46
                height: captureRow.height
                radius: 10
                text: String(modelData)
                fontSize: 13
                highlighted: root.captureBeats === modelData
                onClicked: root.captureBeats = modelData
            }
        }
        CLButton {
            width: 104
            height: captureRow.height
            radius: 10
            text: qsTr("Solo voz")
            fontSize: 13
            highlighted: root.voiceOnly
            onClicked: root.voiceOnly = !root.voiceOnly
        }
    }

    // ---- Where they go ----
    Row {
        id: targetRow

        x: 10
        anchors.top: captureRow.bottom
        anchors.topMargin: 8
        height: 30
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 13
            text: qsTr("Tocá un slot y va al deck")
        }
        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Rectangle {
                required property string modelData

                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 26
                radius: 6
                color: root.target === modelData ? Style.deckColor(modelData) : Style.raised

                Text {
                    anchors.centerIn: parent
                    color: root.target === parent.modelData ? Style.background : Style.text
                    font.family: Style.mono
                    font.weight: Font.Bold
                    font.pixelSize: 13
                    text: Style.deckLetter(parent.modelData)
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.target = parent.modelData
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 12
            text: qsTr("· con loop, para scratchear con el vinilo · mantené un slot para borrarlo")
            elide: Text.ElideRight
            width: Math.max(0, root.width - 260)
        }
    }

    // ---- The slots ----
    Grid {
        id: grid

        anchors.top: targetRow.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 10
        columns: 4
        spacing: 8

        Repeater {
            model: 8

            Rectangle {
                id: slotPad

                required property int index
                readonly property var slot: root.slots[index] || null

                width: (grid.width - grid.spacing * 3) / 4
                height: (grid.height - grid.spacing) / 2
                radius: 12
                color: slotMouse.pressed ? Style.buttonPressed : (slot ? Style.raised : Style.panel)
                border.width: 1
                border.color: slot ? Style.deckColor(root.target) : Style.divider
                scale: slotMouse.pressed ? 0.97 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 70
                    }
                }

                Text {
                    x: 10
                    y: 8
                    color: Style.textSecondary
                    font.family: Style.mono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    text: String(slotPad.index + 1)
                }
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 10
                    spacing: 3

                    Text {
                        width: parent.width
                        color: slotPad.slot ? Style.text : Style.textDim
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Style.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        text: slotPad.slot ? slotPad.slot.title : qsTr("vacío")
                    }
                    Text {
                        width: parent.width
                        visible: !!slotPad.slot
                        color: Style.textSecondary
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Style.mono
                        font.pixelSize: 11
                        text: slotPad.slot ? qsTr("%1 tiempos").arg(slotPad.slot.beats) : ""
                    }
                }
                MouseArea {
                    id: slotMouse

                    anchors.fill: parent
                    pressAndHoldInterval: 700
                    onClicked: {
                        if (slotPad.slot) {
                            root.fire(slotPad.index);
                        } else {
                            // An empty slot captures from the deck that plays
                            root.capture(play2.value > 0 && play1.value <= 0 ? "[Channel2]" : "[Channel1]", slotPad.index);
                        }
                    }
                    onPressAndHold: root.clear(slotPad.index)
                }
            }
        }
    }
    Mixxx.ControlProxy {
        id: play1

        group: "[Channel1]"
        key: "play_latched"
    }
    Mixxx.ControlProxy {
        id: play2

        group: "[Channel2]"
        key: "play_latched"
    }
}
