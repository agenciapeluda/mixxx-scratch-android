import "../Deck" as DeckComponent
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Shapes

// The deck as a big dial, laid out on one grid around the centre: the key
// on top, the tempo as it plays big in the middle with the track's own and
// the pitch below it, the time left at the bottom. Around the face a thin
// ring fills with the play position, and a dot turns on the edge with the
// track (nothing crosses the numbers). Drag the ring to scratch.
Item {
    id: root

    required property string group
    property bool mirrored: false
    // The sections of the track (TrackSections), for the drop radar
    property var trackSections: null
    readonly property real diameter: Math.max(80, Math.min(width - 16, height - 8))
    // The numbers are read with the shared position reader (15 times a
    // second), not on every update of the engine
    property real elapsed: 0
    property real remaining: 0
    property real bpmNow: 0
    property real pitch: 0
    // The play position around the face, in half degree steps: the ring is
    // drawn again only when it moves that much
    property real ringPosition: 0
    function read() {
        const position = Math.max(0, Math.min(1, Clock.position(root.group)));
        root.elapsed = duration.value * position;
        root.remaining = Math.max(0, duration.value - root.elapsed);
        root.bpmNow = bpm.value;
        root.pitch = (rateRatio.value - 1) * 100;
        root.ringPosition = Math.round(position * 720) / 720;
    }
    Connections {
        target: Clock
        enabled: root.visible && root.loaded

        function onTick() {
            root.read();
        }
    }
    onLoadedChanged: root.read()
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
        id: duration

        group: root.group
        key: "duration"
    }
    Mixxx.ControlProxy {
        id: fileBpm

        group: root.group
        key: "file_bpm"
    }
    Mixxx.ControlProxy {
        id: keyControl

        group: root.group
        key: "key"
    }
    Mixxx.ControlProxy {
        id: endOfTrack

        group: root.group
        key: "end_of_track"
    }

    function clock(seconds) {
        if (!isFinite(seconds) || seconds < 0) {
            seconds = 0;
        }
        const m = Math.floor(seconds / 60);
        const whole = Math.floor(seconds - m * 60);
        return "-" + m + ":" + (whole < 10 ? "0" : "") + whole;
    }


    Item {
        id: dial

        anchors.centerIn: parent
        width: root.diameter
        height: root.diameter

        // Sizes, all from the diameter
        readonly property real ringWidth: Math.max(10, width * 0.11)
        readonly property real progressWidth: Math.max(2, width * 0.016)

        // The ring you scratch
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#1d1c26"
            border.color: "#34333f"
            border.width: 1
        }

        // The play position: a thin line on the outer edge of the ring
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: root.loaded

            ShapePath {
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                strokeColor: root.warning ? Style.danger : Style.deckColor(root.group)
                strokeWidth: dial.progressWidth

                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.width / 2 - dial.progressWidth
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 360 * root.ringPosition
                }
            }
        }

        // The face
        Rectangle {
            id: face

            anchors.centerIn: parent
            width: parent.width - 2 * dial.ringWidth
            height: width
            radius: width / 2
            color: "#f4f4f6"
            enabled: false

            readonly property real unit: face.height / 100

            // Key, on top
            Rectangle {
                readonly property string keyText: root.loaded && Mixxx.KeyUtils.keyIsValid(keyControl.value) ? Mixxx.KeyUtils.keyToString(keyControl.value) : ""

                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(face.unit * 17)
                visible: keyText !== ""
                width: keyLabel.implicitWidth + face.unit * 9
                height: Math.round(face.unit * 12)
                radius: height / 2
                color: Style.keyColor(keyText)

                Text {
                    id: keyLabel

                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.family: Style.font
                    font.pixelSize: Math.max(8, Math.round(face.unit * 7.5))
                    font.weight: Font.Bold
                    text: parent.keyText
                }
            }

            // Tempo as it plays, big, in the middle; fixed width digits so
            // it never jumps
            Row {
                id: tempo

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -face.unit * 3

                Text {
                    id: bpmWhole

                    color: "#0c0c0d"
                    font.family: Style.font
                    font.features: {"tnum": 1}
                    font.pixelSize: Math.max(18, Math.round(face.unit * 27))
                    font.weight: Font.Bold
                    text: root.bpmNow > 0 ? Math.floor(root.bpmNow).toString() : "--"
                }
                Text {
                    anchors.baseline: bpmWhole.baseline
                    color: "#0c0c0d"
                    font.family: Style.font
                    font.features: {"tnum": 1}
                    font.pixelSize: Math.max(11, Math.round(face.unit * 14))
                    font.weight: Font.Bold
                    text: root.bpmNow > 0 ? "." + Math.floor((root.bpmNow * 10) % 10) : ""
                }
            }
            // The track's own tempo and the pitch
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: tempo.bottom
                anchors.topMargin: -face.unit * 2
                color: Math.abs(root.pitch) >= 0.05 ? "#4a43d6" : "#6a6a70"
                font.family: Style.font
                font.features: {"tnum": 1}
                font.pixelSize: Math.max(8, Math.round(face.unit * 6.5))
                font.weight: Font.Medium
                text: root.loaded && fileBpm.value > 0
                    ? qsTr("orig. %1 · %2%3%").arg(fileBpm.value.toFixed(1)).arg(root.pitch >= 0 ? "+" : "").arg(root.pitch.toFixed(1))
                    : ""
            }

            // Time left, at the bottom
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(face.unit * 15)
                color: root.warning ? Style.danger : "#1c1c1e"
                font.family: Style.font
                font.features: {"tnum": 1}
                font.pixelSize: Math.max(10, Math.round(face.unit * 11))
                font.weight: Font.Bold
                text: root.loaded ? root.clock(root.remaining) : ""
            }
        }

        DeckComponent.TouchSpinny {
            id: spinny

            anchors.fill: parent
            group: root.group
            indicatorVisible: root.loaded

            // A dot on the ring turning with the track; it never crosses
            // the numbers
            indicator: Item {
                width: spinny.width
                height: spinny.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (dial.ringWidth - height) / 2
                    width: Math.max(7, dial.ringWidth * 0.5)
                    height: width
                    radius: width / 2
                    antialiasing: true
                    color: "#ffffff"
                    border.width: Math.max(1, width * 0.18)
                    border.color: Style.deckColor(root.group)
                }
            }
        }
    }

    // DVS mode and timecode signal, when the deck follows a turntable
    DvsBadge {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        x: root.mirrored ? 8 : parent.width - width - 8
        group: root.group
    }
    DropRadar {
        anchors.centerIn: parent
        width: root.diameter
        height: root.diameter
        group: root.group
        trackSections: root.trackSections
    }
}
