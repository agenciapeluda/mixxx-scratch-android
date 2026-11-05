import QtQuick
import QtQuick.Controls

// The menu of the Cutlab mark: a card in the middle of the screen with the
// view (Onda like djay, Dial like Serato) and big tiles for the rest.
// With the controller: turn BROWSE to move, press it to pick, LOAD closes.
Popup {
    id: root

    property bool recording: false
    property string mainView: "onda"
    property bool stemsAuto: false
    property bool diagnostics: false
    // The item lit by the knob: 0 and 1 the views, then the tiles
    property int current: -1

    readonly property var tiles: [
        {key: "autodj", icon: "autodj", title: qsTr("Auto DJ"), text: qsTr("La cola sola")},
        {key: "record", icon: "rec", title: root.recording ? qsTr("Parar") : qsTr("Grabar"), text: root.recording ? qsTr("Grabando la mezcla") : qsTr("La mezcla a un archivo")},
        {key: "pads", icon: "pads", title: qsTr("Pads"), text: qsTr("Samples y rolls")},
        {key: "library", icon: "library", title: qsTr("Biblioteca"), text: qsTr("Cola y listas")},
        {key: "stems", icon: "stems", title: qsTr("Stems solos"), text: root.stemsAuto ? qsTr("Prendido") : qsTr("Apagado")},
        {key: "folders", icon: "folder", title: qsTr("Carpetas"), text: qsTr("Tu música")},
        {key: "diagnostics", icon: "list", title: qsTr("Diagnóstico"), text: root.diagnostics ? qsTr("Visible") : qsTr("Oculto")},
        {key: "settings", icon: "settings", title: qsTr("Ajustes"), text: qsTr("Sonido y DVS")}
    ]

    signal picked(string key)

    function move(step) {
        const count = 2 + root.tiles.length;
        root.current = root.current < 0 ? 0 : (root.current + step + count) % count;
    }
    function activate() {
        if (root.current < 0) {
            return;
        }
        if (root.current < 2) {
            root.picked(root.current === 0 ? "view_onda" : "view_dial");
            return;
        }
        root.pick(root.tiles[root.current - 2].key);
    }
    function pick(key) {
        // The toggles stay open, the rest closes the menu
        if (key !== "stems" && key !== "diagnostics") {
            root.close();
        }
        root.picked(key);
    }

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    width: Math.min(parent ? parent.width - 32 : 660, 680)
    modal: true
    focus: true
    padding: 18
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

    contentItem: Column {
        spacing: 12

        // The mark and the name
        Row {
            spacing: 12

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                source: root.recording ? "icons/cutlab_mark_rec.svg" : "icons/cutlab_mark.svg"
                sourceSize.width: 128
                sourceSize.height: 128
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Style.text
                font.family: Style.font
                font.pixelSize: 24
                font.weight: Font.ExtraBold
                font.letterSpacing: -0.8
                text: "cutlab"
            }
        }

        // The view
        Column {
            width: parent.width
            spacing: 8

            Text {
                color: Style.textSecondary
                font.family: Style.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                text: qsTr("VISTA")
            }
            Row {
                width: parent.width
                spacing: 10

                Repeater {
                    model: [
                        {key: "onda", title: qsTr("Onda"), text: qsTr("Como djay: ondas al medio")},
                        {key: "dial", title: qsTr("Dial"), text: qsTr("Como Serato: platos grandes")}
                    ]

                    Rectangle {
                        id: viewTile

                        required property var modelData
                        required property int index
                        readonly property bool on: root.mainView === modelData.key

                        width: (parent.width - 10) / 2
                        height: 60
                        radius: 14
                        color: on ? Style.accent : (viewMouse.pressed ? Style.buttonPressed : Style.raised)
                        border.width: root.current === index ? 2 : 1
                        border.color: root.current === index ? Style.text : (on ? Style.accent : Qt.rgba(1, 1, 1, 0.08))

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 16
                            spacing: 2

                            Text {
                                color: viewTile.on ? "#ffffff" : Style.text
                                font.family: Style.font
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                text: viewTile.modelData.title
                            }
                            Text {
                                color: viewTile.on ? Qt.rgba(1, 1, 1, 0.8) : Style.textSecondary
                                font.family: Style.font
                                font.pixelSize: 12
                                text: viewTile.modelData.text
                            }
                        }
                        MouseArea {
                            id: viewMouse

                            anchors.fill: parent
                            onClicked: root.picked("view_" + viewTile.modelData.key)
                        }
                    }
                }
            }
        }

        // The rest, as tiles
        Grid {
            width: parent.width
            columns: 4
            spacing: 10

            Repeater {
                model: root.tiles

                Rectangle {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool lit: (modelData.key === "record" && root.recording) || (modelData.key === "stems" && root.stemsAuto)

                    width: (parent.width - 30) / 4
                    height: 78
                    radius: 14
                    color: tileMouse.pressed ? Style.buttonPressed : (tile.lit ? (modelData.key === "record" ? Qt.rgba(1, 0.3, 0.37, 0.18) : Style.accentDark) : Style.raised)
                    border.width: root.current === index + 2 ? 2 : 1
                    border.color: root.current === index + 2 ? Style.text : (tile.lit ? (modelData.key === "record" ? Style.danger : Style.accent) : Qt.rgba(1, 1, 1, 0.08))

                    Image {
                        x: 12
                        y: 12
                        width: 22
                        height: 22
                        source: `icons/${tile.modelData.icon}.svg`
                        sourceSize.width: 48
                        sourceSize.height: 48
                    }
                    Column {
                        x: 14
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        width: parent.width - 28
                        spacing: 1

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            color: Style.text
                            font.family: Style.font
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            text: tile.modelData.title
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            color: Style.textSecondary
                            font.family: Style.font
                            font.pixelSize: 11
                            text: tile.modelData.text
                        }
                    }
                    MouseArea {
                        id: tileMouse

                        anchors.fill: parent
                        onClicked: root.pick(tile.modelData.key)
                    }
                }
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Style.textDim
            font.family: Style.font
            font.pixelSize: 12
            text: qsTr("Girá BROWSE para moverte · apretalo para elegir · LOAD cierra")
        }
    }
}
