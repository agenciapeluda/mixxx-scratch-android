import Mixxx 1.0 as Mixxx
import QtQuick

// A track of the library, as in the design: cover, title and artist, BPM,
// key, length and how it goes with the playing deck. The row under the
// browse knob is big and bright. Upright, BPM and key stack on the right.
Rectangle {
    id: root

    property int row: -1
    property var trackModel: null
    property bool selected: false
    property bool compact: false
    property real u: 1
    // The deck it is compared with
    property string versusGroup: "[Channel1]"
    property real versusBpm: 0
    property string versusKey: ""
    property string loadedUrlA: ""
    property string loadedUrlB: ""
    readonly property var track: trackModel && row >= 0 ? trackModel.getTrack(row) : null
    readonly property string url: track ? track.trackLocationUrl.toString() : ""
    readonly property string camelot: track ? Mixxx.Cutlab.camelot(track.keyText) : ""
    readonly property var match: Style.matchWith(track ? track.bpm : 0, camelot, versusBpm, versusKey)

    signal clicked
    signal loadRequested(string group)
    signal menuRequested

    function fs(px) {
        return Math.max(9, Math.round(px * root.u));
    }

    height: Math.round((selected ? 68 : 56) * u)
    radius: Math.round(10 * u)
    // The deck this track is loaded on ("" if none): the row takes its color
    readonly property string onDeck: url === "" ? "" : (url === loadedUrlA ? "[Channel1]" : (url === loadedUrlB ? "[Channel2]" : ""))

    color: selected ? Style.track : (mouse.pressed ? Style.raised
        : (onDeck !== "" ? Qt.rgba(Style.deckColor(onDeck).r, Style.deckColor(onDeck).g, Style.deckColor(onDeck).b, 0.16) : "transparent"))
    border.width: 2
    border.color: selected ? Style.accent : (onDeck !== "" ? Style.deckColor(onDeck) : "transparent")

    // The letter of the deck over the cover, big, while it is loaded
    Rectangle {
        z: 3
        visible: root.onDeck !== ""
        x: cover.x + cover.width - width / 2 - 2
        y: cover.y - 4
        width: deckTag.implicitWidth + Math.round(10 * root.u)
        height: deckTag.implicitHeight + 2
        radius: 5
        color: root.onDeck !== "" ? Style.deckColor(root.onDeck) : "transparent"

        Text {
            id: deckTag

            anchors.centerIn: parent
            color: Style.background
            font.family: Style.mono
            font.weight: Font.Bold
            font.pixelSize: root.fs(12)
            text: root.onDeck !== "" ? Style.deckLetter(root.onDeck) : ""
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: 90
        }
    }

    Rectangle {
        id: cover

        x: Math.round(8 * root.u)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(44 * root.u)
        height: width
        radius: Math.round(8 * root.u)
        color: "#2a2650"
        clip: true

        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 96
            sourceSize.height: 96
            source: root.track ? root.track.coverArtUrl : ""
            visible: status === Image.Ready
        }
    }

    // Wide: the columns of the table
    Row {
        id: columns

        anchors.right: parent.right
        anchors.rightMargin: Math.round(8 * root.u)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(12 * root.u)
        visible: !root.compact

        Text {
            width: Math.round(64 * root.u)
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            color: Style.text
            font.family: Style.mono
            font.weight: Font.Bold
            font.pixelSize: root.fs(15)
            text: root.track && root.track.bpm > 0 ? root.track.bpm.toFixed(1) : "…"
            opacity: root.track && root.track.bpm > 0 ? 1 : 0.4
        }
        Item {
            width: Math.round(46 * root.u)
            height: keyChip.height
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: keyChip

                visible: root.camelot !== ""
                width: keyText.implicitWidth + Math.round(10 * root.u)
                height: keyText.implicitHeight + 4
                radius: 4
                color: root.match.clash ? Style.textSecondary : Style.keyChip

                Text {
                    id: keyText

                    anchors.centerIn: parent
                    color: Style.background
                    font.family: Style.mono
                    font.weight: Font.Bold
                    font.pixelSize: root.fs(12)
                    text: root.camelot
                }
            }
        }
        Text {
            width: Math.round(56 * root.u)
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            color: Style.textSecondary
            font.family: Style.mono
            font.weight: Font.Medium
            font.pixelSize: root.fs(13)
            text: root.track && root.track.duration > 0 ? Style.formatTime(root.track.duration) : ""
        }
        Text {
            width: Math.round(150 * root.u)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            color: root.url !== "" && (root.url === root.loadedUrlA || root.url === root.loadedUrlB) ? Style.textSecondary
                : (root.match.clash ? "#ff8a95" : (root.match.text !== "" ? Style.ok : Style.textSecondary))
            font.family: Style.font
            font.weight: Font.DemiBold
            font.pixelSize: root.fs(12)
            text: root.url !== "" && root.url === root.loadedUrlA ? qsTr("en deck A")
                : root.url !== "" && root.url === root.loadedUrlB ? qsTr("en deck B")
                : root.match.text
        }
    }
    // Upright: BPM over the key
    Column {
        id: stacked

        anchors.right: parent.right
        anchors.rightMargin: Math.round(10 * root.u)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        visible: root.compact

        Text {
            anchors.right: parent.right
            color: Style.text
            font.family: Style.mono
            font.weight: Font.Bold
            font.pixelSize: root.fs(14)
            text: root.track && root.track.bpm > 0 ? root.track.bpm.toFixed(1) : "…"
        }
        Rectangle {
            anchors.right: parent.right
            visible: root.camelot !== ""
            width: smallKey.implicitWidth + 8
            height: smallKey.implicitHeight + 2
            radius: 3
            color: root.match.clash ? Style.textSecondary : Style.keyChip

            Text {
                id: smallKey

                anchors.centerIn: parent
                color: Style.background
                font.family: Style.mono
                font.weight: Font.Bold
                font.pixelSize: root.fs(10)
                text: root.camelot
            }
        }
    }

    Column {
        anchors.left: cover.right
        anchors.leftMargin: Math.round(12 * root.u)
        anchors.right: root.compact ? stacked.left : columns.left
        anchors.rightMargin: Math.round(12 * root.u)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            elide: Text.ElideRight
            color: Style.text
            font.family: Style.font
            font.weight: Font.DemiBold
            font.pixelSize: root.fs(root.selected ? 18 : 15)
            text: root.track ? root.track.title : ""
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: root.fs(root.compact ? 12 : 13)
            text: root.track ? root.track.artist : ""
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        onClicked: root.clicked()
        onDoubleClicked: root.loadRequested("")
        onPressAndHold: root.menuRequested()
    }
}
