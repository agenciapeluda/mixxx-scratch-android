import Mixxx 1.0 as Mixxx
import QtQuick

// Scratch, one tool for the deck it is open on:
//  - letsktch!: the voice of the track on this deck, its own beat looping
//    on a hidden deck
//  - the bank: capture 1/2/4/8 beats from A or B, tap a slot and the phrase
//    goes to THIS deck, looped (only the voice with "Voz" on)
//  - "Volver al tema": the track, place, loop and stems from before
Rectangle {
    id: root

    required property string group
    // ScratchEngine and Letsktch of the main screen
    required property var engine
    required property var letsktch

    readonly property bool compact: width < 640
    readonly property bool hasStems: root.engine ? root.engine.stemsOf(root.group).count > 0 : false
    readonly property bool letsktchHere: root.letsktch && root.letsktch.group === root.group
    readonly property bool letsktchBusy: root.letsktchHere && root.letsktch.busy
    readonly property bool canReturn: root.engine ? !!root.engine.savedOf(root.group) : false
    readonly property int fired: root.engine ? root.engine.firedOf(root.group) : -1
    readonly property real unitWidth: (captureRow.width - 6 * captureRow.spacing) / 9.6

    color: Style.panelDark

    // ---- letsktch! and the way back ----
    Row {
        id: topRow

        x: 10
        y: 10
        width: parent.width - 20
        height: root.compact ? 40 : 44
        spacing: root.compact ? 6 : 8

        CLButton {
            width: root.canReturn ? (topRow.width - topRow.spacing) * 0.62 : topRow.width
            height: topRow.height
            radius: height / 2
            enabled: root.hasStems || root.letsktchHere
            text: {
                if (root.letsktchBusy) {
                    return qsTr("letsktch!  ·  armando… (%1)").arg(root.letsktch.stepText);
                }
                if (root.letsktchHere) {
                    return qsTr("letsktch!  ·  tocá para volver al tema");
                }
                if (!root.hasStems) {
                    return qsTr("letsktch!  ·  separá el tema en stems");
                }
                return root.compact ? qsTr("letsktch!  ·  voz al plato") : qsTr("letsktch!  ·  voz al plato, beat en loop");
            }
            fontSize: root.compact ? 12 : 14
            fontWeight: Font.Bold
            highlighted: root.letsktchHere && !root.letsktchBusy
            lit: root.letsktchBusy
            litColor: Style.stemVocals
            textColor: root.letsktchHere && !root.letsktchBusy ? Style.background : Style.stemVocals
            onClicked: root.letsktch.toggle(root.group)
        }
        CLButton {
            visible: root.canReturn
            width: (topRow.width - topRow.spacing) * 0.38
            height: topRow.height
            radius: height / 2
            icon: "back"
            iconSize: height * 0.4
            text: qsTr("Volver al tema")
            fontSize: root.compact ? 12 : 13
            fontWeight: Font.DemiBold
            lit: true
            litColor: Style.deckColor(root.group)
            onClicked: root.engine.returnToTrack(root.group)
        }
    }

    // ---- Capture: from which deck, how many beats, voice or all ----
    Row {
        id: captureRow

        x: 10
        anchors.top: topRow.bottom
        anchors.topMargin: 8
        width: parent.width - 20
        height: root.compact ? 40 : 44
        spacing: root.compact ? 6 : 8

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            CLButton {
                required property string modelData

                width: root.unitWidth * 2.2
                height: captureRow.height
                radius: 10
                text: root.compact ? qsTr("Capturar %1").arg(Style.deckLetter(modelData)) : qsTr("Capturar de %1").arg(Style.deckLetter(modelData))
                fontSize: root.compact ? 12 : 13
                fontWeight: Font.DemiBold
                litColor: Style.deckColor(modelData)
                lit: true
                onClicked: root.engine.capture(modelData, -1)
            }
        }
        Repeater {
            model: [1, 2, 4, 8]

            CLButton {
                required property real modelData

                width: root.unitWidth * 0.9
                height: captureRow.height
                radius: 10
                text: String(modelData)
                fontSize: 13
                highlighted: root.engine.captureBeats === modelData
                onClicked: root.engine.setCaptureBeats(modelData)
            }
        }
        CLButton {
            width: root.unitWidth * 1.6
            height: captureRow.height
            radius: 10
            text: root.compact ? qsTr("Voz") : qsTr("Solo voz")
            fontSize: root.compact ? 12 : 13
            highlighted: root.engine.voiceOnly
            litColor: Style.stemVocals
            onClicked: root.engine.setVoiceOnly(!root.engine.voiceOnly, root.group)
        }
    }

    // ---- What to do now ----
    Text {
        id: hint

        x: 12
        anchors.top: captureRow.bottom
        anchors.topMargin: 6
        width: parent.width - 24
        height: visible ? 16 : 0
        visible: root.height > 260
        color: Style.textSecondary
        font.family: Style.font
        font.pixelSize: 12
        elide: Text.ElideRight
        text: {
            if (!root.engine.hasPhrase) {
                return qsTr("Mientras suena la frase, tocá «Capturar» o un casillero vacío. Mantené un casillero para borrarlo.");
            }
            if (root.fired < 0) {
                return qsTr("Tocá un casillero: la frase va al deck %1 en loop.").arg(Style.deckLetter(root.group));
            }
            return qsTr("Scratcheá con el vinilo o el jog del deck %1.").arg(Style.deckLetter(root.group));
        }
    }

    // ---- The slots ----
    Grid {
        id: grid

        anchors.top: hint.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 10
        columns: 4
        spacing: 8

        Repeater {
            model: 8

            Rectangle {
                id: slotPad

                required property int index
                readonly property var slot: root.engine.slots[index] || null
                readonly property bool onDeck: root.fired === index

                width: (grid.width - grid.spacing * 3) / 4
                height: (grid.height - grid.spacing) / 2
                radius: 12
                color: slotMouse.pressed ? Style.buttonPressed : (onDeck ? Style.accentDark : (slot ? Style.raised : Style.panel))
                border.width: onDeck ? 2 : 1
                border.color: slot ? Style.deckColor(root.group) : Style.divider
                scale: slotMouse.pressed ? 0.97 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 70
                    }
                }

                Text {
                    x: 10
                    y: 8
                    visible: slotPad.height > 56
                    color: Style.textSecondary
                    font.family: Style.mono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    text: String(slotPad.index + 1)
                }
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 10
                    spacing: 3

                    Text {
                        width: parent.width
                        color: slotPad.slot ? Style.text : Style.textDim
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Style.font
                        font.pixelSize: slotPad.height > 56 ? 14 : 12
                        font.weight: Font.DemiBold
                        text: slotPad.slot ? slotPad.slot.title : qsTr("vacío")
                    }
                    Text {
                        width: parent.width
                        visible: !!slotPad.slot && slotPad.height > 56
                        color: Style.textSecondary
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Style.mono
                        font.pixelSize: 11
                        text: slotPad.slot ? qsTr("%1 tiempos").arg(slotPad.slot.beats) : ""
                    }
                }
                MouseArea {
                    id: slotMouse

                    anchors.fill: parent
                    pressAndHoldInterval: 700
                    onClicked: {
                        if (slotPad.slot) {
                            root.engine.fire(slotPad.index, root.group);
                        } else {
                            // An empty slot captures from the deck that plays
                            root.engine.capture(play2.value > 0 && play1.value <= 0 ? "[Channel2]" : "[Channel1]", slotPad.index);
                        }
                    }
                    onPressAndHold: root.engine.clear(slotPad.index)
                }
            }
        }
    }
    Mixxx.ControlProxy {
        id: play1

        group: "[Channel1]"
        key: "play_latched"
    }
    Mixxx.ControlProxy {
        id: play2

        group: "[Channel2]"
        key: "play_latched"
    }
}
