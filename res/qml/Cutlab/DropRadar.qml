import Mixxx 1.0 as Mixxx
import QtQuick

// Over a dial or a platter: coming to a drop (red) or to the end of the
// track (yellow) a ring marks the deck and a tag says how far it is; close
// to it a ring grows from the middle on every beat, like a radar. Nothing
// runs while the deck is scratched or far from a drop.
Item {
    id: root

    required property string group
    // The sections of the track (TrackSections)
    property var trackSections: null

    readonly property bool loaded: trackLoaded.value > 0
    readonly property int barsToDrop: root.trackSections ? root.trackSections.barsToDrop : -1
    readonly property bool ending: root.loaded && endOfTrack.value > 0
    readonly property bool dropSoon: root.loaded && root.barsToDrop > 0 && root.barsToDrop <= 16
    readonly property bool active: root.ending || root.dropSoon
    readonly property color tint: root.ending ? Style.cue : Style.danger
    readonly property real remaining: Math.max(0, duration.value * (1 - playPosition.value)) / Math.max(0.01, rateRatio.value)
    readonly property bool scratching: scratchEnable.value > 0 || vinylScratching.value > 0
    readonly property real strength: root.ending ? 0.85 : Math.max(0.35, 1 - (root.barsToDrop - 1) / 8 * 0.65)
    readonly property bool pulsing: play.value > 0 && !root.scratching && (root.ending || (root.dropSoon && root.barsToDrop <= 8))

    visible: active

    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: endOfTrack

        group: root.group
        key: "end_of_track"
    }
    Mixxx.ControlProxy {
        id: duration

        group: root.group
        key: "duration"
    }
    Mixxx.ControlProxy {
        id: playPosition

        group: root.group
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: rateRatio

        group: root.group
        key: "rate_ratio"
    }
    Mixxx.ControlProxy {
        id: play

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: bpm

        group: root.group
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: scratchEnable

        group: root.group
        key: "scratch2_enable"
    }
    Mixxx.ControlProxy {
        id: vinylScratching

        group: root.group
        key: "vinylcontrol_scratching"
    }
    Mixxx.ControlProxy {
        group: root.group
        key: "beat_active"
        onValueChanged: {
            if (value > 0 && root.pulsing) {
                pulse.restart();
            }
        }
    }

    // The ring that marks the deck while the countdown runs
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Math.max(2, root.width * 0.012)
        border.color: root.tint
    }
    // The pulse
    Rectangle {
        id: ring

        anchors.centerIn: parent
        width: parent.width
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(3, root.width * 0.035)
        border.color: root.tint
        opacity: 0
        scale: 0.25
    }
    ParallelAnimation {
        id: pulse

        readonly property int beatMs: Math.max(180, Math.min(650, 54000 / Math.max(60, bpm.value)))

        NumberAnimation {
            target: ring
            property: "scale"
            from: 0.25
            to: 1
            duration: pulse.beatMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: ring
            property: "opacity"
            from: root.strength
            to: 0
            duration: pulse.beatMs
            easing.type: Easing.InQuad
        }
    }
    // How far it is
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.04)
        width: tag.implicitWidth + 18
        height: tag.implicitHeight + 6
        radius: height / 2
        color: root.tint

        Text {
            id: tag

            anchors.centerIn: parent
            color: Style.background
            font.family: Style.mono
            font.weight: Font.Bold
            font.pixelSize: Math.max(11, Math.round(root.width * 0.07))
            text: root.ending ? qsTr("FINAL %1").arg(Style.formatTime(root.remaining))
                : (root.barsToDrop === 1 ? qsTr("DROP EN 1") : qsTr("DROP EN %1").arg(root.barsToDrop))
        }
    }
}
