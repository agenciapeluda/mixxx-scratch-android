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
            const norm = path => path.replace(/^\/sdcard(?=\/|$)/, "/storage/emulated/0")
                .replace(/^\/storage\/self\/primary(?=\/|$)/, "/storage/emulated/0").replace(/\/+$/, "");
            const library = current.map(norm);
            let any = false;
            for (const folder of found) {
                // Keep what is already in the library
                const path = norm(folder.path);
                chosen[folder.path] = library.some(dir => path === dir || path.startsWith(dir + "/") || dir.startsWith(path + "/"));
                any = any || chosen[folder.path];
            }
            if (!any) {
                // Else the folders with the most music, at least the first
                found.forEach((folder, i) => chosen[folder.path] = i === 0 || folder.count >= 20);
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
                            text: folderRow.modelData.count >= 0 ? qsTr("%n temas", "", folderRow.modelData.count) : qsTr("elegida a mano")
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
            // Another folder of the phone, picked by hand
            Rectangle {
                width: column.width
                height: 48
                radius: 12
                color: otherMouse.pressed ? Style.raised : "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.22)

                Text {
                    anchors.centerIn: parent
                    color: Style.text
                    font.family: Style.font
                    font.weight: Font.DemiBold
                    font.pixelSize: 14
                    text: qsTr("+ Elegir otra carpeta")
                }
                MouseArea {
                    id: otherMouse

                    anchors.fill: parent
                    onClicked: picker.openAt("/storage/emulated/0")
                }
            }
            Rectangle {
                width: column.width
                height: excludedColumn.implicitHeight + 24
                radius: 14
                color: Style.panel

                Column {
                    id: excludedColumn

                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 6

                    Text {
                        color: Style.textSecondary
                        font.family: Style.font
                        font.weight: Font.DemiBold
                        font.pixelSize: 11
                        font.letterSpacing: 0.7
                        text: qsTr("QUEDAN AFUERA SOLOS")
                    }
                    Text {
                        width: parent.width
                        color: Style.text
                        font.family: Style.font
                        font.pixelSize: 13
                        lineHeight: 1.3
                        wrapMode: Text.WordWrap
                        text: qsTr("Audios de WhatsApp, grabaciones de voz, videos y todo lo que dure menos de 45 segundos.")
                    }
                }
            }
            Rectangle {
                width: column.width
                height: usbText.implicitHeight + 24
                radius: 14
                color: Style.panel

                Text {
                    id: usbText

                    x: 44
                    y: 12
                    width: parent.width - 56
                    color: Style.text
                    font.family: Style.font
                    font.pixelSize: 13
                    lineHeight: 1.3
                    wrapMode: Text.WordWrap
                    text: qsTr("Un pendrive aparece solo en la biblioteca cuando lo conectás.")
                }
                Text {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.deck2
                    font.family: Style.mono
                    font.weight: Font.Bold
                    font.pixelSize: 16
                    text: "⏏"
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

    // A simple folder browser for "+ Elegir otra carpeta"
    Rectangle {
        id: picker

        property string path: ""
        property var dirs: []

        function openAt(dir) {
            picker.path = dir;
            picker.dirs = Mixxx.MobileLibrary.getSubDirectories(dir);
            picker.visible = true;
        }

        anchors.fill: parent
        visible: false
        color: Style.background
        z: 5

        MouseArea {
            anchors.fill: parent
        }
        Row {
            id: pickerTop

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            CLButton {
                width: 44
                height: 44
                radius: 10
                icon: "back"
                iconSize: 18
                fillColor: "transparent"
                onClicked: {
                    const up = picker.path.substring(0, picker.path.lastIndexOf("/"));
                    if (picker.path === "/storage/emulated/0" || up.length < 2) {
                        picker.visible = false;
                    } else {
                        picker.openAt(up);
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44 - 150 - 16
                elide: Text.ElideLeft
                color: Style.text
                font.family: Style.font
                font.weight: Font.Bold
                font.pixelSize: 16
                text: picker.path.replace("/storage/emulated/0", qsTr("Teléfono"))
            }
            CLButton {
                width: 150
                height: 44
                radius: 10
                text: qsTr("Usar esta")
                highlighted: true
                onClicked: {
                    const found = root.candidates.some(folder => folder.path === picker.path);
                    if (!found) {
                        root.candidates = root.candidates.concat([{name: picker.path.split("/").pop(), path: picker.path, count: -1}]);
                    }
                    const chosen = Object.assign({}, root.chosen);
                    chosen[picker.path] = true;
                    root.chosen = chosen;
                    picker.visible = false;
                }
            }
        }
        ListView {
            anchors.top: pickerTop.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            x: 12
            width: parent.width - 24
            clip: true
            model: picker.dirs

            delegate: NodeRow {
                required property string modelData

                width: ListView.view.width
                text: modelData.split("/").pop()
                icon: "folder"
                onClicked: picker.openAt(modelData.startsWith("/") ? modelData : picker.path + "/" + modelData)
            }
        }
    }
}
