import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "." as Skin
import "Theme"

// Cutlab: Auto DJ controls for the touch interface. The queue is the Auto DJ
// playlist of the library ("Add to Auto DJ" in the track menu).
Popup {
    id: root

    readonly property var modes: [
        qsTr("Intro → Outro"),
        qsTr("Fade at outro start"),
        qsTr("Full track"),
        qsTr("Skip silence"),
        qsTr("Skip silence, start at full volume")
    ]

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    focus: true
    modal: true
    padding: 20
    width: Math.min(parent ? parent.width - 40 : 520, 520)

    background: Rectangle {
        border.color: "#232836"
        border.width: 1
        color: "#12151c"
        radius: 14
    }

    Mixxx.ControlProxy {
        id: enabledControl

        group: "[AutoDJ]"
        key: "enabled"
    }
    Mixxx.ControlProxy {
        id: fadeNowControl

        group: "[AutoDJ]"
        key: "fade_now"
    }
    Mixxx.ControlProxy {
        id: skipNextControl

        group: "[AutoDJ]"
        key: "skip_next"
    }
    Mixxx.ControlProxy {
        id: shuffleControl

        group: "[AutoDJ]"
        key: "shuffle_playlist"
    }
    Mixxx.ControlProxy {
        id: addRandomControl

        group: "[AutoDJ]"
        key: "add_random_track"
    }
    Mixxx.ControlProxy {
        id: transitionTimeControl

        group: "[AutoDJ]"
        key: "transition_time"
    }
    Mixxx.ControlProxy {
        id: transitionModeControl

        group: "[AutoDJ]"
        key: "transition_mode"
    }

    contentItem: ColumnLayout {
        spacing: 14

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                color: "#e8eaf0"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                text: qsTr("Auto DJ")
            }
            Skin.Button {
                Layout.preferredHeight: 34
                Layout.preferredWidth: 110
                backgroundColor: enabledControl.value > 0 ? Qt.rgba(0.17, 0.84, 0.48, 0.2) : "#1c202a"
                normalColor: enabledControl.value > 0 ? "#2bd67b" : "#b4b9c7"
                text: enabledControl.value > 0 ? qsTr("On") : qsTr("Off")

                onClicked: enabledControl.value = enabledControl.value > 0 ? 0 : 1
            }
        }
        Text {
            Layout.fillWidth: true
            color: "#8a91a3"
            font.pixelSize: 11
            text: qsTr("Plays the Auto DJ queue and mixes between deck 1 and deck 2. Add tracks with the track menu → Add to Auto DJ.")
            wrapMode: Text.WordWrap
        }
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: 8
            columns: 2
            rowSpacing: 8

            Skin.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                text: qsTr("Fade now")

                onClicked: fadeNowControl.value = 1
            }
            Skin.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                text: qsTr("Skip next")

                onClicked: skipNextControl.value = 1
            }
            Skin.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                text: qsTr("Shuffle queue")

                onClicked: shuffleControl.value = 1
            }
            Skin.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                text: qsTr("Add random track")

                onClicked: addRandomControl.value = 1
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 110
                color: "#8a91a3"
                font.pixelSize: 12
                text: qsTr("Transition")
            }
            Skin.ComboBox {
                Layout.fillWidth: true
                currentIndex: Math.max(0, Math.min(root.modes.length - 1, Math.round(transitionModeControl.value)))
                model: root.modes

                onActivated: transitionModeControl.value = currentIndex
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 110
                color: "#8a91a3"
                font.pixelSize: 12
                text: qsTr("Fade time")
            }
            Slider {
                id: fadeSlider

                Layout.fillWidth: true
                from: 0
                stepSize: 1
                to: 30
                value: transitionTimeControl.value

                onMoved: transitionTimeControl.value = value
            }
            Text {
                Layout.preferredWidth: 40
                color: "#e8eaf0"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                text: qsTr("%1 s").arg(Math.round(fadeSlider.value))
            }
        }
        Skin.Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            text: qsTr("Open the Auto DJ queue")

            onClicked: {
                Mixxx.Library.showAutoDJ();
                root.close();
            }
        }
    }
}
