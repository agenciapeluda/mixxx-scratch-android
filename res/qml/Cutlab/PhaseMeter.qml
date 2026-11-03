import Mixxx 1.0 as Mixxx
import QtQuick

// How far deck B is from deck A: the dot sits on the green line when the
// beats land together, left when B is behind, right when it is ahead. Below,
// the gap in milliseconds and the tempo difference, to fix it with sync or
// by ear (and by hand on the pitch with DVS).
Item {
    id: root

    property string leader: "[Channel1]"
    property string follower: "[Channel2]"
    property bool vertical: false
    readonly property bool active: playA.value > 0 && playB.value > 0 && bpmA.value > 0 && bpmB.value > 0
    // From -0.5 to 0.5 beats
    readonly property real offset: {
        let d = beatB.value - beatA.value;
        if (d > 0.5) {
            d -= 1;
        } else if (d < -0.5) {
            d += 1;
        }
        return d;
    }
    readonly property real offsetMs: offset * 60000 / Math.max(1, bpmA.value)
    readonly property real tempoGap: bpmB.value - bpmA.value
    readonly property bool inPhase: Math.abs(offsetMs) < 12
    readonly property bool sameTempo: Math.abs(tempoGap) < 0.05

    implicitWidth: vertical ? 34 : 260
    implicitHeight: vertical ? 220 : 40

    Mixxx.ControlProxy {
        id: beatA

        group: root.leader
        key: "beat_distance"
    }
    Mixxx.ControlProxy {
        id: beatB

        group: root.follower
        key: "beat_distance"
    }
    Mixxx.ControlProxy {
        id: bpmA

        group: root.leader
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: bpmB

        group: root.follower
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: playA

        group: root.leader
        key: "play_latched"
    }
    Mixxx.ControlProxy {
        id: playB

        group: root.follower
        key: "play_latched"
    }

    Rectangle {
        id: bar

        width: root.vertical ? 22 : root.width
        height: root.vertical ? root.height - 18 : 22
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Math.min(width, height) / 2
        color: Style.background
        border.width: 1
        border.color: Style.buttonBorder
        opacity: root.active ? 1 : 0.5

        Rectangle {
            x: root.vertical ? 3 : parent.width / 2 - 1
            y: root.vertical ? parent.height / 2 - 1 : 3
            width: root.vertical ? parent.width - 6 : 2
            height: root.vertical ? 2 : parent.height - 6
            color: Style.ok
        }
        Rectangle {
            id: dot

            readonly property real travel: (root.vertical ? bar.height : bar.width) / 2 - 12
            width: 12
            height: 12
            radius: 6
            color: root.inPhase ? Style.ok : (Math.abs(root.offsetMs) < 40 ? Style.cue : Style.danger)
            visible: root.active
            x: root.vertical ? (bar.width - width) / 2 : bar.width / 2 - 6 + root.offset * 2 * travel
            y: root.vertical ? bar.height / 2 - 6 - root.offset * 2 * travel : (bar.height - height) / 2

            Behavior on x {
                SmoothedAnimation {
                    velocity: 600
                }
            }
            Behavior on y {
                SmoothedAnimation {
                    velocity: 600
                }
            }
        }
    }
    // ATRÁS and ADELANTE at the ends of the bar, as in the design
    Text {
        visible: !root.vertical
        anchors.left: bar.left
        anchors.leftMargin: 10
        anchors.verticalCenter: bar.verticalCenter
        color: Style.textSecondary
        font.family: Style.mono
        font.weight: Font.Bold
        font.pixelSize: 9
        text: qsTr("ATRÁS")
    }
    Text {
        visible: !root.vertical
        anchors.right: bar.right
        anchors.rightMargin: 10
        anchors.verticalCenter: bar.verticalCenter
        color: Style.textSecondary
        font.family: Style.mono
        font.weight: Font.Bold
        font.pixelSize: 9
        text: qsTr("ADELANTE")
    }
    Rectangle {
        anchors.centerIn: phaseLabel
        visible: phaseLabel.visible
        width: phaseLabel.implicitWidth + 16
        height: phaseLabel.implicitHeight + 2
        radius: height / 2
        color: Style.background
    }
    Text {
        id: phaseLabel

        anchors.top: bar.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.vertical
        color: root.active && root.inPhase && root.sameTempo ? Style.ok : Style.textSecondary
        font.family: Style.mono
        font.weight: Font.Bold
        font.pixelSize: 10
        text: {
            if (!root.active) {
                return qsTr("FASE · con los dos decks sonando");
            }
            const ms = Math.round(root.offsetMs);
            const gap = root.sameTempo ? qsTr("TEMPO IGUAL")
                : qsTr("B %1%2 BPM").arg(root.tempoGap > 0 ? "+" : "").arg(root.tempoGap.toFixed(1));
            return qsTr("B %1%2 ms · %3").arg(ms > 0 ? "+" : "").arg(ms).arg(gap);
        }
    }
}
