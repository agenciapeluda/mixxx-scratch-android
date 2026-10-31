import QtQuick
import QtQuick.Controls

// A popup menu in the Cutlab look: dark rounded sheet, roomy rows.
Menu {
    id: root

    padding: 6
    implicitWidth: 260

    background: Rectangle {
        implicitWidth: 260
        color: "#2c2c2e"
        radius: 12
        border.color: "#3e3e41"
        border.width: 1
    }
}
