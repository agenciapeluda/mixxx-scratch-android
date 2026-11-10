import QtQuick
import QtQuick.Controls

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
    readonly property var order: ["record", "autodj", "quantize", "wave_vertical", "wave_horizontal"].concat(root.portrait ? [] : ["wave_extended"]).concat(["look_dial", "look_platter", "zoom_out", "zoom_in", "library", "pads", "stems", "folders", "diagnostics", "settings"])
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
        property color onColor: Style.accent
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

    contentItem: Flickable {
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content

            width: parent.width
            spacing: 12

            // The mark and the quick toggles
            Row {
                width: parent.width
                height: 56
                spacing: 10

                Row {
                    id: brand

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        source: root.recording ? "icons/cutlab_mark_rec.svg" : "icons/cutlab_mark.svg"
                        sourceSize.width: 96
                        sourceSize.height: 96
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: content.width > 520
                        color: Style.text
                        font.family: Style.font
                        font.pixelSize: 22
                        font.weight: Font.ExtraBold
                        font.letterSpacing: -0.6
                        text: "cutlab"
                    }
                }
                Repeater {
                    model: [
                        {key: "record", icon: "rec", title: root.recording ? qsTr("Grabando") : qsTr("Grabar")},
                        {key: "autodj", icon: "autodj", title: qsTr("Auto DJ")},
                        {key: "quantize", icon: "", title: qsTr("Quantize")}
                    ]

                    MenuButton {
                        required property var modelData

                        width: (content.width - brand.width - 40) / 3
                        height: 56
                        key: modelData.key
                        icon: modelData.icon
                        title: modelData.title
                        on: (modelData.key === "record" && root.recording) || (modelData.key === "quantize" && root.quantize)
                        onColor: modelData.key === "record" ? Style.danger : Style.accent
                    }
                }
            }

            // The waveforms
            Row {
                width: parent.width
                height: 44
                spacing: 8

                Text {
                    width: 70
                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.textSecondary
                    font.family: Style.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
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

                        width: (content.width - 70 - 8 * waveButtons.count) / waveButtons.count
                        height: 44
                        key: modelData.key
                        title: modelData.title
                        on: root.waveMode === modelData.key.substring(5) || (root.portrait && root.waveMode === "extended" && modelData.key === "wave_horizontal")
                    }
                }
            }

            // The decks and the zoom
            Row {
                width: parent.width
                height: 44
                spacing: 8

                Text {
                    width: 70
                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.textSecondary
                    font.family: Style.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                    text: qsTr("PLATO")
                }
                Repeater {
                    model: [
                        {key: "look_dial", title: qsTr("Dial")},
                        {key: "look_platter", title: qsTr("Bandeja")}
                    ]

                    MenuButton {
                        required property var modelData

                        width: (content.width - 70 - 40) / 4
                        height: 44
                        key: modelData.key
                        title: modelData.title
                        on: root.deckLook === modelData.key.substring(5)
                    }
                }
                Repeater {
                    model: [
                        {key: "zoom_out", title: qsTr("Zoom −")},
                        {key: "zoom_in", title: qsTr("Zoom +")}
                    ]

                    MenuButton {
                        required property var modelData

                        width: (content.width - 70 - 40) / 4
                        height: 44
                        key: modelData.key
                        title: modelData.title
                    }
                }
            }

            // The rest
            Grid {
                width: parent.width
                columns: 3
                spacing: 8

                Repeater {
                    model: [
                        {key: "library", icon: "library", title: qsTr("Biblioteca"), detail: qsTr("Cola y listas")},
                        root.waveMode === "extended" && !root.portrait ? {key: "pads", icon: "pads", title: qsTr("Pads"), detail: root.padsHidden ? qsTr("Ocultos: más onda") : qsTr("A la vista")} : {key: "pads", icon: "pads", title: qsTr("Pads grandes"), detail: qsTr("Sobre los diales")},
                        {key: "stems", icon: "stems", title: qsTr("Stems solos"), detail: root.stemsAuto ? qsTr("Prendido") : qsTr("Apagado")},
                        {key: "folders", icon: "folder", title: qsTr("Carpetas"), detail: qsTr("Tu música")},
                        {key: "diagnostics", icon: "list", title: qsTr("Diagnóstico"), detail: root.diagnostics ? qsTr("Visible") : qsTr("Oculto")},
                        {key: "settings", icon: "settings", title: qsTr("Ajustes avanzados"), detail: qsTr("Sonido, latencia, DVS")}
                    ]

                    MenuButton {
                        required property var modelData

                        width: (content.width - 16) / 3
                        height: 52
                        key: modelData.key
                        icon: modelData.icon
                        title: modelData.title
                        detail: modelData.detail
                        on: (modelData.key === "stems" && root.stemsAuto) || (modelData.key === "diagnostics" && root.diagnostics)
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
