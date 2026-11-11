import QtQuick

// The Scratch pads of a deck (letsktch!): 8 slots of the track.
// - empty: keeps the place (from the beat before) and the beats, and plays
// - kept: jumps to its phrase and plays
// - playing: tap to leave (the track is back where it would have been)
// - hold to clear (SHIFT + pad on a controller)
// On top: the beats of a new slot and the stem to scratch. Gray, with
// "Separar", when the track has no stems.
Item {
    id: root

    required property string group
    // LetsktchDeck of the deck
    required property var engine
    property real spacing: 4

    readonly property real headerHeight: Math.max(26, Math.min(34, root.height * 0.2))
    // The blink of the playing slot
    property bool blink: true

    Timer {
        interval: 260
        repeat: true
        running: root.visible && !!root.engine && root.engine.active
        onRunningChanged: root.blink = true
        onTriggered: root.blink = !root.blink
    }

    // ---- Tiempos [1 2 4 8] · Scratchear: Voz ▾ ----
    Row {
        id: header

        width: parent.width
        height: root.headerHeight
        spacing: 6
        enabled: !!root.engine && root.engine.hasStems
        opacity: enabled ? 1 : 0.4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 12
            text: qsTr("Tiempos")
        }
        Repeater {
            model: [1, 2, 4, 8]

            CLButton {
                required property int modelData

                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(header.height * 1.1)
                height: header.height - 4
                radius: height / 2
                text: String(modelData)
                fontSize: 12
                fontWeight: Font.Bold
                highlighted: root.engine && root.engine.beats === modelData
                litColor: Style.deckColor(root.group)
                onClicked: root.engine.setBeats(modelData)
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Style.textDim
            font.family: Style.font
            font.pixelSize: 12
            text: "·"
        }
        CLButton {
            id: stemButton

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(90, header.width - x)
            height: header.height - 4
            radius: height / 2
            text: qsTr("Scratchear: %1 ▾").arg(root.engine ? root.engine.stemName(root.engine.scratchStem || root.engine.stem) : qsTr("Voz"))
            fontSize: 12
            fontWeight: Font.DemiBold
            onClicked: stemMenu.popup(stemButton, 0, stemButton.height)
        }
    }
    CLMenu {
        id: stemMenu

        Repeater {
            model: root.engine ? root.engine.stemLabels : []

            CLMenuItem {
                required property string modelData

                text: (root.engine.scratchStem === modelData ? "✓  " : "    ") + root.engine.stemName(modelData)
                onTriggered: root.engine.setStem(modelData)
            }
        }
    }

    // ---- The 8 slots ----
    Grid {
        id: pads

        y: header.height + root.spacing
        width: parent.width
        height: parent.height - y
        columns: 4
        rows: 2
        spacing: root.spacing
        enabled: !!root.engine && root.engine.hasStems

        Repeater {
            model: 8

            Pad {
                id: pad

                required property int index
                readonly property var slot: root.engine ? root.engine.slots[index] : null
                readonly property int slotState: root.engine ? root.engine.slotState(index) : 0

                width: (pads.width - (pads.columns - 1) * pads.spacing) / pads.columns
                height: (pads.height - (pads.rows - 1) * pads.spacing) / pads.rows
                tag: String(index + 1)
                text: pad.slot ? qsTr("%1 t").arg(pad.slot.b) : ""
                detail: pad.slotState === 2 && root.engine.beatPending ? qsTr("cargando…") : ""
                padColor: pad.slotState > 0 ? Style.deckColor(root.group) : "transparent"
                active: pad.slotState === 2 && root.blink
                dimmed: !pads.enabled

                onClicked: root.engine.press(index)
                onPressAndHold: root.engine.clear(index)
            }
        }
    }

    StemsMissing {
        anchors.fill: pads
        visible: !!root.engine && !root.engine.hasStems
        group: root.group
    }
}
