// Akai MPC Sample (or any MPC sending its pads as MIDI notes) for Cutlab.
// Pad 1 is note 37 (MPC default) or 36; any MIDI channel.

var AkaiMpcSample = {};

AkaiMpcSample.init = function() {};
AkaiMpcSample.shutdown = function() {};

AkaiMpcSample.setting = function(name, fallback) {
    const value = engine.getSetting(name);
    return value === undefined || value === null || value === "" ? fallback : value;
};

AkaiMpcSample.hotcue = function(deck, number, pressed) {
    engine.setValue(`[Channel${deck}]`, `hotcue_${number}_activate`, pressed ? 1 : 0);
};

AkaiMpcSample.pad = function(_channel, control, value, status) {
    const pressed = (status & 0xF0) === 0x90 && value > 0;
    const base = Number(AkaiMpcSample.setting("baseNote", "37"));
    const pad = control - base + 1; // 1..16
    if (pad < 1 || pad > 16) {
        return;
    }
    const layout = AkaiMpcSample.setting("padLayout", "samplers");
    if (layout === "hotcues") {
        AkaiMpcSample.hotcue(pad <= 8 ? 1 : 2, ((pad - 1) % 8) + 1, pressed);
        return;
    }
    if (pad >= 9) {
        // Pads 9-12: deck 1 hot cues 1-4, pads 13-16: deck 2 hot cues 1-4
        AkaiMpcSample.hotcue(pad <= 12 ? 1 : 2, ((pad - 9) % 4) + 1, pressed);
        return;
    }
    if (layout === "stems") {
        if (pressed) {
            const deck = pad <= 4 ? 1 : 2;
            const stem = `[Channel${deck}_Stem${((pad - 1) % 4) + 1}]`;
            engine.setValue(stem, "mute", engine.getValue(stem, "mute") ? 0 : 1);
        }
        return;
    }
    if (pressed) {
        engine.setValue(`[Sampler${pad}]`, "cue_gotoandplay", 1);
    }
};
