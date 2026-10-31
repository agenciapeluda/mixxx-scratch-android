import ".." as Skin
import Mixxx 1.0 as Mixxx
import Qt5Compat.GraphicalEffects
import QtQuick 2.12
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls 2.12
import "../Theme"

Item {
    id: root

    required property var currentTrack
    required property string group

    property int activePadMode: 0 // 0: Hotcue, 1: Loop, 2: Stems

    // The names of the stems of the stem files made by the app
    function stemName(label) {
        switch (label) {
        case "Drums":
            return qsTr("DRUMS");
        case "Bass":
            return qsTr("BASS");
        case "Vocals":
            return qsTr("VOCALS");
        case "Other":
            return qsTr("OTHER");
        default:
            return label.toUpperCase();
        }
    }

    // Plays only one stem, or all again if it is the only one playing
    function soloStem(index) {
        let soloed = true;
        for (let i = 0; i < stemRepeater.count; ++i) {
            const muted = stemRepeater.itemAt(i).muteControl.value > 0;
            if (muted !== (i !== index))
                soloed = false;
        }
        for (let i = 0; i < stemRepeater.count; ++i)
            stemRepeater.itemAt(i).muteControl.value = soloed ? 0 : (i === index ? 0 : 1);
    }

    Mixxx.ControlProxy {
        id: stemCountControl

        group: root.group
        key: "stem_count"

        onValueChanged: {
            if (value <= 0 && root.activePadMode === 2)
                root.activePadMode = 0;
        }
    }

    Rectangle {
        color: '#0e0e0e'

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: tabs.left
            rightMargin: 6
            top: parent.top
        }
        Item {
            id: hotcueTab

            anchors.fill: parent
            visible: root.activePadMode === 0

            Skin.FadeBehavior on visible {
                fadeTarget: hotcueTab
            }

            GridLayout {
                anchors.bottomMargin: 8
                anchors.fill: parent
                anchors.leftMargin: root.width < 260 ? 4 : 16
                anchors.rightMargin: root.width < 260 ? 4 : 16
                anchors.topMargin: 8
                columnSpacing: root.width < 260 ? 3 : 6
                rowSpacing: 6

                Repeater {
                    model: 8

                    Item {
                        required property int index

                        Layout.column: index % 4
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.row: parseInt(index / 4)

                        Skin.Hotcue {
                            id: hotcue

                            readonly property var label: (isSet && root.currentTrack && root.currentTrack.hotcuesModel) ? root.currentTrack.hotcuesModel.get(index).label : null

                            activate: activator.pressedButtons == Qt.LeftButton
                            // onIsSetChanged: {
                            //     if (!isSet)
                            //         popup.close();
                            // }
                            group: root.group
                            hotcueNumber: index + 1
                        }
                        Rectangle {
                            id: backgroundImage

                            anchors.fill: parent
                            color: hotcue.isSet ? hotcue.color : (activator.pressed ? "#464646" : "#262626")
                            radius: 3
                            border.color: hotcue.isSet ? "#ffffff" : "#3c3c3c"
                            border.width: 1

                            MouseArea {
                                id: activator

                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                anchors.fill: parent
                            }
                        }
                        DropShadow {
                            id: effect1

                            anchors.fill: backgroundImage
                            color: "#80000000"
                            horizontalOffset: 0
                            radius: 1.0
                            source: backgroundImage
                            verticalOffset: 0
                        }
                        InnerShadow {
                            id: effect2

                            anchors.fill: parent
                            color: "#343434"
                            horizontalOffset: 1
                            radius: 12
                            samples: 24
                            source: effect1
                            spread: 0.2
                            verticalOffset: 1
                        }
                        InnerShadow {
                            anchors.fill: parent
                            color: "#343434"
                            horizontalOffset: -1
                            radius: 12
                            samples: 24
                            source: effect2
                            spread: 0.2
                            verticalOffset: -1
                        }
                        ColumnLayout {
                            anchors.centerIn: backgroundImage
                            spacing: 0

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                color: hotcue.isSet ? "#ffffff" : "#afafaf"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                text: `${index + 1}`
                            }
                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                color: hotcue.isSet ? "#ffffff" : "#8d8d8d"
                                font.pixelSize: 10
                                text: hotcue.label ?? ""
                                visible: hotcue.label
                            }
                        }
                    }
                }
            }
        }
        Item {
            id: loopTab

            anchors.fill: parent
            visible: root.activePadMode === 1

            Skin.FadeBehavior on visible {
                fadeTarget: loopTab
            }

            GridLayout {
                anchors.bottomMargin: 8
                anchors.fill: parent
                anchors.leftMargin: root.width < 260 ? 4 : 16
                anchors.rightMargin: root.width < 260 ? 4 : 16
                anchors.topMargin: 8
                columnSpacing: root.width < 260 ? 3 : 6
                rowSpacing: 6

                Repeater {
                    model: [
                        { label: "1/4", size: "0.25" },
                        { label: "1/2", size: "0.5" },
                        { label: "1", size: "1" },
                        { label: "2", size: "2" },
                        { label: "4", size: "4" },
                        { label: "8", size: "8" },
                        { label: "16", size: "16" },
                        { label: "32", size: "32" }
                    ]

                    Item {
                        id: loopPadItem
                        required property int index
                        required property var modelData

                        Layout.column: index % 4
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.row: parseInt(index / 4)

                        Mixxx.ControlProxy {
                            id: loopToggleProxy
                            group: root.group
                            key: "beatloop_" + loopPadItem.modelData.size + "_toggle"
                        }

                        Mixxx.ControlProxy {
                            id: loopEnabledProxy
                            group: root.group
                            key: "beatloop_" + loopPadItem.modelData.size + "_enabled"
                        }

                        Rectangle {
                            id: loopPadBg
                            anchors.fill: parent
                            radius: 4
                            color: (loopEnabledProxy.value > 0)
                                ? "#837cff"
                                : (loopPadMouse.pressed ? "#343434" : "#242424")
                            border.color: (loopEnabledProxy.value > 0) ? "#ffffff" : "#3c3c3c"
                            border.width: (loopEnabledProxy.value > 0) ? 2 : 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 15
                                    color: (loopEnabledProxy.value > 0) ? "#0c0c0c" : "#837cff"
                                    text: loopPadItem.modelData.label
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 8
                                    color: (loopEnabledProxy.value > 0) ? "#252525" : "#7a7a7a"
                                    text: "BEATS"
                                }
                            }

                            MouseArea {
                                id: loopPadMouse
                                anchors.fill: parent
                                onClicked: {
                                    loopToggleProxy.trigger();
                                }
                            }
                        }
                    }
                }
            }
        }

        // The stems of the track: tap to mute, hold to play only that one
        RowLayout {
            id: stemTab

            anchors.fill: parent
            anchors.margins: root.width < 260 ? 4 : 8
            spacing: root.width < 260 ? 3 : 6
            visible: root.activePadMode === 2

            Repeater {
                id: stemRepeater

                model: root.currentTrack ? root.currentTrack.stemsModel : 0

                ColumnLayout {
                    id: stem

                    required property int index
                    required property color color
                    required property string label
                    readonly property string group: `${root.group.substr(0, root.group.length - 1)}_Stem${index + 1}]`
                    readonly property bool muted: muteControl.value > 0
                    property alias muteControl: muteControl

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    // The stems share the width equally
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    spacing: 3

                    Mixxx.ControlProxy {
                        id: muteControl

                        group: stem.group
                        key: "mute"
                    }
                    Mixxx.ControlProxy {
                        id: volumeControl

                        group: stem.group
                        key: "volume"
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        radius: 5
                        color: stem.muted ? "#1f1f1f" : Qt.darker(stem.color, stemMouse.pressed ? 1.6 : 1.2)
                        border.color: stem.color
                        border.width: stem.muted ? 1 : 2

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 4
                            horizontalAlignment: Text.AlignHCenter
                            // Long names shrink to fit narrow decks
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: 7
                            text: root.stemName(stem.label)
                            color: stem.muted ? "#767676" : "#ffffff"
                            font.weight: Font.DemiBold
                            font.pixelSize: root.width < 260 ? 9 : 11
                            font.strikeout: stem.muted
                        }

                        MouseArea {
                            id: stemMouse

                            anchors.fill: parent
                            onClicked: muteControl.value = stem.muted ? 0 : 1
                            onPressAndHold: root.soloStem(stem.index)
                        }
                    }

                    // Volume in steps
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 22
                        Layout.maximumHeight: 22
                        spacing: 2

                        VolumeStep {
                            step: -0.25
                            control: volumeControl
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: `${Math.round(volumeControl.value * 100)}%`
                            color: "#dbdbdb"
                            font.pixelSize: 9
                        }
                        VolumeStep {
                            step: 0.25
                            control: volumeControl
                        }
                    }
                }
            }
        }
    }
    ColumnLayout {
        id: tabs

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: root.width < 260 ? 3 : 6
        anchors.top: parent.top
        spacing: root.width < 260 ? 3 : 6
        width: root.width < 260 ? 36 : 44

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 5
            color: root.activePadMode === 0 ? ((root.group === "[Channel2]") ? "#e2622a" : "#453de0") : (cueTabMouse.pressed ? "#373737" : "#1e1e1e")
            border.color: root.activePadMode === 0 ? "#ffffff" : "#383838"
            border.width: root.activePadMode === 0 ? 1.5 : 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3

                Shape {
                    Layout.alignment: Qt.AlignHCenter
                    width: 12
                    height: 10
                    antialiasing: true
                    ShapePath {
                        fillColor: root.activePadMode === 0 ? "#ffffff" : "#949494"
                        strokeColor: "transparent"
                        startX: 1; startY: 0
                        PathLine { x: 11; y: 5 }
                        PathLine { x: 1; y: 10 }
                        PathLine { x: 1; y: 0 }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "CUE"
                    font.weight: Font.DemiBold
                    font.pixelSize: 9
                    color: root.activePadMode === 0 ? "#ffffff" : "#949494"
                }
            }

            MouseArea {
                id: cueTabMouse
                anchors.fill: parent
                onClicked: {
                    root.activePadMode = 0;
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 5
            color: root.activePadMode === 1 ? "#07008f" : (loopTabMouse.pressed ? "#373737" : "#1e1e1e")
            border.color: root.activePadMode === 1 ? "#ffffff" : "#383838"
            border.width: root.activePadMode === 1 ? 1.5 : 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3

                Shape {
                    Layout.alignment: Qt.AlignHCenter
                    width: 14
                    height: 10
                    antialiasing: true
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: root.activePadMode === 1 ? "#ffffff" : "#949494"
                        strokeWidth: 1.6
                        capStyle: ShapePath.RoundCap
                        startX: 2; startY: 2.5
                        PathLine { x: 12; y: 2.5 }
                        PathLine { x: 12; y: 7.5 }
                        PathLine { x: 2; y: 7.5 }
                    }
                    ShapePath {
                        fillColor: root.activePadMode === 1 ? "#ffffff" : "#949494"
                        strokeColor: "transparent"
                        startX: 0.5; startY: 5.5
                        PathLine { x: 4; y: 5.5 }
                        PathLine { x: 2.2; y: 2 }
                        PathLine { x: 0.5; y: 5.5 }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "LOOP"
                    font.weight: Font.DemiBold
                    font.pixelSize: 9
                    color: root.activePadMode === 1 ? "#ffffff" : "#949494"
                }
            }

            MouseArea {
                id: loopTabMouse
                anchors.fill: parent
                onClicked: {
                    root.activePadMode = 1;
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: stemCountControl.value > 0
            radius: 5
            color: root.activePadMode === 2 ? "#211b9a" : (stemsTabMouse.pressed ? "#373737" : "#1e1e1e")
            border.color: root.activePadMode === 2 ? "#ffffff" : "#383838"
            border.width: root.activePadMode === 2 ? 1.5 : 1

            Text {
                anchors.centerIn: parent
                text: "STEM"
                font.weight: Font.DemiBold
                font.pixelSize: 9
                color: root.activePadMode === 2 ? "#ffffff" : "#949494"
            }

            MouseArea {
                id: stemsTabMouse
                anchors.fill: parent
                onClicked: {
                    root.activePadMode = 2;
                }
            }
        }
    }

    // Changes the volume of a stem by a step
    component VolumeStep: Rectangle {
        id: volumeStep

        property real step
        property var control

        Layout.preferredWidth: 18
        Layout.minimumWidth: 14
        Layout.fillHeight: true
        radius: 4
        color: volumeStepMouse.pressed ? "#373737" : "#1e1e1e"
        border.color: "#383838"

        Text {
            anchors.centerIn: parent
            text: volumeStep.step < 0 ? "−" : "+"
            color: "#dbdbdb"
            font.weight: Font.DemiBold
            font.pixelSize: 12
        }

        MouseArea {
            id: volumeStepMouse

            anchors.fill: parent
            onClicked: volumeStep.control.value = Math.max(0, Math.min(1, volumeStep.control.value + volumeStep.step))
        }
    }
}
