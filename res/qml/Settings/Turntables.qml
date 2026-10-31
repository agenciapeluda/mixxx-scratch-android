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

    signal devicesChanged

    label: qsTr("Turntables & Crossfader")

    // The scope of the timecode needs the signal quality reports
    Mixxx.ControlProxy {
        id: showSignalQuality

        group: "[VinylControl]"
        key: "show_signal_quality"
    }
    Component.onCompleted: {
        if (Mixxx.Application.configValue("[VinylControl]", "show_signal_quality", "0") !== "1") {
            Mixxx.Application.setConfigValue("[VinylControl]", "show_signal_quality", "1");
        }
        showSignalQuality.value = 1;
    }

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
                subtitle: qsTr("Choose the sound card input of each turntable here (USB cards appear as \"directo\"), pick your timecode and turn on DVS on the deck. Start in REL mode.")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Skin.Button {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 260
                        text: qsTr("Find USB sound cards")

                        onClicked: {
                            usbStatus.text = qsTr("Reopening the sound cards…");
                            Mixxx.SoundManager.useAndroidAudioForUsbDevices();
                        }
                    }
                    Text {
                        id: usbStatus

                        Layout.fillWidth: true
                        color: "#969696"
                        font.pixelSize: 11
                        text: qsTr("If your sound card (EP-136, mixer…) is not in the list, tap here. If it still is missing, close and open the app.")
                        wrapMode: Text.WordWrap
                    }
                    Connections {
                        function onCommitted(error) {
                            usbStatus.text = error ? error : qsTr("Done: choose the input of each deck below.");
                            root.devicesChanged();
                        }

                        target: Mixxx.SoundManager
                    }
                }

                // What reaches each input of the USB sound card: shows which
                // pair carries the turntable before choosing it below
                ColumnLayout {
                    id: usbInputs

                    property real lastBlocks: 0
                    property bool receiving: false

                    Layout.fillWidth: true
                    spacing: 6

                    Mixxx.ControlProxy {
                        id: usbBlocks

                        group: "[Cutlab]"
                        key: "usb_in_blocks"
                    }
                    Mixxx.ControlProxy {
                        id: usbChannels

                        group: "[Cutlab]"
                        key: "usb_in_channels"
                    }
                    Timer {
                        interval: 1000
                        repeat: true
                        running: root.visible
                        triggeredOnStart: true
                        onTriggered: {
                            usbInputs.receiving = usbBlocks.value !== usbInputs.lastBlocks;
                            usbInputs.lastBlocks = usbBlocks.value;
                        }
                    }

                    Text {
                        color: "#969696"
                        font.pixelSize: 12
                        text: qsTr("Inputs of the USB sound card")
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: 8

                            ColumnLayout {
                                id: meter

                                required property int index

                                Layout.preferredWidth: 34
                                spacing: 3
                                opacity: meter.index < usbChannels.value || !usbInputs.receiving ? 1 : 0.3

                                Mixxx.ControlProxy {
                                    id: peak

                                    group: "[Cutlab]"
                                    key: `usb_in_peak_${meter.index + 1}`
                                }

                                Rectangle {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 70
                                    Layout.alignment: Qt.AlignHCenter
                                    radius: 4
                                    color: "#0e0e0e"
                                    border.color: "#343434"

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width - 4
                                        anchors.bottomMargin: 2
                                        radius: 3
                                        // A dB scale, -60 dB at the bottom
                                        height: (parent.height - 4) * Math.max(0, Math.min(1, 1 + 20 * Math.log(Math.max(peak.value, 1e-6)) / Math.LN10 / 60))
                                        color: peak.value > 0.9 ? "#ff453a" : (peak.value > 0.5 ? "#ff9f0a" : "#34c759")
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: "#bebebe"
                                    font.pixelSize: 11
                                    text: String(meter.index + 1)
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            color: usbInputs.receiving ? "#34c759" : "#ff9f0a"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            text: usbInputs.receiving
                                ? qsTr("Audio is arriving from the card (%1 channels). Play the record: the pair that moves is the one of the turntable, choose it below.").arg(Math.round(usbChannels.value))
                                : qsTr("No audio from the card. Choose the card as the input of a deck below (the \"direct\" one), or tap Find USB sound cards.")
                        }
                    }
                }

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
                            color: deckRow.index ? "#ff7a3d" : "#584fff"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: qsTr("Deck %1").arg(deckRow.index + 1)
                        }
                        Text {
                            color: "#969696"
                            font.pixelSize: 12
                            text: qsTr("Audio input")
                        }
                        Skin.ComboBox {
                            id: inputBox

                            property var routes: []

                            function refresh() {
                                const list = [{
                                        "label": qsTr("Choose the sound card and channels…"),
                                        "device": null,
                                        "group": 0
                                    }];
                                const devices = Mixxx.SoundManager.availableInputDevices(Mixxx.SoundManager.getAPI());
                                for (let d = 0; d < devices.length; d++) {
                                    const device = devices[d];
                                    for (let g = 0; g + 1 < Math.max(2, device.channelCount); g += 2) {
                                        list.push({
                                            "label": `${device.displayName} · ${qsTr("channels")} ${g + 1}-${g + 2}`,
                                            "device": device,
                                            "group": g
                                        });
                                    }
                                }
                                list.push({
                                    "label": qsTr("No input (turn DVS off for this deck)"),
                                    "device": null,
                                    "group": -1
                                });
                                routes = list;
                                model = list.map(r => r.label);
                                currentIndex = currentRouteIndex();
                            }
                            // The entry of the input the deck uses now, so the
                            // box shows it instead of the placeholder
                            function currentRouteIndex() {
                                const name = Mixxx.SoundManager.vinylControlInputName(deckRow.index);
                                const base = Mixxx.SoundManager.vinylControlInputChannelGroup(deckRow.index);
                                if (name === "") {
                                    return 0;
                                }
                                for (let i = 1; i < routes.length; i++) {
                                    const device = routes[i].device;
                                    if (device && (device.displayName === name || device.name === name) && routes[i].group === base) {
                                        return i;
                                    }
                                }
                                return 0;
                            }

                            Layout.columnSpan: 3
                            Layout.fillWidth: true

                            Component.onCompleted: refresh()

                            Connections {
                                function onDevicesChanged() {
                                    inputBox.refresh();
                                }

                                target: root
                            }
                            onActivated: {
                                const route = routes[currentIndex];
                                if (currentIndex === 0) {
                                    return;
                                }
                                Mixxx.SoundManager.setVinylControlInput(route.device, Math.max(0, route.group), deckRow.index);
                                currentRoute.text = route.group < 0 ? qsTr("Not routed") : route.label;
                                // Choosing an input means using it: DVS on
                                // for this deck, off with "No input"
                                dvsEnabled.value = route.group < 0 ? 0 : 1;
                            }
                        }
                        Item {
                            width: 1
                        }
                        Text {
                            id: currentRoute

                            Layout.columnSpan: 3
                            Layout.fillWidth: true
                            color: text === qsTr("Not routed") ? "#ff8f99" : "#6fe3a4"
                            font.pixelSize: 11
                            text: {
                                const name = Mixxx.SoundManager.vinylControlInputName(deckRow.index);
                                const base = Mixxx.SoundManager.vinylControlInputChannelGroup(deckRow.index);
                                return name === "" ? qsTr("Not routed") : `${name} · ${qsTr("channels")} ${base + 1}-${base + 2}`;
                            }
                        }
                        Text {
                            color: "#969696"
                            font.pixelSize: 12
                            text: qsTr("DVS")
                        }
                        RowLayout {
                            Layout.columnSpan: 3
                            spacing: 12

                            Skin.Button {
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 150
                                activeColor: "#2bd67b"
                                highlight: dvsEnabled.value > 0
                                text: dvsEnabled.value > 0 ? qsTr("DVS on") : qsTr("DVS off")
                                onClicked: dvsEnabled.value = dvsEnabled.value > 0 ? 0 : 1
                            }
                            Text {
                                Layout.fillWidth: true
                                color: "#969696"
                                font.pixelSize: 12
                                text: qsTr("With DVS on, the turntable moves this deck. It is the same as the DVS button next to the deck.")
                                wrapMode: Text.WordWrap
                            }

                            Mixxx.ControlProxy {
                                id: dvsEnabled

                                group: deckRow.group
                                key: "vinylcontrol_enabled"
                            }
                        }
                        Text {
                            color: "#969696"
                            font.pixelSize: 12
                            text: qsTr("Signal")
                        }
                        RowLayout {
                            Layout.columnSpan: 3
                            spacing: 14

                            Rectangle {
                                Layout.preferredHeight: 120
                                Layout.preferredWidth: 120
                                border.color: "#2c2c2c"
                                color: "#0e0e0e"
                                radius: 10

                                Mixxx.VinylSignalQuality {
                                    active: root.visible
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    group: deckRow.group
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                color: ["#969696", "#2bd67b", "#f5b544", "#ff5d6c"][Math.max(0, Math.min(3, Math.round(vinylStatus.value)))]
                                font.pixelSize: 12
                                text: [qsTr("DVS is off on this deck: turn it on with the DVS button of the deck."),
                                    qsTr("DVS on and the timecode is read well."),
                                    qsTr("Weak or unstable timecode: check the level and the needle."),
                                    qsTr("No timecode: check the input channels and the timecode type.")][Math.max(0, Math.min(3, Math.round(vinylStatus.value)))] + "\n" + qsTr("Play the record: a clean ring in the box means the timecode is read. Flat or empty: wrong channels or no signal. A messy cloud: wrong timecode type or level.")
                                wrapMode: Text.WordWrap

                                Mixxx.ControlProxy {
                                    id: vinylStatus

                                    group: deckRow.group
                                    key: "vinylcontrol_status"
                                }
                            }
                        }
                        Text {
                            color: "#969696"
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
                            color: "#969696"
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
                            color: "#969696"
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
                        color: "#969696"
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
                        color: "#969696"
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
        border.color: "#2c2c2c"
        border.width: 1
        color: "#171717"
        implicitHeight: cardColumn.implicitHeight + 32
        radius: 12

        ColumnLayout {
            id: cardColumn

            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                color: "#ececec"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                text: card.title
            }
            Text {
                Layout.fillWidth: true
                color: "#969696"
                font.pixelSize: 11
                text: card.subtitle
                visible: text !== ""
                wrapMode: Text.WordWrap
            }
        }
    }
}
