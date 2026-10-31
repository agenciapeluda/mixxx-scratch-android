import "../Deck" as DeckComponent
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Shapes

// The deck as a big dial: tempo, pitch and range, elapsed and remaining
// time on a white face, a red needle turning with the track and the play
// position around it. Drag the ring to scratch, like a record.
Item {
    id: root

    required property string group
    property bool mirrored: false
    readonly property real diameter: Math.max(80, Math.min(width - 16, height - 8))
    readonly property real elapsed: duration.value * playPosition.value
    readonly property real remaining: Math.max(0, duration.value - elapsed)
    readonly property bool loaded: trackLoaded.value > 0
    readonly property bool warning: loaded && endOfTrack.value > 0

    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: bpm

        group: root.group
        key: "bpm"
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
        id: endOfTrack

        group: root.group
        key: "end_of_track"
    }

    function clock(seconds, tenths) {
        if (!isFinite(seconds) || seconds < 0) {
            seconds = 0;
        }
        const m = Math.floor(seconds / 60);
        const s = seconds - m * 60;
        const whole = Math.floor(s);
        let text = (m < 10 ? "0" : "") + m + ":" + (whole < 10 ? "0" : "") + whole;
        if (tenths) {
            text += "." + Math.floor((s - whole) * 10);
        }
        return text;
    }

    Item {
        id: dial

        anchors.centerIn: parent
        width: root.diameter
        height: root.diameter

        // The ring you scratch
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#202022"
            border.color: "#3c3c3f"
            border.width: 1
        }

        // Play position around the face
        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            visible: root.loaded

            ShapePath {
                capStyle: ShapePath.FlatCap
                fillColor: "transparent"
                strokeColor: root.warning ? Style.danger : Style.accent
                strokeWidth: Math.max(3, dial.width * 0.025)

                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.width / 2 - dial.width * 0.04
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0, Math.min(1, playPosition.value))
                }
            }
        }

        // The face, under the needle
        Rectangle {
            id: face

            anchors.centerIn: parent
            width: parent.width * 0.78
            height: width
            radius: width / 2
            color: "#f4f4f6"
            enabled: false

            readonly property real hub: Math.max(10, root.diameter * 0.075)

            // Tempo above the needle's hub
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: face.hub * 0.7
                spacing: -2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#1c1c1e"
                    font.family: Style.font
                    font.pixelSize: Math.max(9, face.height * 0.075)
                    font.weight: Font.Medium
                    text: "BPM"
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        id: bpmWhole

                        color: "#0c0c0d"
                        font.family: Style.font
                        font.pixelSize: Math.max(18, face.height * 0.24)
                        font.weight: Font.Bold
                        text: bpm.value > 0 ? Math.floor(bpm.value).toString() : "--"
                    }
                    Text {
                        anchors.baseline: bpmWhole.baseline
                        color: "#0c0c0d"
                        font.family: Style.font
                        font.pixelSize: Math.max(11, face.height * 0.13)
                        font.weight: Font.Bold
                        text: bpm.value > 0 ? "." + Math.floor((bpm.value * 10) % 10) : ""
                    }
                }
            }

            // Pitch and range on both sides of the hub
            Text {
                readonly property real percent: (rateRatio.value - 1) * 100

                anchors.right: parent.horizontalCenter
                anchors.rightMargin: face.hub * 0.9
                anchors.verticalCenter: parent.verticalCenter
                color: "#3a3a3d"
                font.family: Style.font
                font.pixelSize: Math.max(8, face.height * 0.075)
                text: (percent >= 0 ? "+" : "") + percent.toFixed(1) + "%"
            }
            Text {
                anchors.left: parent.horizontalCenter
                anchors.leftMargin: face.hub * 0.9
                anchors.verticalCenter: parent.verticalCenter
                color: "#3a3a3d"
                font.family: Style.font
                font.pixelSize: Math.max(8, face.height * 0.075)
                text: "±" + Math.round(rateRange.value * 100)
            }

            // Elapsed and remaining below
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: face.hub * 0.7
                spacing: -2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#8a8a8f"
                    font.family: Style.font
                    font.pixelSize: Math.max(9, face.height * 0.1)
                    font.weight: Font.Medium
                    text: root.clock(root.elapsed, true)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root.warning ? Style.danger : "#1c1c1e"
                    font.family: Style.font
                    font.pixelSize: Math.max(10, face.height * 0.115)
                    font.weight: Font.Bold
                    text: root.clock(root.remaining, true)
                }
            }
        }

        DeckComponent.TouchSpinny {
            id: spinny

            anchors.fill: parent
            group: root.group
            indicatorVisible: true

            // The red needle, turning with the track
            indicator: Item {
                width: spinny.width
                height: spinny.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.verticalCenter
                    width: Math.max(4, spinny.width * 0.035)
                    height: spinny.height / 2 - 2
                    radius: width / 2
                    antialiasing: true
                    // Solid on the ring, faint over the face so the
                    // numbers stay readable
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "#e3202a"
                        }
                        GradientStop {
                            position: 0.2
                            color: "#e3202a"
                        }
                        GradientStop {
                            position: 0.23
                            color: "#55e3202a"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#55e3202a"
                        }
                    }
                }
            }
        }


        // Hub of the needle
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(10, parent.width * 0.075)
            height: width
            radius: width / 2
            color: "#8e8e93"
            border.color: "#5a5a5e"
            border.width: 1
        }
    }

    // DVS mode and timecode signal, when the deck follows a turntable
    DvsBadge {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        x: root.mirrored ? 8 : parent.width - width - 8
        group: root.group
    }
}
