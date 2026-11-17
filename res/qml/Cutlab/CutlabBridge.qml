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
        group: "[Channel1]"
    }
    SmartCfx {
        group: "[Channel2]"
    }
    SmartFader {
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
                    const mode = Math.max(0, Math.min(5, Math.round(value) - 1));
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

    // The Quick Effect of each deck: the Filter preset (1), on
    Repeater {
        model: 4

        Item {
            id: quickEffect

            required property int index
            readonly property string rack: `[QuickEffectRack1_[Channel${index + 1}]]`

            function enforce() {
                if (Math.round(preset.value) !== 1) {
                    preset.value = 1;
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
