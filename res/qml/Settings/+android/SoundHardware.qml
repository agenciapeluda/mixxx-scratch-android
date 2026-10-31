import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Mixxx 1.0 as Mixxx
import ".." as Skin
import "../Theme"

Category {
    id: root

    property bool committing: false
    property bool hasChanges: router.hasChanges
    property string activePreset: ""
    // True once the user tapped a preset in this session. Only then are the
    // outputs rebuilt on save; otherwise the configured routing is kept.
    property bool presetChosen: false
    // Warning or error about the selected preset, shown below the presets
    property string presetMessage: ""
    property bool presetError: false
    property bool loading: false
    property bool showAdvancedRouter: false

    // The Android enumerator suffixes device names with their type, e.g.
    // "TB331FC: Speaker", "DDJ-400: USB" or "Buds: Bluetooth".
    function outputDeviceKinds() {
        let kinds = {
            speaker: null,
            wired: null,
            bluetooth: null,
            usb: null,
            other: null
        };
        let devices = Mixxx.SoundManager.availableOutputDevices(soundApi.selected) || [];
        for (let d of devices) {
            let n = d.displayName || "";
            if (n.endsWith(": USB")) {
                // Prefer the device exposing the most channels (a DJ
                // controller rather than e.g. a USB headset)
                if (!kinds.usb || d.channelCount > kinds.usb.channelCount)
                    kinds.usb = d;
            } else if (n.endsWith(": Speaker") || n.endsWith(": Altavoz")) {
                kinds.speaker = kinds.speaker || d;
            } else if (n.endsWith(": Wired headphones") || n.endsWith(": Wired headset")) {
                kinds.wired = kinds.wired || d;
            } else if (n.endsWith(": Bluetooth")) {
                kinds.bluetooth = kinds.bluetooth || d;
            } else if (d.channelCount >= 4) {
                kinds.usb = kinds.usb || d;
            } else {
                kinds.other = kinds.other || d;
            }
        }
        return kinds;
    }

    function isUsbDevice(device) {
        return !!device && ((device.displayName || "").endsWith(": USB") || device.channelCount >= 4);
    }

    // Returns the outputs a preset needs, without touching anything:
    // {outputs: [{device, type, channel}], headSplit, syncBuffers, sampleRate, message, error}
    // Output types: 0 = Main, 1 = Headphones
    function presetPlan(presetType) {
        let k = outputDeviceKinds();
        let plan = {
            outputs: [],
            headSplit: 0,
            syncBuffers: -1,
            sampleRate: 0,
            message: "",
            error: false
        };
        if (presetType === "single") {
            let dev = k.bluetooth || k.wired || k.speaker || k.other;
            if (!dev) {
                plan.error = true;
                plan.message = qsTr("No audio output was found.");
                return plan;
            }
            plan.outputs.push({ device: dev, type: 0, channel: 0 });
            plan.message = qsTr("Main output through: %1").arg(dev.displayName);
        } else if (presetType === "splitter") {
            // Mixxx's head split mode: left = CUE (mono), right = Master (mono)
            let dev = k.wired || k.speaker || k.other;
            if (!dev) {
                plan.error = true;
                plan.message = qsTr("The headphone output of the tablet was not found.");
                return plan;
            }
            plan.outputs.push({ device: dev, type: 1, channel: 0 });
            plan.headSplit = 1;
            plan.message = qsTr("Left channel = CUE (pre-listening), right channel = Main, through: %1").arg(dev.displayName);
        } else if (presetType === "controller") {
            if (!k.usb) {
                plan.error = true;
                plan.message = qsTr("The USB sound card of the controller is not detected. Connect it, wait a few seconds and open the settings again.");
                return plan;
            }
            plan.outputs.push({ device: k.usb, type: 0, channel: 0 });
            plan.sampleRate = 44100;
            if (k.usb.channelCount >= 4) {
                plan.outputs.push({ device: k.usb, type: 1, channel: 2 });
                plan.message = qsTr("Main → channels 1-2 (RCA) and CUE → channels 3-4 (headphones) of %1").arg(k.usb.displayName);
            } else {
                plan.message = qsTr("Android only exposes %1 channels of %2: the main output will play through the controller, but its headphones will not receive CUE. Use the splitter mode for pre-listening.").arg(k.usb.channelCount).arg(k.usb.displayName);
            }
        } else if (presetType === "hybrid") {
            let mainDev = k.speaker || k.wired || k.bluetooth || k.other;
            if (!k.usb || k.usb.channelCount < 4) {
                plan.error = true;
                plan.message = k.usb
                    ? qsTr("Android only exposes %1 channels of %2, so its headphones (channels 3-4) are not available.").arg(k.usb.channelCount).arg(k.usb.displayName)
                    : qsTr("The USB sound card of the controller is not detected.");
                return plan;
            }
            if (!mainDev) {
                plan.error = true;
                plan.message = qsTr("The speaker of the tablet was not found.");
                return plan;
            }
            plan.outputs.push({ device: mainDev, type: 0, channel: 0 });
            plan.outputs.push({ device: k.usb, type: 1, channel: 2 });
            // Two sound cards with independent clocks need drift compensation
            plan.syncBuffers = 2;
            plan.message = qsTr("Main output through %1 and CUE through the headphones of %2. Using two sound cards may cause slight clicks on the CUE.").arg(mainDev.displayName).arg(k.usb.displayName);
        }
        return plan;
    }

    function applyPreset(presetType) {
        let plan = presetPlan(presetType);
        root.activePreset = presetType;
        root.presetChosen = true;
        root.presetMessage = plan.message;
        root.presetError = plan.error;
        // Only the form is updated here; the engine changes on save
        mainMixEnabled.selected = "on";
        mainOutputMode.selected = "stereo";
        if (plan.sampleRate > 0) {
            let rate = qsTr("%1 Hz").arg(plan.sampleRate);
            if (sampleRate.options.indexOf(rate) !== -1) {
                sampleRate.selected = rate;
            }
        }
        if (plan.syncBuffers >= 0) {
            router.multiSoundcard.selected = router.multiSoundcard.options[plan.syncBuffers];
        }
        root.hasChanges = true;
    }

    function load() {
        const manager = Mixxx.SoundManager;
        // The engine may have rerouted the outputs (DJ controller plugged in)
        manager.reload();
        root.loading = true;
        root.presetChosen = false;
        root.presetMessage = "";
        root.presetError = false;
        mainMixEnabled.selected = mainMixEnabled.options[mainEnabled.value ? 0 : 1];
        mainOutputMode.selected = mainOutputMode.options[monoMix.value ? 0 : 1];
        soundClock.selected = soundClock.options[manager.getForceNetworkClock() ? 1 : 0];
        sampleRate.update(manager.getAPI());
        sampleRate.selected = qsTr("%1 Hz").arg(manager.getSampleRate());
        audioBuffer.currentIndex = manager.getAudioBufferSizeIndex() - 1;
        microphoneMonitorMode.enabled = manager.hasMicInputs();
        microphoneMonitorMode.currentIndex = micMonitorMode.value;
        soundApi.options = manager.getHostAPIList();
        let curApi = manager.getAPI();
        if ((!curApi || curApi === "ALSA") && soundApi.options.indexOf("Android Oboe") !== -1) {
            curApi = "Android Oboe";
            manager.setAPI(curApi);
        }
        soundApi.selected = curApi;
        keylock.update();
        keylock.selected = keylock.options[manager.getKeylockEngine()];
        usbDirectMode.selected = usbDirectMode.options[Math.max(0, Math.min(2, Mixxx.MobileAudio.getAndroidUsbDirectMode()))];

        // Detect current preset by analyzing real SoundManager output connections
        let detected = "custom";
        try {
            let devices = manager.availableOutputDevices(soundApi.selected);
            let mainDevs = [];
            let headDev = null;
            let headChannel = 0;
            let otherOutputs = false;

            for (let d of devices) {
                let conns = d.connections(manager);
                if (!conns) continue;
                for (let c of conns) {
                    if (c.type === 0) { // Main
                        mainDevs.push(d);
                    } else if (c.type === 1) { // Headphones (PFL / Preescucha)
                        headDev = d;
                        headChannel = c.channelGroup;
                    } else {
                        otherOutputs = true;
                    }
                }
            }

            let mainDev = mainDevs.length === 1 ? mainDevs[0] : null;
            if (otherOutputs || mainDevs.length > 1) {
                detected = "custom";
            } else if (!mainDev && headDev && headSplit.value > 0) {
                detected = "splitter";
            } else if (mainDev && !headDev) {
                detected = isUsbDevice(mainDev) ? "controller" : "single";
            } else if (mainDev && headDev && isUsbDevice(headDev) && headChannel >= 2) {
                detected = mainDev === headDev ? "controller" : "hybrid";
            } else if (!mainDev && !headDev) {
                detected = "";
            }
        } catch (e) {
            console.error("Error detecting active audio preset:", e);
        }
        root.activePreset = detected;

        // Router
        router.multiSoundcard.selected = router.multiSoundcard.options[manager.getSyncBuffers()];
        router.update(manager.getAPI());

        // Delays
        mainDelayLabel.enabled = mainEnabled.value;
        mainDelaySlider.enabled = mainEnabled.value;
        mainDelaySlider.value = mainDelay.value;
        boothDelayLabel.enabled = boothEnabled.value;
        boothDelaySlider.enabled = boothEnabled.value;
        boothDelaySlider.value = boothDelay.value;
        headphoneDelayLabel.enabled = headEnabled.value;
        headphoneDelaySlider.enabled = headEnabled.value;
        headphoneDelaySlider.value = headDelay.value;

        root.hasChanges = Qt.binding(function () {
            return router.hasChanges;
        });
        root.loading = false;
    }

    function save() {
        const manager = Mixxx.SoundManager;
        mainEnabled.value = mainMixEnabled.selected === "on" ? 1 : 0;
        monoMix.value = !mainOutputMode.options.indexOf(mainOutputMode.selected);
        manager.setForceNetworkClock(soundClock.options[1] == soundClock.selected);
        manager.setSampleRate(parseInt(sampleRate.selected));
        manager.setAudioBufferSizeIndex(audioBuffer.currentIndex + 1);
        micMonitorMode.value = microphoneMonitorMode.currentIndex;
        manager.setAPI(soundApi.selected);
        manager.setKeylockEngine(keylock.options.indexOf(keylock.selected));
        Mixxx.MobileAudio.setAndroidUsbDirectMode(Math.max(0, usbDirectMode.options.indexOf(usbDirectMode.selected)));

        // Router
        manager.setSyncBuffers(router.multiSoundcard.options.indexOf(router.multiSoundcard.selected));

        let connectionsHandler = (connections, device) => {
            for (let channel of Object.keys(connections)) {
                let connection = connections[channel];
                let type;
                let index = 0;
                let isOutput = true;
                if (connection.source.entity.name == "Mixer") {
                    switch (connection.source.address) {
                    case "Main":
                        type = 0;
                        break;
                    case "PFL":
                        type = 1;
                        break;
                    case "Booth":
                        type = 2;
                        break;
                    case "Left Bus":
                    case "Center Bus":
                    case "Right Bus":
                        index = connection.source.address.startsWith("Left") ? 0 : connection.source.address.startsWith("Right") ? 2 : 1;
                        type = 3;
                        break;
                    default:
                        console.error(`unsupported address: ${connection.source.address}`);
                        continue;
                    }
                } else if (connection.sink.entity.name == "Mixer") {
                    isOutput = false;
                    type = connection.sink.address == "Auxiliary" ? 7 : 6;
                    index = connection.sink.instance;
                } else if (connection.source.entity.name.startsWith("Deck ") && connection.source.address == "Output") {
                    type = 4;
                    index = parseInt(connection.source.entity.name.split(' ')[1]) - 1;
                } else if (connection.sink.entity.name.startsWith("Deck ")) {
                    isOutput = false;
                    type = connection.source.address == "Output" ? 4 : 5;
                    index = parseInt(connection.sink.entity.name.split(' ')[1]) - 1;
                } else if (connection.sink.entity.name == "Microphone") {
                    isOutput = false;
                    type = 6;
                    index = connection.sink.instance;
                } else if (connection.sink.entity.name == "Auxiliary") {
                    isOutput = false;
                    type = 7;
                    index = connection.sink.instance;
                } else if (connection.sink.entity.name == "RecordBroadcast") {
                    isOutput = false;
                    type = 8;
                    index = connection.sink.instance;
                } else {
                    console.error(`unsupported entity: ${connection.source.entity.name} ${connection.sink.entity.name}`);
                    continue;
                }
                console.log(isOutput ? "addOutput" : "addInput", device, type, channel * 2, index);
                if (isOutput) {
                    manager.addOutput(device, type, channel * 2, index);
                } else {
                    manager.addInput(device, type, channel * 2, index);
                }
            }
        };

        let rebuildFromRouter = () => {
            for (let device of Object.keys(router.outputs)) {
                for (let address of Object.keys(router.outputs[device].gateways)) {
                    let gateway = router.outputs[device].gateways[address];
                    let connections = gateway.node && gateway.node.assignedEdges ? gateway.node.assignedEdges() : {};
                    connectionsHandler(connections, gateway.device);
                }
            }
        };

        // Outputs are only rebuilt when the user picked a preset or edited the
        // matrix; any other change (buffer size, sample rate...) keeps the
        // configured routing untouched.
        const routerEdited = root.showAdvancedRouter && router.hasChanges;
        if (routerEdited) {
            manager.clearOutputs();
            rebuildFromRouter();
            // Respect the manual routing even when a controller is plugged in
            Mixxx.MobileAudio.setAutoRouteController(false);
        } else if (root.presetChosen) {
            // Only the controller preset follows the controller automatically
            Mixxx.MobileAudio.setAutoRouteController(root.activePreset === "controller");
            let plan = presetPlan(root.activePreset);
            if (!plan.error) {
                manager.clearOutputs();
                for (let output of plan.outputs) {
                    manager.addOutput(output.device, output.type, output.channel, 0);
                }
                headSplit.value = plan.headSplit;
                monoMix.value = 0;
            }
        }

        if (routerEdited) {
            manager.clearInputs();
            for (let device of Object.keys(router.inputs)) {
                for (let address of Object.keys(router.inputs[device].gateways)) {
                    let gateway = router.inputs[device].gateways[address];
                    let connections = gateway.node && gateway.node.assignedEdges ? gateway.node.assignedEdges() : {};
                    connectionsHandler(connections, gateway.device);
                }
            }
        }

        mainDelay.value = mainDelaySlider.value;
        boothDelay.value = boothDelaySlider.value;
        headDelay.value = headphoneDelaySlider.value;

        root.committing = true;
        manager.commit();
    }

    label: qsTr("Audio & Outputs")
    tabs: [qsTr("Setup & Outputs"), qsTr("Delays")]

    Component.onCompleted: {
        load();
    }

    Mixxx.ControlProxy {
        id: mainEnabled
        group: "[Master]"
        key: "enabled"
    }
    Mixxx.ControlProxy {
        id: headEnabled
        group: "[Master]"
        key: "headEnabled"
    }
    Mixxx.ControlProxy {
        id: boothEnabled
        group: "[Master]"
        key: "booth_enabled"
    }
    Mixxx.ControlProxy {
        id: mainDelay
        group: "[Master]"
        key: "delay"
    }
    Mixxx.ControlProxy {
        id: headDelay
        group: "[Master]"
        key: "headDelay"
    }
    Mixxx.ControlProxy {
        id: boothDelay
        group: "[Master]"
        key: "boothDelay"
    }
    Mixxx.ControlProxy {
        id: headSplit
        group: "[Master]"
        key: "headSplit"
    }
    Mixxx.ControlProxy {
        id: monoMix
        group: "[Master]"
        key: "mono_mixdown"
    }
    Mixxx.ControlProxy {
        id: micMonitorMode
        group: "[Master]"
        key: "talkover_mix"
    }

    ScrollView {
        id: scrollView
        anchors.bottom: soundAction.top
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            spacing: 16
            width: scrollView.availableWidth

            // ================= PESTAÑA 1: CONFIGURACIÓN & SALIDAS =================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: root.selectedIndex === 0

                // CARD 1: PERFILES DE SALIDA RÁPIDOS (1-TOUCH PRESETS)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: presetsCol.implicitHeight + 28
                    color: "#212121"
                    radius: 12
                    border.color: "#2a2854"
                    border.width: 1

                    ColumnLayout {
                        id: presetsCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: qsTr("Quick audio output profiles")
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: "#908aff"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("Tap to configure automatically")
                                font.pixelSize: 11
                                color: "#969696"
                            }
                        }

                        // 4 Interactive Preset Cards (2x2 Grid)
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 10

                            // Preset 1: Móvil / Bluetooth (Salida simple)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(96, presetCol1.implicitHeight + 20)
                                Layout.fillHeight: true
                                radius: 10
                                color: root.activePreset === "single" ? "#25225b" : (p1Mouse.containsMouse ? "#2c2c2c" : "#232323")
                                border.color: root.activePreset === "single" ? "#4b42f5" : "#414141"
                                border.width: root.activePreset === "single" ? 2 : 1

                                ColumnLayout {
                                    id: presetCol1
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: ""; font.pixelSize: 16 }
                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: qsTr("Phone / Bluetooth")
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: root.activePreset === "single" ? "#ffffff" : "#dbdbdb"
                                        }
                                        Text {
                                            text: root.activePreset === "single" ? qsTr("✓ ACTIVE") : ""
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: "#908aff"
                                        }
                                    }
                                    Text {
                                        text: qsTr("Single stereo output. All sound goes to the tablet speakers or Bluetooth headphones.")
                                        font.pixelSize: 11
                                        color: "#969696"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: p1Mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyPreset("single")
                                }
                            }

                            // Preset 2: Cable Splitter DJ
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(96, presetCol2.implicitHeight + 20)
                                Layout.fillHeight: true
                                radius: 10
                                color: root.activePreset === "splitter" ? "#303030" : (p2Mouse.containsMouse ? "#262626" : "#1c1c1c")
                                border.color: root.activePreset === "splitter" ? "#ff7043" : "#3e3e3e"
                                border.width: root.activePreset === "splitter" ? 2 : 1

                                ColumnLayout {
                                    id: presetCol2
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: ""; font.pixelSize: 16 }
                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: qsTr("DJ splitter cable")
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: root.activePreset === "splitter" ? "#ffffff" : "#dbdbdb"
                                        }
                                        Text {
                                            text: root.activePreset === "splitter" ? qsTr("✓ ACTIVE") : ""
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: "#ffab91"
                                        }
                                    }
                                    Text {
                                        text: qsTr("Splitter cable on the jack: left channel = CUE (your headphones) and right channel = Main (speaker), both in mono.")
                                        font.pixelSize: 11
                                        color: "#bebebe"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: p2Mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyPreset("splitter")
                                }
                            }

                            // Preset 3: Controladora DJ / 4 Canales
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(96, presetCol3.implicitHeight + 20)
                                Layout.fillHeight: true
                                radius: 10
                                color: root.activePreset === "controller" ? "#1b3a24" : (p3Mouse.containsMouse ? "#242424" : "#1c1c1c")
                                border.color: root.activePreset === "controller" ? "#66bb6a" : "#3d3d3d"
                                border.width: root.activePreset === "controller" ? 2 : 1

                                ColumnLayout {
                                    id: presetCol3
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: ""; font.pixelSize: 16 }
                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: qsTr("DJ controller (RCA + headphones)")
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: root.activePreset === "controller" ? "#ffffff" : "#dbdbdb"
                                        }
                                        Text {
                                            text: root.activePreset === "controller" ? qsTr("✓ ACTIVE") : ""
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: "#81c784"
                                        }
                                    }
                                    Text {
                                        text: qsTr("Pro audio: channels 1-2 to the main RCA output (speakers) and channels 3-4 to the headphone jack of the controller.")
                                        font.pixelSize: 11
                                        color: "#a5d6a7"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: p3Mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyPreset("controller")
                                }
                            }

                            // Preset 4: Híbrido (Tablet Master + Auriculares Mesa)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(96, presetCol4.implicitHeight + 20)
                                Layout.fillHeight: true
                                radius: 10
                                color: root.activePreset === "hybrid" ? "#211b92" : (p4Mouse.containsMouse ? "#282828" : "#1d1d1d")
                                border.color: root.activePreset === "hybrid" ? "#8e88ff" : "#2d27a0"
                                border.width: root.activePreset === "hybrid" ? 2 : 1

                                ColumnLayout {
                                    id: presetCol4
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: ""; font.pixelSize: 16 }
                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: qsTr("Tablet + controller headphones (hybrid)")
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: root.activePreset === "hybrid" ? "#ffffff" : "#dbdbdb"
                                        }
                                        Text {
                                            text: root.activePreset === "hybrid" ? qsTr("✓ ACTIVE") : ""
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: "#8e88ff"
                                        }
                                    }
                                    Text {
                                        text: qsTr("Main output through the tablet speakers and CUE pre-listening through the headphones (channels 3-4) of the controller.")
                                        font.pixelSize: 11
                                        color: "#c2c0ed"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: p4Mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyPreset("hybrid")
                                }
                            }
                        }

                        // Result of the selected preset (target devices or problem)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: presetMessageText.implicitHeight + 16
                            radius: 8
                            visible: root.presetMessage.length > 0
                            color: root.presetError ? "#2c2c2c" : "#1e1e1e"
                            border.color: root.presetError ? "#ef5350" : "#66bb6a"
                            border.width: 1

                            Text {
                                id: presetMessageText
                                anchors.fill: parent
                                anchors.margins: 8
                                text: (root.presetError ? "" : (root.presetChosen ? "" : "")) + root.presetMessage
                                      + (root.presetChosen && !root.presetError ? qsTr(" — press Save to apply it.") : "")
                                wrapMode: Text.WordWrap
                                font.pixelSize: 12
                                color: root.presetError ? "#ffcdd2" : "#c8e6c9"
                            }
                        }

                        // Banner informativo cuando el ruteo es Personalizado (Matriz)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 8
                            visible: root.activePreset === "custom"
                            color: "#262626"
                            border.color: "#4238f8"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Text { text: ""; font.pixelSize: 14 }
                                Text {
                                    text: qsTr("Custom routing active (virtual cables in the matrix)")
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: "#4238f8"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: qsTr("Manual configuration in use")
                                    font.pixelSize: 11
                                    color: "#a6a6a6"
                                }
                            }
                        }

                        // Card explicativa de conexiones de audio físicas
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: audioExplCol.implicitHeight + 16
                            radius: 8
                            color: "#1c1c1c"
                            border.color: "#333333"
                            border.width: 1

                            ColumnLayout {
                                id: audioExplCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                Text {
                                    text: qsTr("How do I connect my speakers and headphones?")
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: "#9590f9"
                                }

                                Text {
                                    text: qsTr("• <b>Main output (1-2)</b>: sound for the audience. Connect your speakers to the rear RCA outputs of your controller.<br>• <b>CUE pre-listening (3-4)</b>: private sound. Connect your headphones to the headphone jack of the controller.<br>• <b>Hybrid mode</b>: no external speakers? Choose <i>'Tablet + controller headphones'</i> so the music plays through the tablet and the pre-listening through your headphones.<br>• <b>Important</b>: after choosing your profile, press the blue <b>'Apply and save outputs'</b> button at the bottom.")
                                    font.pixelSize: 11
                                    color: "#bebebe"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                // CARD 2: MOTOR DE AUDIO & LATENCIA
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: engineSettingsCol.implicitHeight + 28
                    color: "#181818"
                    radius: 12
                    border.color: "#2c2c2c"
                    border.width: 1

                    ColumnLayout {
                        id: engineSettingsCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: qsTr("Audio engine, latency & quality")
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }

                        // Grid with settings
                        GridLayout {
                            Layout.fillWidth: true
                            columns: root.width > 750 ? 2 : 1
                            columnSpacing: 24
                            rowSpacing: 12

                            // Sound API
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    color: Theme.white
                                    font.pixelSize: 13
                                    text: qsTr("Audio API")
                                }
                                RatioChoice {
                                    id: soundApi
                                    maxWidth: 240
                                    options: []
                                    onSelectedChanged: {
                                        root.hasChanges = true;
                                        router.update(soundApi.selected);
                                        sampleRate.update(soundApi.selected);
                                    }
                                }
                            }

                            // Sample Rate
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    color: Theme.white
                                    font.pixelSize: 13
                                    text: qsTr("Sample rate")
                                }
                                RatioChoice {
                                    id: sampleRate
                                    function update(api) {
                                        let data = [];
                                        for (let sr of Mixxx.SoundManager.getSampleRates(api)) {
                                            data.push(qsTr("%1 Hz").arg(sr));
                                        }
                                        sampleRate.options = data;
                                    }
                                    maxWidth: 240
                                    options: []
                                    onSelectedChanged: {
                                        root.hasChanges = true;
                                    }
                                }
                                Connections {
                                    target: sampleRate
                                    function onSelectedChanged() {
                                        let sampleRateValue = parseInt(sampleRate.selected);
                                        audioBuffer.update(sampleRateValue);
                                    }
                                }
                            }

                            // Audio Buffer (Latency)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        color: Theme.white
                                        font.pixelSize: 13
                                        text: qsTr("Latency / audio buffer")
                                    }
                                    Skin.ComboBox {
                                        id: audioBuffer
                                        function update(sr) {
                                            let data = [];
                                            let framesPerBuffer = 1;
                                            for (; framesPerBuffer / sr * 1000 < 1.0; framesPerBuffer *= 2) {}
                                            for (let i = 0; i < 7; i++) {
                                                const latency = framesPerBuffer / sr * 1000;
                                                data.push(qsTr("%1 ms").arg(latency.toFixed(1)));
                                                framesPerBuffer *= 2;
                                            }
                                            let cur = audioBuffer.currentIndex;
                                            audioBuffer.model = data;
                                            audioBuffer.currentIndex = cur;
                                        }
                                        clip: true
                                        font.pixelSize: 12
                                        spacing: 2
                                        onCurrentIndexChanged: {
                                            root.hasChanges = true;
                                        }
                                    }
                                }

                                // Latency explanation text
                                Text {
                                    text: {
                                        const idx = audioBuffer.currentIndex;
                                        if (idx <= 1) return qsTr("Ultra-low latency: instant response for scratching and fast mixing.");
                                        if (idx <= 3) return qsTr("Balanced latency: recommended for most Android phones (stable, no dropouts).");
                                        return qsTr("Safe mode: maximum stability if you hear crackles or the phone is slow.");
                                    }
                                    font.pixelSize: 11
                                    color: audioBuffer.currentIndex <= 1 ? "#908aff" : (audioBuffer.currentIndex <= 3 ? "#81c784" : "#f7c86a")
                                }
                            }

                            // Main Output Mode (Mono / Stereo)
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    color: Theme.white
                                    font.pixelSize: 13
                                    text: qsTr("Main mix mode")
                                }
                                RatioChoice {
                                    id: mainOutputMode
                                    maxWidth: 200
                                    options: ["mono", "stereo"]
                                    selected: options[monoMix.value ? 0 : 1]
                                    onSelectedChanged: {
                                        root.hasChanges = true;
                                    }
                                }
                            }

                            // Keylock engine
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    color: Theme.white
                                    font.pixelSize: 13
                                    text: qsTr("Keylock quality")
                                }
                                RatioChoice {
                                    id: keylock
                                    function update() {
                                        let opts = [];
                                        let tips = [];
                                        for (let eng of Mixxx.SoundManager.getKeylockEngines()) {
                                            switch (eng) {
                                            case 0:
                                                opts.push(qsTr("Soundtouch"));
                                                tips.push(qsTr("Fast"));
                                                break;
                                            case 1:
                                                opts.push(qsTr("Rubberband"));
                                                tips.push(qsTr("High quality"));
                                                break;
                                            case 2:
                                                opts.push(qsTr("Rubberband R3"));
                                                tips.push(qsTr("Highest quality"));
                                                break;
                                            }
                                        }
                                        keylock.options = opts;
                                        keylock.tooltips = tips;
                                    }
                                    maxWidth: 240
                                    normalizedWidth: false
                                    options: []
                                    tooltips: []
                                    onSelectedChanged: {
                                        root.hasChanges = true;
                                    }
                                }
                            }

                            // Main Mix Enabled
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    color: Theme.white
                                    font.pixelSize: 13
                                    text: qsTr("Main mix")
                                }
                                RatioChoice {
                                    id: mainMixEnabled
                                    options: ["on", "off"]
                                    selected: options[mainEnabled.value ? 0 : 1]
                                    onSelectedChanged: {
                                        root.hasChanges = true;
                                    }
                                }
                            }

                            // Mixxx's own USB audio driver (Android)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        color: Theme.white
                                        font.pixelSize: 13
                                        text: qsTr("Mixxx USB driver")
                                    }
                                    RatioChoice {
                                        id: usbDirectMode
                                        // Indexed by the config value: 0 = auto, 1 = always, 2 = never
                                        options: [qsTr("auto"), qsTr("always"), qsTr("never")]
                                        tooltips: [qsTr("Multichannel sound cards only (DJ controllers)"), qsTr("All compatible USB sound cards"), qsTr("Always use Android audio")]
                                        onSelectedChanged: {
                                            root.hasChanges = true;
                                        }

                                        // The options are rebuilt in the new language,
                                        // keep the choice (stored by its index)
                                        property int indexBeforeRetranslation: -1
                                        property bool hadChangesBeforeRetranslation: false
                                        Connections {
                                            target: Mixxx.Language

                                            function onLocaleAboutToChange() {
                                                usbDirectMode.indexBeforeRetranslation = usbDirectMode.options.indexOf(usbDirectMode.selected);
                                                usbDirectMode.hadChangesBeforeRetranslation = root.hasChanges;
                                            }
                                            function onLocaleChanged() {
                                                if (usbDirectMode.indexBeforeRetranslation >= 0) {
                                                    usbDirectMode.selected = usbDirectMode.options[usbDirectMode.indexBeforeRetranslation];
                                                    root.hasChanges = usbDirectMode.hadChangesBeforeRetranslation;
                                                }
                                                usbDirectMode.indexBeforeRetranslation = -1;
                                            }
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    color: "#969696"
                                    font.pixelSize: 11
                                    text: qsTr("Mixxx drives the USB sound card directly when Android cannot use all of its channels (e.g. the headphones of a DJ controller). Changes take effect after restarting Mixxx.")
                                }
                            }
                        }

                        // Network Clock (oculto / avanzado)
                        RowLayout {
                            Layout.fillWidth: true
                            visible: false
                            RatioChoice {
                                id: soundClock
                                options: ["soundcard", "network"]
                            }
                            Skin.ComboBox {
                                id: microphoneMonitorMode
                                model: [qsTr("Main output only"), qsTr("Main and booth outputs"), qsTr("Direct monitor")]
                            }
                        }
                    }
                }

                // CARD 3: ROUTER AVANZADO (CABLES VIRTUALES)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.showAdvancedRouter ? 460 : 54
                    color: "#181818"
                    radius: 12
                    border.color: "#2c2c2c"
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // Header with toggle
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: qsTr("Advanced routing matrix (virtual cables)")
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: "#bebebe"
                            }
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 150
                                height: 28
                                radius: 6
                                color: toggleRouterMouse.containsMouse ? "#3e3e3e" : "#2e2e2e"
                                border.color: "#3e37bd"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: root.showAdvancedRouter ? qsTr("Hide matrix") : qsTr("Show full matrix")
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: "#9590f9"
                                }

                                MouseArea {
                                    id: toggleRouterMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.showAdvancedRouter = !root.showAdvancedRouter;
                                    }
                                }
                            }
                        }

                        // The full AudioRouter canvas
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.showAdvancedRouter

                            AudioRouter {
                                id: router
                                anchors.fill: parent
                                onHasChangesChanged: {
                                    if (hasChanges && !root.loading && root.showAdvancedRouter) {
                                        root.activePreset = "custom";
                                        root.presetChosen = false;
                                        root.presetMessage = "";
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.alpha('grey', 0.3)
                                visible: root.committing

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    onWheel: mouse => { mouse.accepted = true; }
                                }
                            }
                        }
                    }
                }
            }

            // ================= PESTAÑA 2: RETARDOS (DELAYS) =================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: root.selectedIndex === 1

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: delaysCol.implicitHeight + 28
                    color: "#181818"
                    radius: 12
                    border.color: "#2c2c2c"
                    border.width: 1

                    ColumnLayout {
                        id: delaysCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        Text {
                            text: qsTr("Output delays (acoustic latency compensation)")
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 10

                            Text {
                                id: mainDelayLabel
                                Layout.fillWidth: true
                                color: Theme.white
                                font.pixelSize: 14
                                opacity: enabled ? 1 : 0.5
                                text: qsTr("Main output delay")
                            }
                            Skin.Slider {
                                id: mainDelaySlider
                                Layout.fillWidth: true
                                markers: ["0ms", "100ms", "1s", "10s", null]
                                slider.to: 1000
                                suffix: "ms"
                                onValueChanged: { root.hasChanges = true; }
                            }

                            Text {
                                id: boothDelayLabel
                                Layout.fillWidth: true
                                color: Theme.white
                                enabled: boothEnabled.value
                                font.pixelSize: 14
                                opacity: enabled ? 1 : 0.5
                                text: qsTr("Booth output delay")
                            }
                            Skin.Slider {
                                id: boothDelaySlider
                                Layout.fillWidth: true
                                enabled: boothEnabled.value
                                markers: ["0ms", "100ms", "1s", "10s", null]
                                slider.to: 1000
                                suffix: "ms"
                                value: boothDelay.value
                                onValueChanged: { root.hasChanges = true; }
                            }

                            Text {
                                id: headphoneDelayLabel
                                Layout.fillWidth: true
                                color: Theme.white
                                enabled: headEnabled.value
                                font.pixelSize: 14
                                opacity: enabled ? 1 : 0.5
                                text: qsTr("Headphone output delay (CUE)")
                            }
                            Skin.Slider {
                                id: headphoneDelaySlider
                                Layout.fillWidth: true
                                enabled: headEnabled.value
                                markers: ["0ms", "100ms", "1s", "10s", null]
                                slider.to: 1000
                                suffix: "ms"
                                value: headDelay.value
                                onValueChanged: { root.hasChanges = true; }
                            }
                        }
                    }
                }
            }

        }
    }

    // ================= PINNED BOTTOM ACTION BAR =================
    Rectangle {
        id: soundAction
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 58
        color: "#171717"
        border.color: "#383838"
        border.width: 1
        radius: 8

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            // Status Indicator Pill
            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth: statusText.implicitWidth + 20
                radius: 15
                color: root.hasChanges ? "#303030" : "#1b5e20"
                border.color: root.hasChanges ? "#ff9800" : "#4caf50"
                border.width: 1

                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: root.hasChanges ? qsTr("● Unsaved changes") : qsTr("✓ Audio configured")
                    font.weight: Font.DemiBold
                    font.pixelSize: 11
                    color: root.hasChanges ? "#f7c86a" : "#81c784"
                }
            }

            Text {
                id: errorMessage
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: 12
                color: "#ff5d6c"
                text: ""
            }

            Skin.Button {
                visible: root.hasChanges
                Layout.preferredHeight: 38
                Layout.preferredWidth: 130
                activeColor: "#ff5d6c"
                backgroundColor: "#222222"
                normalColor: "#ff8f99"
                font.weight: Font.DemiBold
                font.pixelSize: 12
                text: qsTr("Discard")
                onClicked: {
                    errorMessage.text = "";
                    root.load();
                }
            }

            Rectangle {
                id: applyButtonRect
                Layout.preferredHeight: 40
                Layout.preferredWidth: 230
                radius: 8
                color: root.committing ? "#453de0" : (root.hasChanges ? "#22b868" : (applyMouse.containsMouse ? "#3429ff" : "#584fff"))
                border.color: root.hasChanges ? "#b9f6ca" : "#908aff"
                border.width: 1.5

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: root.committing ? "" : (root.hasChanges ? "" : "✓")
                        font.pixelSize: 14
                        color: "#ffffff"
                    }

                    Text {
                        text: root.committing ? qsTr("Applying...") : qsTr("Apply and save outputs")
                        font.weight: Font.DemiBold
                        font.pixelSize: 13
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    id: applyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.committing
                    onClicked: {
                        errorMessage.text = "";
                        root.save();
                    }
                }
            }
        }
    }

    Connections {
        function onCommitted(error) {
            root.committing = false;
            if (error) {
                errorMessage.text = error;
            }
            root.load();
        }
        target: Mixxx.SoundManager
    }
}
