import "../Library" as LibraryComponent
import "../Library/Streaming" as StreamingComponent
import Mixxx 1.0 as Mixxx
import QtQml.Models
import QtQuick
import QtQuick.Controls

// The library over the whole screen: the source at the top, sections at the
// bottom (playlists, all tracks, folders, Auto DJ queue, history) and a
// list you go into and back out of. Tapping a track loads it into the deck
// the library was opened for and closes it.
Rectangle {
    id: root

    // The deck or sampler that gets the track, empty for the next free deck
    property string targetGroup: ""
    // 0 local music, 1 streaming
    property int source: 0
    // 0 playlists, 1 tracks, 2 folders, 3 Auto DJ queue, 4 history
    property int section: 0
    property var pages: []
    readonly property var page: pages.length > 0 ? pages[pages.length - 1] : null
    readonly property var sidebar: sourceTree.sidebar()
    readonly property var tracklist: sidebar ? sidebar.tracklist : null
    property bool searching: false
    // The track picked with the controller's browse knob
    property int selectedRow: -1

    signal closeRequested
    signal settingsRequested
    signal autoDJRequested

    color: "#141415"

    function open(group) {
        root.targetGroup = group || "";
        root.visible = true;
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
        root.searching = false;
        searchField.text = "";
        let page;
        switch (section) {
        case 0: {
            const parents = ["playlist", "crates", "rekordbox", "enginedj", "recordings"]
                .map(name => root.featureIndex(name))
                .filter(index => index !== null);
            page = {title: qsTr("Playlists"), parents: parents, node: null, showTracks: false};
            break;
        }
        case 1: {
            const tracks = root.featureIndex("tracks");
            page = {title: qsTr("Tracks"), parents: [], node: tracks, showTracks: true};
            break;
        }
        case 2: {
            const folders = root.featureIndex("computer");
            page = {title: qsTr("Folders"), parents: folders ? [folders] : [], node: null, showTracks: false, folders: true};
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
    function applySearch() {
        if (!root.tracklist) {
            return;
        }
        if (!root.page || !root.page.showTracks) {
            // Search all tracks from the sections without tracks
            root.section = 1;
            const tracks = root.featureIndex("tracks");
            root.pages = [];
            root.push({title: qsTr("Tracks"), parents: [], node: tracks, showTracks: true});
        }
        root.tracklist.search(searchField.text);
    }

    LibraryComponent.SourceTree {
        id: sourceTree
    }

    // The controller's browse knob scrolls the tracks and loads them
    LibraryComponent.Control {
        enabled: root.visible && root.source === 0

        onMoveVertical: offset => {
            root.selectedRow = Math.max(0, Math.min(trackView.count - 1, root.selectedRow + offset));
            trackView.positionViewAtIndex(root.selectedRow, ListView.Contain);
        }
        onLoadSelectedTrack: (group, play) => {
            if (root.selectedRow >= 0) {
                root.load(root.selectedRow, group);
            }
        }
        onLoadSelectedTrackIntoNextAvailableDeck: play => {
            if (root.selectedRow >= 0) {
                root.load(root.selectedRow, "");
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
            fillColor: "#232325"
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
                color: "#232325"
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
        height: root.source === 0 ? 34 : 0
        visible: height > 0
        color: "#1c1c1e"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Style.textSecondary
            font.family: Style.font
            font.pixelSize: 13
            text: {
                const g = root.targetGroup;
                if (g === "[Channel1]")
                    return qsTr("Tap a track to load it into deck 1, or use 1 and 2");
                if (g === "[Channel2]")
                    return qsTr("Tap a track to load it into deck 2, or use 1 and 2");
                if (g.startsWith("[Sampler"))
                    return qsTr("Tap a track to load it into sample pad %1").arg(g.replace(/\D/g, ""));
                return qsTr("Tap a track to load it into a free deck, or use 1 and 2");
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

        ListView {
            id: trackView

            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.page && root.page.showTracks ? root.tracklist : null
            onModelChanged: root.selectedRow = -1
            ScrollBar.vertical: ScrollBar {
            }

            // The playlists, crates or folders of the page come first
            header: Column {
                width: trackView.width

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
                    {icon: "list", label: qsTr("Playlists")},
                    {icon: "note", label: qsTr("Tracks")},
                    {icon: "folder", label: qsTr("Folders")},
                    {icon: "queue", label: qsTr("Queue")},
                    {icon: "history", label: qsTr("History")}
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
