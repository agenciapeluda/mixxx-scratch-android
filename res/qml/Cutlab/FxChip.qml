import Mixxx 1.0 as Mixxx
import QtQuick

// What the FX of a deck does, next to its platter: the effect picked for
// its FX pad and whether it sounds. Tap it to open the pad (FX ON on the
// controller opens it too).
Rectangle {
    id: root

    required property string group
    property real u: 1

    readonly property int unit: group === "[Channel2]" ? 2 : 1
    readonly property bool on: [slot1, slot2, slot3].some(c => c.value > 0) || (unit === 1 ? Shots.engaged1 : Shots.engaged2)

    signal requested

    function fs(px) {
        return Math.max(9, Math.round(px * root.u));
    }
    function effectName(id) {
        const names = {roll: "Roll", trans: "Trans", gater: "Gater", glitch: "Glitch", echo: "Echo", filter: qsTr("Filtro"), flanger: "Flanger", reverb: "Reverb", bitcrush: "Bitcrush"};
        return names[id] || id;
    }

    implicitHeight: column.implicitHeight + Math.round(16 * u)
    radius: Math.round(10 * u)
    color: mouse.pressed ? Style.buttonPressed : Style.track
    border.width: on ? 1 : 0
    border.color: Style.deckColor(group)

    Column {
        id: column

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
            text: qsTr("FX %1 · %2").arg(root.unit).arg(Style.deckLetter(root.group))
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            color: Style.text
            font.family: Style.font
            font.weight: Font.DemiBold
            font.pixelSize: root.fs(14)
            text: root.effectName(root.unit === 1 ? Shots.effect1 : Shots.effect2)
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            color: root.on ? Style.deckColor(root.group) : Style.textDim
            font.family: Style.font
            font.weight: Font.Medium
            font.pixelSize: root.fs(11)
            text: root.on ? qsTr("sonando") : qsTr("tocá o FX ON")
        }
    }
    MouseArea {
        id: mouse

        anchors.fill: parent
        onClicked: root.requested()
    }
    Mixxx.ControlProxy {
        id: slot1

        group: `[EffectRack1_EffectUnit${root.unit}_Effect1]`
        key: "enabled"
    }
    Mixxx.ControlProxy {
        id: slot2

        group: `[EffectRack1_EffectUnit${root.unit}_Effect2]`
        key: "enabled"
    }
    Mixxx.ControlProxy {
        id: slot3

        group: `[EffectRack1_EffectUnit${root.unit}_Effect3]`
        key: "enabled"
    }
}
