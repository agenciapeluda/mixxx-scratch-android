import QtQuick
import QtQuick.Controls

// A popup menu in the Cutlab look: dark rounded sheet, roomy rows.
Menu {
    id: root

    padding: 6
    implicitWidth: 260

    background: Rectangle {
        implicitWidth: 260
        color: Style.raised
        radius: 12
        border.color: Style.buttonBorder
        border.width: 1
    }
}
