import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Shapes

// The platter of a deck, as in the design: the ring is how much of the track
// played, in the deck color; the white platter turns with the music (33 rpm)
// and shows the BPM (or the deck letter), the pitch range and the pitch.
// Coming to a drop (red) or to the end of the track (yellow) it says how
// far it is and, close to it, pulses like a radar on every beat. Tap it to
// play or pause (not with DVS: the record rules).
Item {
    id: root

    required property string group
    readonly property real size: Math.min(width, height)
    readonly property real k: size / 200
    readonly property real pitchPercent: (rateRatio.value - 1) * 100
    // The sections of the track (TrackSections), for the drop countdown
    property var trackSections: null
    // The BPM in the middle; else the deck letter (the pitch column shows it)
    property bool showBpm: true

    readonly property bool loaded: trackLoaded.value > 0
    readonly property int barsToDrop: root.trackSections ? root.trackSections.barsToDrop : -1
    readonly property bool ending: root.loaded && endOfTrack.value > 0
    readonly property bool dropSoon: root.loaded && root.barsToDrop > 0 && root.barsToDrop <= 16
    readonly property bool radar: root.ending || root.dropSoon
    readonly property color radarColor: root.ending ? Style.cue : Style.danger
    readonly property real remaining: Math.max(0, duration.value * (1 - playPosition.value)) / Math.max(0.01, rateRatio.value)
    readonly property bool scratching: scratchEnable.value > 0 || vinylScratching.value > 0
    // How strong the pulse is: stronger as the drop comes
    readonly property real pulseStrength: root.ending ? 0.85 : Math.max(0.35, 1 - (root.barsToDrop - 1) / 8 * 0.65)
    readonly property bool pulsing: play.value > 0 && !root.scratching && (root.ending || (root.dropSoon && root.barsToDrop <= 8))

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
        id: rateRange

        group: root.group
        key: "rateRange"
    }
    Mixxx.ControlProxy {
        id: bpm

        group: root.group
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: duration

        group: root.group
        key: "duration"
    }
    Mixxx.ControlProxy {
        id: play

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: dvs

        group: root.group
        key: "vinylcontrol_enabled"
    }
    Mixxx.ControlProxy {
        id: endOfTrack

        group: root.group
        key: "end_of_track"
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
    // One radar pulse on each beat, only near a drop or the end
    Mixxx.ControlProxy {
        group: root.group
        key: "beat_active"
        onValueChanged: {
            if (value > 0 && root.pulsing) {
                pulse.restart();
            }
        }
    }

    Item {
        anchors.centerIn: parent
        width: root.size
        height: root.size

        // Track ring
        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: "transparent"
                strokeColor: Style.divider
                strokeWidth: 10 * root.k
                PathAngleArc {
                    centerX: 100 * root.k
                    centerY: 100 * root.k
                    radiusX: 92 * root.k
                    radiusY: 92 * root.k
                    startAngle: 0
                    sweepAngle: 360
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Style.deckColor(root.group)
                strokeWidth: 10 * root.k
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 100 * root.k
                    centerY: 100 * root.k
                    radiusX: 92 * root.k
                    radiusY: 92 * root.k
                    startAngle: -90
                    sweepAngle: Math.max(0.5, 360 * Math.max(0, Math.min(1, playPosition.value)))
                }
            }
        }
        // Platter
        Rectangle {
            anchors.centerIn: parent
            width: 148 * root.k
            height: width
            radius: width / 2
            color: Style.text

            // The marker turns with the music: 33 1/3 rpm
            Item {
                anchors.fill: parent
                rotation: (playPosition.value * duration.value * 200) % 360

                Rectangle {
                    x: parent.width / 2 - width / 2
                    y: 4 * root.k
                    width: 4 * root.k
                    height: parent.height / 2 - 4 * root.k
                    radius: width / 2
                    antialiasing: true
                    color: root.group === "[Channel2]" ? "#0098aa" : Style.accent
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 60 * root.k
                height: width
                radius: width / 2
                color: Style.text
            }
            // The radar: a ring that grows from the middle and fades
            Rectangle {
                id: radarRing

                anchors.centerIn: parent
                width: parent.width
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(2, 7 * root.k)
                border.color: root.radarColor
                opacity: 0
                scale: 0.3
                visible: root.radar
            }
            ParallelAnimation {
                id: pulse

                readonly property int beatMs: Math.max(180, Math.min(650, 54000 / Math.max(60, bpm.value)))

                NumberAnimation {
                    target: radarRing
                    property: "scale"
                    from: 0.3
                    to: 1
                    duration: pulse.beatMs
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: radarRing
                    property: "opacity"
                    from: root.pulseStrength
                    to: 0
                    duration: pulse.beatMs
                    easing.type: Easing.InQuad
                }
            }
            // Still, while the countdown runs: a thin ring in its color
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 4 * root.k
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(1, 2 * root.k)
                border.color: root.radarColor
                visible: root.radar
            }
            Column {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root.radar ? root.radarColor : (root.showBpm ? Style.background : Style.deckColor(root.group))
                    font.family: Style.mono
                    font.weight: Font.Bold
                    font.pixelSize: Math.max(10, (root.radar ? 26 : 24) * root.k)
                    text: {
                        if (root.ending) {
                            return Style.formatTime(root.remaining);
                        }
                        if (root.dropSoon) {
                            return String(root.barsToDrop);
                        }
                        if (!root.showBpm) {
                            return Style.deckLetter(root.group);
                        }
                        return root.loaded && bpm.value > 0 ? bpm.value.toFixed(1) : "—";
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.radar || root.showBpm
                    color: root.radar ? root.radarColor : "#5a5f75"
                    font.family: Style.font
                    font.weight: Font.Bold
                    font.pixelSize: Math.max(8, 11 * root.k)
                    font.letterSpacing: 0.5
                    text: root.ending ? qsTr("FINAL") : (root.dropSoon ? qsTr("AL DROP") : "BPM")
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showBpm
                y: parent.height * 0.76
                color: "#5a5f75"
                font.family: Style.mono
                font.pixelSize: Math.max(8, 12 * root.k)
                text: "±" + Math.round(rateRange.value * 100) + " · " + (root.pitchPercent >= 0 ? "+" : "") + root.pitchPercent.toFixed(1) + "%"
            }
        }
        // Playing: a soft glow on the ring
        Rectangle {
            anchors.centerIn: parent
            width: 196 * root.k
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Style.deckColor(root.group)
            opacity: play.value > 0 ? 0.25 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: trackLoaded.value > 0 && dvs.value <= 0
            onClicked: play.value = play.value > 0 ? 0 : 1
        }
    }
}
