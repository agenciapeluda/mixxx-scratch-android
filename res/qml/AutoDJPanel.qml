import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "." as Skin
import "Theme"
import "Cutlab" as Cutlab

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

    // The queue is shown by whoever opened the panel
    signal queueRequested

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    focus: true
    modal: true
    padding: 20
    width: Math.min(parent ? parent.width - 40 : 640, 640)
    height: Math.min(implicitHeight, parent ? parent.height - 24 : 600)

    background: Rectangle {
        border.color: "#3e3e41"
        border.width: 1
        color: Cutlab.Style.panelDark
        radius: 16
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

    contentItem: Flickable {
        implicitHeight: panelLayout.implicitHeight
        contentHeight: panelLayout.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

    ColumnLayout {
        id: panelLayout

        width: parent.width
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Image {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                source: "Cutlab/icons/autodj.svg"
                sourceSize.width: 64
                sourceSize.height: 64
            }
            Text {
                Layout.fillWidth: true
                color: Cutlab.Style.text
                font.family: Cutlab.Style.font
                font.pixelSize: 20
                font.weight: Font.Medium
                text: qsTr("Auto DJ")
            }
            // On / off switch
            Rectangle {
                id: autoSwitch

                readonly property bool on: enabledControl.value > 0

                Layout.preferredWidth: 58
                Layout.preferredHeight: 32
                radius: 16
                color: on ? Cutlab.Style.play : "#48484b"

                Rectangle {
                    x: autoSwitch.on ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: "#ffffff"

                    Behavior on x {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: enabledControl.value = autoSwitch.on ? 0 : 1
                }
            }
        }
        Text {
            Layout.fillWidth: true
            color: Cutlab.Style.textSecondary
            font.family: Cutlab.Style.font
            font.pixelSize: 13
            text: qsTr("Plays the queue and mixes between deck 1 and deck 2. Add tracks by holding a track in the library → Add to the end of the queue.")
            wrapMode: Text.WordWrap
        }
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: 8
            columns: root.width > 520 ? 4 : 2
            rowSpacing: 8

            Cutlab.CLButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: qsTr("Fade now")
                fontSize: 14
                onClicked: {
                    fadeNowControl.value = 1;
                    fadeNowControl.value = 0;
                }
            }
            Cutlab.CLButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: qsTr("Skip next")
                fontSize: 14
                onClicked: {
                    skipNextControl.value = 1;
                    skipNextControl.value = 0;
                }
            }
            Cutlab.CLButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: qsTr("Shuffle queue")
                fontSize: 14
                onClicked: {
                    shuffleControl.value = 1;
                    shuffleControl.value = 0;
                }
            }
            Cutlab.CLButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: qsTr("Add random track")
                fontSize: 14
                onClicked: {
                    addRandomControl.value = 1;
                    addRandomControl.value = 0;
                }
            }
        }
        // Transition: one chip per mode
        Text {
            color: Cutlab.Style.textSecondary
            font.family: Cutlab.Style.font
            font.pixelSize: 13
            text: qsTr("Transition")
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.modes

                Cutlab.CLButton {
                    required property int index
                    required property string modelData

                    height: 36
                    text: modelData
                    fontSize: 13
                    fontWeight: Font.Normal
                    radius: 18
                    highlighted: Math.round(transitionModeControl.value) === index
                    onClicked: transitionModeControl.value = index
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                color: Cutlab.Style.textSecondary
                font.family: Cutlab.Style.font
                font.pixelSize: 13
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

                background: Rectangle {
                    x: fadeSlider.leftPadding
                    y: fadeSlider.topPadding + fadeSlider.availableHeight / 2 - height / 2
                    width: fadeSlider.availableWidth
                    height: 6
                    radius: 3
                    color: Cutlab.Style.track

                    Rectangle {
                        width: fadeSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        color: Cutlab.Style.accent
                    }
                }
                handle: Rectangle {
                    x: fadeSlider.leftPadding + fadeSlider.visualPosition * (fadeSlider.availableWidth - width)
                    y: fadeSlider.topPadding + fadeSlider.availableHeight / 2 - height / 2
                    width: 26
                    height: 26
                    radius: 13
                    color: "#e5e5ea"
                }
            }
            Text {
                Layout.preferredWidth: 44
                color: Cutlab.Style.text
                font.family: Cutlab.Style.font
                font.pixelSize: 14
                horizontalAlignment: Text.AlignRight
                text: qsTr("%1 s").arg(Math.round(fadeSlider.value))
            }
        }
        Cutlab.CLButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            icon: "queue"
            iconSize: 20
            text: qsTr("Open the queue")
            fontSize: 14
            highlighted: true
            onClicked: {
                root.close();
                root.queueRequested();
            }
        }
    }
    }
}
