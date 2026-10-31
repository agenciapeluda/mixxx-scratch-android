import Mixxx 1.0 as Mixxx
import QtQuick

// The samplers as pads: tap plays the sample from its start, hold stops
// it (or empties the pad when stopped). An empty pad asks for a sample
// from the library.
Grid {
    id: root

    property int count: 8

    signal loadRequested(string group)

    columns: 4
    rows: Math.ceil(count / columns)
    spacing: 1

    Repeater {
        model: root.count

        Pad {
            id: pad

            required property int index
            readonly property string samplerGroup: `[Sampler${index + 1}]`
            readonly property var player: Mixxx.PlayerManager.getPlayer(samplerGroup)
            readonly property var track: player ? player.currentTrack : null
            readonly property bool loaded: trackLoaded.value > 0

            width: (root.width - (root.columns - 1) * root.spacing) / root.columns
            height: (root.height - (root.rows - 1) * root.spacing) / root.rows
            text: loaded && track ? (track.title !== "" ? track.title : qsTr("Sample %1").arg(index + 1)) : "+"
            dimmed: !loaded
            active: play.value > 0
            padColor: loaded ? Style.accent : "transparent"

            onClicked: {
                if (!loaded) {
                    root.loadRequested(samplerGroup);
                    return;
                }
                gotoAndPlay.value = 1;
                gotoAndPlay.value = 0;
            }
            onPressAndHold: {
                if (play.value > 0) {
                    play.value = 0;
                } else if (loaded) {
                    eject.value = 1;
                    eject.value = 0;
                }
            }

            Mixxx.ControlProxy {
                id: trackLoaded

                group: pad.samplerGroup
                key: "track_loaded"
            }
            Mixxx.ControlProxy {
                id: play

                group: pad.samplerGroup
                key: "play"
            }
            Mixxx.ControlProxy {
                id: eject

                group: pad.samplerGroup
                key: "eject"
            }
            Mixxx.ControlProxy {
                id: gotoAndPlay

                group: pad.samplerGroup
                key: "cue_gotoandplay"
            }
        }
    }
}
