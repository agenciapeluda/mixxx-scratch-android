import Mixxx 1.0 as Mixxx
import QtQuick

// [AI-generated text, Claude (Anthropic) — start]
// Cutlab 1.32.0: "Modo show". What the app does on its own (Do Not
// Disturb, the other apps paused, screen on, no analysis, no internet) and
// what only Android can do, one tap away: Internet and Bluetooth off.
// [AI-generated text, Claude (Anthropic) — end]
Rectangle {
    id: root

    property var access: ({dnd: false, battery: false})
    function refresh() {
        root.access = Mixxx.Cutlab.showModeAccess();
    }

    signal closeRequested()

    color: Qt.rgba(0.02, 0.02, 0.05, 0.94)
    visible: false
    onVisibleChanged: if (visible) root.refresh()

    // Back from Android's settings: the access may have changed
    Connections {
        target: Qt.application

        function onStateChanged() {
            if (root.visible && Qt.application.state === Qt.ApplicationActive) {
                root.refresh();
                // Do Not Disturb applies once the access is there
                if (Mixxx.Cutlab.showMode && root.access.dnd) {
                    Mixxx.Cutlab.showMode = false;
                    Mixxx.Cutlab.showMode = true;
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 520)
        height: column.implicitHeight + 40
        color: Style.panel
        radius: 12
        border.width: 1
        border.color: Style.buttonBorder

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            x: 20
            y: 20
            width: card.width - 40
            spacing: 12

            Text {
                width: parent.width
                color: Style.text
                font.family: Style.font
                font.weight: Font.DemiBold
                font.pixelSize: 20
                text: Mixxx.Cutlab.showMode ? qsTr("Modo show prendido") : qsTr("Modo show")
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Style.textSecondary
                font.family: Style.font
                font.pixelSize: 13
                text: qsTr("Mientras Cutlab está abierta: No molestar, las otras apps que suenan se pausan, la pantalla no se apaga, el análisis y las búsquedas en internet esperan. Al salir, todo vuelve como estaba.")
            }

            Repeater {
                model: [
                    {key: "dnd", title: qsTr("No molestar"), ok: root.access.dnd, okText: qsTr("Listo"), action: qsTr("Dar acceso"),
                     detail: qsTr("Android pide permiso una vez")},
                    {key: "battery", title: qsTr("Batería sin restricciones"), ok: root.access.battery, okText: qsTr("Listo"), action: qsTr("Permitir"),
                     detail: qsTr("Que Android no frene la app")},
                    {key: "internet", title: qsTr("Wi-Fi y datos"), ok: false, okText: "", action: qsTr("Apagar"),
                     detail: qsTr("Android no deja apagarlos desde una app")},
                    {key: "bluetooth", title: qsTr("Bluetooth"), ok: false, okText: "", action: qsTr("Apagar"),
                     detail: qsTr("Si no sacás el sonido por Bluetooth")}
                ]

                Item {
                    required property var modelData

                    width: column.width
                    height: 52

                    Column {
                        anchors.left: parent.left
                        anchors.right: rowButton.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            color: Style.text
                            font.family: Style.font
                            font.pixelSize: 15
                            text: modelData.title
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            color: Style.textDim
                            font.family: Style.font
                            font.pixelSize: 12
                            text: modelData.detail
                        }
                    }
                    CLButton {
                        id: rowButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 130
                        height: 42
                        radius: 8
                        text: modelData.ok ? modelData.okText : modelData.action
                        lit: modelData.ok
                        litColor: Style.ok
                        onClicked: {
                            if (modelData.ok) {
                                return;
                            }
                            if (modelData.key === "dnd") {
                                Mixxx.Cutlab.openDndAccess();
                            } else if (modelData.key === "battery") {
                                Mixxx.Cutlab.requestBatteryExemption();
                            } else if (modelData.key === "internet") {
                                Mixxx.Cutlab.openInternetPanel();
                            } else {
                                Mixxx.Cutlab.openBluetoothSettings();
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 12
                topPadding: 8

                CLButton {
                    width: (parent.width - 12) / 2
                    height: 48
                    radius: 8
                    text: Mixxx.Cutlab.showMode ? qsTr("Apagar modo show") : qsTr("Prender modo show")
                    lit: Mixxx.Cutlab.showMode
                    litColor: Style.ok
                    onClicked: Mixxx.Cutlab.showMode = !Mixxx.Cutlab.showMode
                }
                CLButton {
                    width: (parent.width - 12) / 2
                    height: 48
                    radius: 8
                    text: qsTr("Listo")
                    onClicked: root.closeRequested()
                }
            }
        }
    }
}
