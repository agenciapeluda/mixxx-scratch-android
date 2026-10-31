import QtQuick
import QtQuick.Controls

// A row of a CLMenu.
MenuItem {
    id: root

    implicitHeight: 46
    leftPadding: 16
    rightPadding: 16

    contentItem: Text {
        color: root.enabled ? Style.text : Style.textDim
        elide: Text.ElideRight
        font.family: Style.font
        font.pixelSize: 15
        text: root.text
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 8
        color: root.highlighted || root.down ? "#3a3a3d" : "transparent"
    }
}
