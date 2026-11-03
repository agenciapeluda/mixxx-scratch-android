import QtQuick

// The game-like layer of the FX pad: a trail behind the finger, rings that
// repeat with an echo, a border that pulses on the beat, pixels with the
// bitcrusher, a wobble with the flanger, a dark veil with the filter. All of
// it is a fixed set of rectangles moved by animations, light enough to keep
// the screen at 60 frames per second; `lite` keeps only the essentials.
Item {
    id: root

    property string effect: "echo"
    property bool active: false
    property real fingerX: width / 2
    property real fingerY: height / 2
    property bool beat: false
    property color color: Style.accentText
    property bool lite: false
    readonly property int trailLength: lite ? 6 : 16
    property var trail: []

    clip: true

    onFingerXChanged: pushTrail()
    onFingerYChanged: pushTrail()
    function pushTrail() {
        if (!root.active) {
            return;
        }
        const points = root.trail.slice(0, root.trailLength - 1);
        points.unshift({x: root.fingerX, y: root.fingerY});
        root.trail = points;
    }
    onActiveChanged: {
        if (!active) {
            fadeTrail.start();
        } else {
            fadeTrail.stop();
        }
    }
    // The trail shrinks away after the finger lifts
    Timer {
        id: fadeTrail

        interval: 30
        repeat: true
        onTriggered: {
            if (root.trail.length === 0) {
                stop();
                return;
            }
            root.trail = root.trail.slice(0, root.trail.length - 1);
        }
    }

    // ---- Filter: a veil darker at one side ----
    Rectangle {
        anchors.fill: parent
        visible: root.effect === "filter" && root.active
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0.55 * (1 - root.fingerX / Math.max(1, root.width)))
            }
            GradientStop {
                position: 1
                color: Qt.rgba(1, 1, 1, 0.12 * root.fingerX / Math.max(1, root.width))
            }
        }
    }

    // ---- Echo and reverb: rings born on the beat around the finger ----
    Repeater {
        model: root.lite ? 2 : 4

        Rectangle {
            id: ring

            required property int index
            property real grow: 0

            x: root.fingerX - width / 2
            y: root.fingerY - height / 2
            width: 60 + grow * (root.effect === "reverb" ? 420 : 300)
            height: width
            radius: width / 2
            color: root.effect === "reverb" ? Qt.rgba(root.color.r, root.color.g, root.color.b, 0.10 * (1 - grow)) : "transparent"
            border.width: root.effect === "reverb" ? 0 : 3
            border.color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.6 * (1 - grow))
            visible: root.active && (root.effect === "echo" || root.effect === "reverb" || root.effect === "glitch")

            NumberAnimation on grow {
                id: growAnimation

                running: false
                from: 0
                to: 1
                duration: root.effect === "reverb" ? 1800 : 900
                easing.type: Easing.OutCubic
            }
            Connections {
                target: root

                function onBeatChanged() {
                    if (root.beat && root.active && ring.index === beatCounter.count % (root.lite ? 2 : 4)) {
                        growAnimation.restart();
                    }
                }
            }
        }
    }
    QtObject {
        id: beatCounter

        property int count: 0
    }
    Connections {
        target: root

        function onBeatChanged() {
            if (root.beat) {
                beatCounter.count += 1;
            }
        }
    }

    // ---- Bitcrush: blocks around the finger ----
    Repeater {
        model: root.effect === "bitcrush" && root.active && !root.lite ? 24 : 0

        Rectangle {
            required property int index
            readonly property real step: 18

            x: Math.round((root.fingerX + ((index % 6) - 3) * step) / step) * step
            y: Math.round((root.fingerY + (Math.floor(index / 6) - 2) * step) / step) * step
            width: step - 2
            height: step - 2
            color: root.color
            opacity: ((index * 37 + beatCounter.count * 11) % 10) / 14
        }
    }

    // ---- The trail of the finger ----
    Repeater {
        model: root.trail

        Rectangle {
            required property var modelData
            required property int index
            readonly property real fade: 1 - index / Math.max(1, root.trailLength)
            // The flanger makes it wobble, trans makes it blink on the beat
            readonly property real wobble: root.effect === "flanger" ? Math.sin(index * 0.9 + beatCounter.count) * 10 : 0

            x: modelData.x - width / 2 + wobble
            y: modelData.y - height / 2
            width: 6 + 18 * fade
            height: width
            radius: root.effect === "bitcrush" || root.effect === "glitch" ? 2 : width / 2
            color: root.color
            opacity: (root.effect === "trans" || root.effect === "gater") && !root.beat ? 0.25 * fade : 0.85 * fade
        }
    }

    // ---- Roll: the finger repeats in place on the beat ----
    Rectangle {
        visible: root.active && root.effect === "roll"
        x: root.fingerX - width / 2
        y: root.fingerY - height / 2
        width: root.beat ? 120 : 70
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 4
        border.color: root.color

        Behavior on width {
            NumberAnimation {
                duration: 70
            }
        }
    }

    // ---- The border pulses on every beat ----
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: 14
        border.width: root.beat ? 4 : 2
        border.color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.beat ? 0.9 : 0.35)

        Behavior on border.width {
            NumberAnimation {
                duration: 80
            }
        }
    }
    // Four dots: where the bar is
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        spacing: 6

        Repeater {
            model: 4

            Rectangle {
                required property int index

                width: 10
                height: 10
                radius: 5
                color: (beatCounter.count - 1 + 4) % 4 === index ? root.color : Style.buttonBorder
            }
        }
    }
}
