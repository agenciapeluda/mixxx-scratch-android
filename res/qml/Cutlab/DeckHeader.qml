import ".." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick

// The top of a deck: cover, artist and title, key, remaining time and the
// overview of the whole track. Tapping the cover or the title opens the
// library to load a track into this deck.
Item {
    id: root

    required property string group
    // The cover sits on the outer side: left for deck 1, right for deck 2
    property bool coverOnRight: false
    readonly property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
    readonly property var currentTrack: deckPlayer ? deckPlayer.currentTrack : null
    readonly property bool loaded: trackLoaded.value > 0

    signal browseRequested

    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: duration

        group: root.group
        key: "duration"
    }
    Mixxx.ControlProxy {
        id: playPosition

        group: root.group
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: rateRatio

        group: root.group
        key: "rate_ratio"
    }
    Mixxx.ControlProxy {
        id: endOfTrack

        group: root.group
        key: "end_of_track"
    }

    Rectangle {
        id: cover

        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        x: root.coverOnRight ? root.width - width - 8 : 8
        width: height
        radius: 8
        color: "#1d1d1f"
        clip: true

        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: root.loaded && root.currentTrack ? root.currentTrack.coverArtUrl : ""
            visible: status === Image.Ready
        }
        Image {
            anchors.centerIn: parent
            width: parent.width * 0.42
            height: width
            opacity: 0.35
            source: "icons/note.svg"
            sourceSize.width: 64
            sourceSize.height: 64
            visible: !root.loaded || !root.currentTrack || root.currentTrack.coverArtUrl.toString() === ""
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.browseRequested()
        }
    }

    Item {
        id: info

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: root.coverOnRight ? parent.left : cover.right
        anchors.right: root.coverOnRight ? cover.left : parent.right
        anchors.leftMargin: root.coverOnRight ? 8 : 14
        anchors.rightMargin: root.coverOnRight ? 14 : 8

        readonly property real remaining: Math.max(0, duration.value * (1 - playPosition.value)) / Math.max(0.01, rateRatio.value)

        Text {
            id: artist

            anchors.left: parent.left
            anchors.right: keyText.left
            anchors.rightMargin: 8
            y: parent.height * 0.08
            color: Style.textSecondary
            elide: Text.ElideRight
            font.family: Style.font
            font.pixelSize: Math.max(10, Math.round(root.height * 0.19))
            text: root.loaded && root.currentTrack ? root.currentTrack.artist : ""
        }
        Text {
            id: title

            anchors.left: parent.left
            anchors.right: timeText.left
            anchors.rightMargin: 8
            anchors.top: artist.bottom
            color: Style.text
            elide: Text.ElideRight
            font.family: Style.font
            font.pixelSize: Math.max(12, Math.round(root.height * 0.25))
            text: root.loaded && root.currentTrack ? root.currentTrack.title : qsTr("Tap to load a track")
            opacity: root.loaded ? 1 : 0.5
        }
        Text {
            id: keyText

            anchors.right: parent.right
            anchors.baseline: artist.baseline
            color: Style.keyColor(text.replace("♪ ", ""))
            font.family: Style.font
            font.pixelSize: artist.font.pixelSize
            font.weight: Font.Medium
            // The key as it sounds now, with the pitch applied
            text: root.loaded && Mixxx.KeyUtils.keyIsValid(keyControl.value) ? "♪ " + Mixxx.KeyUtils.keyToString(keyControl.value) : ""

            Mixxx.ControlProxy {
                id: keyControl

                group: root.group
                key: "key"
            }
        }
        Text {
            id: timeText

            anchors.right: parent.right
            anchors.baseline: title.baseline
            color: endOfTrack.value > 0 ? Style.danger : Style.text
            font.family: Style.font
            font.pixelSize: title.font.pixelSize
            text: root.loaded ? "-" + Style.formatTime(info.remaining) : ""
        }

        Item {
            id: overview

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: title.bottom
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8

            Skin.WaveformOverview {
                anchors.fill: parent
                group: root.group
                visible: root.loaded
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: Style.tick
                visible: !root.loaded
            }
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: overview.top
            onClicked: root.browseRequested()
        }
    }
}
