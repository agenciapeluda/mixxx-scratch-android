import QtQuick

// Over the waveforms while letsktch! is on: which deck, and a tap to leave
Rectangle {
    id: root

    // The deck letsktch! is on ("" hides it)
    property string group: ""
    // Still setting up, and the step it is in
    property bool busy: false
    property string stepText: ""

    signal stopRequested

    visible: group !== ""
    width: label.implicitWidth + 28
    height: 32
    radius: 16
    z: 10
    color: Style.stemVocals

    Text {
        id: label

        anchors.centerIn: parent
        color: Style.background
        font.family: Style.font
        font.pixelSize: 13
        font.weight: Font.Bold
        text: root.busy ? qsTr("letsktch! · deck %1 · armando… (%2)").arg(root.group === "[Channel2]" ? "B" : "A").arg(root.stepText) : qsTr("letsktch! · deck %1 · tocá para salir").arg(root.group === "[Channel2]" ? "B" : "A")
    }
    TapHandler {
        onTapped: root.stopRequested()
    }
}
