import QtQuick

// Over the waveforms while letsktch! is on: which deck, and a tap to leave.
// 1.32.6: small, in the top corner of the deck's lane (not over the middle,
// where the scratch happens)
Rectangle {
    id: root

    // The deck letsktch! is on ("" hides it)
    property string group: ""

    signal stopRequested

    visible: group !== ""
    width: label.implicitWidth + 18
    height: 24
    radius: 12
    z: 10
    color: Style.stemVocals

    Text {
        id: label

        anchors.centerIn: parent
        color: Style.background
        font.family: Style.font
        font.pixelSize: 11
        font.weight: Font.Bold
        text: qsTr("letsktch! %1  ✕").arg(root.group === "[Channel2]" ? "B" : "A")
    }
    TapHandler {
        onTapped: root.stopRequested()
    }
}
