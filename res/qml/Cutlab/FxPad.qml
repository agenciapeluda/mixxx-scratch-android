import Mixxx 1.0 as Mixxx
import QtQuick

// The FX pad of a deck: pick an effect (rhythm or ambience), play it with
// the finger on the surface, fire the one shots on the side, choose the
// beat fraction below. The surface draws a game-like layer of its own.
// What plays is the FxEngine of the deck (Shots.engineFor), which lives the
// whole session: a controller plays it with the pad closed, and opening or
// closing the pad changes nothing of the audio.
Item {
    id: root

    required property string group
    // Scale: from its own size, so it fits the half of a deck or the whole
    // width without anything over anything
    property real u: Math.max(0.6, Math.min(1.15, width / 620, height / 430))
    readonly property int unitNumber: group === "[Channel2]" ? 2 : 1
    readonly property var shots: Shots.forGroup(group)
    readonly property var engine: Shots.engineFor(group)
    readonly property bool dvs: vinylEnabled.value > 0
    readonly property color deckColor: Style.deckColor(group)

    readonly property string effect: engine ? engine.effect : Shots.effectFor(group)
    readonly property bool engaged: engine ? engine.engaged : false
    readonly property bool engagedPlaying: engine ? engine.engagedPlaying : false
    readonly property real liveFraction: engine ? engine.liveFraction : 0.5
    readonly property real fraction: engine ? engine.fraction : 0.5
    readonly property bool hold: engine ? engine.hold : false
    readonly property bool playing: engine ? engine.playing : false
    property bool liteVisuals: Mixxx.Application.configValue("[Cutlab]", "fx_visuals_lite", "0") === "1"

    readonly property var rhythmEffects: [
        {id: "roll", name: qsTr("Roll")},
        {id: "trans", name: qsTr("Trans")},
        {id: "gater", name: qsTr("Gater")},
        {id: "glitch", name: qsTr("Glitch")}
    ]
    readonly property var ambientEffects: [
        {id: "echo", name: qsTr("Echo")},
        {id: "filter", name: qsTr("Filtro")},
        {id: "flanger", name: qsTr("Flanger")},
        {id: "reverb", name: qsTr("Reverb")},
        {id: "bitcrush", name: qsTr("Bitcrush")}
    ]
    readonly property var fractions: [0.125, 0.25, 0.5, 0.75, 1, 2, 4]
    readonly property var liveFractions: [0.0625, 0.125, 0.25, 0.5, 1]

    function fractionText(beats) {
        if (beats === 0.75) {
            return "3/4";
        }
        return beats >= 1 ? String(beats) : "1/" + Math.round(1 / beats);
    }
    function start(x, y) {
        if (root.engine) {
            root.engine.start(x, y, false);
        }
    }
    function stop() {
        if (root.engine) {
            root.engine.stop();
        }
    }
    function pick(effect) {
        if (root.engine) {
            root.engine.pick(effect);
        }
    }
    function setFraction(beats) {
        if (root.engine) {
            root.engine.fraction = beats;
        }
    }
    function toggleHold() {
        if (root.engine) {
            root.engine.hold = !root.engine.hold;
            if (!root.engine.hold) {
                root.engine.stop();
            }
        }
    }
    function fingerUp() {
        if (root.engine) {
            root.engine.fingerUp();
        }
    }

    Mixxx.ControlProxy {
        id: beatActive

        group: root.group
        key: "beat_active"
    }
    Mixxx.ControlProxy {
        id: vinylEnabled

        group: root.group
        key: "vinylcontrol_enabled"
    }

    // The pad closed while the finger held an effect (HOLD) that no
    // controller plays: it stops, as before
    Component.onDestruction: {
        if (root.engine && !root.engine.engaged) {
            root.engine.stop();
        }
    }

    // ---- Effects: RITMO and AMBIENTE, as in the design ----
    // One row that scrolls sideways: it never wraps over the pad
    Flickable {
        id: chips

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round(36 * root.u)
        contentWidth: chipRow.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Row {
            id: chipRow

            height: chips.height
            spacing: Math.round(6 * root.u)

        Repeater {
            model: [{header: qsTr("RITMO")}].concat(root.rhythmEffects).concat([{header: qsTr("AMBIENTE")}]).concat(root.ambientEffects)

            Item {
                id: chip

                required property var modelData
                required property int index
                readonly property bool isHeader: modelData.header !== undefined
                readonly property bool picked: !isHeader && root.effect === modelData.id

                width: isHeader ? headerText.implicitWidth + (index > 0 ? Math.round(10 * root.u) : 0) + Math.round(6 * root.u) : chipText.implicitWidth + Math.round(26 * root.u)
                height: Math.round(36 * root.u)

                Text {
                    id: headerText

                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(4 * root.u)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.isHeader
                    color: Style.textSecondary
                    font.family: Style.font
                    font.pixelSize: Math.max(8, Math.round(10 * root.u))
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                    text: chip.isHeader ? chip.modelData.header : ""
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !chip.isHeader
                    radius: 0
                    color: chip.picked ? Style.deckColor(root.group) : (chipMouse.pressed ? Style.buttonPressed : "transparent")
                    border.width: 1
                    border.color: chip.picked ? Style.deckColor(root.group) : Qt.rgba(1, 1, 1, 0.14)

                    Text {
                        id: chipText

                        anchors.centerIn: parent
                        color: chip.picked ? "#ffffff" : Style.text
                        font.family: Style.font
                        font.weight: Font.DemiBold
                        font.pixelSize: Math.max(10, Math.round(13 * root.u))
                        text: chip.isHeader ? "" : chip.modelData.name
                    }
                    MouseArea {
                        id: chipMouse

                        anchors.fill: parent
                        onClicked: root.pick(chip.modelData.id)
                    }
                }
            }
        }
    }
    }

    // ---- Fractions and HOLD ----
    Row {
        id: fractionRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 0
        height: Math.round(44 * root.u)
        spacing: Math.round(6 * root.u)

        Repeater {
            model: root.fractions

            CLButton {
                required property var modelData

                width: (fractionRow.width - fractionRow.spacing * 7) / 8
                height: fractionRow.height
                radius: 0
                text: root.fractionText(modelData)
                fontSize: Math.max(10, Math.round(13 * root.u))
                highlighted: root.fraction === modelData
                onClicked: root.setFraction(modelData)
            }
        }
        CLButton {
            width: (fractionRow.width - fractionRow.spacing * 7) / 8
            height: fractionRow.height
            radius: 0
            text: qsTr("HOLD")
            fontSize: Math.max(10, Math.round(13 * root.u))
            highlighted: root.hold
            onClicked: root.toggleHold()
        }
    }

    readonly property bool narrow: width < 460

    // ---- One shots: a column on the side, a row when narrow ----
    Grid {
        id: shotColumn

        x: root.narrow ? 0 : root.width - width
        y: root.narrow ? fractionRow.y - height - gap : chips.y + chips.height + gap + shotLabel.height + Math.round(8 * root.u)
        width: root.narrow ? root.width : Math.round(118 * root.u)
        height: root.narrow ? Math.round(44 * root.u) : fractionRow.y - gap - y
        columns: root.narrow ? 4 : 1
        spacing: Math.round(8 * root.u)

        readonly property real gap: Math.round(12 * root.u)

        Repeater {
            model: [
                {code: 1, name: qsTr("Backspin"), detail: qsTr("2 tiempos"), hand: true},
                {code: 2, name: qsTr("Brake"), detail: qsTr("1 tiempo"), hand: true},
                {code: 3, name: qsTr("Censor"), detail: qsTr("mantener"), hand: false},
                {code: 4, name: qsTr("Echo out"), detail: qsTr("4 tiempos"), hand: false}
            ]

            Rectangle {
                id: shot

                required property var modelData
                readonly property bool blocked: modelData.hand && root.dvs

                width: root.narrow ? (shotColumn.width - 3 * shotColumn.spacing) / 4 : shotColumn.width
                height: root.narrow ? shotColumn.height : (shotColumn.height - 3 * shotColumn.spacing) / 4
                radius: 0
                color: shotMouse.pressed ? Style.buttonPressed : Style.raised
                border.width: 1
                border.color: shotMouse.pressed ? root.deckColor : Qt.rgba(1, 1, 1, 0.14)
                opacity: blocked ? 0.35 : 1
                scale: shotMouse.pressed ? 0.95 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 80
                    }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Style.text
                        font.family: Style.font
                        font.pixelSize: Math.max(10, Math.round(14 * root.u))
                        font.weight: Font.Bold
                        text: shot.modelData.name
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !root.narrow
                        color: Style.textSecondary
                        font.family: Style.mono
                        font.pixelSize: Math.max(8, Math.round(11 * root.u))
                        text: shot.blocked ? qsTr("con DVS, tu mano") : shot.modelData.detail
                    }
                }
                MouseArea {
                    id: shotMouse

                    anchors.fill: parent
                    enabled: !shot.blocked
                    onPressed: {
                        if (root.shots) {
                            root.shots.trigger(shot.modelData.code, true);
                        }
                        visuals.burst();
                    }
                    onReleased: {
                        if (root.shots && shot.modelData.code === 3) {
                            root.shots.trigger(3, false);
                        }
                    }
                    onCanceled: {
                        if (root.shots && shot.modelData.code === 3) {
                            root.shots.trigger(3, false);
                        }
                    }
                }
            }
        }
    }

    Text {
        id: shotLabel

        visible: !root.narrow
        x: shotColumn.x
        y: chips.y + chips.height + shotColumn.gap
        width: shotColumn.width
        horizontalAlignment: Text.AlignHCenter
        color: Style.textSecondary
        font.family: Style.font
        font.weight: Font.DemiBold
        font.pixelSize: Math.max(8, Math.round(10 * root.u))
        font.letterSpacing: 0.6
        text: qsTr("UN TOQUE")
    }

    // ---- The surface ----
    Rectangle {
        id: surface

        anchors.top: chips.bottom
        anchors.bottom: root.narrow ? shotColumn.top : fractionRow.top
        anchors.left: parent.left
        anchors.right: root.narrow ? parent.right : shotColumn.left
        anchors.topMargin: Math.round(12 * root.u)
        anchors.bottomMargin: Math.round(12 * root.u)
        anchors.rightMargin: root.narrow ? 0 : Math.round(12 * root.u)
        radius: 0
        color: Style.raised
        border.width: 1
        border.color: Qt.rgba(root.deckColor.r, root.deckColor.g, root.deckColor.b, 0.35)
        clip: true

        // The center lines
        Rectangle {
            y: parent.height / 2
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }
        Rectangle {
            x: parent.width / 2
            width: 1
            height: parent.height
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // The zones of the rhythm: where the finger is, that fraction plays
        Row {
            anchors.fill: parent
            visible: root.effect === "roll" || root.effect === "trans" || root.effect === "gater" || root.effect === "glitch"

            Repeater {
                model: root.liveFractions

                Item {
                    required property var modelData
                    required property int index
                    readonly property bool live: root.playing && root.liveFraction === modelData

                    width: surface.width / root.liveFractions.length
                    height: surface.height

                    Rectangle {
                        anchors.fill: parent
                        color: root.deckColor
                        opacity: parent.live ? 0.16 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 90
                            }
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: Style.divider
                        visible: parent.index < root.liveFractions.length - 1
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 30
                        color: parent.live ? Style.text : Style.textSecondary
                        font.family: Style.mono
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        text: root.fractionText(parent.modelData)
                    }
                }
            }
        }

        FxVisuals {
            id: visuals

            function burst() {
                // A one shot flashes the border
                flash.restart();
            }

            anchors.fill: parent
            effect: root.effect
            active: root.playing
            fingerX: touch.mouseX
            fingerY: touch.mouseY
            beat: beatActive.value > 0
            color: root.deckColor
            lite: root.liteVisuals
        }
        Rectangle {
            id: flashRect

            anchors.fill: parent
            radius: 0
            color: root.deckColor
            opacity: 0

            SequentialAnimation {
                id: flash

                NumberAnimation {
                    target: flashRect
                    property: "opacity"
                    to: 0.35
                    duration: 60
                }
                NumberAnimation {
                    target: flashRect
                    property: "opacity"
                    to: 0
                    duration: 380
                    easing.type: Easing.OutQuad
                }
            }
        }

        // The finger
        Rectangle {
            visible: root.playing
            x: touch.mouseX - width / 2
            y: touch.mouseY - height / 2
            width: Math.round(44 * root.u)
            height: width
            radius: 0
            color: Style.deckColor(root.group)
            border.width: 3
            border.color: "#ffffff"
        }
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Math.round(14 * root.u)
            color: Style.deckLight(root.group)
            font.family: Style.mono
            font.pixelSize: Math.max(9, Math.round(12 * root.u))
            font.weight: Font.Bold
            text: root.engagedPlaying && !touch.pressed ? qsTr("PALANCA ON · %1").arg(root.fractionText(root.liveFraction))
                : (root.effect === "roll" || root.effect === "trans" || root.effect === "gater" || root.effect === "glitch") && root.playing
                ? qsTr("%1 %2 · arrastrá ← →").arg(root.effect.toUpperCase()).arg(root.fractionText(root.liveFraction))
                : root.playing && root.effect === "echo" ? qsTr("MIX %1% · FB %2%").arg(Math.round(touch.mouseX / Math.max(1, surface.width) * 100)).arg(Math.round((1 - touch.mouseY / Math.max(1, surface.height)) * 100))
                : root.playing ? qsTr("X %1% · Y %2%").arg(Math.round(touch.mouseX / Math.max(1, surface.width) * 100)).arg(Math.round((1 - touch.mouseY / Math.max(1, surface.height)) * 100))
                : qsTr("Tocá y arrastrá")
        }
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(14 * root.u)
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: Math.max(9, Math.round(12 * root.u))
            text: root.effect === "filter" ? qsTr("← graves · agudos →")
                : root.effect === "roll" ? qsTr("← 1/16 · 1 tiempo →  mantené y arrastrá")
                : root.effect === "trans" || root.effect === "gater" ? qsTr("← más rápido · más lento →   ↑ más corte")
                : root.effect === "glitch" ? qsTr("← más corto · más largo →")
                : qsTr("← menos efecto · X · más efecto →")
        }
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.round(14 * root.u)
            visible: root.effect !== "roll" && root.effect !== "glitch" && root.effect !== "filter"
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: Math.max(9, Math.round(12 * root.u))
            text: root.effect === "echo" ? qsTr("↑ Feedback · Y") : (root.effect === "trans" || root.effect === "gater" ? qsTr("↑ Corte · Y") : qsTr("↑ Mezcla · Y"))
        }

        MouseArea {
            id: touch

            function report() {
                const x = Math.max(0, Math.min(1, mouseX / Math.max(1, width)));
                const y = Math.max(0, Math.min(1, 1 - mouseY / Math.max(1, height)));
                root.start(x, y);
            }

            anchors.fill: parent
            preventStealing: true
            onPressed: {
                if (root.hold && root.playing) {
                    root.stop();
                    return;
                }
                report();
            }
            onPositionChanged: {
                if (pressed && (root.playing || !root.hold)) {
                    report();
                }
            }
            onReleased: root.fingerUp()
            onCanceled: root.fingerUp()
        }
    }
}
