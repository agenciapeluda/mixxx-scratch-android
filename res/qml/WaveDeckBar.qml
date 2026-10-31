import QtQuick 2.12
import QtQuick.Layouts 1.12
import Mixxx 1.0 as Mixxx
import "." as Skin
import "Theme"

Item {
    id: root

    implicitHeight: 96

    RowLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 6

        // ================= DECK 1 CARD =================
        DeckCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            group: "[Channel1]"
            isDeck1: true
        }

        // ================= DECK 2 CARD =================
        DeckCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            group: "[Channel2]"
            isDeck1: false
        }
    }

    component NudgeButton: Rectangle {
        required property var control
        // ▶, else ◀
        required property bool pointsRight

        Layout.preferredWidth: 24
        radius: 4
        color: control.value > 0 ? "#343434" : "#1c1c1c"
        border.color: "#343434"
        border.width: 1

        // Drawn, as Android draws ◀ ▶ as emoji
        Skin.Triangle {
            anchors.centerIn: parent
            color: "#bebebe"
            height: 8
            pointsRight: parent.pointsRight
            width: 7
        }

        MouseArea {
            anchors.fill: parent
            onPressed: parent.control.value = 1
            onReleased: parent.control.value = 0
            onCanceled: parent.control.value = 0
        }
    }

    // ================= REUSABLE DECK CARD COMPONENT =================
    component DeckCard: Rectangle {
        id: card

        required property string group
        required property bool isDeck1

        readonly property color accentColor: isDeck1 ? "#837cff" : "#ff7a3d"
        readonly property color accentDim: isDeck1 ? "#332cb8" : "#bf360c"
        readonly property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
        readonly property var currentTrack: deckPlayer?.currentTrack
        readonly property bool isLoaded: !!deckPlayer?.isLoaded

        color: "#141414"
        radius: 6
        border.color: isDeck1 ? "#00b0ff55" : "#ff6d0055"
        border.width: 1
        clip: true

        // Controls
        Mixxx.ControlProxy { id: bpmControl; group: card.group; key: "bpm" }
        Mixxx.ControlProxy { id: rateControl; group: card.group; key: "rate" }
        Mixxx.ControlProxy { id: durationControl; group: card.group; key: "duration" }
        Mixxx.ControlProxy { id: playPositionControl; group: card.group; key: "playposition" }
        Mixxx.ControlProxy { id: keyControl; group: card.group; key: "visual_key" }
        Mixxx.ControlProxy { id: playControl; group: card.group; key: "play" }
        Mixxx.ControlProxy { id: cueControl; group: card.group; key: "cue_default" }
        Mixxx.ControlProxy { id: syncEnabledControl; group: card.group; key: "sync_enabled" }
        Mixxx.ControlProxy { id: syncModeControl; group: card.group; key: "sync_mode" }
        Mixxx.ControlProxy { id: syncLeaderControl; group: card.group; key: "sync_leader" }
        Mixxx.ControlProxy { id: beatSyncControl; group: card.group; key: "beatsync" }
        Mixxx.ControlProxy { id: rateRatioControl; group: card.group; key: "rate_ratio" }
        Mixxx.ControlProxy { id: quantizeControl; group: card.group; key: "quantize" }
        Mixxx.ControlProxy { id: rateTempDownControl; group: card.group; key: "rate_temp_down" }
        Mixxx.ControlProxy { id: rateTempUpControl; group: card.group; key: "rate_temp_up" }

        property int timeDisplayMode: 0 // 0: REMAIN, 1: ELAPSED

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 3

            // -------- 1. TOP HEADER ROW (DECK & TRACK INFO) --------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                spacing: 6

                // Deck Pill
                Rectangle {
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: 54
                    radius: 3
                    color: card.accentDim
                    border.color: card.accentColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: card.isDeck1 ? "DECK 1" : "DECK 2"
                        color: "#ffffff"
                        font.weight: Font.DemiBold
                        font.pixelSize: 10
                        font.letterSpacing: 0.5
                    }
                }

                // Track Title & Artist
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: {
                        if (!card.isLoaded) return qsTr("No track - load");
                        var t = card.currentTrack?.title || "";
                        var a = card.currentTrack?.artist || "";
                        return a.length > 0 ? (a + " - " + t) : t;
                    }
                    color: card.isLoaded ? "#ffffff" : "#7a7a7a"
                    font.weight: Font.DemiBold
                    font.pixelSize: 11
                }

                // Key Badge
                Rectangle {
                    visible: card.isLoaded && !!keyControl.value && keyText.text.length > 0
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: keyText.implicitWidth + 10
                    radius: 3
                    color: "#242424"
                    border.color: card.accentColor
                    border.width: 1

                    Text {
                        id: keyText
                        anchors.centerIn: parent
                        text: keyControl.value ? keyControl.value.toString() : ""
                        color: "#ffffff"
                        font.weight: Font.DemiBold
                        font.pixelSize: 10
                    }
                }

                // Quantize: snaps play, cue and hotcues to the beat grid.
                // Turn it off to drop a track slightly off the beat.
                Rectangle {
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: 26
                    radius: 3
                    color: quantizeControl.value > 0 ? card.accentColor : "#242424"
                    border.color: card.accentColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Q"
                        color: quantizeControl.value > 0 ? "#000000" : "#7a7a7a"
                        font.weight: Font.DemiBold
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: quantizeControl.value = quantizeControl.value > 0 ? 0 : 1
                    }
                }
            }

            // -------- 2. MIDDLE DASHBOARD ROW (TIME, BPM, PITCH & TRANSPORT) --------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 6

                // Digital Time Display (Click to toggle Remain / Elapsed)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 4
                    color: "#0c0c0c"
                    border.color: timeMouse.containsMouse ? card.accentColor : "#262626"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 4

                        Text {
                            text: card.timeDisplayMode === 0 ? qsTr("REMAIN") : qsTr("TIME")
                            font.weight: Font.DemiBold
                            font.pixelSize: 8
                            color: card.accentColor
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            font.family: "monospace"
                            font.weight: Font.DemiBold
                            font.pixelSize: card.width < 380 ? 13 : 15
                            color: "#ffffff"
                            text: {
                                var total = durationControl.value || 0;
                                var pos = playPositionControl.value || 0;
                                if (total <= 0) return "--:--.--";

                                var cur = Math.max(0, Math.min(total, total * pos));
                                var rem = Math.max(0, total - cur);
                                var target = (card.timeDisplayMode === 0) ? rem : cur;

                                var m = Math.floor(target / 60);
                                var s = Math.floor(target % 60);
                                var ms = Math.floor((target % 1) * 10);
                                return (card.timeDisplayMode === 0 ? "-" : "") +
                                       m + ":" + (s < 10 ? "0" : "") + s + "." + ms;
                            }
                        }
                    }

                    MouseArea {
                        id: timeMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.timeDisplayMode = (card.timeDisplayMode === 0 ? 1 : 0)
                    }
                }

                // Hold to bend the tempo for manual beatmatching. Unlike a
                // scratch, the engine keeps this offset while sync is locked.
                NudgeButton {
                    Layout.preferredHeight: parent.height
                    control: rateTempDownControl
                    pointsRight: false
                }

                // Pitch / Tempo Percentage
                Rectangle {
                    Layout.preferredHeight: parent.height
                    Layout.preferredWidth: card.width < 380 ? 46 : 56
                    radius: 4
                    color: "#0c0c0c"
                    border.color: "#262626"
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "TEMPO"
                            font.pixelSize: 7
                            color: "#969696"
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.weight: Font.DemiBold
                            font.pixelSize: 10
                            color: card.accentColor
                            text: {
                                var p = ((rateRatioControl.value || 1) - 1) * 100.0;
                                return (p >= 0 ? "+" : "") + p.toFixed(1) + "%";
                            }
                        }
                    }
                }

                NudgeButton {
                    Layout.preferredHeight: parent.height
                    control: rateTempUpControl
                    pointsRight: true
                }

                // BPM Box (Hero display)
                Rectangle {
                    Layout.preferredHeight: parent.height
                    Layout.preferredWidth: card.width < 380 ? 70 : 84
                    radius: 4
                    color: "#0c0c0c"
                    border.color: (syncModeControl.value >= 2) ? "#ff8f57" : (syncEnabledControl.value > 0 ? "#2bd67b" : card.accentColor)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 3

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "BPM"
                                font.pixelSize: 7
                                color: "#969696"
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.weight: Font.DemiBold
                                font.pixelSize: card.width < 380 ? 12 : 14
                                color: (syncModeControl.value >= 2) ? "#f7c86a" : "#ffffff"
                                text: bpmControl.value > 0 ? bpmControl.value.toFixed(1) : "--.-"
                            }
                        }

                        // SYNC tag. A tap matches tempo and phase once
                        // (beatsync) so an accidental touch never locks the
                        // deck; a long press toggles sync lock, and a long
                        // press while locked toggles the leader.
                        Rectangle {
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: 38
                            radius: 3
                            color: (syncModeControl.value >= 2) ? "#ff8f57" : (syncEnabledControl.value > 0 ? "#2bd67b" : (syncMouse.pressed ? "#212121" : "#252525"))
                            border.color: "#2bd67b"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: (syncModeControl.value >= 2) ? "MSTR" : (syncEnabledControl.value > 0 ? "LOCK" : "SYNC")
                                font.weight: Font.DemiBold
                                font.pixelSize: 9
                                color: (syncModeControl.value >= 2 || syncEnabledControl.value > 0) ? "#000000" : "#bebebe"
                            }

                            MouseArea {
                                id: syncMouse
                                anchors.fill: parent
                                anchors.margins: -3
                                onClicked: {
                                    if (syncEnabledControl.value > 0) {
                                        syncEnabledControl.value = 0;
                                    } else {
                                        beatSyncControl.value = 1;
                                    }
                                }
                                onPressAndHold: {
                                    if (syncEnabledControl.value > 0) {
                                        syncLeaderControl.value = syncLeaderControl.value > 0 ? 0 : 1;
                                    } else {
                                        syncEnabledControl.value = 1;
                                    }
                                }
                            }
                        }
                    }
                }

                // Mini Transport: CUE & PLAY
                Rectangle {
                    Layout.preferredHeight: parent.height
                    Layout.preferredWidth: 36
                    radius: 4
                    color: cueMouse.pressed ? "#ff8f57" : "#1c1c1c"
                    border.color: "#ff8f57"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "CUE"
                        font.weight: Font.DemiBold
                        font.pixelSize: 10
                        color: cueMouse.pressed ? "#000000" : "#ff8f57"
                    }

                    MouseArea {
                        id: cueMouse
                        anchors.fill: parent
                        onPressed: cueControl.value = 1
                        onReleased: cueControl.value = 0
                    }
                }

                Rectangle {
                    Layout.preferredHeight: parent.height
                    Layout.preferredWidth: 38
                    radius: 4
                    color: playControl.value > 0 ? "#2bd67b" : (playMouse.pressed ? "#00b248" : "#1c1c1c")
                    border.color: "#2bd67b"
                    border.width: 1

                    // Drawn, as the fonts of Android lack the pause sign and
                    // draw the play sign as an emoji
                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        visible: playControl.value > 0

                        Repeater {
                            model: 2

                            Rectangle {
                                color: "#000000"
                                height: 11
                                width: 3
                            }
                        }
                    }
                    Skin.Triangle {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1
                        color: "#2bd67b"
                        height: 12
                        visible: playControl.value <= 0
                        width: 10
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        onClicked: playControl.value = (playControl.value > 0 ? 0 : 1)
                    }
                }
            }

            // -------- 3. BOTTOM OVERVIEW WAVEFORM --------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                radius: 4
                color: "#080808"
                border.color: "#262626"
                border.width: 1
                clip: true

                Skin.WaveformOverview {
                    anchors.fill: parent
                    anchors.margins: 1
                    group: card.group
                }
            }
        }
    }
}
