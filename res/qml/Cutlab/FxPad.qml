import Mixxx 1.0 as Mixxx
import QtQuick

// The FX pad of a deck: pick an effect (rhythm or ambience), play it with
// the finger on the surface, fire the one shots on the side, choose the
// beat fraction below. The surface draws a game-like layer of its own.
Item {
    id: root

    required property string group
    readonly property int unitNumber: group === "[Channel2]" ? 2 : 1
    readonly property string unitGroup: `[EffectRack1_EffectUnit${unitNumber}]`
    readonly property string slotGroup: `[EffectRack1_EffectUnit${unitNumber}_Effect1]`
    readonly property var shots: Shots.forGroup(group)
    readonly property bool dvs: vinylEnabled.value > 0
    readonly property color deckColor: Style.deckColor(group)

    property string effect: "echo"
    // Beats
    property real fraction: 0.5
    property bool hold: false
    property bool playing: false
    property string rollKey: ""
    property bool liteVisuals: Mixxx.Application.configValue("[Cutlab]", "fx_visuals_lite", "0") === "1"

    readonly property var rhythmEffects: [
        {id: "roll", name: qsTr("Roll")},
        {id: "trans", name: qsTr("Trans")},
        {id: "gater", name: qsTr("Gater")},
        {id: "glitch", name: qsTr("Glitch")}
    ]
    readonly property var ambientEffects: [
        {id: "echo", name: qsTr("Echo"), effectId: "org.mixxx.effects.echo"},
        {id: "filter", name: qsTr("Filtro"), effectId: ""},
        {id: "flanger", name: qsTr("Flanger"), effectId: "org.mixxx.effects.flanger"},
        {id: "reverb", name: qsTr("Reverb"), effectId: "org.mixxx.effects.reverb"},
        {id: "bitcrush", name: qsTr("Bitcrush"), effectId: "org.mixxx.effects.bitcrusher"}
    ]
    readonly property var fractions: [0.0625, 0.125, 0.25, 0.5, 1, 2, 4]

    function fractionText(beats) {
        return beats >= 1 ? String(beats) : "1/" + Math.round(1 / beats);
    }
    function ambient(id) {
        for (const effect of root.ambientEffects) {
            if (effect.id === id) {
                return effect;
            }
        }
        return null;
    }
    function rollKeyFor(beats) {
        return `beatlooproll_${beats}_activate`;
    }

    function start(x, y) {
        const effect = root.effect;
        if (effect === "roll") {
            const key = root.rollKeyFor(Math.min(1, root.fraction));
            if (key !== root.rollKey) {
                if (root.rollKey !== "") {
                    rollControl.value = 0;
                }
                root.rollKey = key;
                rollControl.key = key;
                rollControl.value = 1;
            }
        } else if (effect === "trans" || effect === "gater" || effect === "glitch") {
            if (!root.playing && root.shots) {
                root.shots.rhythm(effect, true, Math.min(8, Math.max(0.25, 1 / root.fraction)));
            }
            // Depth for trans and gater
            if (effect !== "glitch") {
                parameter1.value = 0.35 + 0.65 * y;
            }
        } else if (effect === "filter") {
            quickFilter.parameter = x;
        } else {
            if (!root.playing) {
                const slot = Mixxx.EffectsManager.getEffectSlot(root.unitNumber, 1);
                const wanted = root.ambient(effect).effectId;
                if (slot && slot.effectId !== wanted) {
                    slot.effectId = wanted;
                }
                if (effect === "echo") {
                    // delay_time in beats
                    parameter1.value = Math.min(2, root.fraction);
                }
                unitEnabled.value = 1;
                routing.value = 1;
                unitMix.value = 1;
                unitSuper.parameter = 1;
                slotEnabled.value = 1;
            }
            meta.parameter = x;
            if (effect === "echo") {
                // feedback
                parameter2.parameter = 0.2 + 0.75 * y;
            } else {
                unitMix.value = 0.35 + 0.65 * y;
            }
        }
        root.playing = true;
    }
    function stop() {
        if (!root.playing) {
            return;
        }
        const effect = root.effect;
        if (effect === "roll") {
            rollControl.value = 0;
            root.rollKey = "";
        } else if (effect === "trans" || effect === "gater" || effect === "glitch") {
            if (root.shots) {
                root.shots.rhythm(effect, false, 1);
            }
        } else if (effect === "filter") {
            quickFilter.reset();
        } else {
            slotEnabled.value = 0;
            unitSuper.parameter = 0;
        }
        root.playing = false;
    }
    function pick(effect) {
        root.stop();
        root.effect = effect;
    }

    Mixxx.ControlProxy {
        id: rollControl

        group: root.group
        key: "beatlooproll_0.5_activate"
    }
    Mixxx.ControlProxy {
        id: quickFilter

        group: `[QuickEffectRack1_${root.group}]`
        key: "super1"
    }
    Mixxx.ControlProxy {
        id: routing

        group: root.unitGroup
        key: `group_${root.group}_enable`
    }
    Mixxx.ControlProxy {
        id: unitEnabled

        group: root.unitGroup
        key: "enabled"
    }
    Mixxx.ControlProxy {
        id: unitMix

        group: root.unitGroup
        key: "mix"
    }
    Mixxx.ControlProxy {
        id: unitSuper

        group: root.unitGroup
        key: "super1"
    }
    Mixxx.ControlProxy {
        id: slotEnabled

        group: root.slotGroup
        key: "enabled"
    }
    Mixxx.ControlProxy {
        id: meta

        group: root.slotGroup
        key: "meta"
    }
    Mixxx.ControlProxy {
        id: parameter1

        group: root.slotGroup
        key: "parameter1"
    }
    Mixxx.ControlProxy {
        id: parameter2

        group: root.slotGroup
        key: "parameter2"
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

    Component.onDestruction: root.stop()

    // ---- Effects: one row that scrolls sideways when narrow ----
    ListView {
        id: chips

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        height: 34
        orientation: ListView.Horizontal
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: [{header: qsTr("RITMO")}].concat(root.rhythmEffects).concat([{header: qsTr("AMBIENTE")}]).concat(root.ambientEffects)

        delegate: Item {
            id: chip

            required property var modelData
            readonly property bool isHeader: modelData.header !== undefined

            width: isHeader ? headerText.implicitWidth + 6 : Math.max(58, modelData.name.length * 8 + 26)
            height: 34

            Text {
                id: headerText

                anchors.verticalCenter: parent.verticalCenter
                visible: chip.isHeader
                color: Style.textSecondary
                font.family: Style.font
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                text: chip.isHeader ? chip.modelData.header : ""
            }
            CLButton {
                anchors.fill: parent
                visible: !chip.isHeader
                radius: 17
                text: chip.isHeader ? "" : chip.modelData.name
                fontSize: 13
                highlighted: !chip.isHeader && root.effect === chip.modelData.id
                onClicked: root.pick(chip.modelData.id)
            }
        }
    }

    // ---- Fractions and HOLD ----
    Row {
        id: fractionRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        height: root.narrow ? 36 : 42
        spacing: 4

        Repeater {
            model: root.fractions

            CLButton {
                required property var modelData

                width: (fractionRow.width - 4 * 7) / 8
                height: fractionRow.height
                radius: 8
                text: root.fractionText(modelData)
                fontSize: root.narrow ? 11 : 13
                highlighted: root.fraction === modelData
                onClicked: root.fraction = modelData
            }
        }
        CLButton {
            width: (fractionRow.width - 4 * 7) / 8
            height: fractionRow.height
            radius: 8
            text: qsTr("HOLD")
            fontSize: 12
            highlighted: root.hold
            onClicked: {
                root.hold = !root.hold;
                if (!root.hold) {
                    root.stop();
                }
            }
        }
    }

    readonly property bool narrow: width < 400

    // ---- One shots: a column on the side, a row when narrow ----
    Grid {
        id: shotColumn

        x: root.narrow ? 8 : root.width - width - 8
        y: root.narrow ? fractionRow.y - height - 8 : chips.y + chips.height + 8
        width: root.narrow ? root.width - 16 : Math.max(96, Math.min(124, root.width * 0.24))
        height: root.narrow ? 44 : fractionRow.y - 8 - y
        columns: root.narrow ? 4 : 1
        spacing: 6

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

                width: root.narrow ? (shotColumn.width - 18) / 4 : shotColumn.width
                height: root.narrow ? shotColumn.height : (shotColumn.height - 18) / 4
                radius: 12
                color: shotMouse.pressed ? Style.buttonPressed : Style.raised
                border.width: 1
                border.color: shotMouse.pressed ? root.deckColor : Style.buttonBorder
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
                        font.pixelSize: root.narrow ? 12 : 14
                        font.weight: Font.Bold
                        text: shot.modelData.name
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !root.narrow
                        color: Style.textSecondary
                        font.family: Style.mono
                        font.pixelSize: 10
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

    // ---- The surface ----
    Rectangle {
        id: surface

        anchors.top: chips.bottom
        anchors.bottom: root.narrow ? shotColumn.top : fractionRow.top
        anchors.left: parent.left
        anchors.right: root.narrow ? parent.right : shotColumn.left
        anchors.margins: 8
        radius: 14
        color: Style.raised
        clip: true

        // The dot grid
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = "#2a2940";
                const step = 16;
                for (let y = step / 2; y < height; y += step) {
                    for (let x = step / 2; x < width; x += step) {
                        ctx.fillRect(x, y, 2, 2);
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
            radius: 14
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
            width: 46
            height: 46
            radius: 23
            color: Style.accent
            border.width: 3
            border.color: "#ffffff"
        }
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 12
            color: root.deckColor
            font.family: Style.mono
            font.pixelSize: 12
            font.weight: Font.Bold
            text: root.effect === "roll" ? qsTr("ROLL %1").arg(root.fractionText(Math.min(1, root.fraction)))
                : root.playing ? qsTr("X %1% · Y %2%").arg(Math.round(touch.mouseX / Math.max(1, surface.width) * 100)).arg(Math.round((1 - touch.mouseY / Math.max(1, surface.height)) * 100))
                : qsTr("Tocá y arrastrá")
        }
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 12
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 11
            text: root.effect === "filter" ? qsTr("← graves · agudos →")
                : root.effect === "roll" ? qsTr("mantené para repetir · la fracción va abajo")
                : root.effect === "trans" || root.effect === "gater" ? qsTr("arriba: más corte · la velocidad va abajo")
                : qsTr("← menos · más →   ↑ feedback / mezcla")
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
            onReleased: {
                if (!root.hold) {
                    root.stop();
                }
            }
            onCanceled: {
                if (!root.hold) {
                    root.stop();
                }
            }
        }
    }
}
