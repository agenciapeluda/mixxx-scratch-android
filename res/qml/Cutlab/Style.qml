pragma Singleton
import Mixxx 1.0 as Mixxx
import QtQuick

// Colors of the Cutlab layout: neutral grays, the Cutlab indigo as accent,
// green for what is playing and a red playhead.
QtObject {
    // Inter Tight for the interface, JetBrains Mono for numbers that change
    // while playing (BPM, time, pitch): the digits keep their width
    readonly property string font: "Inter Tight"
    readonly property string mono: "JetBrains Mono"

    readonly property color black: "#000000"
    readonly property color topBar: "#0e0d1a"
    readonly property color background: "#07060f"
    readonly property color panel: "#0e0d1a"
    readonly property color panelDark: "#0b0a16"
    readonly property color raised: "#17162a"
    readonly property color divider: "#1d1b33"
    readonly property color button: "#17162a"
    readonly property color buttonPressed: "#2a2650"
    readonly property color buttonBorder: "#2a2940"
    readonly property color track: "#1d1b33"
    readonly property color tick: "#3a3858"

    readonly property color text: "#f4f5fb"
    readonly property color textSecondary: "#9ca1b8"
    readonly property color textDim: "#6e7390"

    // The Cutlab indigo marks the brand and everything that is on
    readonly property color accent: "#635bff"
    // The accent for text and icons on dark grounds, easier to read
    readonly property color accentText: "#8b85ff"
    readonly property color accentDark: "#2b2766"
    readonly property color play: "#2bd67b"
    readonly property color ok: "#2bd67b"
    readonly property color cue: "#ffb547"
    readonly property color playhead: "#ffffff"
    readonly property color loop: "#2bd67b"
    readonly property color danger: "#ff4d5e"

    // Each deck keeps its color everywhere: waveform, dial, pads, load
    readonly property color deck1: "#8b85ff"
    readonly property color deck2: "#00c2d8"
    function deckColor(group) {
        return group === "[Channel2]" || group === "[Channel4]" ? deck2 : deck1;
    }
    // The waveform of each deck: dark body, light peaks
    readonly property color deck1Dark: "#5a52d6"
    readonly property color deck1Light: "#b3aeff"
    readonly property color deck2Dark: "#00879a"
    readonly property color deck2Light: "#7fe6f2"
    function deckDark(group) {
        return group === "[Channel2]" || group === "[Channel4]" ? deck2Dark : deck1Dark;
    }
    function deckLight(group) {
        return group === "[Channel2]" || group === "[Channel4]" ? deck2Light : deck1Light;
    }
    // The cover placeholder of each deck
    function deckShade(group) {
        return group === "[Channel2]" || group === "[Channel4]" ? "#0b3640" : "#2a2650";
    }
    // Keys are amber chips; a key that clashes with the other deck goes gray
    readonly property color keyChip: "#ffb547"
    function deckLetter(group) {
        return group === "[Channel2]" ? "B" : group === "[Channel3]" ? "C" : group === "[Channel4]" ? "D" : "A";
    }

    // Stems: voice, beat and music (bass and instruments)
    readonly property color stemVocals: "#ff6fb5"
    readonly property color stemDrums: "#ffe066"
    readonly property color stemMusic: "#4d8bff"

    // Sections of a track on the overview
    readonly property color sectionBreak: "#ffb547"
    readonly property color sectionPause: "#9ca1b8"
    readonly property color sectionDrop: "#ff4d5e"
    readonly property color sectionIntro: "#2bd67b"

    // Hot cues: one color per number, the same on both decks, in the Cutlab
    // palette. A cue keeps its own color when it has one (picked by hand or
    // imported from Serato or Rekordbox); the automatic colors of the old
    // palette are replaced by these.
    readonly property var hotcueColors: ["#ff4d5e", "#ffb547", "#2bd67b", "#00c2d8", "#8b85ff", "#ff6fb5", "#ffe066", "#4d8bff"]
    // The automatic hot cue colors of the original palette
    readonly property var autoCueColors: [0xc50a08, 0x32be44, 0x42d4f4, 0xf8d200, 0x0044ff, 0xaf00cc, 0xfca6d7, 0xf2f2ff]
    function hotcueColor(number) {
        return hotcueColors[(Math.max(1, number) - 1) % hotcueColors.length];
    }
    // Whether the color stored in a cue is only the automatic one
    function isAutoCueColor(value) {
        const rgb = Math.round(value);
        return !(rgb >= 0) || autoCueColors.indexOf(rgb) >= 0;
    }
    // The color to show for hot cue `number` holding `value` (its
    // hotcue_N_color control)
    function cueColor(number, value) {
        if (isAutoCueColor(value)) {
            return hotcueColor(number);
        }
        return "#" + Math.round(value).toString(16).padStart(6, "0");
    }
    function hexToRgb(color) {
        return parseInt(String(color).replace("#", "").slice(-6), 16);
    }

    // The colors of the scrolling waveforms:
    //  - "rgb": bass, mids and highs in their own vivid colors, so kicks,
    //    voices and hats read apart (the default)
    //  - "deck": in the color of each deck
    //  - "config": the colors of the type picked in the settings
    // The type of waveform always comes from the settings.
    property string waveColors: {
        const stored = Mixxx.Application.configValue("[Cutlab]", "wave_colors", "rgb");
        return stored === "cutlab" ? "deck" : (["rgb", "deck", "config"].indexOf(stored) >= 0 ? stored : "rgb");
    }
    function setWaveColors(colors) {
        waveColors = colors;
        Mixxx.Application.setConfigValue("[Cutlab]", "wave_colors", colors);
    }
    readonly property color waveLow: "#ff3366"
    readonly property color waveMid: "#2ee88f"
    readonly property color waveHigh: "#45b8ff"

    // Panels and the library slide in with this curve
    readonly property int motion: 180

    // Key colors of the Camelot wheel, as shown next to the key of a track
    function keyColor(key) {
        const colors = {
            "1": "#55e0c8", "2": "#78e08f", "3": "#a4e05a", "4": "#d4d94e",
            "5": "#f5b74a", "6": "#ff8f52", "7": "#ff6f6f", "8": "#ff6fb0",
            "9": "#e07ae6", "10": "#b48cff", "11": "#7aa4ff", "12": "#54c8f0"
        };
        const match = (key || "").toString().match(/^(\d{1,2})[ABdm]$/);
        if (match && colors[match[1]]) {
            return colors[match[1]];
        }
        // Musical notation: spread the 12 notes over the wheel
        const notes = ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"];
        const name = (key || "").toString().replace(/m$/, "");
        const i = notes.indexOf(name);
        return i >= 0 ? colors[String(i + 1)] : textSecondary;
    }

    // How a track goes with a deck: the tempo gap and the key relation,
    // like "−1% · misma tonalidad" or "+12% · choca"
    function keyRelation(a, b) {
        const pa = /^(\d{1,2})([AB])$/.exec(a || "");
        const pb = /^(\d{1,2})([AB])$/.exec(b || "");
        if (!pa || !pb) {
            return "";
        }
        const na = parseInt(pa[1]);
        const nb = parseInt(pb[1]);
        const step = Math.min((na - nb + 12) % 12, (nb - na + 12) % 12);
        if (pa[2] === pb[2]) {
            return step === 0 ? "same" : (step === 1 ? "near" : "clash");
        }
        return step === 0 ? "relative" : "clash";
    }
    function matchWith(bpm, key, deckBpm, deckKey) {
        const parts = [];
        let clash = false;
        if (bpm > 0 && deckBpm > 0) {
            // Half and double time count as the same tempo
            let ratio = bpm / deckBpm;
            if (ratio > 1.6) {
                ratio /= 2;
            } else if (ratio < 0.625) {
                ratio *= 2;
            }
            const percent = Math.round((ratio - 1) * 100);
            parts.push(Math.abs(percent) <= 0 ? qsTr("BPM ok") : (percent > 0 ? "+" : "−") + Math.abs(percent) + "%");
            clash = Math.abs(percent) > 8;
        }
        const relation = keyRelation(key, deckKey);
        if (relation === "same") {
            parts.push(qsTr("misma tonalidad"));
        } else if (relation === "near") {
            parts.push(qsTr("tonalidad vecina"));
        } else if (relation === "relative") {
            parts.push(qsTr("relativa"));
        } else if (relation === "clash") {
            parts.push(qsTr("choca"));
            clash = true;
        }
        return {text: parts.join(" · "), clash: clash};
    }

    // Beats as a DJ says them: 1/4, 1/2, 1, 4…
    function beatsText(beats) {
        if (beats <= 0) {
            return "—";
        }
        return beats >= 1 ? String(Math.round(beats * 100) / 100) : "1/" + Math.round(1 / beats);
    }
    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0) {
            seconds = 0;
        }
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
