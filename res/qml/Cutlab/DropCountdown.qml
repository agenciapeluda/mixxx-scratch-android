import QtQuick

// "DROP EN 8": how many bars are left to the next drop, shown from 16 bars
// on and blinking on the beat in the last 4.
Rectangle {
    id: root

    property int bars: -1
    property bool beat: false
    readonly property bool close: bars > 0 && bars <= 4

    visible: bars > 0 && bars <= 16
    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 6
    radius: height / 2
    color: close ? (beat ? Style.sectionDrop : Qt.darker(Style.sectionDrop, 1.6)) : "transparent"
    border.width: 1
    border.color: Style.sectionDrop

    Text {
        id: label

        anchors.centerIn: parent
        color: root.close ? "#ffffff" : Style.sectionDrop
        font.family: Style.mono
        font.weight: Font.Bold
        font.pixelSize: 11
        text: qsTr("DROP EN %1").arg(root.bars)
    }
}
