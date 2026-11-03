import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls

// "Tu música, en orden": the folders of the phone that hold music, each one
// with a switch. The chosen ones become the music folders of the library,
// their subfolders work like crates, and voice notes, recordings and short
// files stay out.
Rectangle {
    id: root

    property var candidates: []
    property var chosen: ({})
    property bool searching: false

    signal done

    color: Style.background

    function open() {
        root.visible = true;
        root.searching = true;
        root.candidates = [];
        scanTimer.start();
    }
    function apply() {
        const paths = Object.keys(root.chosen).filter(path => root.chosen[path]);
        if (paths.length === 0) {
            return;
        }
        Mixxx.Cutlab.useFolders(paths);
        Mixxx.Application.setConfigValue("[Cutlab]", "folders_done", "1");
        root.visible = false;
        root.done();
    }

    // Let the screen show before walking the storage
    Timer {
        id: scanTimer

        interval: 120
        onTriggered: {
            const current = Mixxx.Cutlab.folders();
            const found = Mixxx.Cutlab.candidateFolders();
            const chosen = {};
            for (const folder of found) {
                // Keep what is already in the library, else pick the folders
                // with the most music
                chosen[folder.path] = current.length > 0
                    ? current.some(path => folder.path === path || folder.path.startsWith(path + "/"))
                    : folder.count >= 20;
            }
            root.chosen = chosen;
            root.candidates = found;
            root.searching = false;
        }
    }

    MouseArea {
        anchors.fill: parent
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: applyButton.height + 32
        contentHeight: column.implicitHeight + 40
        clip: true

        Column {
            id: column

            x: 20
            y: 24
            width: Math.min(parent.width - 40, 640)
            spacing: 14

            Text {
                width: parent.width
                color: Style.text
                font.family: Style.font
                font.weight: Font.ExtraBold
                font.pixelSize: 32
                font.letterSpacing: -0.6
                lineHeight: 0.95
                wrapMode: Text.WordWrap
                text: qsTr("Tu música,\nen orden.")
            }
            Text {
                width: parent.width
                color: Style.textSecondary
                font.family: Style.font
                font.pixelSize: 15
                lineHeight: 1.3
                wrapMode: Text.WordWrap
                text: qsTr("Encontramos estas carpetas con música. Prendé las que tengan temas para pasar: cada subcarpeta se vuelve una caja que se actualiza sola.")
            }
            Text {
                visible: root.searching
                color: Style.accentText
                font.family: Style.font
                font.pixelSize: 15
                text: qsTr("Buscando música en el teléfono…")
            }
            Repeater {
                model: root.candidates

                Rectangle {
                    id: folderRow

                    required property var modelData
                    readonly property bool on: root.chosen[modelData.path] === true

                    width: column.width
                    height: 66
                    radius: 14
                    color: Style.panel
                    border.width: 2
                    border.color: on ? Style.accent : "transparent"

                    Rectangle {
                        id: folderIcon

                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: 10
                        color: folderRow.on ? Style.accent : Style.buttonBorder

                        Image {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: "icons/folder.svg"
                            sourceSize.width: 40
                            sourceSize.height: 40
                        }
                    }
                    Column {
                        anchors.left: folderIcon.right
                        anchors.leftMargin: 12
                        anchors.right: toggle.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            color: Style.text
                            elide: Text.ElideMiddle
                            font.family: Style.font
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: folderRow.modelData.name
                        }
                        Text {
                            color: Style.textSecondary
                            font.family: Style.font
                            font.pixelSize: 12
                            text: qsTr("%n temas", "", folderRow.modelData.count)
                        }
                    }
                    Rectangle {
                        id: toggle

                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        height: 28
                        radius: 14
                        color: folderRow.on ? Style.accent : Style.buttonBorder

                        Rectangle {
                            y: 3
                            x: folderRow.on ? parent.width - width - 3 : 3
                            width: 22
                            height: 22
                            radius: 11
                            color: "#ffffff"

                            Behavior on x {
                                NumberAnimation {
                                    duration: Style.motion
                                    easing.type: Easing.OutQuint
                                }
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            const chosen = Object.assign({}, root.chosen);
                            chosen[folderRow.modelData.path] = !folderRow.on;
                            root.chosen = chosen;
                        }
                    }
                }
            }
            Text {
                visible: !root.searching && root.candidates.length === 0
                width: parent.width
                color: Style.textSecondary
                font.family: Style.font
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                text: qsTr("No encontramos música. Revisá que Cutlab tenga permiso para leer tus archivos en los ajustes de Android.")
            }
            Rectangle {
                width: column.width
                height: excluded.implicitHeight + 24
                radius: 14
                color: Style.panel

                Text {
                    id: excluded

                    x: 12
                    y: 12
                    width: parent.width - 24
                    color: Style.textSecondary
                    font.family: Style.font
                    font.pixelSize: 13
                    lineHeight: 1.3
                    wrapMode: Text.WordWrap
                    text: qsTr("Quedan afuera solos: audios de WhatsApp, grabaciones de voz, videos y todo lo que dure menos de 45 segundos. Un pendrive aparece solo cuando lo conectás.")
                }
            }
        }
    }

    CLButton {
        id: applyButton

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 40, 640)
        height: 54
        radius: 14
        fillColor: Style.accent
        bordered: false
        fontSize: 16
        text: qsTr("Armar la biblioteca")
        enabled: Object.keys(root.chosen).some(path => root.chosen[path])
        opacity: enabled ? 1 : 0.4
        onClicked: root.apply()
    }
    CLButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        width: 44
        height: 44
        icon: "close"
        iconSize: 20
        bordered: false
        fillColor: "transparent"
        onClicked: root.visible = false
    }
}
