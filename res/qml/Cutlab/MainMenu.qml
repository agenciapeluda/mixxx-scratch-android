import QtQuick
import QtQuick.Controls
import Mixxx 1.0 as Mixxx

// The menu of the Cutlab mark, a card in the middle of the screen: quick
// toggles on top (record, Auto DJ, quantize), then how the screen looks
// (the waveforms, dial or turntable, zoom) and the rest below.
// With the controller: turn BROWSE to move, press it to pick, LOAD closes.
Popup {
    id: root

    property bool recording: false
    property string waveMode: "vertical"
    property string deckLook: "dial"
    property bool padsHidden: true
    property bool quantize: false
    property bool stemsAuto: false
    property bool diagnostics: false
    // Upright there is no extended waveform: it is horizontal
    property bool portrait: false
    // The item lit by the knob, by its key ("" none)
    property int current: -1

    // Every item in the order the knob walks them
    // Cutlab 1.32.1: the show mode in the quick row, the rest in the order
    // they are on screen
    readonly property var order: ["record", "autodj", "quantize", "showmode", "wave_vertical", "wave_horizontal"].concat(root.portrait ? [] : ["wave_extended"]).concat(["look_dial", "look_platter", "zoom_out", "zoom_in", "library", "folders", "pads", "stems", "diagnostics", "sharelog", "settings"])
    readonly property string currentKey: current >= 0 ? order[current] : ""
    // These stay open after a tap: they are toggles or looks
    readonly property var stays: ["quantize", "wave_vertical", "wave_horizontal", "wave_extended", "look_dial", "look_platter", "zoom_out", "zoom_in", "stems", "diagnostics"]

    signal picked(string key)

    function move(step) {
        root.current = root.current < 0 ? 0 : (root.current + step + root.order.length) % root.order.length;
    }
    function activate() {
        if (root.current >= 0) {
            root.pick(root.order[root.current]);
        }
    }
    function pick(key) {
        if (root.stays.indexOf(key) < 0) {
            root.close();
        }
        root.picked(key);
    }

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    width: Math.min(parent ? parent.width - 24 : 660, 660)
    height: Math.min(parent ? parent.height - 24 : 400, content.implicitHeight + topPadding + bottomPadding)
    modal: true
    focus: true
    padding: 16
    onOpened: root.current = -1
    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "scale"
            from: 0.96
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: 120
        }
    }
    Overlay.modal: Rectangle {
        color: Qt.rgba(0.03, 0.02, 0.06, 0.72)
    }
    background: Rectangle {
        color: Style.panel
        radius: 22
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
    }

    // A button of the menu: lit when on, ringed when the knob is on it
    component MenuButton: Rectangle {
        id: button

        property string key: ""
        property string title: ""
        property string detail: ""
        property string icon: ""
        property bool on: false
        property color onColor: Style.neutral
        readonly property real textRoom: width - (icon !== "" ? 48 : 16)

        radius: 12
        color: buttonMouse.pressed ? Style.buttonPressed : (on ? Qt.rgba(onColor.r, onColor.g, onColor.b, 0.22) : Style.raised)
        border.width: root.currentKey === key ? 2 : 1
        border.color: root.currentKey === key ? Style.text : (on ? onColor : Qt.rgba(1, 1, 1, 0.08))

        Row {
            anchors.centerIn: parent
            spacing: 8

            Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: button.icon !== ""
                width: 20
                height: 20
                source: button.icon !== "" ? `icons/${button.icon}.svg` : ""
                sourceSize.width: 40
                sourceSize.height: 40
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: Math.min(implicitWidth, button.textRoom)
                    elide: Text.ElideRight
                    color: Style.text
                    font.family: Style.font
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    text: button.title
                }
                Text {
                    width: Math.min(implicitWidth, button.textRoom)
                    elide: Text.ElideRight
                    visible: button.detail !== ""
                    color: Style.textSecondary
                    font.family: Style.font
                    font.pixelSize: 11
                    text: button.detail
                }
            }
        }
        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            onClicked: root.pick(button.key)
        }
    }

    // [AI-generated text, Claude (Anthropic) — start]
    // Cutlab 1.32.1: one grid for the whole menu. Every row has the same
    // label column on the left and the same area for its buttons, so the
    // buttons of all rows start and end at the same place.
    // [AI-generated text, Claude (Anthropic) — end]
    readonly property real labelWidth: content.width > 520 ? 86 : 64
    readonly property real gap: 8
    readonly property real area: content.width - root.labelWidth - root.gap
    function cell(count) {
        return (root.area - root.gap * (count - 1)) / count;
    }

    component RowLabel: Text {
        width: root.labelWidth
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Style.textSecondary
        font.family: Style.font
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        elide: Text.ElideRight
    }

    contentItem: Flickable {
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content

            width: parent.width
            spacing: 10

            // The mark
            Row {
                height: 34
                spacing: 8

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    source: root.recording ? "icons/cutlab_mark_rec.svg" : "icons/cutlab_mark.svg"
                    sourceSize.width: 96
                    sourceSize.height: 96
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.text
                    font.family: Style.font
                    font.pixelSize: 20
                    font.weight: Font.ExtraBold
                    font.letterSpacing: -0.6
                    text: "cutlab"
                }
            }

            // The quick toggles
            Row {
                height: 52
                spacing: root.gap

                RowLabel {
                    text: qsTr("RÁPIDO")
                }
                Repeater {
                    model: [
                        {key: "record", icon: "rec", title: root.recording ? qsTr("Grabando") : qsTr("Grabar")},
                        {key: "autodj", icon: "autodj", title: qsTr("Auto DJ")},
                        {key: "quantize", icon: "", title: qsTr("Quantize")},
                        {key: "showmode", icon: "", title: qsTr("Modo show")}
                    ]

                    MenuButton {
                        required property var modelData

                        width: root.cell(4)
                        height: 52
                        key: modelData.key
                        icon: modelData.icon
                        title: modelData.title
                        on: (modelData.key === "record" && root.recording) || (modelData.key === "quantize" && root.quantize)
                            || (modelData.key === "showmode" && Mixxx.Cutlab.showMode)
                        onColor: modelData.key === "record" ? Style.danger : (modelData.key === "showmode" ? Style.ok : Style.neutral)
                    }
                }
            }

            // The waveforms
            Row {
                height: 44
                spacing: root.gap

                RowLabel {
                    text: qsTr("ONDA")
                }
                Repeater {
                    id: waveButtons

                    model: [
                        {key: "wave_vertical", title: qsTr("Vertical")},
                        {key: "wave_horizontal", title: qsTr("Horizontal")}
                    ].concat(root.portrait ? [] : [{key: "wave_extended", title: qsTr("Extendida")}])

                    MenuButton {
                        required property var modelData

                        width: root.cell(waveButtons.count)
                        height: 44
                        key: modelData.key
                        title: modelData.title
                        on: root.waveMode === modelData.key.substring(5) || (root.portrait && root.waveMode === "extended" && modelData.key === "wave_horizontal")
                    }
                }
            }

            // The decks and the zoom
            Row {
                height: 44
                spacing: root.gap

                RowLabel {
                    text: qsTr("PLATO")
                }
                Repeater {
                    model: [
                        {key: "look_dial", title: qsTr("Dial")},
                        {key: "look_platter", title: qsTr("Bandeja")},
                        {key: "zoom_out", title: qsTr("Zoom −")},
                        {key: "zoom_in", title: qsTr("Zoom +")}
                    ]

                    MenuButton {
                        required property var modelData

                        width: root.cell(4)
                        height: 44
                        key: modelData.key
                        title: modelData.title
                        on: modelData.key.startsWith("look_") && root.deckLook === modelData.key.substring(5)
                    }
                }
            }

            // The rest
            Row {
                spacing: root.gap

                RowLabel {
                    anchors.verticalCenter: undefined
                    topPadding: 18
                    text: qsTr("APP")
                }
                // Cutlab 1.32.2: 4 columns (2 upright), Ajustes takes two
                // places so no row is left with a hole
                Flow {
                    readonly property int columns: content.width > 520 ? 4 : 2

                    width: root.area
                    spacing: root.gap

                    Repeater {
                        model: [
                            {key: "library", icon: "library", title: qsTr("Biblioteca"), detail: qsTr("Cola y listas")},
                            {key: "folders", icon: "folder", title: qsTr("Carpetas"), detail: qsTr("Tu música")},
                            root.waveMode === "extended" && !root.portrait ? {key: "pads", icon: "pads", title: qsTr("Pads"), detail: root.padsHidden ? qsTr("Ocultos: más onda") : qsTr("A la vista")} : {key: "pads", icon: "pads", title: qsTr("Pads grandes"), detail: qsTr("Sobre los diales")},
                            {key: "stems", icon: "stems", title: qsTr("Stems solos"), detail: root.stemsAuto ? qsTr("Prendido") : qsTr("Apagado")},
                            {key: "diagnostics", icon: "list", title: qsTr("Diagnóstico"), detail: root.diagnostics ? qsTr("Visible") : qsTr("Oculto")},
                            {key: "sharelog", icon: "more", title: qsTr("Compartir log"), detail: qsTr("Para reportar fallas")},
                            {key: "settings", icon: "settings", title: qsTr("Ajustes"), detail: qsTr("Sonido, latencia, DVS")}
                        ]

                        MenuButton {
                            required property var modelData

                            width: modelData.key === "settings" ? root.cell(parent.columns) * 2 + root.gap : root.cell(parent.columns)
                            height: 56
                            key: modelData.key
                            icon: modelData.icon
                            title: modelData.title
                            detail: modelData.detail
                            on: (modelData.key === "stems" && root.stemsAuto) || (modelData.key === "diagnostics" && root.diagnostics)
                        }
                    }
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Style.textDim
                font.family: Style.font
                font.pixelSize: 11
                text: qsTr("Girá BROWSE para moverte · apretalo para elegir · LOAD cierra")
            }
        }
    }
}
