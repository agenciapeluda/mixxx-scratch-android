import "../Library" as LibraryComponent
import "../Library/Streaming" as StreamingComponent
import Mixxx 1.0 as Mixxx
import QtQml.Models
import QtQuick
import QtQuick.Controls

// The library, as in the designs "Horizontal · biblioteca con BROWSE y LOAD"
// and "Vertical · biblioteca".
// Sideways: both decks reduced on top; your folders, genres and more on the
// left; the search, "compatibles", the order, the suggestions for the
// playing deck and the tracks on the right; what the controller does below.
// Upright: one column with the sections as chips and LOAD A / B at the
// bottom.
// The browse knob moves in the column it is in (SHIFT + BROWSE changes the
// column), a press goes into the folder or back out, LOAD loads and closes.
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
    readonly property bool wide: width > height
    readonly property real u: wide ? Math.max(0.6, Math.min(width / 1284, height / 600)) : Math.max(0.8, Math.min(1.15, width / 390))
    // The track picked with the controller's browse knob or a tap
    property int selectedRow: -1
    // Where the browse knob is: 0 the sources on the left, 1 the tracks,
    // 2 the suggestions
    property int focusColumn: 1
    property int selectedSuggestion: 0
    readonly property bool focusSuggestions: focusColumn === 2
    // The deck the suggestions and "compatibles" are for: the one playing,
    // else deck A
    readonly property string playingGroup: play2.value > 0 && play1.value <= 0 ? "[Channel2]" : "[Channel1]"
    readonly property string otherGroup: playingGroup === "[Channel1]" ? "[Channel2]" : "[Channel1]"
    property var suggestions: []
    property var folderRows: []
    property var genreRows: []
    // MicroSD cards and USB drives plugged in
    property var volumes: []
    // The source picked on the left (its key) and under the knob there
    property string currentSource: "all"
    property int selectedSource: 0
    // How the tracks are sorted: a TrackModel::SortColumnId
    // (1 artist, 2 title, 13 duration, 15 BPM, 17 added, 20 key, 31 played)
    property int sortId: parseInt(Mixxx.Application.configValue("[Cutlab]", "library_sort", "17"))
    property bool sortAscending: Mixxx.Application.configValue("[Cutlab]", "library_sort_asc", "0") === "1"
    readonly property var sortNames: ({1: qsTr("Artista"), 2: qsTr("Título"), 13: qsTr("Duración"), 15: qsTr("BPM"), 17: qsTr("Agregados"), 20: qsTr("Tonalidad"), 31: qsTr("Tocados")})
    // Only the tracks near the tempo and in a key that mixes with the deck
    // that is playing
    property bool compatible: false
    property int missing: 0
    readonly property string versusKey: {
        // Again when a key changes
        keyA.value;
        keyB.value;
        return Mixxx.Cutlab.deckKey(root.playingGroup);
    }
    // Playlists and crates holding the picked track
    readonly property var pickedLists: root.selectedRow >= 0 ? Mixxx.Cutlab.listsContaining(root.urlAt(root.selectedRow)) : []

    // The entries on the left, in the order the knob goes through them
    readonly property var sourceRows: {
        const rows = [{kind: "all", key: "all", name: qsTr("Todas las canciones")}];
        for (const folder of root.folderRows) {
            rows.push({kind: "folder", key: "folder:" + folder.path, name: folder.name, count: folder.count, path: folder.path});
        }
        for (const genre of root.genreRows) {
            rows.push({kind: "genre", key: "genre:" + genre.name, name: genre.name === "" ? qsTr("Sin género") : genre.name, genre: genre.name, count: genre.count});
        }
        rows.push({kind: "lists", key: "lists", name: qsTr("Listas y cajas")});
        rows.push({kind: "queue", key: "queue", name: qsTr("Cola")});
        rows.push({kind: "history", key: "history", name: qsTr("Recientes")});
        for (const volume of root.volumes) {
            rows.push({kind: "volume", key: "volume:" + volume.path, name: volume.name, path: volume.path});
        }
        return rows;
    }

    signal closeRequested
    signal settingsRequested
    signal autoDJRequested
    signal foldersRequested

    color: Style.background

    onVisibleChanged: {
        if (!visible) {
            searchField.focus = false;
            Qt.inputMethod.hide();
        }
    }

    function fs(px) {
        return Math.max(9, Math.round(px * root.u));
    }
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

    function open(group) {
        root.targetGroup = group || "";
        root.visible = true;
        root.refreshSuggestions();
        root.missing = Mixxx.Cutlab.missingAnalysis();
        root.folderRows = Mixxx.Cutlab.musicFolders();
        root.genreRows = Mixxx.Cutlab.genres();
        root.volumes = Mixxx.Cutlab.storageVolumes();
        queueCount.count = Mixxx.Cutlab.queueCount();
        root.focusColumn = 1;
        if (root.pages.length === 0) {
            root.pickSource(root.sourceRows[0]);
        } else {
            // Bring back the tracks of the page on top
            root.activatePage(root.page);
        }
    }
    function close() {
        searchField.text = "";
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
    // The tracks of a page: its node, then its search. The search goes
    // again once the new track list is in place, so a genre or a folder
    // always filters (it could stay on the whole library)
    function activatePage(page) {
        if (!page) {
            return;
        }
        if (page.node && page.node.valid) {
            root.sidebar.activate(page.node);
        }
        if (page.showTracks) {
            root.refreshQuery();
            Qt.callLater(root.refreshQuery);
            searchSettle.restart();
        }
    }
    Timer {
        id: searchSettle

        interval: 250
        onTriggered: root.refreshQuery()
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
    // A source on the left: all, a folder, a genre, the lists, the queue
    // or the history
    function pickSource(row) {
        if (!row) {
            return;
        }
        root.currentSource = row.key;
        root.selectedSource = Math.max(0, root.sourceRows.findIndex(r => r.key === row.key));
        root.pages = [];
        switch (row.kind) {
        case "all":
            root.section = 0;
            root.push({title: row.name, parents: [], node: root.featureIndex("tracks"), showTracks: true, filter: ""});
            break;
        case "folder":
            root.section = 0;
            root.push({title: row.name, parents: [], node: root.featureIndex("tracks"), showTracks: true, filter: "location:\"" + row.path + "/\""});
            break;
        case "volume":
            // Into the library the first time, then like a folder
            Mixxx.Cutlab.addFolder(row.path);
            root.section = 0;
            root.push({title: row.name, parents: [], node: root.featureIndex("tracks"), showTracks: true, filter: "location:\"" + row.path + "/\""});
            break;
        case "genre":
            root.section = 1;
            root.push({title: row.name, parents: [], node: root.featureIndex("tracks"), showTracks: true, filter: "genre:\"" + (row.genre !== undefined ? row.genre : row.name) + "\""});
            break;
        case "lists": {
            root.section = 2;
            const parents = ["playlist", "crates", "rekordbox", "enginedj", "recordings"]
                .map(name => root.featureIndex(name))
                .filter(index => index !== null);
            root.push({title: row.name, parents: parents, node: null, showTracks: false});
            break;
        }
        case "queue":
            root.section = 3;
            root.push({title: row.name, parents: [], node: root.featureIndex("autodj"), showTracks: true, queue: true});
            break;
        case "history": {
            root.section = 4;
            const history = root.featureIndex("history");
            root.push({title: row.name, parents: history ? [history] : [], node: null, showTracks: false});
            break;
        }
        }
    }
    // The chips of the upright layout
    function showSection(section) {
        const kinds = ["all", "genre", "lists", "queue", "history"];
        if (section >= kinds.length) {
            const volume = root.volumes[section - kinds.length];
            root.pickSource(root.sourceRows.find(row => volume && row.key === "volume:" + volume.path));
            root.section = section;
            return;
        }
        if (section === 1) {
            root.pages = [];
            root.section = 1;
            root.currentSource = "genres";
            root.push({title: qsTr("Géneros"), parents: [], node: null, showTracks: false, genres: true});
            return;
        }
        root.pickSource(root.sourceRows.find(row => row.kind === kinds[section]));
    }
    // A playlist, crate or history session was tapped
    function openNode(index) {
        root.push({
            title: root.labelOf(index),
            parents: [],
            node: index,
            showTracks: true
        });
        root.focusColumn = 1;
    }

    function urlAt(row) {
        return root.tracklist ? root.tracklist.getUrl(row) : "";
    }
    function urlOf(group) {
        const player = Mixxx.PlayerManager.getPlayer(group);
        return player && player.currentTrack ? player.currentTrack.trackLocationUrl.toString() : "";
    }
    // The deck a track goes to without saying: the one asked for, else the
    // one that isn't playing
    function defaultGroup() {
        return root.targetGroup !== "" ? root.targetGroup : root.otherGroup;
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

    // The search of the page, "compatibles" and the typed text together,
    // then the sorting
    function queryText() {
        const parts = [];
        if (root.page && root.page.filter) {
            parts.push(root.page.filter);
        }
        if (root.compatible) {
            const bpm = root.playingGroup === "[Channel2]" ? bpm2.value : bpm1.value;
            if (bpm > 0) {
                parts.push("~bpm:" + bpm.toFixed(1));
            }
            const key = Mixxx.Cutlab.deckKey(root.playingGroup);
            if (key !== "") {
                parts.push("~key:" + key);
            }
        }
        if (searchField.text.trim() !== "") {
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
            root.pickSource(root.sourceRows[0]);
            return;
        }
        root.refreshQuery();
    }
    // A press of the browse knob: into the source on the left, back out of
    // the tracks
    function browsePress() {
        if (root.menuOpen) {
            Mixxx.Cutlab.sendKey(Qt.Key_Return);
            return;
        }
        if (root.focusColumn === 0) {
            root.pickSource(root.sourceRows[root.selectedSource]);
            root.focusColumn = 1;
        } else if (root.focusColumn === 1 && root.page && !root.page.showTracks) {
            // A list of playlists or sessions: into the first one
            return;
        } else {
            root.focusColumn = 0;
        }
    }
    // SHIFT + BROWSE: sources, tracks, suggestions
    function nextColumn() {
        root.focusColumn = (root.focusColumn + 1) % (root.suggestions.length > 0 ? 3 : 2);
        if (!root.wide && root.focusColumn === 0) {
            root.focusColumn = 1;
        }
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
        id: keyA

        group: "[Channel1]"
        key: "key"
    }
    Mixxx.ControlProxy {
        id: keyB

        group: "[Channel2]"
        key: "key"
    }

    // ---- The queue, playlists and crates ----
    // Playlists and crates for "Agregar a…"
    property var allLists: []
    // The menus were opened from the controller: the knob moves in them and
    // new lists get a name by themselves (no keyboard)
    property bool knobMenu: false
    readonly property bool menuOpen: trackMenu.opened || addMenu.opened || sortMenu.opened || moreMenu.opened

    function toast(text) {
        toastText.text = text;
        toastBox.visible = true;
        toastTimer.restart();
    }
    // The track the menu or the controller is about: a suggestion or a row
    function pickedUrl() {
        if (root.focusColumn === 2 && root.suggestions.length > 0) {
            return root.suggestions[root.selectedSuggestion].url;
        }
        return root.selectedRow >= 0 ? root.urlAt(root.selectedRow) : "";
    }
    function refreshQueue() {
        queueCount.count = Mixxx.Cutlab.queueCount();
        if (root.page && root.page.queue) {
            root.refreshQuery();
        }
    }
    function addToQueue(url, top) {
        if (!url || url.toString() === "") {
            root.toast(qsTr("Elegí un tema primero: girá BROWSE o tocalo."));
            return;
        }
        if (Mixxx.Cutlab.addToQueue(url, top)) {
            root.refreshQueue();
            root.toast(top ? qsTr("Va primero en la cola") : qsTr("Agregado a la cola · %1 temas").arg(queueCount.count));
        } else {
            root.toast(qsTr("Ese tema no está en tu biblioteca: no puede ir a la cola."));
        }
    }
    function fillQueue() {
        const group = root.playingGroup;
        const before = Mixxx.Cutlab.queueCount();
        const loadedTrack = Mixxx.PlayerManager.getPlayer(group) ? Mixxx.PlayerManager.getPlayer(group).currentTrack : null;
        if (before === 0 && !loadedTrack) {
            root.toast(qsTr("Cargá un tema en un deck: la cola se arma a partir de él."));
            return;
        }
        const added = Mixxx.Cutlab.fillQueue(group, 10);
        root.refreshQueue();
        if (added > 0) {
            root.toast(qsTr("Sumé %1 temas que pegan (BPM, tono, sin repetir artista)").arg(added));
        } else {
            root.toast(qsTr("No encontré más temas que peguen: falta analizar BPM y tono, o ya están todos en la cola."));
        }
    }
    function openTrackMenu(row, fromKnob) {
        if (row < 0) {
            root.toast(qsTr("Elegí un tema primero: girá BROWSE o tocalo."));
            return;
        }
        root.knobMenu = fromKnob;
        if (fromKnob) {
            trackMenu.track = null;
        }
        trackMenu.row = row;
        trackMenu.url = root.urlAt(row);
        if (fromKnob) {
            trackMenu.popup(root, (root.width - trackMenu.width) / 2, Math.round(root.height * 0.18));
        } else {
            trackMenu.popup();
        }
    }
    function openAddMenu() {
        root.allLists = Mixxx.Cutlab.lists();
        addMenu.url = trackMenu.url;
        addMenu.popup(root, (root.width - addMenu.width) / 2, Math.round(root.height * 0.12));
    }
    function addToList(list, url) {
        if (Mixxx.Cutlab.addToList(list.kind, list.id, url)) {
            root.toast(qsTr("Agregado a «%1»").arg(list.name));
        } else {
            root.toast(qsTr("No se pudo agregar a «%1»").arg(list.name));
        }
    }
    // A new playlist or crate; with a track, it goes in. From the controller
    // it is named by the date, on the screen it asks for a name
    function newList(kind, url) {
        if (root.knobMenu) {
            const name = (kind === "crate" ? qsTr("Caja %1") : qsTr("Lista %1")).arg(Qt.formatDateTime(new Date(), "dd/MM HH:mm"));
            root.createList(kind, name, url);
            return;
        }
        nameDialog.kind = kind;
        nameDialog.url = url || "";
        nameField.text = "";
        nameDialog.open();
    }
    function createList(kind, name, url) {
        const id = Mixxx.Cutlab.createList(kind, name);
        if (id < 0) {
            root.toast(qsTr("No se pudo crear"));
            return;
        }
        const lists = Mixxx.Cutlab.lists();
        const made = lists.find(l => l.kind === kind && l.id === id);
        const shown = made ? made.name : name;
        if (url && url.toString() !== "") {
            Mixxx.Cutlab.addToList(kind, id, url);
            root.toast(qsTr("Creé «%1» con el tema").arg(shown));
        } else {
            root.toast(kind === "crate" ? qsTr("Creé la caja «%1»").arg(shown) : qsTr("Creé la lista «%1»").arg(shown));
        }
    }

    // The quick keys of the controllers: the picked track to the queue, and
    // its menu (queue, playlists, crates)
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: "queue_add"
        onValueChanged: {
            if (value > 0 && root.visible && !root.menuOpen) {
                root.addToQueue(root.pickedUrl(), false);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: "track_menu"
        onValueChanged: {
            if (value <= 0 || !root.visible || root.menuOpen) {
                return;
            }
            if (root.focusColumn === 2 && root.suggestions.length > 0) {
                root.toast(qsTr("Las sugerencias van a la cola con SHIFT + BROWSE"));
                return;
            }
            root.openTrackMenu(root.selectedRow, true);
        }
    }

    // A scan is over: new folders, genres and tracks
    Connections {
        target: Mixxx.Cutlab

        function onLibraryScanned() {
            root.missing = Mixxx.Cutlab.missingAnalysis();
            root.folderRows = Mixxx.Cutlab.musicFolders();
            root.genreRows = Mixxx.Cutlab.genres();
            if (root.visible && root.page && root.page.showTracks) {
                root.refreshQuery();
            }
        }
    }

    LibraryComponent.SourceTree {
        id: sourceTree
    }

    // The controller's browse knob
    LibraryComponent.Control {
        enabled: root.visible && root.source === 0

        onMoveVertical: offset => {
            if (root.menuOpen) {
                for (let i = 0; i < Math.min(8, Math.abs(offset)); ++i) {
                    Mixxx.Cutlab.sendKey(offset > 0 ? Qt.Key_Down : Qt.Key_Up);
                }
                return;
            }
            if (root.focusColumn === 2 && root.suggestions.length > 0) {
                root.selectedSuggestion = Math.max(0, Math.min(root.suggestions.length - 1, root.selectedSuggestion + offset));
                suggestionView.positionViewAtIndex(root.selectedSuggestion, ListView.Contain);
                return;
            }
            if (root.focusColumn === 0) {
                root.selectedSource = Math.max(0, Math.min(root.sourceRows.length - 1, root.selectedSource + offset));
                sourceList.positionViewAtIndex(root.selectedSource, ListView.Contain);
                return;
            }
            if (!root.page || !root.page.showTracks) {
                return;
            }
            root.selectedRow = Math.max(0, Math.min(trackView.count - 1, root.selectedRow + offset));
            trackView.positionViewAtIndex(root.selectedRow, ListView.Contain);
        }
        onLoadSelectedTrack: (group, play) => {
            if (root.menuOpen) {
                Mixxx.Cutlab.sendKey(Qt.Key_Return);
                return;
            }
            if (root.focusColumn === 0) {
                root.browsePress();
            } else if (root.focusColumn === 2 && root.suggestions.length > 0) {
                root.loadUrl(root.suggestions[root.selectedSuggestion].url, group);
            } else if (root.selectedRow >= 0) {
                root.load(root.selectedRow, group);
            }
        }
        onLoadSelectedTrackIntoNextAvailableDeck: play => {
            if (root.menuOpen) {
                Mixxx.Cutlab.sendKey(Qt.Key_Return);
                return;
            }
            if (root.focusColumn === 2 && root.suggestions.length > 0) {
                root.loadUrl(root.suggestions[root.selectedSuggestion].url, "");
            } else if (root.selectedRow >= 0) {
                root.load(root.selectedRow, "");
            }
        }
    }
    // SHIFT + browse on the controllers changes the column
    Mixxx.ControlProxy {
        group: "[Cutlab]"
        key: "browse_suggestions"
        onValueChanged: {
            if (value > 0 && root.visible) {
                root.nextColumn();
            }
        }
    }

    // ===== Top: the decks, reduced (sideways) or the title (upright) =====
    Rectangle {
        id: topBar

        width: parent.width
        height: root.wide ? Math.round(40 * root.u) + 8 : Math.round(68 * root.u)
        color: root.wide ? Style.panel : Style.background

        // Sideways: both decks
        Row {
            visible: root.wide
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(14 * root.u)
            width: parent.width - 2 * x - closeButton.width - 8
            spacing: Math.round(12 * root.u)

            Repeater {
                model: ["[Channel1]", "[Channel2]"]

                Item {
                    id: miniDeck

                    required property string modelData
                    readonly property var player: Mixxx.PlayerManager.getPlayer(modelData)
                    readonly property var track: player ? player.currentTrack : null
                    readonly property bool playing: modelData === "[Channel1]" ? play1.value > 0 : play2.value > 0

                    width: (parent.width - parent.spacing) / 2
                    height: Math.round(28 * root.u)

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(10 * root.u)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: miniLetter.implicitWidth + 12
                            height: miniLetter.implicitHeight + 2
                            radius: 4
                            color: Style.deckColor(miniDeck.modelData)

                            Text {
                                id: miniLetter

                                anchors.centerIn: parent
                                color: Style.background
                                font.family: Style.mono
                                font.weight: Font.Bold
                                font.pixelSize: root.fs(11)
                                text: Style.deckLetter(miniDeck.modelData)
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, miniDeck.width * 0.45)
                            elide: Text.ElideRight
                            color: Style.text
                            font.family: Style.font
                            font.weight: Font.DemiBold
                            font.pixelSize: root.fs(14)
                            text: miniDeck.track && miniDeck.track.title ? miniDeck.track.title : qsTr("Sin tema")
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Style.text
                            font.family: Style.mono
                            font.weight: Font.Bold
                            font.pixelSize: root.fs(14)
                            text: (miniDeck.modelData === "[Channel1]" ? bpm1.value : bpm2.value) > 0 ? (miniDeck.modelData === "[Channel1]" ? bpm1.value : bpm2.value).toFixed(1) : ""
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: miniDeck.playing ? Style.ok : Style.textSecondary
                        font.family: Style.font
                        font.weight: Font.Bold
                        font.pixelSize: root.fs(10)
                        text: miniDeck.playing ? qsTr("● SONANDO") : (root.defaultGroup() === miniDeck.modelData ? qsTr("PARADO · LISTO PARA CARGAR") : qsTr("PARADO"))
                    }
                }
            }
        }

        // Upright: back, where you are, search
        CLButton {
            id: backButton

            visible: !root.wide
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 10
            icon: "back"
            iconSize: 18
            fillColor: "transparent"
            onClicked: root.pages.length > 1 ? root.back() : root.close()
        }
        Column {
            visible: !root.wide
            anchors.left: backButton.right
            anchors.leftMargin: 8
            anchors.right: closeButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Text {
                color: Style.textSecondary
                font.family: Style.font
                font.weight: Font.DemiBold
                font.pixelSize: 11
                text: root.section === 0 ? qsTr("Tus carpetas") : root.section === 1 ? qsTr("Géneros") : root.section === 2 ? qsTr("Listas") : root.section === 3 ? qsTr("Cola") : root.section === 4 ? qsTr("Recientes") : qsTr("MicroSD o pendrive")
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                color: Style.text
                font.family: Style.font
                font.weight: Font.Bold
                font.pixelSize: 17
                text: root.page ? root.page.title : ""
            }
        }
        CLButton {
            id: closeButton

            anchors.right: parent.right
            anchors.rightMargin: root.wide ? 8 : 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(52, Math.round(52 * root.u))
            height: width
            radius: 12
            icon: root.wide ? "close" : "more"
            iconSize: width * 0.46
            bordered: !root.wide
            fillColor: "transparent"
            onClicked: root.wide ? root.close() : moreMenu.popup(closeButton, 0, closeButton.height)
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
            visible: root.wide
        }
    }

    // ===== Left: the sources (sideways) =====
    Rectangle {
        id: sourcesPane

        anchors.top: topBar.bottom
        anchors.bottom: hints.top
        width: root.wide ? Math.round(260 * root.u) : 0
        visible: root.wide && root.source === 0
        color: Style.panelDark

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        ListView {
            id: sourceList

            anchors.fill: parent
            anchors.margins: Math.round(10 * root.u)
            anchors.rightMargin: Math.round(10 * root.u) + 1
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.sourceRows
            spacing: 2

            delegate: Item {
                id: sourceItem

                required property var modelData
                required property int index
                // A title above the first folder, genre and "more" entry
                readonly property string title: index === 0 ? qsTr("TUS CARPETAS")
                    : modelData.kind === "genre" && root.sourceRows[index - 1].kind !== "genre" ? qsTr("POR GÉNERO")
                    : modelData.kind === "lists" ? qsTr("MÁS") : ""

                width: sourceList.width
                height: (title !== "" ? sourceTitle.height : 0) + sourceRow.height

                Text {
                    id: sourceTitle

                    visible: sourceItem.title !== ""
                    leftPadding: Math.round(10 * root.u)
                    topPadding: sourceItem.index === 0 ? Math.round(4 * root.u) : Math.round(14 * root.u)
                    bottomPadding: Math.round(4 * root.u)
                    color: Style.textSecondary
                    font.family: Style.font
                    font.weight: Font.DemiBold
                    font.pixelSize: root.fs(11)
                    font.letterSpacing: 0.7
                    text: sourceItem.title
                }

            Rectangle {
                id: sourceRow

                readonly property var modelData: sourceItem.modelData
                readonly property int index: sourceItem.index
                readonly property bool current: root.currentSource === modelData.key
                readonly property bool knob: root.focusColumn === 0 && root.selectedSource === index

                anchors.bottom: parent.bottom
                width: sourceList.width
                height: Math.round(38 * root.u)
                radius: Math.round(8 * root.u)
                color: current ? Style.accent : (sourceMouse.pressed ? Style.raised : "transparent")
                border.width: knob ? 2 : 0
                border.color: current ? "#ffffff" : Style.accent

                Row {
                    x: Math.round(10 * root.u)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * x
                    spacing: Math.round(8 * root.u)

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(16 * root.u)
                        height: width
                        visible: sourceRow.modelData.kind === "folder" || sourceRow.modelData.kind === "all" || sourceRow.modelData.kind === "volume"
                        source: sourceRow.modelData.kind === "all" ? "icons/note.svg" : "icons/folder.svg"
                        sourceSize.width: 32
                        sourceSize.height: 32
                        opacity: sourceRow.current ? 1 : 0.6
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - countText.width - Math.round(24 * root.u)
                        elide: Text.ElideRight
                        color: sourceRow.current ? "#ffffff" : Style.text
                        font.family: Style.font
                        font.weight: sourceRow.current ? Font.DemiBold : Font.Medium
                        font.pixelSize: root.fs(14)
                        text: sourceRow.modelData.kind === "queue" && queueCount.count > 0 ? qsTr("Cola · %1").arg(queueCount.count) : sourceRow.modelData.name
                    }
                }
                Text {
                    id: countText

                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(10 * root.u)
                    anchors.verticalCenter: parent.verticalCenter
                    color: sourceRow.current ? "#ffffff" : Style.textSecondary
                    opacity: sourceRow.current ? 0.8 : 1
                    font.family: Style.mono
                    font.weight: Font.Medium
                    font.pixelSize: root.fs(12)
                    text: sourceRow.modelData.count !== undefined ? String(sourceRow.modelData.count) : ""
                }
                MouseArea {
                    id: sourceMouse

                    anchors.fill: parent
                    onClicked: {
                        root.pickSource(sourceRow.modelData);
                        root.focusColumn = 1;
                    }
                }
            }
            }

            footer: Column {
                width: sourceList.width
                topPadding: Math.round(12 * root.u)
                spacing: Math.round(6 * root.u)

                CLButton {
                    width: parent.width
                    height: Math.round(38 * root.u)
                    radius: Math.round(8 * root.u)
                    icon: "folder"
                    iconSize: Math.round(16 * root.u)
                    fontSize: root.fs(13)
                    text: qsTr("Elegir mis carpetas…")
                    fillColor: "transparent"
                    onClicked: root.foldersRequested()
                }
                CLButton {
                    width: parent.width
                    height: Math.round(38 * root.u)
                    radius: Math.round(8 * root.u)
                    fontSize: root.fs(13)
                    text: qsTr("Más opciones…")
                    fillColor: "transparent"
                    onClicked: moreMenu.popup()
                }
            }
        }
    }

    // ===== Right: search, compatibles, order, suggestions, tracks =====
    Item {
        id: mainPane

        anchors.top: topBar.bottom
        anchors.bottom: root.wide ? hints.top : loadBar.top
        anchors.left: sourcesPane.right
        anchors.right: parent.right
        visible: root.source === 0

        // Upright: the sections as chips
        Flickable {
            id: chipRow

            width: parent.width
            height: root.wide ? 0 : 44
            visible: !root.wide
            contentWidth: chipsRow.width + 24
            flickableDirection: Flickable.HorizontalFlick
            clip: true

            Row {
                id: chipsRow

                x: 12
                spacing: 6

                Repeater {
                    model: [qsTr("Carpetas"), qsTr("Géneros"), qsTr("Listas"), qsTr("Cola"), qsTr("Recientes")].concat(root.volumes.map(volume => volume.name))

                    Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool on: root.section === index

                        width: chipLabel.implicitWidth + 24
                        height: 34
                        radius: 17
                        color: on ? Style.accent : "transparent"
                        border.width: 1
                        border.color: on ? Style.accent : Qt.rgba(1, 1, 1, 0.14)

                        Text {
                            id: chipLabel

                            anchors.centerIn: parent
                            color: parent.on ? "#ffffff" : Style.text
                            font.family: Style.font
                            font.weight: Font.DemiBold
                            font.pixelSize: 13
                            text: parent.modelData
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.showSection(parent.index)
                        }
                    }
                }
            }
        }

        // Search, compatibles and the order
        Item {
            id: searchRow

            anchors.top: chipRow.bottom
            width: parent.width
            height: root.wide ? Math.round(60 * root.u) : 44

            Rectangle {
                id: searchBox

                visible: root.wide || root.searchOpen
                x: Math.round(14 * root.u)
                anchors.verticalCenter: parent.verticalCenter
                width: root.wide ? parent.width - x - compatButton.width - orderButton.width - Math.round(30 * root.u) : parent.width - 24
                height: Math.round(40 * root.u)
                radius: Math.round(10 * root.u)
                color: Style.raised

                Image {
                    id: searchIcon

                    x: Math.round(12 * root.u)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(16 * root.u)
                    height: width
                    source: "icons/search.svg"
                    sourceSize.width: 32
                    sourceSize.height: 32
                    opacity: 0.6
                }
                TextField {
                    id: searchField

                    // Only with the library on screen and only by a tap:
                    // hidden, it must never take the focus (that opened
                    // the keyboard over the decks)
                    enabled: root.visible
                    focusPolicy: Qt.ClickFocus
                    onActiveFocusChanged: {
                        if (activeFocus && !root.visible) {
                            focus = false;
                            Qt.inputMethod.hide();
                        }
                    }

                    anchors.left: searchIcon.right
                    anchors.leftMargin: Math.round(8 * root.u)
                    anchors.right: clearSearch.visible ? clearSearch.left : parent.right
                    anchors.rightMargin: Math.round(8 * root.u)
                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.text
                    font.family: Style.font
                    font.pixelSize: root.fs(14)
                    placeholderText: qsTr("Buscar en %1").arg(root.page ? root.page.title : qsTr("tu música"))
                    placeholderTextColor: Style.textSecondary
                    inputMethodHints: Qt.ImhNoPredictiveText
                    background: Item {
                    }
                    onTextChanged: searchTimer.restart()

                    Timer {
                        id: searchTimer

                        interval: 300
                        onTriggered: root.applySearch()
                    }
                }
                // Clears what was typed
                CLButton {
                    id: clearSearch

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height
                    height: parent.height
                    visible: searchField.text !== ""
                    icon: "close"
                    iconSize: Math.round(14 * root.u)
                    bordered: false
                    fillColor: "transparent"
                    onClicked: {
                        searchField.text = "";
                        root.applySearch();
                    }
                }
            }
            CLButton {
                id: compatButton

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: root.wide ? orderButton.left : undefined
                anchors.rightMargin: Math.round(8 * root.u)
                visible: root.wide || !root.searchOpen
                x: 12
                width: compatText.implicitWidth + Math.round(28 * root.u)
                height: Math.round((root.wide ? 40 : 32) * root.u)
                radius: height / 2
                fillColor: root.compatible ? Style.accent : "transparent"
                bordered: true

                Text {
                    id: compatText

                    anchors.centerIn: parent
                    color: root.compatible ? "#ffffff" : (root.wide ? Style.text : Style.accentText)
                    font.family: Style.font
                    font.weight: Font.DemiBold
                    font.pixelSize: root.fs(root.wide ? 13 : 12)
                    text: {
                        const bpm = root.playingGroup === "[Channel2]" ? bpm2.value : bpm1.value;
                        const key = Mixxx.Cutlab.deckKey(root.playingGroup);
                        const base = qsTr("Compatibles con %1").arg(Style.deckLetter(root.playingGroup));
                        return root.wide || bpm <= 0 ? base : base + " · " + Math.round(bpm) + " BPM" + (key !== "" ? " · " + key : "");
                    }
                }
                onClicked: {
                    root.compatible = !root.compatible;
                    root.applySearch();
                }
            }
            CLButton {
                id: orderButton

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: root.wide ? parent.right : searchToggle.left
                anchors.rightMargin: root.wide ? Math.round(14 * root.u) : 4
                visible: root.wide || !root.searchOpen
                width: orderText.implicitWidth + Math.round(28 * root.u)
                height: compatButton.height
                radius: height / 2
                fillColor: "transparent"
                bordered: root.wide

                Text {
                    id: orderText

                    anchors.centerIn: parent
                    color: root.wide ? Style.text : Style.textSecondary
                    font.family: Style.font
                    font.weight: root.wide ? Font.DemiBold : Font.Medium
                    font.pixelSize: root.fs(root.wide ? 13 : 12)
                    text: qsTr("Orden: %1").arg(root.sortNames[root.sortId]) + (root.sortAscending ? " ↑" : " ↓")
                }
                onClicked: sortMenu.popup(orderButton, 0, orderButton.height + 4)
            }
            CLButton {
                id: searchToggle

                visible: !root.wide
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: 10
                icon: root.searchOpen ? "close" : "search"
                iconSize: 16
                fillColor: "transparent"
                onClicked: {
                    root.searchOpen = !root.searchOpen;
                    if (root.searchOpen) {
                        searchField.forceActiveFocus();
                    } else if (searchField.text !== "") {
                        searchField.text = "";
                    }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
                visible: root.wide
            }
        }

        // The tracks that suit the one playing, Tidal style
        Item {
            id: suggestionStrip

            anchors.top: searchRow.bottom
            width: parent.width
            height: root.suggestions.length > 0 && root.page && root.page.showTracks && (root.wide || root.focusSuggestions)
                ? suggestionHeader.height + Math.round(52 * root.u) + Math.round(26 * root.u) : 0
            visible: height > 0
            clip: true

            Row {
                id: suggestionHeader

                x: Math.round(14 * root.u)
                y: Math.round(10 * root.u)
                spacing: Math.round(8 * root.u)
                height: Math.round(18 * root.u)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: sugLetter.implicitWidth + 12
                    height: sugLetter.implicitHeight + 2
                    radius: 4
                    color: Style.deckColor(root.playingGroup)

                    Text {
                        id: sugLetter

                        anchors.centerIn: parent
                        color: Style.background
                        font.family: Style.mono
                        font.weight: Font.Bold
                        font.pixelSize: root.fs(11)
                        text: Style.deckLetter(root.playingGroup)
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.focusSuggestions ? Style.accentText : Style.text
                    font.family: Style.font
                    font.weight: Font.Bold
                    font.pixelSize: root.fs(13)
                    text: qsTr("Sugeridos para lo que suena en %1").arg(Style.deckLetter(root.playingGroup))
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.wide
                    color: Style.textSecondary
                    font.family: Style.font
                    font.weight: Font.Medium
                    font.pixelSize: root.fs(12)
                    text: qsTr("BPM ±6% · tonalidad · género · tu historial")
                }
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: Math.round(14 * root.u)
                anchors.verticalCenter: suggestionHeader.verticalCenter
                visible: root.wide
                color: Style.textSecondary
                font.family: Style.font
                font.weight: Font.Medium
                font.pixelSize: root.fs(12)
                textFormat: Text.StyledText
                text: qsTr("<b><font color=\"#f4f5fb\">SHIFT + BROWSE</font></b> para recorrerlos")
            }
            ListView {
                id: suggestionView

                anchors.top: suggestionHeader.bottom
                anchors.topMargin: Math.round(6 * root.u)
                x: Math.round(14 * root.u)
                width: parent.width - 2 * x
                height: Math.round(52 * root.u)
                orientation: ListView.Horizontal
                spacing: Math.round(8 * root.u)
                clip: true
                model: root.suggestions

                delegate: Rectangle {
                    id: suggestion

                    required property var modelData
                    required property int index
                    readonly property bool picked: root.focusSuggestions && root.selectedSuggestion === index

                    width: root.wide ? (suggestionView.width - 3 * suggestionView.spacing) / 4 : 220
                    height: suggestionView.height
                    radius: Math.round(10 * root.u)
                    color: picked ? Style.track : Style.panel
                    border.width: picked ? 2 : 1
                    border.color: picked ? Style.accent : Qt.rgba(0.55, 0.52, 1, 0.25)

                    Rectangle {
                        id: sugCover

                        x: Math.round(8 * root.u)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(36 * root.u)
                        height: width
                        radius: Math.round(6 * root.u)
                        color: "#2a2650"
                    }
                    Column {
                        anchors.left: sugCover.right
                        anchors.leftMargin: Math.round(8 * root.u)
                        anchors.right: sugBpm.left
                        anchors.rightMargin: Math.round(6 * root.u)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            color: Style.text
                            font.family: Style.font
                            font.weight: Font.DemiBold
                            font.pixelSize: root.fs(13)
                            text: suggestion.modelData.title
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            color: Style.textSecondary
                            font.family: Style.font
                            font.pixelSize: root.fs(11)
                            text: suggestion.modelData.why || suggestion.modelData.artist
                        }
                    }
                    Text {
                        id: sugBpm

                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(8 * root.u)
                        anchors.verticalCenter: parent.verticalCenter
                        color: Style.text
                        font.family: Style.mono
                        font.weight: Font.Bold
                        font.pixelSize: root.fs(12)
                        text: suggestion.modelData.bpm > 0 ? suggestion.modelData.bpm.toFixed(1) : ""
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.loadUrl(suggestion.modelData.url, root.defaultGroup())
                    }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
            }
        }

        // The header of the table (sideways)
        Item {
            id: tableHeader

            anchors.top: suggestionStrip.bottom
            width: parent.width
            height: root.wide && root.page && root.page.showTracks ? Math.round(28 * root.u) : 0
            visible: height > 0

            Text {
                x: Math.round(14 * root.u) + Math.round(8 * root.u) + Math.round(44 * root.u) + Math.round(12 * root.u)
                anchors.verticalCenter: parent.verticalCenter
                color: Style.textSecondary
                font.family: Style.font
                font.weight: Font.DemiBold
                font.pixelSize: root.fs(11)
                font.letterSpacing: 0.5
                text: qsTr("TEMA")
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Math.round(16 * root.u)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(12 * root.u)

                Repeater {
                    model: [
                        {t: qsTr("BPM"), w: 64, right: true},
                        {t: qsTr("TON."), w: 46, right: false},
                        {t: qsTr("DUR."), w: 56, right: true},
                        {t: qsTr("VS. DECK %1").arg(Style.deckLetter(root.playingGroup)), w: 150, right: false}
                    ]

                    Text {
                        required property var modelData

                        width: Math.round(modelData.w * root.u)
                        horizontalAlignment: modelData.right ? Text.AlignRight : Text.AlignLeft
                        color: Style.textSecondary
                        font.family: Style.font
                        font.weight: Font.DemiBold
                        font.pixelSize: root.fs(11)
                        font.letterSpacing: 0.5
                        text: modelData.t
                    }
                }
            }
        }

        ListView {
            id: trackView

            anchors.top: tableHeader.bottom
            anchors.bottom: parent.bottom
            x: root.wide ? Math.round(8 * root.u) : 8
            width: parent.width - 2 * x
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2
            model: root.page && root.page.showTracks ? root.tracklist : null
            onModelChanged: root.selectedRow = -1
            ScrollBar.vertical: ScrollBar {
            }

            // Lists of playlists, crates, sessions or genres come first
            header: Column {
                width: trackView.width

                // Above the playlists and crates: make new ones
                Row {
                    x: 8
                    height: root.page && root.section === 2 && !root.page.showTracks ? 52 : 0
                    visible: height > 0
                    spacing: 8

                    CLButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        height: 40
                        icon: "plus"
                        text: qsTr("Nueva lista")
                        iconSize: 16
                        fontSize: 14
                        onClicked: {
                            root.knobMenu = false;
                            root.newList("playlist", "");
                        }
                    }
                    CLButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        height: 40
                        icon: "plus"
                        text: qsTr("Nueva caja")
                        iconSize: 16
                        fontSize: 14
                        onClicked: {
                            root.knobMenu = false;
                            root.newList("crate", "");
                        }
                    }
                }

                Repeater {
                    model: root.page && root.page.genres ? root.genreRows : []

                    NodeRow {
                        required property var modelData

                        width: trackView.width
                        text: (modelData.name === "" ? qsTr("Sin género") : modelData.name) + "  ·  " + modelData.count
                        icon: "list"
                        onClicked: root.pickSource({kind: "genre", key: "genre:" + modelData.name, name: modelData.name === "" ? qsTr("Sin género") : modelData.name, genre: modelData.name, count: modelData.count})
                    }
                }
                Repeater {
                    model: root.page ? root.page.parents : []

                    Column {
                        id: parentSection

                        required property var modelData
                        required property int index

                        width: trackView.width

                        Text {
                            leftPadding: 16
                            topPadding: 14
                            bottomPadding: 6
                            color: Style.textSecondary
                            font.family: Style.font
                            font.pixelSize: root.fs(11)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6
                            text: root.labelOf(parentSection.modelData).toUpperCase()
                            visible: root.page && root.page.parents.length > 1
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
                                    icon: root.section === 4 ? "history" : "list"
                                    onClicked: root.openNode(childNodes.modelIndex(index))
                                }
                            }
                        }
                    }
                }
                // Above the Auto DJ queue
                Row {
                    x: 8
                    height: root.page && root.page.queue ? 48 : 0
                    visible: height > 0
                    spacing: 8

                    CLButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        height: 40
                        icon: "autodj"
                        text: qsTr("Auto DJ")
                        iconSize: 18
                        fontSize: 14
                        onClicked: root.autoDJRequested()
                    }
                    CLButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 190
                        height: 40
                        icon: "queue"
                        text: qsTr("Llenar la cola")
                        iconSize: 18
                        fontSize: 14
                        highlighted: true
                        textColor: "#ffffff"
                        onClicked: root.fillQueue()
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Style.textSecondary
                        font.family: Style.font
                        font.pixelSize: 12
                        text: qsTr("con temas que pegan con %1").arg(Style.deckLetter(root.playingGroup))
                    }
                }
            }

            delegate: LibTrackRow {
                required property int index

                width: trackView.width
                row: index
                trackModel: trackView.model
                compact: !root.wide
                u: root.wide ? root.u : 1
                selected: root.selectedRow === index && root.focusColumn !== 2
                versusBpm: root.playingGroup === "[Channel2]" ? bpm2.value : bpm1.value
                versusKey: root.versusKey
                loadedUrlA: root.urlOf("[Channel1]")
                loadedUrlB: root.urlOf("[Channel2]")
                // A tap picks it, a second tap loads it on the free deck
                onClicked: {
                    if (root.selectedRow === index && root.wide) {
                        root.load(index, root.defaultGroup());
                    } else {
                        root.selectedRow = index;
                        root.focusColumn = 1;
                    }
                }
                onLoadRequested: group => root.load(index, group !== "" ? group : root.defaultGroup())
                onMenuRequested: {
                    root.selectedRow = index;
                    root.focusColumn = 1;
                    trackMenu.track = track;
                    root.openTrackMenu(index, false);
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
                text: searchField.text !== "" || root.compatible ? qsTr("Nada coincide. Probá sin «Compatibles» o con otra búsqueda.")
                    : (root.page && root.page.queue ? qsTr("La cola está vacía. Apretá «Llenar la cola», mantené un tema → Agregar a la cola, o con la controladora SHIFT + BROWSE.") : qsTr("No hay temas acá"))
            }
        }
    }

    property bool searchOpen: false

    StreamingComponent.StreamingHub {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: hints.top
        visible: root.source === 1
        targetDeck: root.targetGroup.startsWith("[Channel") ? root.targetGroup : "[Channel1]"
    }

    // ===== Bottom: the controller (sideways) or LOAD A / B (upright) =====
    HintsBar {
        id: hints

        anchors.bottom: parent.bottom
        width: parent.width
        height: root.wide ? Math.round(34 * root.u) : 0
        visible: root.wide
        u: root.u
        hints: [
            [qsTr("Girá BROWSE"), qsTr("para moverte")],
            [qsTr("Apretá BROWSE"), qsTr("entra o sale de la carpeta")],
            [qsTr("Mantené BROWSE"), qsTr("cola y listas del tema")],
            [qsTr("LOAD %1").arg(Style.deckLetter(root.defaultGroup())), qsTr("carga y cierra")]
        ]
    }
    Rectangle {
        id: loadBar

        anchors.bottom: parent.bottom
        width: parent.width
        height: root.wide ? 0 : 96
        visible: !root.wide
        color: Style.panel

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }
        Row {
            x: 12
            y: 10
            spacing: 8

            Repeater {
                model: ["[Channel1]", "[Channel2]"]

                Rectangle {
                    required property string modelData
                    readonly property bool main: modelData === root.defaultGroup()

                    width: (loadBar.width - 24 - 8) / 2
                    height: 52
                    radius: 12
                    color: main ? Style.deckColor(modelData) : "transparent"
                    border.width: main ? 0 : 1
                    border.color: Style.deckColor(modelData)
                    opacity: root.selectedRow >= 0 ? 1 : 0.45

                    Text {
                        anchors.centerIn: parent
                        color: parent.main ? Style.background : Style.text
                        font.family: Style.font
                        font.weight: Font.Bold
                        font.pixelSize: 14
                        text: qsTr("Cargar en %1").arg(Style.deckLetter(parent.modelData))
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.selectedRow >= 0
                        onClicked: root.load(root.selectedRow, parent.modelData)
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            color: Style.textSecondary
            font.family: Style.font
            font.weight: Font.Medium
            font.pixelSize: 11
            text: root.pickedLists.length > 0 ? qsTr("También en: %1").arg(root.pickedLists.join(" · ")) : qsTr("Con la controladora: girá BROWSE y apretá LOAD")
        }
    }

    // Queue size for "Cola · n"
    QtObject {
        id: queueCount

        property int count: 0
    }

    CLMenu {
        id: sortMenu

        Repeater {
            model: [17, 2, 1, 15, 20, 13, 31]

            CLMenuItem {
                required property int modelData

                text: root.sortNames[modelData] + (root.sortId === modelData ? (root.sortAscending ? "  ↑" : "  ↓") : "")
                onTriggered: root.setSort(modelData, root.sortId === modelData ? !root.sortAscending : [1, 2, 15, 20].includes(modelData))
            }
        }
    }
    CLMenu {
        id: moreMenu

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
            text: root.source === 0 ? qsTr("Streaming…") : qsTr("Música local")
            onTriggered: root.source = root.source === 0 ? 1 : 0
        }
        CLMenuItem {
            text: qsTr("Elegir mis carpetas de música…")
            onTriggered: root.foldersRequested()
        }
        CLMenuItem {
            text: qsTr("Volver a escanear la biblioteca")
            onTriggered: Mixxx.Library.rescanLibrary()
        }
        CLMenuItem {
            text: qsTr("Llenar la cola con temas que pegan")
            onTriggered: root.fillQueue()
        }
        CLMenuItem {
            text: qsTr("Auto DJ…")
            onTriggered: root.autoDJRequested()
        }
        CLMenuItem {
            text: qsTr("Ajustes de la biblioteca…")
            onTriggered: root.settingsRequested()
        }
    }
    CLMenu {
        id: trackMenu

        property int row: -1
        property var track: null
        property var url: ""

        onClosed: Qt.inputMethod.hide()

        CLMenuItem {
            text: qsTr("Agregar a la cola")
            onTriggered: root.addToQueue(trackMenu.url, false)
        }
        CLMenuItem {
            text: qsTr("Tocar después (primero en la cola)")
            onTriggered: root.addToQueue(trackMenu.url, true)
        }
        CLMenuItem {
            text: qsTr("Agregar a…")
            onTriggered: Qt.callLater(root.openAddMenu)
        }
        CLMenuItem {
            text: qsTr("Cargar en A")
            onTriggered: root.load(trackMenu.row, "[Channel1]")
        }
        CLMenuItem {
            text: qsTr("Cargar en B")
            onTriggered: root.load(trackMenu.row, "[Channel2]")
        }
        CLMenuItem {
            text: qsTr("Escuchar en el preview")
            onTriggered: Mixxx.PlayerManager.getPlayer("[PreviewDeck1]").loadTrackFromLocationUrl(trackMenu.url, true)
        }
        CLMenuItem {
            text: qsTr("Separar stems…")
            onTriggered: stemsPopup.openFor(trackMenu.url)
        }
        CLMenuItem {
            text: qsTr("Analizar BPM y tono")
            enabled: trackMenu.track !== null
            onTriggered: Mixxx.Library.analyze(trackMenu.track)
        }
    }
    // "Agregar a…": a new list or crate with the track, or one of yours
    CLMenu {
        id: addMenu

        property var url: ""

        implicitWidth: 300
        onClosed: Qt.inputMethod.hide()

        CLMenuItem {
            text: qsTr("+ Nueva lista con este tema")
            onTriggered: root.newList("playlist", addMenu.url)
        }
        CLMenuItem {
            text: qsTr("+ Nueva caja con este tema")
            onTriggered: root.newList("crate", addMenu.url)
        }
        Repeater {
            model: root.allLists

            CLMenuItem {
                required property var modelData

                text: (modelData.kind === "crate" ? qsTr("Caja · %1") : qsTr("Lista · %1")).arg(modelData.name)
                onTriggered: root.addToList(modelData, addMenu.url)
            }
        }
    }

    // The name of a new list or crate, typed on the screen
    Popup {
        id: nameDialog

        property string kind: "playlist"
        property var url: ""

        anchors.centerIn: parent
        width: Math.min(root.width - 40, 420)
        modal: true
        focus: true
        padding: 20
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: nameField.forceActiveFocus()
        onClosed: Qt.inputMethod.hide()
        background: Rectangle {
            color: Style.panel
            radius: 16
            border.width: 1
            border.color: Style.buttonBorder
        }

        contentItem: Column {
            spacing: 14

            Text {
                color: Style.text
                font.family: Style.font
                font.pixelSize: 18
                font.weight: Font.Bold
                text: nameDialog.kind === "crate" ? qsTr("Nueva caja") : qsTr("Nueva lista")
            }
            Rectangle {
                width: parent.width
                height: 44
                radius: 10
                color: Style.raised

                TextField {
                    id: nameField

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    color: Style.text
                    font.family: Style.font
                    font.pixelSize: 15
                    placeholderText: nameDialog.kind === "crate" ? qsTr("Nombre de la caja") : qsTr("Nombre de la lista")
                    placeholderTextColor: Style.textSecondary
                    background: Item {
                    }
                    onAccepted: createButton.clicked()
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 8

                CLButton {
                    width: 110
                    height: 44
                    text: qsTr("Cancelar")
                    fontSize: 14
                    fillColor: "transparent"
                    onClicked: nameDialog.close()
                }
                CLButton {
                    id: createButton

                    width: 110
                    height: 44
                    text: qsTr("Crear")
                    fontSize: 14
                    highlighted: true
                    textColor: "#ffffff"
                    onClicked: {
                        const name = nameField.text.trim() !== "" ? nameField.text.trim()
                            : (nameDialog.kind === "crate" ? qsTr("Caja %1") : qsTr("Lista %1")).arg(Qt.formatDateTime(new Date(), "dd/MM HH:mm"));
                        nameDialog.close();
                        root.createList(nameDialog.kind, name, nameDialog.url);
                    }
                }
            }
        }
    }

    // A short message over the list, then it goes
    Rectangle {
        id: toastBox

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (root.wide ? hints.height : loadBar.height) + 16
        width: Math.min(root.width - 32, toastText.implicitWidth + 32)
        height: toastText.implicitHeight + 20
        radius: height / 2
        color: Style.raised
        border.width: 1
        border.color: Style.accent
        visible: false
        z: 50

        Text {
            id: toastText

            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.width - 64)
            color: Style.text
            font.family: Style.font
            font.pixelSize: 14
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        Timer {
            id: toastTimer

            interval: 2800
            onTriggered: toastBox.visible = false
        }
    }

    LibraryComponent.StemsPopup {
        id: stemsPopup

        trackList: root.tracklist
    }
}
