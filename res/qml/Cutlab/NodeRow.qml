import QtQuick

// A playlist, crate, folder or history session in the library list.
Rectangle {
    id: root

    property string text: ""
    property string icon: "list"

    signal clicked

    height: 56
    color: mouse.pressed ? "#2a2a2c" : "transparent"

    Rectangle {
        id: iconBox

        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: 6
        color: "#2c2c2e"

        Image {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: `icons/${root.icon}.svg`
            sourceSize.width: 48
            sourceSize.height: 48
            opacity: 0.8
        }
    }
    Text {
        anchors.left: iconBox.right
        anchors.leftMargin: 14
        anchors.right: chevron.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        color: Style.text
        elide: Text.ElideRight
        font.family: Style.font
        font.pixelSize: 16
        text: root.text
    }
    Image {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        source: "icons/chevron_right.svg"
        sourceSize.width: 48
        sourceSize.height: 48
        opacity: 0.7
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: iconBox.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        height: 1
        color: "#2a2a2c"
    }
    MouseArea {
        id: mouse

        anchors.fill: parent
        onClicked: root.clicked()
    }
}
