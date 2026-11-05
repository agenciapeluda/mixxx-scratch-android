import Mixxx 1.0 as Mixxx
import QtQuick

// The mixer of the bottom bar, like djay: the volume fader of each deck
// with its level, and the crossfader between them. Double tap a fader to
// reset it.
Item {
    id: root

    property real u: 1

    function fs(px) {
        return Math.max(9, Math.round(px * root.u));
    }

    Mixxx.ControlProxy {
        id: crossfader

        group: "[Master]"
        key: "crossfader"
    }
    Mixxx.ControlProxy {
        id: curve

        group: "[Mixer Profile]"
        key: "xFaderCurve"
    }

    readonly property real faderWidth: Math.round(52 * u)
    readonly property real vuWidth: Math.max(4, Math.round(6 * u))
    readonly property real gap: Math.round(8 * u)

    Repeater {
        model: ["[Channel1]", "[Channel2]"]

        Item {
            id: channel

            required property string modelData
            required property int index

            x: index === 0 ? 0 : root.width - width
            width: root.vuWidth + root.gap / 2 + root.faderWidth
            height: root.height

            VuBar {
                x: channel.index === 0 ? 0 : parent.width - width
                width: root.vuWidth
                height: parent.height - Math.round(8 * root.u)
                anchors.verticalCenter: parent.verticalCenter
                group: channel.modelData
                segments: 10
            }
            CLFader {
                x: channel.index === 0 ? root.vuWidth + root.gap / 2 : 0
                width: root.faderWidth
                height: parent.height
                group: channel.modelData
                key: "volume"
                ticks: 5
                handleColor: Style.deckColor(channel.modelData)
                handleLength: Math.min(width * 0.9, Math.round(44 * root.u))
                handleThickness: Math.round(18 * root.u)
            }
        }
    }

    // Crossfader
    Item {
        id: xfader

        x: root.vuWidth + root.faderWidth + root.gap * 2
        width: root.width - 2 * x
        height: root.height

        Text {
            id: curveText

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(4 * root.u)
            color: Style.textSecondary
            font.family: Style.font
            font.weight: Font.DemiBold
            font.pixelSize: root.fs(10)
            font.letterSpacing: 0.5
            text: qsTr("A · CROSSFADER · %1 · B").arg(curve.value > 0.75 ? qsTr("CORTE FILOSO") : (curve.value > 0.35 ? qsTr("CORTE") : qsTr("MEZCLA")))
        }
        Item {
            id: track

            anchors.top: curveText.bottom
            anchors.bottom: parent.bottom
            width: parent.width

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Math.round(10 * root.u)
                radius: height / 2
                color: Style.track
            }
            Rectangle {
                anchors.centerIn: parent
                width: 2
                height: Math.round(18 * root.u)
                color: Style.tick
            }
            Rectangle {
                id: handle

                anchors.verticalCenter: parent.verticalCenter
                x: (crossfader.value + 1) / 2 * (track.width - width)
                width: Math.round(18 * root.u)
                height: Math.round(40 * root.u)
                radius: Math.round(5 * root.u)
                color: "#ffffff"

                Rectangle {
                    anchors.centerIn: parent
                    width: 2
                    height: parent.height * 0.6
                    color: "#8c8c92"
                }
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                function set(x) {
                    crossfader.value = Math.max(-1, Math.min(1, (x - handle.width / 2) / (track.width - handle.width) * 2 - 1));
                }
                onPressed: mouse => set(mouse.x)
                onPositionChanged: mouse => set(mouse.x)
                onDoubleClicked: crossfader.value = 0
            }
        }
    }
}
