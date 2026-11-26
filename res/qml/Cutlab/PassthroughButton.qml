import QtQuick

// EN VIVO: the turntable of the deck plays through the channel
// (passthrough). Next to the DVS badge, whenever the deck has an input.
Rectangle {
    id: root

    required property string group
    readonly property var engine: Live.forGroup(group)
    readonly property bool on: !!engine && engine.live

    visible: !!engine && (engine.inputReady || on)
    width: label.implicitWidth + 26
    height: 28
    radius: 0
    color: on ? Style.danger : (mouse.pressed ? Style.buttonPressed : "#1c1c1e")
    border.width: 1
    border.color: on ? Style.danger : Style.buttonBorder

    Row {
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 0
            color: root.on ? "#ffffff" : Style.danger
        }
        Text {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            color: Style.text
            font.family: Style.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
            text: qsTr("EN VIVO")
        }
    }
    MouseArea {
        id: mouse

        anchors.fill: parent
        anchors.margins: -6
        onClicked: if (root.engine) root.engine.toggle()
    }
}
