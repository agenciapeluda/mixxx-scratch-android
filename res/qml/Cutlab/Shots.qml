pragma Singleton
import QtQuick

// Where the FX pad finds the one shot effects of each deck, and the effect
// picked on the pad of each deck. The engines live in the performance
// screen so the controllers can fire them with the pad closed.
QtObject {
    property var deck1: null
    property var deck2: null
    // What the FX pad of each deck plays (FxEngine), alive all the session
    property var engine1: null
    property var engine2: null
    // The effect of the FX pad of each deck, picked on the screen or with
    // the FX SLOT buttons of a controller
    property string effect1: "echo"
    property string effect2: "echo"
    // The effect plays from a controller (the BEAT FX lever)
    property bool engaged1: false
    property bool engaged2: false
    // [AI-generated text, Claude (Anthropic) — start]
    // Cutlab 1.31: Key Shift / Pitch Play of each deck (KeyPlay)
    property var keyPlay1: null
    property var keyPlay2: null
    function keyPlayFor(group) {
        return group === "[Channel2]" ? keyPlay2 : keyPlay1;
    }
    // [AI-generated text, Claude (Anthropic) — end]

    readonly property var banks: [
        ["echo", "reverb", "flanger"],
        ["roll", "trans", "gater", "glitch"],
        ["filter", "bitcrush"]
    ]

    function forGroup(group) {
        return group === "[Channel2]" ? deck2 : deck1;
    }
    function engineFor(group) {
        return group === "[Channel2]" ? engine2 : engine1;
    }
    function effectFor(group) {
        return group === "[Channel2]" ? effect2 : effect1;
    }
    function setEffect(group, effect) {
        if (group === "[Channel2]") {
            effect2 = effect;
        } else {
            effect1 = effect;
        }
    }
    function engagedFor(group) {
        return group === "[Channel2]" ? engaged2 : engaged1;
    }
    // The next or previous effect, through all the banks
    function step(group, by) {
        const all = [].concat(...banks);
        const at = all.indexOf(effectFor(group));
        setEffect(group, all[((at < 0 ? 0 : at + by) + all.length) % all.length]);
    }
    // A bank button: its first effect, or the next one if the effect is
    // already in that bank
    function selectBank(group, bank) {
        const effects = banks[Math.max(0, Math.min(banks.length - 1, bank))];
        const current = effectFor(group);
        const at = effects.indexOf(current);
        setEffect(group, at < 0 ? effects[0] : effects[(at + 1) % effects.length]);
    }
}
