// Arturia MiniLab mkII DJ mapping for Cutlab (Mixxx).
// Factory memory 1: pads 1-8 send notes 36-43 on channel 10, pads 9-16
// send CC 22-29 on channel 1, the encoders send relative values around 64.

var ArturiaMiniLabMk2 = {};

ArturiaMiniLabMk2.topKnobs = [0x70, 0x4A, 0x47, 0x4C, 0x4D, 0x5D, 0x49, 0x4B];
ArturiaMiniLabMk2.bottomKnobs = [0x72, 0x12, 0x13, 0x10, 0x11, 0x5B, 0x4F, 0x48];

// What each knob position controls: [group suffix, key]. "%d" is the deck.
ArturiaMiniLabMk2.knobTargets = [
    ["[QuickEffectRack1_[Channel%d]]", "super1"],
    ["[EqualizerRack1_[Channel%d]_Effect1]", "parameter3"],
    ["[EqualizerRack1_[Channel%d]_Effect1]", "parameter2"],
    ["[EqualizerRack1_[Channel%d]_Effect1]", "parameter1"],
    ["[Channel%d]", "volume"],
    ["[Channel%d_Stem1]", "volume"], // drums
    ["[Channel%d_Stem2]", "volume"], // bass
    ["[Channel%d_Stem4]", "volume"], // vocals
];

ArturiaMiniLabMk2.init = function() {};
ArturiaMiniLabMk2.shutdown = function() {};

ArturiaMiniLabMk2.setting = function(name, fallback) {
    const value = engine.getSetting(name);
    return value === undefined || value === null || value === "" ? fallback : value;
};

ArturiaMiniLabMk2.knob = function(_channel, control, value) {
    let deck = 1;
    let index = ArturiaMiniLabMk2.topKnobs.indexOf(control);
    if (index < 0) {
        deck = 2;
        index = ArturiaMiniLabMk2.bottomKnobs.indexOf(control);
    }
    if (index < 0) {
        return;
    }
    const target = ArturiaMiniLabMk2.knobTargets[index];
    const group = target[0].replace("%d", deck);
    const key = target[1];
    if (ArturiaMiniLabMk2.setting("knobMode", "relative") === "absolute") {
        engine.setParameter(group, key, value / 127);
        return;
    }
    // Relative: 64 = no change, above turns up, below turns down
    const delta = value - 64;
    if (delta === 0) {
        return;
    }
    const current = engine.getParameter(group, key);
    engine.setParameter(group, key, Math.max(0, Math.min(1, current + delta / 100)));
};

ArturiaMiniLabMk2.pad = function(deck, number, pressed) {
    const mode = ArturiaMiniLabMk2.setting("padMode", "hotcue");
    const group = `[Channel${deck}]`;
    if (mode === "stems") {
        // Pads 1-4: mute or unmute stems 1-4 (drums, bass, other, vocals)
        if (pressed && number <= 4) {
            const stem = `[Channel${deck}_Stem${number}]`;
            engine.setValue(stem, "mute", engine.getValue(stem, "mute") ? 0 : 1);
        } else if (pressed && number > 4) {
            // Pads 5-8: solo-like: mute every stem except this one
            for (let s = 1; s <= 4; s++) {
                engine.setValue(`[Channel${deck}_Stem${s}]`, "mute", s === number - 4 ? 0 : 1);
            }
        }
        return;
    }
    if (mode === "sampler") {
        if (pressed) {
            const sampler = `[Sampler${(deck - 1) * 8 + number}]`;
            engine.setValue(sampler, "cue_gotoandplay", 1);
        }
        return;
    }
    engine.setValue(group, `hotcue_${number}_activate`, pressed ? 1 : 0);
};

// Pads 1-8 (notes 36-43 on channel 10): deck 1
ArturiaMiniLabMk2.padBank1 = function(_channel, control, value, status) {
    const pressed = (status & 0xF0) === 0x90 && value > 0;
    ArturiaMiniLabMk2.pad(1, control - 0x24 + 1, pressed);
};

// Pads 9-16 (CC 22-29 on channel 1): deck 2
ArturiaMiniLabMk2.padBank2 = function(_channel, control, value) {
    ArturiaMiniLabMk2.pad(2, control - 0x16 + 1, value > 0);
};

// Mod touch strip: crossfader
ArturiaMiniLabMk2.modStrip = function(_channel, _control, value) {
    engine.setValue("[Master]", "crossfader", value / 127 * 2 - 1);
};
