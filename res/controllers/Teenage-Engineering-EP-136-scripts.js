// Teenage Engineering EP-136 K.O.-sidekick for Cutlab (Mixxx).
// MIDI per teenage.engineering/guides/ep-136/system-settings:
// channel 1 and 2 = mixer channels, channel 3 = force pad and mod stick.
// CC 7 fader, 22/23/24 EQ, 20 gain (relative), 3 cue, 14 fx; with SELECT
// held: 9, 27/28/29, 25, 52, 15. Force pad CC 1 (SELECT: 2) on channel 3,
// mod stick = pitch bend on channel 3.

var TEEP136 = {};

TEEP136.init = function() {};
TEEP136.shutdown = function() {};

TEEP136.relative = function(value) {
    // 1..63 up, 65..127 down, 0 and 64 nothing
    if (value === 0 || value === 64) {
        return 0;
    }
    return value < 64 ? value : value - 128;
};

TEEP136.nudge = function(group, key, value) {
    const step = TEEP136.relative(value);
    if (step !== 0) {
        const current = engine.getParameter(group, key);
        engine.setParameter(group, key, Math.max(0, Math.min(1, current + step / 64)));
    }
};

TEEP136.channelControl = function(channel, control, value) {
    const deck = channel + 1; // MIDI channel 1 = deck 1
    const group = `[Channel${deck}]`;
    const eq = `[EqualizerRack1_[Channel${deck}]_Effect1]`;
    const quickFx = `[QuickEffectRack1_[Channel${deck}]]`;
    const level = value / 127;
    switch (control) {
    case 7:
        engine.setParameter(group, "volume", level);
        break;
    case 22:
        engine.setParameter(eq, "parameter3", level);
        break;
    case 23:
        engine.setParameter(eq, "parameter2", level);
        break;
    case 24:
        engine.setParameter(eq, "parameter1", level);
        break;
    case 20:
        TEEP136.nudge(group, "pregain", value);
        break;
    case 3:
        engine.setValue(group, "pfl", value > 0 ? 1 : 0);
        break;
    case 14:
        engine.setValue(quickFx, "enabled", value > 0 ? 1 : 0);
        break;
    // SELECT held
    case 27:
        engine.setParameter(`[Channel${deck}_Stem4]`, "volume", level); // vocals
        break;
    case 28:
        engine.setParameter(`[Channel${deck}_Stem3]`, "volume", level); // other
        break;
    case 29:
        engine.setParameter(`[Channel${deck}_Stem1]`, "volume", level); // drums
        break;
    case 25:
        TEEP136.nudge(quickFx, "super1", value);
        break;
    case 52:
        if (value > 0) {
            script.toggleControl(group, "play");
        }
        break;
    case 15:
        if (value > 0) {
            script.toggleControl(group, "sync_enabled");
        }
        break;
    case 9:
        engine.setParameter(group, "volume", level);
        break;
    }
};

TEEP136.forcePad = function(_channel, control, value) {
    const unit = control === 2 ? 2 : 1;
    engine.setParameter(`[EffectRack1_EffectUnit${unit}]`, "mix", value / 127);
};

TEEP136.modStick = function(_channel, lsb, msb) {
    if (engine.getSetting("modStick") !== "crossfader") {
        return;
    }
    const position = ((msb << 7) | lsb) / 16383; // 0..1, 0.5 = center
    engine.setValue("[Master]", "crossfader", position * 2 - 1);
};
