import QtQuick
import QtQuick.Controls 2.12
import Qt5Compat.GraphicalEffects
import "Theme"

AbstractButton {
    id: root

    enum Category {
        None,
        Danger,
        Action
    }

    property var category: ActionButton.Category.None
    property alias label: labelField

    implicitHeight: 24

    background: Item {
        Rectangle {
            id: content

            anchors.fill: parent
            color: root.category == ActionButton.Category.Action ? '#2D4EA1' : root.category == ActionButton.Category.Danger ? '#5a2a30' : Theme.darkGray3
            radius: 4
        }
        DropShadow {
            anchors.fill: parent
            color: "#80000000"
            horizontalOffset: 0
            radius: 8.0
            source: content
            verticalOffset: 0
        }
    }
    contentItem: Item {
        Label {
            id: labelField

            anchors.fill: parent
            color: Theme.white
            font.weight: Font.DemiBold
            font.capitalization: Font.MixedCase
            font.family: Theme.fontFamily
            font.pixelSize: Theme.buttonFontPixelSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
