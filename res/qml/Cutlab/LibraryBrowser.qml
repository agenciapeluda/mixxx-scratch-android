import "../Library" as LibraryComponent
import "../Library/Streaming" as StreamingComponent
import Mixxx 1.0 as Mixxx
import QtQml.Models
import QtQuick
import QtQuick.Controls

// The library over the whole screen: the source at the top, sections at the
// bottom (your folders, genres, playlists, Auto DJ queue, history), the
// tracks that suit the playing deck and a list you go into and back out of.
// The browse knob of a controller moves through it and LOAD loads the track
// and closes it; tapping a track does the same.
Rectangle {
    id: root

    // The deck or sampler that gets the track, empty for the next free deck
    property string targetGroup: ""
    // 0 local music, 1 streaming
    property int source: 0
    // 0 your folders, 1 genres, 2 playlists, 3 Auto DJ queue, 4 history
    property int section: 0
    property var pages: []
    readonly property var page: pages.length > 0 ? pages[pages.length - 1] : null
    readonly property var sidebar: sourceTree.sidebar()
    readonly property var tracklist: sidebar ? sidebar.tracklist : null
    property bool searching: false
    // The track picked with the controller's browse knob
    property int selectedRow: -1
    // The browse knob moves through the suggestions instead of the tracks
    property bool focusSuggestions: false
    property int selectedSuggestion: 0
    // The deck the suggestions are for: the one playing, else deck 1
    readonly property string playingGroup: play2.value > 0 && play1.value <= 0 ? "[Channel2]" : "[Channel1]"
    property var suggestions: []
    property var folderRows: []
    property var genreRows: []
    // The folder or genre picked with the browse knob
    property int selectedNode: 0
    readonly property var nodeRows: !root.page ? [] : (root.page.rows === "folders"
        ? [{name: qsTr("Todas las canciones"), path: "", count: -1}].concat(root.folderRows)
        : (root.page.rows === "genres" ? root.genreRows : []))
    // How the tracks are sorted: a TrackModel::SortColumnId
    // (1 artist, 2 title, 13 duration, 15 BPM, 17 added, 20 key, 31 played)
    property int sortId: parseInt(Mixxx.Application.configValue("[Cutlab]", "library_sort", "17"))
    property bool sortAscending: Mixxx.Application.configValue("[Cutlab]", "library_sort_asc", "0") === "1"
    readonly property var sortNames: ({1: qsTr("Artista"), 2: qsTr("Título"), 13: qsTr("Duración"), 15: qsTr("BPM"), 17: qsTr("Agregados"), 20: qsTr("Tonalidad"), 31: qsTr("Tocados")})
    // Only the tracks near the tempo or in a key that mixes with the deck
    // that is playing
    property bool filterBpm: false
    property bool filterKey: false
    property int missing: 0
    // Playlists and crates holding the picked track
    readonly property var pickedLists: root.selectedRow >= 0 ? Mixxx.Cutlab.listsContaining(root.urlAt(root.selectedRow)) : []

    function refreshSuggestions() {
        root.suggestions = Mixxx.Cutlab.suggestions(root.playingGroup, 12);
        root.selectedSuggestion = 0;
    }
    function loadUrl(url, group) {
        if (!url || url.toString() === "") {
            return;
        }
        if (group && group !== "") {
            Mixxx.PlayerManager.getPlayer(group).loadTrackFromLocationUrl(url, false);
        } else {
            Mixxx.PlayerManager.loadLocationUrlIntoNextAvailableDeck(url, false);
        }
        root.close();
    }

    Mixxx.ControlProxy {
        id: play1

        group: "[Channel1]"
        key: "play_latched"
    }
    Mixxx.ControlProxy {
        id: play2

        group: "[Channel2]"
        key: "play_latched"
    }

    signal closeRequested
    signal settingsRequested
    signal autoDJRequested
    signal foldersRequested

    color: Style.background

    function open(group) {
        root.targetGroup = group || "";
        root.visible = true;
        root.refreshSuggestions();
        root.missing = Mixxx.Cutlab.missingAnalysis();
        if (root.pages.length === 0) {
            root.showSection(root.section);
        } else {
            // Bring back the tracks of the page on top
            root.activatePage(root.page);
        }
    }
    function close() {
        root.searching = false;
        root.closeRequested();
    }

    // The top level node of the sidebar with this icon name
    function featureIndex(iconName) {
        if (!root.sidebar) {
            return null;
        }
        const rows = root.sidebar.rowCount();
        for (let row = 0; row < rows; ++row) {
            const index = root.sidebar.index(row, 0);
            // SidebarModel::IconNameRole
            if (root.sidebar.data(index, Qt.UserRole + 1) === iconName) {
                return index;
            }
        }
        return null;
    }
    function labelOf(index) {
        const label = index && root.sidebar ? root.sidebar.data(index, Qt.DisplayRole) : "";
        return label ? label.toString() : "";
    }
    function activatePage(page) {
        if (page && page.node && page.node.valid) {
            root.sidebar.activate(page.node);
            root.refreshQuery();
        }
    }
    function push(page) {
        root.activatePage(page);
        root.pages = root.pages.concat([page]);
        trackView.positionViewAtBeginning();
    }
    function back() {
        if (root.pages.length <= 1) {
            root.close();
            return;
        }
        root.pages = root.pages.slice(0, root.pages.length - 1);
        root.activatePage(root.page);
    }
    function showSection(section) {
        root.section = section;
        root.selectedNode = 0;
        root.searching = false;
        searchField.text = "";
        let page;
        switch (section) {
        case 0: {
            root.folderRows = Mixxx.Cutlab.musicFolders();
            page = {title: qsTr("Tus carpetas"), parents: [], node: null, showTracks: false, rows: "folders"};
            break;
        }
        case 1: {
            root.genreRows = Mixxx.Cutlab.genres();
            page = {title: qsTr("Géneros"), parents: [], node: null, showTracks: false, rows: "genres"};
            break;
        }
        case 2: {
            const parents = ["playlist", "crates", "rekordbox", "enginedj", "recordings"]
                .map(name => root.featureIndex(name))
                .filter(index => index !== null);
            page = {title: qsTr("Listas"), parents: parents, node: null, showTracks: false};
            break;
        }
        case 3: {
            const queue = root.featureIndex("autodj");
            page = {title: qsTr("Queue"), parents: [], node: queue, showTracks: true, queue: true};
            break;
        }
        case 4: {
            const history = root.featureIndex("history");
            page = {title: qsTr("History"), parents: history ? [history] : [], node: null, showTracks: false};
            break;
        }
        }
        root.pages = [];
        root.push(page);
    }
    // A music folder or a genre was tapped: all tracks, filtered
    function openFiltered(title, filter) {
        root.push({
            title: title,
            parents: [],
            node: root.featureIndex("tracks"),
            showTracks: true,
            filter: filter
        });
    }
    // A playlist, crate, folder or history session was tapped
    function openNode(index) {
        const folders = root.page && root.page.folders;
        root.push({
            title: root.labelOf(index),
            parents: folders ? [index] : [],
            node: index,
            showTracks: true,
            folders: folders
        });
    }

    function urlAt(row) {
        return root.tracklist ? root.tracklist.getUrl(row) : "";
    }
    function load(row, group) {
        const url = root.urlAt(row);
        if (url.toString() === "") {
            return;
        }
        if (group && group !== "") {
            Mixxx.PlayerManager.getPlayer(group).loadTrackFromLocationUrl(url, false);
        } else {
            Mixxx.PlayerManager.loadLocationUrlIntoNextAvailableDeck(url, false);
        }
        root.close();
    }
    // The search of the page, the filters and the typed text together, then
    // the sorting
    function queryText() {
        const parts = [];
        if (root.page && root.page.filter) {
            parts.push(root.page.filter);
        }
        if (root.filterBpm) {
            const bpm = root.playingGroup === "[Channel2]" ? bpm2.value : bpm1.value;
            if (bpm > 0) {
                parts.push("~bpm:" + bpm.toFixed(1));
            }
        }
        if (root.filterKey) {
            const key = Mixxx.Cutlab.deckKey(root.playingGroup);
            if (key !== "") {
                parts.push("~key:" + key);
            }
        }
        if (root.searching && searchField.text.trim() !== "") {
            parts.push(searchField.text.trim());
        }
        return parts.join(" ");
    }
    function refreshQuery() {
        if (!root.tracklist) {
            return;
        }
        root.tracklist.search(root.queryText());
        root.tracklist.sortById(root.sortId, root.sortAscending);
        root.selectedRow = -1;
    }
    function setSort(id, ascending) {
        root.sortId = id;
        root.sortAscending = ascending;
        Mixxx.Application.setConfigValue("[Cutlab]", "library_sort", id.toString());
        Mixxx.Application.setConfigValue("[Cutlab]", "library_sort_asc", ascending ? "1" : "0");
        if (root.tracklist) {
            root.tracklist.sortById(id, ascending);
        }
        trackView.positionViewAtBeginning();
    }
    function applySearch() {
        if (!root.tracklist) {
            return;
        }
        if (!root.page || !root.page.showTracks) {
            // Search all tracks from the sections without tracks
            root.section = 0;
            root.pages = [];
            root.push({title: qsTr("Todas las canciones"), parents: [], node: root.featureIndex("tracks"), showTracks: true});
            return;
        }
        root.refreshQuery();
    }
    function openSelectedNode() {
        const rows = root.nodeRows;
        if (root.selectedNode < 0 || root.selectedNode >= rows.length) {
            return;
        }
        const row = rows[root.selectedNode];
        if (root.page.rows === "folders") {
            root.openFiltered(row.name, row.path === "" ? "" : "location:\"" + row.path + "/\"");
        } else {
            root.openFiltered(row.name, "genre:\"" + row.name + "\"");
        }
    }
    // The browse knob of a controller was pressed: into the folder or
    // genre, or listen to the picked track on the preview deck
    function browsePress() {
        if (root.page && !root.page.showTracks && root.nodeRows.length > 0) {
            root.openSelectedNode();
            return;
        }
        if (previewPlay.value > 0) {
            previewStop.value = 1;
            return;
        }
        const url = root.focusSuggestions && root.suggestions.length > 0
            ? root.suggestions[root.selectedSuggestion].url
            : (root.selectedRow >= 0 ? root.urlAt(root.selectedRow) : "");
        if (url && url.toString() !== "") {
            Mixxx.PlayerManager.getPlayer("[PreviewDeck1]").loadTrackFromLocationUrl(url, true);
        }
    }

    Mixxx.ControlProxy {
        id: bpm1

        group: "[Channel1]"
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: bpm2

        group: "[Channel2]"
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: previewPlay

        group: "[PreviewDeck1]"
        key: "play"
    }
    Mixxx.ControlProxy {
        id: previewStop

        group: "[PreviewDeck1]"
        key: "stop"
    }
    // A scan is over: new folders and tracks
    Connections {
        target: Mixxx.Cutlab

        function onLibraryScanned() {
            root.missing = Mixxx.Cutlab.missingAnalysis();
            root.folderRows = Mixxx.Cutlab.musicFolders();
            root.genreRows = Mixxx.Cutlab.genres();
        }
    }

    LibraryComponent.SourceTree {
        id: sourceTree
    }

    // The controller's browse knob scrolls the tracks and loads them
    LibraryComponent.Control {
        enabled: root.visible && root.source === 0

        onMoveVertical: offset => {
            if (root.focusSuggestions && root.suggestions.length > 0) {
                root.selectedSuggestion = Math.max(0, Math.min(root.suggestions.length - 1, root.selectedSuggestion + offset));
                suggestionView.positionViewAtIndex(root.selectedSuggestion, ListView.Contain);
                return;
            }
            if (!root.page || !root.page.showTracks) {
                // In the folders or genres the knob picks one, LOAD or a
                // press of the knob goes into it
                if (root.nodeRows.length > 0) {
                    root.selectedNode = Math.max(0, Math.min(root.nodeRows.length - 1, root.selectedNode + offset));
                    trackView.positionViewAtBeginning();
                    trackView.contentY = Math.max(0, root.selectedNode * 56 - trackView.height / 2);
                }
                return;
            }
            root.selectedRow = Math.max(0, Math.min(trackView.count - 1, root.selectedRow + offset));
            trackView.positionViewAtIndex(root.selectedRow, ListView.Contain);
        }
        onLoadSelectedTrack: (group, play) => {
            if (root.page && !root.page.showTracks && root.nodeRows.length > 0) {
                root.openSelectedNode();
            } else if (root.focusSuggestions && root.suggestions.length > 0) {
                root.loadUrl(root.suggestions[root.selectedSuggestion].url, group);
            } else if (root.selectedRow >= 0) {
                root.load(root.selectedRow, group);
            }
        }
        onLoadSelectedTrackIntoNextAvailableDeck: play => {
            if (root.page && !root.page.showTracks && root.nodeRows.length > 0) {
                root.openSelectedNode();
            } else if (root.focusSuggestions && root.suggestions.length > 0) {
                root.loadUrl(root.suggestions[root.selectedSuggestion].url, "");
            } else if (root.selectedRow >= 0) {
                root.load(root.selectedRow, "");
            }
        }
    }
    // SHIFT + browse on the controllers (or tapping the strip) switches the
    // knob between the suggestions and the tracks
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: "browse_suggestions"
        onValueChanged: {
            if (value > 0 && root.visible) {
                root.focusSuggestions = !root.focusSuggestions;
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "MoveFocusForward"
        onValueChanged: {
            if (value > 0 && root.visible) {
                root.focusSuggestions = !root.focusSuggestions;
            }
        }
    }

    // Top bar
    Rectangle {
        id: topBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: Style.topBar

        CLButton {
            id: closeButton

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            icon: root.pages.length > 1 && root.source === 0 ? "back" : "close"
            iconSize: 22
            bordered: false
            fillColor: "transparent"
            onClicked: root.pages.length > 1 && root.source === 0 ? root.back() : root.close()
        }
        CLButton {
            id: sourceButton

            anchors.left: closeButton.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: sourceLabel.implicitWidth + 44
            height: 38
            fillColor: Style.raised
            bordered: false
            radius: 10
            onClicked: sourceMenu.open()

            Text {
                id: sourceLabel

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Style.text
                font.family: Style.font
                font.pixelSize: 14
                font.weight: Font.Medium
                text: root.source === 0 ? qsTr("Local music") : qsTr("Streaming")
            }
            Image {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: "icons/chevron_down.svg"
                sourceSize.width: 32
                sourceSize.height: 32
            }

            CLMenu {
                id: sourceMenu

                y: sourceButton.height + 4

                CLMenuItem {
                    text: qsTr("Local music")
                    onTriggered: root.source = 0
                }
                CLMenuItem {
                    text: qsTr("Streaming")
                    onTriggered: root.source = 1
                }
            }
        }
        Text {
            anchors.left: sourceButton.right
            anchors.leftMargin: 16
            anchors.right: actions.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Style.text
            elide: Text.ElideRight
            font.family: Style.font
            font.pixelSize: 17
            text: root.source === 0 && root.page ? root.page.title : ""
            visible: !root.searching
        }
        TextField {
            id: searchField

            anchors.left: sourceButton.right
            anchors.leftMargin: 16
            anchors.right: actions.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 40
            visible: root.searching
            color: Style.text
            font.family: Style.font
            font.pixelSize: 15
            placeholderText: qsTr("Search title, artist, album…")
            placeholderTextColor: Style.textDim
            inputMethodHints: Qt.ImhNoPredictiveText
            background: Rectangle {
                radius: 10
                color: Style.raised
            }
            onTextChanged: searchTimer.restart()

            Timer {
                id: searchTimer

                interval: 300
                onTriggered: root.applySearch()
            }
        }
        Row {
            id: actions

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.source === 0

            CLButton {
                width: 44
                height: 44
                icon: root.searching ? "close" : "search"
                iconSize: 22
                bordered: false
                fillColor: "transparent"
                onClicked: {
                    root.searching = !root.searching;
                    if (root.searching) {
                        searchField.forceActiveFocus();
                    } else if (searchField.text !== "") {
                        searchField.text = "";
                        root.applySearch();
                    }
                }
            }
            CLButton {
                id: moreButton

                width: 44
                height: 44
                icon: "more"
                iconSize: 22
                bordered: false
                fillColor: "transparent"
                onClicked: moreMenu.open()

                CLMenu {
                    id: moreMenu

                    y: moreButton.height
                    x: moreButton.width - width

                    CLMenuItem {
                        text: root.missing > 0 ? qsTr("Analizar BPM y tono (%1 pendientes)").arg(root.missing) : qsTr("Todo analizado")
                        enabled: root.missing > 0
                        onTriggered: {
                            Mixxx.Cutlab.analyzeMissing();
                            root.missing = 0;
                        }
                    }
                    CLMenuItem {
                        text: qsTr("Separar stems de esta lista…")
                        enabled: root.page && root.page.showTracks && trackView.count > 0
                        onTriggered: stemsPopup.openFor("")
                    }
                    CLMenuItem {
                        text: qsTr("Rescan the library")
                        onTriggered: Mixxx.Library.rescanLibrary()
                    }
                    CLMenuItem {
                        text: qsTr("Auto DJ…")
                        onTriggered: root.autoDJRequested()
                    }
                    CLMenuItem {
                        text: qsTr("Library settings…")
                        onTriggered: root.settingsRequested()
                    }
                }
            }
        }
    }

    // Who gets the track
    Rectangle {
        id: targetBar

        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        // On a short screen the tracks get the room, except to show the
        // lists the picked track is in
        height: root.source === 0 && (root.height >= 480 || !(root.page && root.page.showTracks) || root.pickedLists.length > 0) ? 34 : 0
        visible: height > 0
        color: Style.panelDark

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: root.pickedLists.length > 0 ? Style.accentText : Style.textSecondary
            font.family: Style.font
            font.pixelSize: 13
            width: parent.width - 32
            elide: Text.ElideRight
            text: {
                if (root.pickedLists.length > 0)
                    return qsTr("También en: %1").arg(root.pickedLists.join(" · "));
                const g = root.targetGroup;
                if (g.startsWith("[Sampler"))
                    return qsTr("Tocá un tema para cargarlo en el pad %1").arg(g.replace(/\D/g, ""));
                if (root.page && !root.page.showTracks)
                    return qsTr("Girá BROWSE para elegir · apretá BROWSE o LOAD para entrar");
                return qsTr("Girá BROWSE para moverte · apretá para escuchar · LOAD A / B carga · SHIFT + BROWSE a los sugeridos");
            }
        }
    }

    // Local music
    Item {
        id: localArea

        anchors.top: targetBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: tabBar.top
        visible: root.source === 0

        // The tracks that suit the one playing, Tidal style
        Rectangle {
            id: suggestionStrip

            anchors.top: parent.top
            width: parent.width
            height: root.suggestions.length > 0 ? 104 : 0
            visible: height > 0
            color: Style.panel

            Text {
                id: suggestionTitle

                x: 16
                y: 8
                color: root.focusSuggestions ? Style.accentText : Style.text
                font.family: Style.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                text: qsTr("Sugeridos para lo que suena en %1").arg(Style.deckLetter(root.playingGroup))

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: root.focusSuggestions = !root.focusSuggestions
                }
            }
            ListView {
                id: suggestionView

                anchors.top: suggestionTitle.bottom
                anchors.topMargin: 6
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                height: 62
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: root.suggestions

                delegate: Rectangle {
                    id: suggestion

                    required property var modelData
                    required property int index
                    readonly property bool picked: root.focusSuggestions && root.selectedSuggestion === index

                    width: 236
                    height: 62
                    radius: 10
                    color: picked ? Style.track : Style.panelDark
                    border.width: picked ? 2 : 1
                    border.color: picked ? Style.accent : Qt.rgba(0.55, 0.52, 1, 0.25)

                    Column {
                        anchors.left: parent.left
                        anchors.right: bpmText.left
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            color: Style.text
                            elide: Text.ElideRight
                            font.family: Style.font
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            text: suggestion.modelData.title
                        }
                        Text {
                            width: parent.width
                            color: Style.textSecondary
                            elide: Text.ElideRight
                            font.family: Style.font
                            font.pixelSize: 11
                            text: suggestion.modelData.why || suggestion.modelData.artist
                        }
                    }
                    Column {
                        id: bpmText

                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            anchors.right: parent.right
                            color: Style.text
                            font.family: Style.mono
                            font.weight: Font.Bold
                            font.pixelSize: 13
                            text: suggestion.modelData.bpm > 0 ? suggestion.modelData.bpm.toFixed(1) : ""
                        }
                        Text {
                            anchors.right: parent.right
                            color: Style.keyColor(suggestion.modelData.key)
                            font.family: Style.mono
                            font.weight: Font.Bold
                            font.pixelSize: 11
                            text: suggestion.modelData.key
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.loadUrl(suggestion.modelData.url,
                            root.targetGroup !== "" ? root.targetGroup : (root.playingGroup === "[Channel1]" ? "[Channel2]" : "[Channel1]"))
                    }
                }
            }
        }

        // Sorting and filters of the tracks, like djay
        Rectangle {
            id: sortBar

            anchors.top: suggestionStrip.bottom
            width: parent.width
            height: root.page && root.page.showTracks ? 48 : 0
            visible: height > 0
            color: Style.panelDark

            Flickable {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                contentWidth: sortRow.width
                flickableDirection: Flickable.HorizontalFlick
                clip: true

                Row {
                    id: sortRow

                    height: parent.height
                    spacing: 8

                    Repeater {
                        model: [17, 2, 1, 15, 20, 13, 31]

                        Rectangle {
                            id: sortChip

                            required property int modelData
                            readonly property bool active: root.sortId === modelData

                            anchors.verticalCenter: parent.verticalCenter
                            height: 32
                            width: sortText.implicitWidth + 24
                            radius: 16
                            color: active ? Style.accent : Style.raised

                            Text {
                                id: sortText

                                anchors.centerIn: parent
                                color: Style.text
                                font.family: Style.font
                                font.pixelSize: 13
                                font.weight: sortChip.active ? Font.DemiBold : Font.Normal
                                text: root.sortNames[sortChip.modelData] + (sortChip.active ? (root.sortAscending ? "  ↑" : "  ↓") : "")
                            }
                            MouseArea {
                                anchors.fill: parent
                                // Tapped again: the other way round
                                onClicked: root.setSort(sortChip.modelData,
                                    sortChip.active ? !root.sortAscending : [1, 2, 15, 20].includes(sortChip.modelData))
                            }
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 24
                        color: Style.divider
                    }
                    Repeater {
                        model: [
                            {id: "bpm", label: qsTr("BPM ≈ %1").arg(Style.deckLetter(root.playingGroup))},
                            {id: "key", label: qsTr("Tono ≈ %1").arg(Style.deckLetter(root.playingGroup))}
                        ]

                        Rectangle {
                            id: filterChip

                            required property var modelData
                            readonly property bool active: modelData.id === "bpm" ? root.filterBpm : root.filterKey

                            anchors.verticalCenter: parent.verticalCenter
                            height: 32
                            width: filterText.implicitWidth + 24
                            radius: 16
                            color: active ? Style.deckColor(root.playingGroup) : "transparent"
                            border.width: 1
                            border.color: active ? "transparent" : Style.buttonBorder

                            Text {
                                id: filterText

                                anchors.centerIn: parent
                                color: filterChip.active ? Style.background : Style.text
                                font.family: Style.font
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                text: filterChip.modelData.label
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (filterChip.modelData.id === "bpm") {
                                        root.filterBpm = !root.filterBpm;
                                    } else {
                                        root.filterKey = !root.filterKey;
                                    }
                                    root.refreshQuery();
                                }
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 8
                        color: Style.textSecondary
                        font.family: Style.mono
                        font.pixelSize: 12
                        text: qsTr("%1 temas").arg(trackView.count)
                    }
                }
            }
        }

        ListView {
            id: trackView

            anchors.top: sortBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.page && root.page.showTracks ? root.tracklist : null
            onModelChanged: root.selectedRow = -1
            ScrollBar.vertical: ScrollBar {
            }

            // The playlists, crates or folders of the page come first
            header: Column {
                width: trackView.width

                // Your music folders: each one works like a crate that
                // follows the folder, plus all the tracks
                Repeater {
                    model: root.page && root.page.rows === "folders" ? root.nodeRows : []

                    NodeRow {
                        required property var modelData
                        required property int index

                        selected: root.selectedNode === index
                        width: trackView.width
                        text: modelData.count >= 0 ? modelData.name + "  ·  " + modelData.count : modelData.name
                        icon: modelData.path === "" ? "note" : "folder"
                        onClicked: root.openFiltered(modelData.name,
                            modelData.path === "" ? "" : "location:\"" + modelData.path + "/\"")
                    }
                }
                Repeater {
                    model: root.page && root.page.rows === "genres" ? root.genreRows : []

                    NodeRow {
                        required property var modelData
                        required property int index

                        selected: root.selectedNode === index
                        width: trackView.width
                        text: modelData.name + "  ·  " + modelData.count
                        icon: "list"
                        onClicked: root.openFiltered(modelData.name, "genre:\"" + modelData.name + "\"")
                    }
                }
                // Choose the folders again
                CLButton {
                    x: 16
                    width: Math.min(trackView.width - 32, 320)
                    height: root.page && root.page.rows === "folders" ? 44 : 0
                    visible: height > 0
                    icon: "folder"
                    iconSize: 18
                    fontSize: 14
                    text: qsTr("Elegir mis carpetas de música…")
                    onClicked: root.foldersRequested()
                }

                Repeater {
                    model: root.page ? root.page.parents : []

                    Column {
                        id: parentSection

                        required property var modelData
                        required property int index

                        width: trackView.width

                        // Section title, except for a folder's own subfolders
                        Text {
                            leftPadding: 16
                            topPadding: 16
                            bottomPadding: 6
                            color: Style.textSecondary
                            font.family: Style.font
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            text: root.labelOf(parentSection.modelData).toUpperCase()
                            visible: !(root.page && root.page.node) && root.page.parents.length > 1
                        }

                        Repeater {
                            model: DelegateModel {
                                id: childNodes

                                model: root.sidebar
                                rootIndex: parentSection.modelData

                                delegate: NodeRow {
                                    required property int index
                                    required property var model

                                    width: trackView.width
                                    text: model.label !== undefined ? model.label : (model.display || "")
                                    icon: root.page && root.page.folders ? "folder" : (root.section === 4 ? "history" : "list")
                                    onClicked: root.openNode(childNodes.modelIndex(index))
                                }
                            }
                        }
                    }
                }

                // Shown above the tracks of the Auto DJ queue
                Rectangle {
                    width: trackView.width
                    height: root.page && root.page.queue ? 56 : 0
                    visible: height > 0
                    color: "transparent"

                    CLButton {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 170
                        height: 40
                        icon: "autodj"
                        text: qsTr("Auto DJ")
                        iconSize: 18
                        fontSize: 14
                        onClicked: root.autoDJRequested()
                    }
                }
            }

            delegate: TrackRow {
                required property int index

                width: trackView.width
                row: index
                trackModel: trackView.model
                selected: root.selectedRow === index
                onLoadRequested: group => root.load(index, group)
                onMenuRequested: {
                    root.selectedRow = index;
                    trackMenu.row = index;
                    trackMenu.track = track;
                    trackMenu.popup();
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 48
                horizontalAlignment: Text.AlignHCenter
                color: Style.textSecondary
                font.family: Style.font
                font.pixelSize: 15
                wrapMode: Text.WordWrap
                visible: root.page && root.page.showTracks && trackView.count === 0
                text: root.searching && searchField.text !== "" ? qsTr("No tracks match the search") : (root.page && root.page.queue ? qsTr("The queue is empty. Hold a track and add it to the queue.") : qsTr("No tracks here"))
            }
        }
    }

    StreamingComponent.StreamingHub {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: tabBar.top
        visible: root.source === 1
        targetDeck: root.targetGroup.startsWith("[Channel") ? root.targetGroup : "[Channel1]"
    }

    // Sections
    Rectangle {
        id: tabBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.source === 0 ? 60 : 0
        visible: height > 0
        color: Style.topBar

        Rectangle {
            id: tabIndicator

            anchors.top: parent.top
            height: 3
            width: parent.width / 5
            x: root.section * width
            color: Style.accent

            Behavior on x {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: [
                    {icon: "folder", label: qsTr("Carpetas")},
                    {icon: "note", label: qsTr("Géneros")},
                    {icon: "list", label: qsTr("Listas")},
                    {icon: "queue", label: qsTr("Cola")},
                    {icon: "history", label: qsTr("Recientes")}
                ]

                Item {
                    required property int index
                    required property var modelData

                    width: tabBar.width / 5
                    height: tabBar.height

                    Column {
                        anchors.centerIn: parent
                        spacing: 3

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 24
                            height: 24
                            source: root.section === index ? `icons/${modelData.icon}_lit.svg` : `icons/${modelData.icon}.svg`
                            sourceSize.width: 48
                            sourceSize.height: 48
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: root.section === index ? Style.accentText : Style.text
                            font.family: Style.font
                            font.pixelSize: 12
                            text: modelData.label
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.showSection(index)
                    }
                }
            }
        }
    }

    CLMenu {
        id: trackMenu

        property int row: -1
        property var track: null

        CLMenuItem {
            text: qsTr("Load into deck 1")
            onTriggered: root.load(trackMenu.row, "[Channel1]")
        }
        CLMenuItem {
            text: qsTr("Load into deck 2")
            onTriggered: root.load(trackMenu.row, "[Channel2]")
        }
        CLMenuItem {
            text: qsTr("Play next in the queue")
            onTriggered: Mixxx.Library.addToAutoDJ(trackMenu.track, true)
        }
        CLMenuItem {
            text: qsTr("Add to the end of the queue")
            onTriggered: Mixxx.Library.addToAutoDJ(trackMenu.track, false)
        }
        CLMenuItem {
            text: qsTr("Separate stems…")
            onTriggered: stemsPopup.openFor(root.urlAt(trackMenu.row))
        }
        CLMenuItem {
            text: qsTr("Analyze")
            onTriggered: Mixxx.Library.analyze(trackMenu.track)
        }
    }

    LibraryComponent.StemsPopup {
        id: stemsPopup

        trackList: root.tracklist
    }
}
