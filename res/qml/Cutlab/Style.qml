pragma Singleton
import QtQuick

// Colors of the Cutlab layout: neutral grays, the Cutlab indigo as accent,
// green for what is playing and a red playhead.
QtObject {
    readonly property string font: "Roboto"

    readonly property color black: "#000000"
    readonly property color topBar: "#0b0b0c"
    readonly property color background: "#2b2b2d"
    readonly property color panel: "#363638"
    readonly property color panelDark: "#29292b"
    readonly property color divider: "#161617"
    readonly property color button: "#262628"
    readonly property color buttonPressed: "#47474a"
    readonly property color buttonBorder: "#4a4a4d"
    readonly property color track: "#1e1e20"
    readonly property color tick: "#505054"

    readonly property color text: "#ffffff"
    readonly property color textSecondary: "#9d9da3"
    readonly property color textDim: "#6c6c72"

    readonly property color accent: "#635bff"
    // The accent for text and icons on dark grays, easier to read
    readonly property color accentText: "#8b85ff"
    readonly property color accentDark: "#2b2766"
    readonly property color play: "#34c759"
    readonly property color cue: "#ff9f0a"
    readonly property color playhead: "#ff2d2d"
    readonly property color loop: "#30d158"
    readonly property color danger: "#ff453a"

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
