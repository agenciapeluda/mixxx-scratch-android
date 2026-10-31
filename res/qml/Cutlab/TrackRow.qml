import Mixxx 1.0 as Mixxx
import QtQuick

// A track in the library: cover, title and artist, tempo, key and length,
// and buttons to load it into deck 1 or 2. Tap loads it where the library
// was opened for, hold shows more actions.
Rectangle {
    id: root

    property int row: -1
    property var trackModel: null
    property bool selected: false
    readonly property var track: trackModel && row >= 0 ? trackModel.getTrack(row) : null
    readonly property bool compact: width < 560

    signal loadRequested(string group)
    signal menuRequested

    height: 60
    color: mouse.pressed ? "#2a2a2c" : (selected ? "#1f2a3a" : "transparent")

    Rectangle {
        id: cover

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        radius: 5
        color: "#2c2c2e"
        clip: true

        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: root.track ? root.track.coverArtUrl : ""
            sourceSize.width: 96
            sourceSize.height: 96
        }
    }

    Column {
        anchors.left: cover.right
        anchors.leftMargin: 12
        anchors.right: meta.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            color: Style.text
            elide: Text.ElideRight
            font.family: Style.font
            font.pixelSize: 15
            text: root.track ? (root.track.title !== "" ? root.track.title : decodeURIComponent(root.track.trackLocationUrl.toString().replace(/^.*\//, ""))) : ""
        }
        Text {
            width: parent.width
            color: Style.textSecondary
            elide: Text.ElideRight
            font.family: Style.font
            font.pixelSize: 13
            text: root.track ? root.track.artist : ""
        }
    }

    Row {
        id: meta

        anchors.right: loadButtons.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Text {
            width: 46
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 13
            text: root.track && root.track.bpm > 0 ? root.track.bpm.toFixed(root.compact ? 0 : 1) : ""
        }
        Text {
            width: 36
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            color: Style.keyColor(text)
            font.family: Style.font
            font.pixelSize: 13
            font.weight: Font.Medium
            text: root.track ? root.track.keyText : ""
        }
        Text {
            width: 40
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 13
            text: root.track && root.track.duration > 0 ? Style.formatTime(root.track.duration) : ""
            visible: !root.compact
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        anchors.rightMargin: loadButtons.width + 12
        onClicked: root.loadRequested("")
        onPressAndHold: root.menuRequested()
    }

    Row {
        id: loadButtons

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: ["[Channel1]", "[Channel2]"]

            CLButton {
                required property int index
                required property string modelData

                width: 40
                height: 36
                radius: 8
                text: String(index + 1)
                fontSize: 15
                fillColor: "#232325"
                onClicked: root.loadRequested(modelData)
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: cover.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        height: 1
        color: "#242426"
    }
}
