import QtQuick

// Breaks and pauses as shaded bands over the overview of the track, drops
// as a red line with a mark on top. Nothing here moves with the beat: the
// countdown to the drop pulses in the platter.
Item {
    id: root

    property var sections: []
    property int barsToDrop: -1
    property real nextDropStart: -1
    property bool beat: false

    Repeater {
        model: root.sections

        Item {
            id: mark

            required property var modelData
            readonly property bool band: modelData.type === "break" || modelData.type === "pause"
            readonly property bool drop: modelData.type === "drop"

            x: modelData.start * root.width
            width: Math.max(2, (modelData.end - modelData.start) * root.width)
            height: root.height

            Rectangle {
                anchors.fill: parent
                visible: mark.band
                color: mark.modelData.type === "pause" ? Qt.rgba(0.61, 0.63, 0.72, 0.2) : Qt.rgba(1, 0.71, 0.28, 0.18)

                Rectangle {
                    width: parent.width
                    height: 3
                    color: mark.modelData.type === "pause" ? Style.sectionPause : Style.sectionBreak
                }
            }
            Rectangle {
                width: 2
                height: parent.height
                visible: mark.modelData.type === "intro" || mark.modelData.type === "outro"
                x: mark.modelData.type === "intro" ? parent.width - 1 : 0
                color: Style.sectionIntro
                opacity: 0.8
            }
            // The drop: only the mark, still (the platter pulses for it)
            Item {
                visible: mark.drop
                width: 1
                height: parent.height

                Rectangle {
                    x: -1.5
                    width: 3
                    height: parent.height
                    color: Style.sectionDrop
                }
                Rectangle {
                    x: -5
                    width: 10
                    height: parent.height
                    color: Style.sectionDrop
                    opacity: 0.18
                }
                // The mark on top
                Canvas {
                    x: -7
                    y: -1
                    width: 14
                    height: 10
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = Style.sectionDrop;
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(14, 0);
                        ctx.lineTo(7, 10);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }
        }
    }
}
