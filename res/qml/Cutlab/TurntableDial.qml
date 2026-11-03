import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Shapes

// The platter of a deck, as in the design: the ring is how much of the track
// played, in the deck color; the white platter turns with the music (33 rpm)
// and shows the BPM, the pitch range and the pitch. Tap it to play or pause
// (not with DVS: the record rules).
Item {
    id: root

    required property string group
    readonly property real size: Math.min(width, height)
    readonly property real k: size / 200
    readonly property real pitchPercent: (rateRatio.value - 1) * 100

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
            Column {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Style.background
                    font.family: Style.mono
                    font.weight: Font.Bold
                    font.pixelSize: Math.max(10, 24 * root.k)
                    text: trackLoaded.value > 0 && bpm.value > 0 ? bpm.value.toFixed(1) : "—"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#5a5f75"
                    font.family: Style.font
                    font.weight: Font.DemiBold
                    font.pixelSize: Math.max(8, 11 * root.k)
                    text: "BPM"
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
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
