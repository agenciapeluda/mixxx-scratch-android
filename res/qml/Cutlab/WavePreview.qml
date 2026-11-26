import Mixxx 1.0 as Mixxx
import QtQuick

// The preview of the waveform colors in the settings: a made-up stretch of
// track (kicks, a voice, hats) for deck A and deck B, in the colors picked
// and drawn the way of the type picked, so a change shows on the tap.
Item {
    id: root

    // "rgb", "deck" or "config" (Clásico)
    property string colors: Style.waveColors
    // Mixxx.WaveformDisplay.Type
    property int waveformType: Mixxx.Config.waveformType

    Column {
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            Rectangle {
                id: lane

                required property string modelData
                required property int index

                width: parent.width
                height: (root.height - 4) / 2
                radius: 6
                color: Style.panelDark

                Canvas {
                    id: canvas

                    readonly property var set: Style.waveColorSet(root.colors, root.waveformType, lane.modelData)

                    anchors.fill: parent
                    anchors.margins: 2
                    renderStrategy: Canvas.Immediate

                    onSetChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    // The bands of a made-up track at x (0..1): lows on the
                    // beat, a voice that comes and goes, hats in between
                    function bands(t, seed) {
                        const beat = (t * 16 + seed * 0.25) % 1;
                        const low = Math.max(0.15, Math.exp(-beat * 6)) * 0.95;
                        const voice = 0.5 + 0.5 * Math.sin(t * 9 + seed * 2);
                        const mid = 0.25 + 0.45 * voice * (0.7 + 0.3 * Math.sin(t * 140 + seed));
                        const hat = ((t * 32 + 0.5 + seed * 0.1) % 1);
                        const high = 0.12 + 0.4 * Math.exp(-hat * 9);
                        return [low, mid, high];
                    }
                    function mix(a, b, c, low, mid, high) {
                        let r = low * a.r + mid * b.r + high * c.r;
                        let g = low * a.g + mid * b.g + high * c.g;
                        let bl = low * a.b + mid * b.b + high * c.b;
                        const max = Math.max(r, g, bl, 0.0001);
                        return Qt.rgba(r / max, g / max, bl / max, 1);
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const w = width;
                        const h = height;
                        const middle = h / 2;
                        const lowColor = Qt.lighter(canvas.set.low, 1);
                        const midColor = Qt.lighter(canvas.set.mid, 1);
                        const highColor = Qt.lighter(canvas.set.high, 1);
                        const simpleColor = Qt.lighter(canvas.set.simple, 1);
                        const type = root.waveformType;
                        const step = 2;
                        for (let x = 0; x < w; x += step) {
                            const b = bands(x / Math.max(1, w), lane.index);
                            const all = Math.min(1, (b[0] + b[1] + b[2]) / 1.6);
                            if (type === Mixxx.WaveformDisplay.Type.Simple) {
                                ctx.fillStyle = String(simpleColor);
                                ctx.fillRect(x, middle - all * middle, step, all * h);
                            } else if (type === Mixxx.WaveformDisplay.Type.RGB || type === Mixxx.WaveformDisplay.Type.HSV) {
                                ctx.fillStyle = String(mix(lowColor, midColor, highColor, b[0], b[1], b[2]));
                                ctx.fillRect(x, middle - all * middle, step, all * h);
                            } else {
                                // Filtered and Stacked: the bands one over the other
                                const layers = [[lowColor, b[0]], [midColor, b[1] * 0.8], [highColor, b[2] * 0.6]];
                                for (let i = 0; i < layers.length; ++i) {
                                    const amp = Math.min(1, layers[i][1]);
                                    ctx.fillStyle = String(layers[i][0]);
                                    ctx.fillRect(x, middle - amp * middle, step, amp * h);
                                }
                            }
                        }
                        // The playhead
                        ctx.fillStyle = String(Style.playhead);
                        ctx.fillRect(Math.round(w / 2), 0, 1, h);
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 4
                    color: Style.text
                    font.family: Style.font
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    style: Text.Outline
                    styleColor: Style.background
                    text: lane.index === 0 ? "A" : "B"
                }
            }
        }
    }
}
