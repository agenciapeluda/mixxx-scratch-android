// [AI-generated text, Claude (Anthropic) — start]
// Cutlab 1.31: what the controllers ask of Cutlab and the Cutlab functions
// that work with any controller, alive all the session in the performance
// screen (DJView.qml):
//  - the pad mode of each deck on the screen ([Cutlab] pads_modeN) and the
//    loop tool ([Cutlab] loop_openN), asked by the pad mode buttons of a
//    controller;
//  - Key Shift / Pitch Play of each deck (KeyPlay);
//  - the Quick Effect of every deck always the Filter preset and on, for
//    any controller (before 1.31 only the Mixtour script made sure);
//  - Smart CFX and Smart Fader, kept in the settings.
// A controller plugged in for the first time already gets its own mapping
// by itself (ControllerManager::autoAssignMapping); each mapping asks
// Cutlab for the logical action of each control.
// [AI-generated text, Claude (Anthropic) — end]
import Mixxx 1.0 as Mixxx
import QtQuick

Item {
    id: root

    // The DJView
    required property var host

    Component.onCompleted: {
        Shots.keyPlay1 = keyPlay1;
        Shots.keyPlay2 = keyPlay2;
        smartCfx.value = Number(Mixxx.Application.configValue("[Cutlab]", "smart_cfx", "0")) || 0;
        smartFader.value = Mixxx.Application.configValue("[Cutlab]", "smart_fader", "0") === "1" ? 1 : 0;
    }

    KeyPlay {
        id: keyPlay1

        group: "[Channel1]"
    }
    KeyPlay {
        id: keyPlay2

        group: "[Channel2]"
    }
    SmartCfx {
        id: smartCfx1

        group: "[Channel1]"
    }
    SmartCfx {
        id: smartCfx2

        group: "[Channel2]"
    }
    SmartFader {
        cfx1: smartCfx1
        cfx2: smartCfx2
    }
    // [AI-generated text, Claude (Anthropic) — start]
    // 1.32.4: with a folder for Auto DJ, while it plays, the queue never
    // runs dry: when three tracks or fewer are left, the rest of the
    // folder goes after them, from the BPM of the last one up. Tracks added
    // to the folder come in once the library has scanned them.
    // [AI-generated text, Claude (Anthropic) — end]
    Timer {
        interval: 20000
        repeat: true
        running: autoDjEnabled.value > 0
        triggeredOnStart: true
        onTriggered: {
            const folder = Mixxx.Application.configValue("[Cutlab]", "autodj_folder", "");
            if (folder.length > 0 && Mixxx.Cutlab.queueCount() <= 3) {
                Mixxx.Cutlab.fillQueueFromFolder(folder, false);
            }
        }
    }
    Mixxx.ControlProxy {
        id: autoDjEnabled

        group: "[AutoDJ]"
        key: "enabled"
    }

    Mixxx.ControlProxy {
        id: smartCfx

        group: "[Cutlab]"
        key: "smart_cfx"
        onValueChanged: Mixxx.Application.setConfigValue("[Cutlab]", "smart_cfx", Math.round(value).toString())
    }
    Mixxx.ControlProxy {
        id: smartFader

        group: "[Cutlab]"
        key: "smart_fader"
        onValueChanged: Mixxx.Application.setConfigValue("[Cutlab]", "smart_fader", value > 0 ? "1" : "0")
    }

    Repeater {
        model: 2

        Item {
            id: deckBridge

            required property int index
            readonly property int deck: index + 1
            readonly property string group: `[Channel${deck}]`

            // A pad mode button of a controller: the same mode on the screen
            Mixxx.ControlProxy {
                id: padsMode

                group: "[Cutlab]"
                key: `pads_mode${deckBridge.deck}`
                onValueChanged: {
                    if (value <= 0) {
                        return;
                    }
                    const mode = Math.max(0, Math.min(6, Math.round(value) - 1));
                    if (deckBridge.deck === 1) {
                        root.host.padMode1 = mode;
                    } else {
                        root.host.padMode2 = mode;
                    }
                    // Ready for the next press of the same mode
                    padsMode.value = 0;
                }
            }
            // BEAT LOOP of a controller: the loop tool of the deck
            Mixxx.ControlProxy {
                group: "[Cutlab]"
                key: `loop_open${deckBridge.deck}`
                onValueChanged: {
                    if (value > 0) {
                        root.host.openTool(deckBridge.group, 2);
                    }
                }
            }
        }
    }

    // [AI-generated text, Claude (Anthropic) — start]
    // Cutlab 1.31.1: the row of the Filter in the list of Quick Effect
    // presets. 1.31 forced row 1, which is another preset (the Cutlab chains
    // come first): the filter knobs were zero all the way left. The row is
    // looked up by the effect, never fixed.
    property int filterPreset: -1
    function findFilterPreset() {
        const model = Mixxx.EffectsManager.quickChainPresetModel;
        root.filterPreset = model ? model.indexOfEffect("org.mixxx.effects.filter") : -1;
    }
    Connections {
        target: Mixxx.EffectsManager.quickChainPresetModel
        function onModelReset() {
            root.findFilterPreset();
        }
    }
    // [AI-generated text, Claude (Anthropic) — end]

    // The Quick Effect of each deck: the Filter preset, on
    Repeater {
        model: 4

        Item {
            id: quickEffect

            required property int index
            readonly property string rack: `[QuickEffectRack1_[Channel${index + 1}]]`

            function enforce() {
                if (root.filterPreset < 0) {
                    root.findFilterPreset();
                }
                if (root.filterPreset >= 0 && Math.round(preset.value) !== root.filterPreset) {
                    preset.value = root.filterPreset;
                }
                if (fxEnabled.value <= 0) {
                    fxEnabled.value = 1;
                }
            }

            Mixxx.ControlProxy {
                id: preset

                group: quickEffect.rack
                key: "loaded_chain_preset"
                onValueChanged: Qt.callLater(quickEffect.enforce)
            }
            Mixxx.ControlProxy {
                id: fxEnabled

                group: quickEffect.rack
                key: "enabled"
                onValueChanged: Qt.callLater(quickEffect.enforce)
            }
            // Once the effects are up
            Timer {
                interval: 1600
                running: true
                onTriggered: quickEffect.enforce()
            }
        }
    }
}
