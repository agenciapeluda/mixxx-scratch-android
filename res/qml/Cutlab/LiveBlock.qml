import QtQuick

// Over the pads and the tools that act on the track (hot cues, loops,
// stems) while the deck plays its turntable live: they would act on a
// track nobody hears
Rectangle {
    id: root

    required property string group
    readonly property bool live: Live.isLive(group)

    visible: live
    color: Qt.rgba(0.03, 0.02, 0.06, 0.82)
    radius: 10
    z: 50

    MouseArea {
        anchors.fill: parent
        preventStealing: true
    }
    Text {
        anchors.centerIn: parent
        width: parent.width - 24
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: Style.textSecondary
        font.family: Style.font
        font.pixelSize: 13
        text: qsTr("En vivo: hot cues, loops, sync y pads bloqueados. Capturá un loop y apagá EN VIVO para usarlos.")
    }
}
