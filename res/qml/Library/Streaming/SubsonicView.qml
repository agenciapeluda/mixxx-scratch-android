import QtQuick
import "../../Cutlab" as Cutlab
import QtQuick.Controls 2.15
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "../../Theme"
import "../.." as Skin

Item {
    id: root

    property bool showSettings: !Mixxx.StreamingManager.isSubsonicConnected
    property string activeMode: "search" // "search", "playlists", "playlist_tracks"
    property var tracksModel: []
    property var playlistsModel: []
    property string currentPlaylistName: ""
    property string statusMessage: ""
    property bool isBusy: false
    property var downloadProgressMap: ({})

    Connections {
        target: Mixxx.StreamingManager

        function onSubsonicConnectionTested(success, message, version) {
            root.isBusy = false;
            root.statusMessage = success
                ? ("✓ " + message + (version ? " (" + version + ")" : ""))
                : ("" + message);
            if (success) {
                root.showSettings = false;
            }
        }

        function onSubsonicSearchFinished(success, songs, errorString) {
            root.isBusy = false;
            if (success) {
                root.tracksModel = songs;
                root.activeMode = "search";
                root.statusMessage = qsTr("%1 tracks found").arg(songs.length);
            } else {
                root.statusMessage = qsTr("Error: %1").arg(errorString);
            }
        }

        function onSubsonicPlaylistsFinished(success, playlists, errorString) {
            root.isBusy = false;
            if (success) {
                root.playlistsModel = playlists;
                root.activeMode = "playlists";
                root.statusMessage = qsTr("%1 playlists available").arg(playlists.length);
            } else {
                root.statusMessage = qsTr("Error: %1").arg(errorString);
            }
        }

        function onSubsonicPlaylistSongsFinished(success, songs, errorString) {
            root.isBusy = false;
            if (success) {
                root.tracksModel = songs;
                root.activeMode = "playlist_tracks";
                root.statusMessage = qsTr("%1 tracks in %2").arg(songs.length).arg(root.currentPlaylistName);
            } else {
                root.statusMessage = qsTr("Error: %1").arg(errorString);
            }
        }

        function onDownloadProgress(trackId, progress, bytesReceived, bytesTotal) {
            var updated = Object.assign({}, root.downloadProgressMap);
            updated[trackId] = progress;
            root.downloadProgressMap = updated;
        }

        function onDownloadFinished(trackId, localPath, targetDeck, autoPlay) {
            var updated = Object.assign({}, root.downloadProgressMap);
            delete updated[trackId];
            root.downloadProgressMap = updated;

            // QmlStreamingProxy already loaded the track safely into targetDeck in C++

            // Refresh cached indicator in tracksModel
            var currentTracks = root.tracksModel.slice();
            for (var i = 0; i < currentTracks.length; i++) {
                if (currentTracks[i].id === trackId) {
                    currentTracks[i].isCached = true;
                    break;
                }
            }
            root.tracksModel = currentTracks;
            root.statusMessage = qsTr("✓ Track ready and loaded into %1").arg(targetDeck === "[Channel1]" ? qsTr("Deck 1") : (targetDeck === "[Channel2]" ? qsTr("Deck 2") : qsTr("cache")));
        }

        function onDownloadFailed(trackId, errorMessage) {
            var updated = Object.assign({}, root.downloadProgressMap);
            delete updated[trackId];
            root.downloadProgressMap = updated;
            root.statusMessage = qsTr("Download error: %1").arg(errorMessage);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ================= TOP HEADER & TOGGLE BAR =================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            color: "#232323"
            border.color: "#2c2c2c"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: "Navidrome / Subsonic"
                    font.weight: Font.DemiBold
                    font.pixelSize: 13
                    font.letterSpacing: 1
                    color: "#837cff"
                }

                Rectangle {
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: statusText.implicitWidth + 14
                    radius: 11
                    color: Mixxx.StreamingManager.isSubsonicConnected ? "#00e67622" : "#ff525222"
                    border.color: Mixxx.StreamingManager.isSubsonicConnected ? "#2bd67b" : "#ff5d6c"
                    border.width: 1

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Mixxx.StreamingManager.isSubsonicConnected ? "#2bd67b" : "#ff5d6c"
                        text: Mixxx.StreamingManager.isSubsonicConnected ? qsTr("● Connected") : qsTr("● Disconnected")
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: root.statusMessage !== ""
                    text: root.statusMessage
                    font.pixelSize: 11
                    color: "#bebebe"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 280
                }

                Cutlab.CLButton {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 100
                    highlighted: root.showSettings
                    text: root.showSettings ? qsTr("▲ Hide") : qsTr("Settings")
                    onClicked: root.showSettings = !root.showSettings
                }
            }
        }

        // ================= SETTINGS DRAWER =================
        Rectangle {
            id: settingsDrawer
            Layout.fillWidth: true
            Layout.preferredHeight: root.showSettings ? implicitHeight : 0
            implicitHeight: 90
            visible: root.showSettings
            clip: true
            color: "#1a1a1a"
            border.color: "#303030"
            border.width: 1

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200 }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    TextField {
                        id: serverUrlField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        placeholderText: qsTr("Server URL (e.g. http://192.168.1.50:4533)")
                        text: Mixxx.StreamingManager.subsonicUrl
                        color: "#ffffff"
                        font.pixelSize: 12
                        background: Rectangle {
                            color: "#282828"
                            border.color: serverUrlField.activeFocus ? "#837cff" : "#343434"
                            border.width: 1
                            radius: 4
                        }
                        onEditingFinished: Mixxx.StreamingManager.subsonicUrl = text
                    }

                    TextField {
                        id: userField
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 34
                        placeholderText: qsTr("Username")
                        text: Mixxx.StreamingManager.subsonicUsername
                        color: "#ffffff"
                        font.pixelSize: 12
                        background: Rectangle {
                            color: "#282828"
                            border.color: userField.activeFocus ? "#837cff" : "#343434"
                            border.width: 1
                            radius: 4
                        }
                        onEditingFinished: Mixxx.StreamingManager.subsonicUsername = text
                    }

                    TextField {
                        id: passField
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 34
                        placeholderText: qsTr("Password")
                        echoMode: TextInput.Password
                        text: Mixxx.StreamingManager.subsonicPassword
                        color: "#ffffff"
                        font.pixelSize: 12
                        background: Rectangle {
                            color: "#282828"
                            border.color: passField.activeFocus ? "#837cff" : "#343434"
                            border.width: 1
                            radius: 4
                        }
                        onEditingFinished: Mixxx.StreamingManager.subsonicPassword = text
                    }

                    Cutlab.CLButton {
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: 110
                        highlighted: true
                        text: root.isBusy ? qsTr("Connecting") : qsTr("✓ Connect")
                        enabled: !root.isBusy
                        onClicked: {
                            Mixxx.StreamingManager.subsonicUrl = serverUrlField.text;
                            Mixxx.StreamingManager.subsonicUsername = userField.text;
                            Mixxx.StreamingManager.subsonicPassword = passField.text;
                            root.isBusy = true;
                            root.statusMessage = qsTr("Connecting to the server...");
                            Mixxx.StreamingManager.testSubsonicConnection();
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: qsTr("Compatible with Navidrome, Funkwhale, Ampache, Subsonic, Airsonic and Nextcloud Music.")
                        font.pixelSize: 11
                        color: "#7a7a7a"
                        Layout.fillWidth: true
                    }

                    Cutlab.CLButton {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: 140
                        fillColor: Cutlab.Style.button
                        fontSize: 13
                        text: qsTr("Clear cache")
                        onClicked: {
                            Mixxx.StreamingManager.clearCache();
                            root.statusMessage = qsTr("Streaming cache cleared");
                        }
                    }
                }
            }
        }

        // ================= SEARCH & NAVIGATION TOOLBAR =================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            color: "#171717"
            border.color: "#2c2c2c"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 8

                Cutlab.CLButton {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 100
                    highlighted: root.activeMode === "search"
                    text: qsTr("Search")
                    onClicked: {
                        root.activeMode = "search";
                        if (searchInput.text.trim() !== "") {
                            root.isBusy = true;
                            Mixxx.StreamingManager.searchSubsonic(searchInput.text);
                        }
                    }
                }

                Cutlab.CLButton {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 105
                    highlighted: root.activeMode === "playlists"
                    text: qsTr("Playlists")
                    onClicked: {
                        root.isBusy = true;
                        Mixxx.StreamingManager.getSubsonicPlaylists();
                    }
                }

                // Search Box
                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    placeholderText: qsTr("Search artists, tracks or albums in your cloud...")
                    color: "#ffffff"
                    font.pixelSize: 13
                    background: Rectangle {
                        color: "#2a2a2a"
                        border.color: searchInput.activeFocus ? "#837cff" : "#3a3a3a"
                        border.width: 1
                        radius: 4
                    }
                    onAccepted: {
                        if (text.trim() !== "") {
                            root.isBusy = true;
                            root.statusMessage = qsTr("Searching...");
                            Mixxx.StreamingManager.searchSubsonic(text);
                        }
                    }
                }

                Cutlab.CLButton {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 40
                    fillColor: Cutlab.Style.button
                    icon: "search"
                    iconSize: 20
                    onClicked: searchInput.accepted()
                }
            }
        }

        // ================= PLAYLIST HEADER (if in playlist tracks) =================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.activeMode === "playlist_tracks" ? 34 : 0
            visible: root.activeMode === "playlist_tracks"
            color: "#282828"
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 8

                Cutlab.CLButton {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: 80
                    fillColor: Cutlab.Style.button
                    text: qsTr("Back")
                    onClicked: root.activeMode = "playlists"
                }

                Text {
                    text: root.currentPlaylistName
                    font.weight: Font.DemiBold
                    font.pixelSize: 13
                    color: "#ada9ff"
                    Layout.fillWidth: true
                }
            }
        }

        // ================= CONTENT AREA =================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // --- TRACKS LISTVIEW (Search & Playlist Tracks) ---
            ListView {
                id: tracksList
                anchors.fill: parent
                visible: root.activeMode !== "playlists"
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.tracksModel

                ScrollBar.vertical: ScrollBar {
                    id: subScroll
                    width: 14
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 10
                        implicitHeight: 40
                        radius: 5
                        color: subScroll.pressed ? "#837cff" : "#595959"
                    }
                }

                delegate: Rectangle {
                    id: trackDelegate
                    width: tracksList.width
                    height: 56
                    color: index % 2 === 0 ? "#1c1c1c" : "#181818"
                    border.color: "#212121"
                    border.width: 1

                    readonly property var song: modelData
                    readonly property real downloadProg: root.downloadProgressMap[song.id] !== undefined ? root.downloadProgressMap[song.id] : -1
                    readonly property bool isDownloading: downloadProg >= 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        // Cover Art Thumbnail or Icon
                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 4
                            color: "#323232"
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: song.coverArtUrl ? song.coverArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.pixelSize: 16
                                visible: !song.coverArtUrl
                            }
                        }

                        // Title, Artist, Album
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: song.title
                                font.weight: Font.DemiBold
                                font.pixelSize: 13
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: song.artist + (song.album ? (" • " + song.album) : "")
                                    font.pixelSize: 11
                                    color: "#969696"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Format / Bitrate Pill
                        Rectangle {
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: formatText.implicitWidth + 8
                            color: "#262626"
                            radius: 3

                            Text {
                                id: formatText
                                anchors.centerIn: parent
                                text: (song.suffix ? song.suffix : "MP3") + (song.bitRate ? (" " + song.bitRate + "k") : "")
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: "#4238f8"
                            }
                        }

                        // Duration
                        Text {
                            text: {
                                var s = song.duration || 0;
                                var m = Math.floor(s / 60);
                                var sec = Math.floor(s % 60);
                                return m + ":" + (sec < 10 ? "0" : "") + sec;
                            }
                            font.pixelSize: 11
                            color: "#7a7a7a"
                        }

                        // Offline Cache Status Pill
                        Rectangle {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: cacheStatusText.implicitWidth + 10
                            radius: 10
                            color: song.isCached ? "#00e67622" : "#0288d122"
                            border.color: song.isCached ? "#2bd67b" : "#0c02d1"
                            border.width: 1

                            Text {
                                id: cacheStatusText
                                anchors.centerIn: parent
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: song.isCached ? "#2bd67b" : "#0c02d1"
                                text: song.isCached ? qsTr("Ready") : qsTr("Cloud")
                            }
                        }

                        // Load Deck 1 Button
                        Cutlab.CLButton {
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: 80
                            fillColor: Cutlab.Style.button
                            fontSize: 13
                            text: "1"
                            enabled: !trackDelegate.isDownloading
                            onClicked: {
                                Mixxx.StreamingManager.downloadAndLoad(
                                    song.streamUrl, "subsonic", song.id, song.title, song.artist, "[Channel1]", false
                                );
                            }
                        }

                        // Load Deck 2 Button
                        Cutlab.CLButton {
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: 80
                            fillColor: Cutlab.Style.button
                            fontSize: 13
                            text: "2"
                            enabled: !trackDelegate.isDownloading
                            onClicked: {
                                Mixxx.StreamingManager.downloadAndLoad(
                                    song.streamUrl, "subsonic", song.id, song.title, song.artist, "[Channel2]", false
                                );
                            }
                        }
                    }

                    // Progress bar across bottom when downloading
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        height: 3
                        visible: trackDelegate.isDownloading
                        width: parent.width * Math.max(0.05, trackDelegate.downloadProg)
                        color: "#837cff"
                    }
                }

                // Empty / Placeholder View
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    height: 120
                    color: "transparent"
                    visible: tracksList.count === 0 && !root.isBusy

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: Mixxx.StreamingManager.isSubsonicConnected
                                ? qsTr("Type an artist, title or album to search your server")
                                : qsTr("Connect your Navidrome / Subsonic server in the settings above")
                            font.pixelSize: 13
                            color: "#7a7a7a"
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            // --- PLAYLISTS LISTVIEW ---
            ListView {
                id: playlistsList
                anchors.fill: parent
                visible: root.activeMode === "playlists"
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.playlistsModel

                ScrollBar.vertical: ScrollBar {
                    width: 6
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    width: playlistsList.width
                    height: 52
                    color: index % 2 === 0 ? "#1c1c1c" : "#181818"
                    border.color: "#212121"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Text {
                            text: ""
                            font.pixelSize: 20
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.name
                                font.weight: Font.DemiBold
                                font.pixelSize: 14
                                color: "#ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: qsTr("%1 tracks").arg(modelData.songCount)
                                font.pixelSize: 11
                                color: "#969696"
                            }
                        }

                        Cutlab.CLButton {
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: 95
                            highlighted: true
                            fontSize: 13
                            text: qsTr("Show tracks")
                            onClicked: {
                                root.currentPlaylistName = modelData.name;
                                root.isBusy = true;
                                root.statusMessage = qsTr("Loading %1...").arg(modelData.name);
                                Mixxx.StreamingManager.getSubsonicPlaylistSongs(modelData.id);
                            }
                        }
                    }
                }
            }

            // Loading overlay
            Rectangle {
                anchors.centerIn: parent
                width: 140
                height: 40
                radius: 6
                color: "#282828"
                border.color: "#837cff"
                border.width: 1
                visible: root.isBusy

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: ""
                        font.pixelSize: 16
                        color: "#837cff"
                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: root.isBusy
                        }
                    }

                    Text {
                        text: qsTr("Loading...")
                        font.weight: Font.DemiBold
                        font.pixelSize: 12
                        color: "#ffffff"
                    }
                }
            }
        }
    }
}
