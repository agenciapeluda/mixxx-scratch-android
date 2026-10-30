import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import ".." as Skin
import "." as Setting
import "../Theme"

// Cutlab: vinyl control (DVS) and crossfader settings for Android.
// The values live in mixxx.cfg with the same keys as the desktop
// preferences, so a config moved between desktop and Android keeps them.
Category {
    id: root

    // Must match MIXXX_VINYL_* in src/vinylcontrol/defs_vinylcontrol.h
    readonly property var timecodes: [
        "Serato CV02 Vinyl, Side A",
        "Serato CV02 Vinyl, Side B",
        "Serato CD",
        "Algoriddim djay PRO AI 12\", Side A",
        "Algoriddim djay PRO AI 12\", Side B (no stem support)",
        "Traktor Scratch MK1 Vinyl, Side A",
        "Traktor Scratch MK1 Vinyl, Side B",
        "Traktor Scratch MK2 Vinyl, Side A (beta)",
        "Traktor Scratch MK2 Vinyl, Side B (beta)",
        "Traktor Scratch MK2 CD (beta)",
        "Pioneer RekordBox DVS Control Vinyl, Side A",
        "Pioneer RekordBox DVS Control Vinyl, Side B",
        "MixVibes DVS V2 Vinyl",
        "MixVibes 7\""
    ]
    readonly property var speeds: ["33.3 RPM", "45 RPM"]
    // Crossfader curves: [label, mode (0 additive, 1 constant power), curve]
    readonly property var curves: [
        [qsTr("Smooth"), 1, 1.0],
        [qsTr("Mix"), 0, 2.0],
        [qsTr("Scratch"), 0, 150.0],
        [qsTr("Hard cut"), 0, 1000.0]
    ]

    function cfg(group, key, fallback) {
        return Mixxx.Application.configValue(group, key, fallback);
    }

    function curveIndex() {
        const mode = parseInt(cfg("[Mixer Profile]", "xFaderMode", "0"));
        const curve = parseFloat(cfg("[Mixer Profile]", "xFaderCurve", "1.0"));
        let best = 0;
        let bestDiff = Number.MAX_VALUE;
        for (let i = 0; i < curves.length; i++) {
            const diff = Math.abs(Math.log(curves[i][2]) - Math.log(curve)) + (curves[i][1] === mode ? 0 : 0.5);
            if (diff < bestDiff) {
                bestDiff = diff;
                best = i;
            }
        }
        return best;
    }

    function applyCurve(index) {
        const c = curves[index];
        xfaderMode.value = c[1];
        xfaderCurve.value = c[2];
        Mixxx.Application.setConfigValue("[Mixer Profile]", "xFaderMode", String(c[1]));
        Mixxx.Application.setConfigValue("[Mixer Profile]", "xFaderCurve", String(c[2]));
    }

    label: qsTr("Turntables & Crossfader")

    Mixxx.ControlProxy {
        id: xfaderMode

        group: "[Mixer Profile]"
        key: "xFaderMode"
    }
    Mixxx.ControlProxy {
        id: xfaderCurve

        group: "[Mixer Profile]"
        key: "xFaderCurve"
    }
    Mixxx.ControlProxy {
        id: xfaderReverse

        group: "[Mixer Profile]"
        key: "xFaderReverse"
    }

    Flickable {
        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: column.implicitHeight + 32

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.margins: 16
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 14

            // ---------------- Vinyl control ----------------
            Card {
                title: qsTr("Vinyl control (DVS)")
                subtitle: qsTr("Route the turntable in Audio & Outputs (Deck → Vinyl Control) and turn on DVS on the deck. Start in REL mode.")

                Repeater {
                    model: 2

                    delegate: GridLayout {
                        id: deckRow

                        required property int index
                        readonly property string group: `[Channel${index + 1}]`

                        Layout.fillWidth: true
                        columnSpacing: 12
                        columns: 4
                        rowSpacing: 6

                        Text {
                            Layout.columnSpan: 4
                            Layout.topMargin: deckRow.index ? 8 : 0
                            color: deckRow.index ? "#ff7a3d" : "#4f7cff"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: qsTr("Deck %1").arg(deckRow.index + 1)
                        }
                        Text {
                            color: "#8a91a3"
                            font.pixelSize: 12
                            text: qsTr("Timecode")
                        }
                        Skin.ComboBox {
                            id: timecodeBox

                            Layout.columnSpan: 3
                            Layout.fillWidth: true
                            currentIndex: Math.max(0, root.timecodes.indexOf(root.cfg(deckRow.group, "vinylcontrol_vinyl_type", root.timecodes[0])))
                            model: root.timecodes

                            onActivated: {
                                Mixxx.Application.setConfigValue(deckRow.group, "vinylcontrol_vinyl_type", root.timecodes[currentIndex]);
                                Mixxx.Application.reloadVinylControlConfig();
                            }
                        }
                        Text {
                            color: "#8a91a3"
                            font.pixelSize: 12
                            text: qsTr("Speed")
                        }
                        Setting.RatioChoice {
                            options: root.speeds
                            selected: root.cfg(deckRow.group, "vinylcontrol_speed_type", root.speeds[0]) === root.speeds[1] ? root.speeds[1] : root.speeds[0]

                            onSelectedChanged: {
                                if (selected !== root.cfg(deckRow.group, "vinylcontrol_speed_type", root.speeds[0])) {
                                    Mixxx.Application.setConfigValue(deckRow.group, "vinylcontrol_speed_type", selected);
                                    Mixxx.Application.reloadVinylControlConfig();
                                }
                            }
                        }
                        Text {
                            color: "#8a91a3"
                            font.pixelSize: 12
                            text: qsTr("Lead-in (s)")
                        }
                        SpinBox {
                            from: 0
                            to: 60
                            value: parseInt(root.cfg(deckRow.group, "vinylcontrol_lead_in_time", "0"))

                            onValueModified: {
                                Mixxx.Application.setConfigValue(deckRow.group, "vinylcontrol_lead_in_time", String(value));
                                Mixxx.Application.reloadVinylControlConfig();
                            }
                        }
                    }
                }
            }

            // ---------------- Crossfader ----------------
            Card {
                title: qsTr("Crossfader")
                subtitle: qsTr("Scratch and Hard cut open the channel fully in the first millimetres, like a battle mixer.")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        Layout.preferredWidth: 90
                        color: "#8a91a3"
                        font.pixelSize: 12
                        text: qsTr("Curve")
                    }
                    Setting.RatioChoice {
                        id: curveChoice

                        options: root.curves.map(c => c[0])
                        selected: root.curves[root.curveIndex()][0]

                        onSelectedChanged: {
                            const i = options.indexOf(selected);
                            if (i >= 0 && i !== root.curveIndex()) {
                                root.applyCurve(i);
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        Layout.preferredWidth: 90
                        color: "#8a91a3"
                        font.pixelSize: 12
                        text: qsTr("Hamster")
                    }
                    Setting.RatioChoice {
                        options: [qsTr("off"), qsTr("on")]
                        selected: xfaderReverse.value > 0 ? options[1] : options[0]

                        onSelectedChanged: {
                            const on = selected === options[1];
                            if (on !== (xfaderReverse.value > 0)) {
                                xfaderReverse.value = on ? 1 : 0;
                                Mixxx.Application.setConfigValue("[Mixer Profile]", "xFaderReverse", on ? "1" : "0");
                            }
                        }
                    }
                }
            }
        }
    }

    component Card: Rectangle {
        id: card

        default property alias content: cardColumn.data
        property string subtitle
        property string title

        Layout.fillWidth: true
        border.color: "#232836"
        border.width: 1
        color: "#12151c"
        implicitHeight: cardColumn.implicitHeight + 32
        radius: 12

        ColumnLayout {
            id: cardColumn

            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                color: "#e8eaf0"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                text: card.title
            }
            Text {
                Layout.fillWidth: true
                color: "#8a91a3"
                font.pixelSize: 11
                text: card.subtitle
                visible: text !== ""
                wrapMode: Text.WordWrap
            }
        }
    }
}
