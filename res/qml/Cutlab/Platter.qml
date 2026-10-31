import "../Deck" as DeckComponent
import Mixxx 1.0 as Mixxx
import QtQuick
import Qt5Compat.GraphicalEffects

// A turntable: the record turns with the track and scratches under the
// finger; the cover is its label. − and + bend the tempo while held.
Item {
    id: root

    required property string group
    property bool mirrored: false
    readonly property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
    readonly property var currentTrack: deckPlayer ? deckPlayer.currentTrack : null
    readonly property real diameter: Math.min(width - 24, height - 8)

    Mixxx.ControlProxy {
        id: trackLoaded

        group: root.group
        key: "track_loaded"
    }

    Item {
        id: deck

        width: root.diameter
        height: root.diameter
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) / 2 + (root.mirrored ? 8 : -8)

        // Platter edge
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#2e2e30"
            border.color: "#4a4a4e"
            border.width: 2
        }
        // The record
        Rectangle {
            id: record

            anchors.centerIn: parent
            width: parent.width * 0.94
            height: width
            radius: width / 2
            color: "#121213"

            Repeater {
                model: 6

                Rectangle {
                    required property int index

                    anchors.centerIn: parent
                    width: record.width * (0.94 - index * 0.085)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: index % 2 ? "#1d1d1f" : "#232325"
                    border.width: 1
                }
            }
        }

        DeckComponent.TouchSpinny {
            id: spinny

            anchors.fill: record
            group: root.group
            indicatorVisible: true

            indicator: Item {
                width: spinny.width
                height: spinny.height

                // The label: the cover of the track, turning with it
                Rectangle {
                    id: label

                    anchors.centerIn: parent
                    width: spinny.width * 0.4
                    height: width
                    radius: width / 2
                    color: "#3a3a3d"
                    clip: true

                    Image {
                        id: coverImage

                        anchors.fill: parent
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        source: trackLoaded.value > 0 && root.currentTrack ? root.currentTrack.coverArtUrl : ""
                        visible: false
                    }
                    Rectangle {
                        id: coverMask

                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                    }
                    OpacityMask {
                        anchors.fill: parent
                        source: coverImage
                        maskSource: coverMask
                        visible: coverImage.status === Image.Ready
                    }
                    // A mark to see it turn when there is no cover
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        width: 3
                        height: parent.height * 0.3
                        radius: 1.5
                        color: Style.text
                        visible: coverImage.status !== Image.Ready
                    }
                }
                // Spindle
                Rectangle {
                    anchors.centerIn: parent
                    width: 7
                    height: 7
                    radius: 3.5
                    color: "#d0d0d4"
                }
                // Position mark on the edge
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2
                    width: 3
                    height: spinny.height * 0.08
                    radius: 1.5
                    color: Style.text
                    opacity: 0.85
                }
            }
        }

        // Tonearm, just for the looks
        Item {
            id: tonearm

            anchors.fill: parent
            visible: root.diameter > 120
            enabled: false
            // Deck 2 has its arm on the other side
            transform: Scale {
                origin.x: tonearm.width / 2
                xScale: root.mirrored ? -1 : 1
            }

            Rectangle {
                id: pivot

                x: parent.width * 0.86
                y: parent.width * 0.02
                width: parent.width * 0.16
                height: width
                radius: width / 2
                color: "#1d1d1f"
                border.color: "#5c5c60"
                border.width: 2

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.45
                    height: width
                    radius: width / 2
                    color: "#a8a8ad"
                }
            }
            Rectangle {
                x: pivot.x + pivot.width / 2 - width / 2
                y: pivot.y + pivot.height / 2
                width: Math.max(3, parent.width * 0.018)
                height: parent.height * 0.72
                radius: width / 2
                color: "#b9b9be"
                transformOrigin: Item.Top
                rotation: 22
            }
        }
    }

    // Tempo bend, like nudging the record
    Row {
        anchors.right: root.mirrored ? undefined : parent.right
        anchors.left: root.mirrored ? parent.left : undefined
        anchors.bottom: parent.bottom
        anchors.margins: 6
        spacing: 4

        CLControlButton {
            width: 40
            height: 34
            group: root.group
            key: "rate_temp_down"
            mode: "push"
            icon: "minus"
            iconSize: 18
            bordered: false
            fillColor: "transparent"
            lit: false
        }
        CLControlButton {
            width: 40
            height: 34
            group: root.group
            key: "rate_temp_up"
            mode: "push"
            icon: "plus"
            iconSize: 18
            bordered: false
            fillColor: "transparent"
            lit: false
        }
    }
}
