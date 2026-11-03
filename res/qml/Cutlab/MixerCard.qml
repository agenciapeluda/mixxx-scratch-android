import Mixxx 1.0 as Mixxx
import QtQuick

// The middle of the main screen, as in the design: what the FX of each deck
// does (tap to open its pad), the crossfader with its curve, and the level
// of each deck around MASTER.
Rectangle {
    id: root

    property real u: 1

    signal fxRequested(string group)

    function fs(px) {
        return Math.max(9, Math.round(px * root.u));
    }
    function effectName(id) {
        const names = {roll: "Roll", trans: "Trans", gater: "Gater", glitch: "Glitch", echo: "Echo", filter: qsTr("Filtro"), flanger: "Flanger", reverb: "Reverb", bitcrush: "Bitcrush"};
        return names[id] || id;
    }

    radius: Math.round(14 * u)
    color: Style.panel
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.07)

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

    implicitHeight: content.implicitHeight + 2 * Math.round(12 * root.u)

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: Math.round(12 * root.u)
        spacing: Math.round(10 * root.u)

        // FX of each deck
        Row {
            width: parent.width
            spacing: Math.round(8 * root.u)

            Repeater {
                model: ["[Channel1]", "[Channel2]"]

                Rectangle {
                    id: fxCard

                    required property string modelData
                    required property int index
                    readonly property bool on: [slot1, slot2, slot3].some(c => c.value > 0) || (index === 0 ? Shots.engaged1 : Shots.engaged2)

                    width: (parent.width - parent.spacing) / 2
                    height: fxColumn.implicitHeight + Math.round(16 * root.u)
                    radius: Math.round(10 * root.u)
                    color: fxMouse.pressed ? Style.buttonPressed : Style.track
                    border.width: on ? 1 : 0
                    border.color: Style.deckColor(modelData)

                    Column {
                        id: fxColumn

                        x: Math.round(10 * root.u)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 2 * x
                        spacing: 2

                        Text {
                            color: Style.textSecondary
                            font.family: Style.font
                            font.weight: Font.DemiBold
                            font.pixelSize: root.fs(10)
                            font.letterSpacing: 0.5
                            text: qsTr("FX %1 · %2").arg(fxCard.index + 1).arg(Style.deckLetter(fxCard.modelData))
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            color: Style.text
                            font.family: Style.font
                            font.weight: Font.DemiBold
                            font.pixelSize: root.fs(14)
                            text: root.effectName(fxCard.index === 0 ? Shots.effect1 : Shots.effect2)
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            color: fxCard.on ? Style.deckColor(fxCard.modelData) : Style.textDim
                            font.family: Style.font
                            font.weight: Font.Medium
                            font.pixelSize: root.fs(11)
                            text: fxCard.on ? qsTr("sonando") : qsTr("FX ON abre el pad")
                        }
                    }
                    MouseArea {
                        id: fxMouse

                        anchors.fill: parent
                        onClicked: root.fxRequested(fxCard.modelData)
                    }
                    Mixxx.ControlProxy {
                        id: slot1

                        group: `[EffectRack1_EffectUnit${fxCard.index + 1}_Effect1]`
                        key: "enabled"
                    }
                    Mixxx.ControlProxy {
                        id: slot2

                        group: `[EffectRack1_EffectUnit${fxCard.index + 1}_Effect2]`
                        key: "enabled"
                    }
                    Mixxx.ControlProxy {
                        id: slot3

                        group: `[EffectRack1_EffectUnit${fxCard.index + 1}_Effect3]`
                        key: "enabled"
                    }
                }
            }
        }

        // Crossfader
        Column {
            width: parent.width
            spacing: Math.round(6 * root.u)

            Item {
                width: parent.width
                height: curveText.implicitHeight

                Text {
                    color: Style.textSecondary
                    font.family: Style.font
                    font.weight: Font.DemiBold
                    font.pixelSize: root.fs(10)
                    text: "A"
                }
                Text {
                    id: curveText

                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Style.textSecondary
                    font.family: Style.font
                    font.weight: Font.DemiBold
                    font.pixelSize: root.fs(10)
                    font.letterSpacing: 0.5
                    text: qsTr("CROSSFADER · %1").arg(curve.value > 0.75 ? qsTr("CORTE FILOSO") : (curve.value > 0.35 ? qsTr("CORTE") : qsTr("MEZCLA")))
                }
                Text {
                    anchors.right: parent.right
                    color: Style.textSecondary
                    font.family: Style.font
                    font.weight: Font.DemiBold
                    font.pixelSize: root.fs(10)
                    text: "B"
                }
            }
            Item {
                id: track

                width: parent.width
                height: Math.round(22 * root.u)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Math.round(10 * root.u)
                    radius: height / 2
                    color: Style.track
                }
                Rectangle {
                    id: handle

                    anchors.verticalCenter: parent.verticalCenter
                    x: (crossfader.value + 1) / 2 * (track.width - width)
                    width: Math.round(10 * root.u)
                    height: Math.round(22 * root.u)
                    radius: 3
                    color: "#ffffff"
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -10
                    anchors.bottomMargin: -10
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

        // Levels
        Row {
            width: parent.width
            height: Math.round(34 * root.u)
            spacing: Math.round(4 * root.u)

            Repeater {
                model: ["[Channel1]", "[Master]", "[Channel2]"]

                Item {
                    id: level

                    required property string modelData
                    required property int index

                    width: index === 1 ? masterText.implicitWidth + 12 : (parent.width - masterText.implicitWidth - 12 - 2 * parent.spacing) / 2
                    height: parent.height

                    Text {
                        id: masterText

                        anchors.centerIn: parent
                        visible: parent.index === 1
                        color: Style.textDim
                        font.family: Style.mono
                        font.weight: Font.Medium
                        font.pixelSize: root.fs(10)
                        text: "MASTER"
                    }
                    Column {
                        visible: parent.index !== 1
                        anchors.bottom: parent.bottom
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: 5

                            Rectangle {
                                required property int index
                                readonly property real threshold: (5 - index) / 5

                                width: parent.width
                                height: Math.max(3, Math.round(4 * root.u))
                                radius: 2
                                color: index === 0 ? Style.danger : (index === 1 ? Style.cue : Style.ok)
                                opacity: vu.parameter >= threshold - 0.1 ? 1 : 0.12
                            }
                        }
                    }
                    Mixxx.ControlProxy {
                        id: vu

                        group: level.modelData
                        key: "vu_meter"
                    }
                }
            }
        }
    }
}
