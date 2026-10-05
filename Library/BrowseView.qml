pragma ComponentBehavior: Bound

import "../Theme"
import Mixxx 1.0 as Mixxx
import QtQml.Models
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property bool applyingSearchFilter: false
    property bool resetSelectionOnFilter: false
    property bool restoreScrollAfterFilter: false
    property bool revealSelectionAfterFilter: false
    property real savedScrollOffset: 0
    property bool sourceActivationInProgress: false
    property int sourceLabelRevision: 0
    property int appearanceRevision: 0
    property var availableGenres: []
    readonly property int bpmColumnWidth: 64
    readonly property real columnWidthProgress: Math.max(0, Math.min(1, (width - 1024) / 896))
    readonly property int commentColumnWidth: 140 + Math.round(50 * root.columnWidthProgress)
    readonly property int durationColumnWidth: 60
    readonly property int genreColumnWidth: 96 + Math.round(24 * root.columnWidthProgress)
    readonly property int keyColumnWidth: 64
    readonly property int lastPlayedColumnWidth: 96 + Math.round(16 * root.columnWidthProgress)
    readonly property int libraryViewFocus: 3
    property int metadataRevision: 0
    readonly property var modelCapabilities: root.trackModel ? root.trackModel.capabilities : Mixxx.LibraryTrackListModel.Capability.None
    property var openSwipeRow: null
    readonly property string previewDeckGroup: "[PreviewDeck1]"
    readonly property int ratingColumnWidth: 64 + Math.round(8 * root.columnWidthProgress)
    property int selectedListIndex: -1
    property string selectedGenreFilter: ""
    readonly property string selectedSourceLabel: {
        root.sourceLabelRevision;
        const index = sourceSelection.currentIndex;
        return index.valid ? String(root.sourceModel.data(index, Qt.DisplayRole)) : qsTr("Tracks");
    }
    property url selectedUrl
    property int sortColumn: 1
    property int sortOrder: Qt.AscendingOrder
    readonly property var sourceModel: Mixxx.Library.sidebar
    readonly property var trackModel: Mixxx.Library.model

    readonly property bool canLoadToDeck: root.hasCapabilities(Mixxx.LibraryTrackListModel.Capability.LoadToDeck)
    readonly property bool canLoadToPreviewDeck: numPreviewDecksControl.value > 0 && root.hasCapabilities(Mixxx.LibraryTrackListModel.Capability.LoadToPreviewDeck)
    readonly property bool canSort: root.hasCapabilities(Mixxx.LibraryTrackListModel.Capability.Sorting)

    function cancelPendingPositionRestore() {
        root.restoreScrollAfterFilter = false;
        root.revealSelectionAfterFilter = false;
    }
    function preserveBrowsePosition() {
        if (!root.resetSelectionOnFilter && !root.restoreScrollAfterFilter &&
                !trackList.moving && !trackScrollBar.pressed) {
            root.savedScrollOffset = trackList.contentY - trackList.originY;
            root.restoreScrollAfterFilter = true;
        }
    }
    function scheduleSearchFilter(resetSelection = false) {
        if (root.sourceActivationInProgress && !resetSelection) {
            return;
        }
        if (resetSelection) {
            root.resetSelectionOnFilter = true;
            root.restoreScrollAfterFilter = false;
            root.revealSelectionAfterFilter = false;
        }
        searchFilterTimer.restart();
    }
    function finishFilterUpdate() {
        if (root.sourceActivationInProgress || searchFilterTimer.running || root.applyingSearchFilter) {
            return;
        }
        root.ensureSelection();
        trackList.forceLayout();
        if (root.revealSelectionAfterFilter) {
            if (root.selectedListIndex >= 0) {
                trackList.positionViewAtIndex(root.selectedListIndex, ListView.Contain);
            }
        } else if (root.restoreScrollAfterFilter && !trackList.moving && !trackScrollBar.pressed) {
            const maximumOffset = Math.max(0, trackList.contentHeight - trackList.height);
            trackList.contentY = trackList.originY + Math.max(0, Math.min(root.savedScrollOffset, maximumOffset));
        }
        root.restoreScrollAfterFilter = false;
        root.revealSelectionAfterFilter = false;
    }
    function applySearchFilter(resetSelection = false) {
        if (root.trackModel === null) {
            return;
        }
        if (root.openSwipeRow) {
            root.openSwipeRow.closeMenu();
        }
        if (resetSelection) {
            root.restoreScrollAfterFilter = false;
            root.selectedUrl = "";
            root.selectedListIndex = -1;
        }
        root.applyingSearchFilter = true;
        const genresByKey = {};
        const query = searchField.text.trim().toLocaleLowerCase();
        const genreFilter = root.selectedGenreFilter.toLocaleLowerCase();
        const filtersActive = query.length > 0 || genreFilter.length > 0;
        const matchingUrls = new Set();
        for (let row = 0; row < root.trackModel.rowCount(); ++row) {
            const genre = root.filterColumnText(row, 1).trim();
            const genreKey = genre.toLocaleLowerCase();
            if (genre.length > 0 && !Object.prototype.hasOwnProperty.call(genresByKey, genreKey)) {
                genresByKey[genreKey] = genre;
            }
            if (!filtersActive || (genreFilter.length > 0 && genreKey !== genreFilter)) {
                continue;
            }
            if (query.length > 0) {
                const numericKey = Number(root.trackModel.data(root.trackModel.index(row, 9), Qt.EditRole)) || 0;
                const key = Mixxx.KeyUtils.keyToString(numericKey, keyNotationControl.value);
                const searchableText = [root.filterColumnText(row, 0), root.filterColumnText(row, 8),
                        genre, root.filterColumnText(row, 2), key].join(" ").toLocaleLowerCase();
                if (!searchableText.includes(query)) {
                    continue;
                }
            }
            matchingUrls.add(root.trackModel.getUrl(row).toString());
        }
        for (let i = filteredTrackModel.items.count - 1; i >= 0; --i) {
            const entry = filteredTrackModel.items.get(i);
            const matches = !filtersActive || matchingUrls.has(entry.model.file_url.toString());
            if (entry.inSearchResults !== matches) {
                if (!resetSelection) {
                    root.preserveBrowsePosition();
                }
                entry.inSearchResults = matches;
            }
        }
        root.availableGenres = Object.keys(genresByKey).map(key => genresByKey[key]).sort((left, right) => left.localeCompare(right));
        root.applyingSearchFilter = false;
        if (resetSelection) {
            trackList.positionViewAtBeginning();
        }
        Qt.callLater(root.finishFilterUpdate);
    }
    function filterColumnText(row, column) {
        const value = root.trackModel.data(root.trackModel.index(row, column), Qt.EditRole);
        return value === undefined || value === null ? "" : String(value);
    }
    function columnValue(row, column, role) {
        if (!root.trackModel || row < 0) {
            return undefined;
        }
        const modelIndex = filteredTrackModel.modelIndex(row);
        if (!modelIndex.valid) {
            return undefined;
        }
        return root.trackModel.data(root.trackModel.index(modelIndex.row, column), role);
    }
    // Model methods do not notify bindings; revision and URL arguments refresh
    // values after metadata/layout changes and when a pooled row is reused.
    function columnText(row, column, _revision, _fileUrl) {
        const value = root.columnValue(row, column, Qt.DisplayRole);
        return value === undefined || value === null || value === "-" ? "" : String(value);
    }
    function rowForeground(row, _metadataRevision, _appearanceRevision, _fileUrl) {
        return root.columnValue(row, 0, Qt.ForegroundRole);
    }
    function formattedKey(track) {
        return Mixxx.KeyUtils.keyToString(track?.numericKey || 0, keyNotationControl.value);
    }
    function hasCapabilities(capabilities) {
        return (root.modelCapabilities & capabilities) === capabilities;
    }
    function loadUrlIntoDeck(url, group, play = false) {
        if (!root.canLoadToDeck || !url || url.toString().length === 0) {
            return false;
        }
        Mixxx.PlayerManager.getPlayer(group).loadTrackFromLocationUrl(url, play);
        return true;
    }
    function loadUrlIntoNextAvailableDeck(url, play = false) {
        if (!root.canLoadToDeck || !url || url.toString().length === 0) {
            return false;
        }
        Mixxx.PlayerManager.loadLocationUrlIntoNextAvailableDeck(url, play);
        return true;
    }
    function loadUrlIntoPreviewDeck(url) {
        if (!root.canLoadToPreviewDeck || !url || url.toString().length === 0) {
            return false;
        }
        const player = Mixxx.PlayerManager.getPlayer(root.previewDeckGroup);
        if (!player) {
            return false;
        }
        player.loadTrackFromLocationUrl(url, true);
        return true;
    }
    function loadSelectedIntoDeck(group, play = false) {
        return root.loadUrlIntoDeck(root.selectedUrl, group, play);
    }
    function moveSelection(direction) {
        root.cancelPendingPositionRestore();
        const count = searchResultsGroup.count;
        if (count === 0) {
            return;
        }
        let nextIndex = root.selectedListIndex;
        if (nextIndex < 0) {
            nextIndex = direction > 0 ? 0 : count - 1;
        } else {
            nextIndex = Mixxx.MathUtils.positiveModulo(nextIndex + direction, count);
        }
        const entry = searchResultsGroup.get(nextIndex);
        root.selectedListIndex = nextIndex;
        root.selectedUrl = entry.model.file_url;
        trackList.currentIndex = nextIndex;
        trackList.positionViewAtIndex(nextIndex, ListView.Contain);
    }
    function ensureSelection() {
        if (root.sourceActivationInProgress || searchFilterTimer.running || root.applyingSearchFilter) {
            return;
        }
        const count = searchResultsGroup.count;
        if (count === 0) {
            root.selectedListIndex = -1;
            root.selectedUrl = "";
            trackList.currentIndex = -1;
            return;
        }
        for (let i = 0; i < count; ++i) {
            if (searchResultsGroup.get(i).model.file_url.toString() === root.selectedUrl.toString()) {
                root.selectedListIndex = i;
                trackList.currentIndex = i;
                return;
            }
        }
        const nextIndex = Math.max(0, Math.min(root.selectedListIndex, count - 1));
        root.selectedListIndex = nextIndex;
        root.selectedUrl = searchResultsGroup.get(nextIndex).model.file_url;
        trackList.currentIndex = nextIndex;
    }
    function activateSource(modelIndex) {
        if (!modelIndex.valid) {
            return false;
        }
        root.sourceActivationInProgress = true;
        searchFilterTimer.stop();
        filteredTrackModel.model = null;
        root.sourceModel.activate(modelIndex);
        sourceSelection.setCurrentIndex(modelIndex, ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Rows);
        root.resetSourceTrackState();
        root.sourceActivationInProgress = false;
        return true;
    }
    function resetSourceTrackState() {
        const wasActivating = root.sourceActivationInProgress;
        root.sourceActivationInProgress = true;
        searchFilterTimer.stop();
        root.cancelPendingPositionRestore();
        root.resetSelectionOnFilter = true;
        if (root.openSwipeRow) {
            root.openSwipeRow.closeMenu();
        }
        root.openSwipeRow = null;
        filteredTrackModel.model = null;
        root.selectedUrl = "";
        root.selectedListIndex = -1;
        root.selectedGenreFilter = "";
        root.availableGenres = [];
        searchField.text = "";
        root.sortColumn = 1;
        root.sortOrder = Qt.AscendingOrder;
        trackList.currentIndex = -1;
        root.trackModel.search("");
        if (root.canSort) {
            root.trackModel.sort(root.sortColumn, root.sortOrder);
        }
        filteredTrackModel.model = root.trackModel;
        root.sourceActivationInProgress = wasActivating;
        root.scheduleSearchFilter(true);
        trackList.positionViewAtBeginning();
    }
    function sourceTreeIndex(row, column) {
        return sourceTreeView.index
                ? sourceTreeView.index(row, column)
                : sourceTreeView.modelIndex(Qt.point(column, row));
    }
    function selectTrack(url, row) {
        root.cancelPendingPositionRestore();
        if (root.openSwipeRow && root.openSwipeRow !== row) {
            root.openSwipeRow.closeMenu();
        }
        root.selectedUrl = url;
        root.selectedListIndex = row.index;
        trackList.currentIndex = row.index;
        focusedWidgetControl.value = root.libraryViewFocus;
        trackList.forceActiveFocus();
    }
    function sortByColumn(column) {
        if (!root.trackModel || !root.canSort) {
            return;
        }
        if (root.sortColumn === column) {
            root.sortOrder = root.sortOrder === Qt.AscendingOrder ? Qt.DescendingOrder : Qt.AscendingOrder;
        } else {
            root.sortColumn = column;
            root.sortOrder = Qt.AscendingOrder;
        }
        root.revealSelectionAfterFilter = true;
        root.trackModel.sort(root.sortColumn, root.sortOrder);
        root.scheduleSearchFilter();
    }

    color: TouchTheme.libraryBackground

    onVisibleChanged: root.appearanceRevision++

    Component.onCompleted: {
        root.trackModel.setColumns(sourceColumns.defaultColumns);
        const firstSource = root.sourceModel.index(0, 0);
        root.sourceModel.activate(firstSource);
        sourceSelection.setCurrentIndex(firstSource, ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Rows);
        root.resetSourceTrackState();
        if (libraryViewControl.value > 0) {
            focusedWidgetControl.value = root.libraryViewFocus;
        }
    }

    Mixxx.LibrarySourceTree {
        id: sourceColumns

        visible: false

        // qmllint disable unresolved-type
        defaultColumns: [
            Mixxx.TrackListColumn {
                columnIdx: Mixxx.TrackListColumn.SQLColumns.Title
                label: qsTr("Title")
            },
            Mixxx.TrackListColumn {
                columnIdx: 6 // ColumnCache::COLUMN_LIBRARYTABLE_GENRE
                label: qsTr("Genre")
            },
            Mixxx.TrackListColumn {
                columnIdx: 11 // ColumnCache::COLUMN_LIBRARYTABLE_COMMENT
                label: qsTr("Comment")
            },
            Mixxx.TrackListColumn {
                columnIdx: Mixxx.TrackListColumn.SQLColumns.Bpm
                label: qsTr("BPM")
            },
            Mixxx.TrackListColumn {
                columnIdx: 26 // ColumnCache::COLUMN_LIBRARYTABLE_RATING
                label: qsTr("Rating")
            },
            Mixxx.TrackListColumn {
                columnIdx: Mixxx.TrackListColumn.SQLColumns.Key
                label: qsTr("Key")
            },
            Mixxx.TrackListColumn {
                columnIdx: 12 // ColumnCache::COLUMN_LIBRARYTABLE_DURATION
                label: qsTr("Time")
            },
            Mixxx.TrackListColumn {
                columnIdx: 41 // ColumnCache::COLUMN_LIBRARYTABLE_LAST_PLAYED_AT
                label: qsTr("Last")
            },
            Mixxx.TrackListColumn {
                columnIdx: Mixxx.TrackListColumn.SQLColumns.Artist
                label: qsTr("Artist")
            },
            Mixxx.TrackListColumn {
                columnIdx: 28 // ColumnCache::COLUMN_LIBRARYTABLE_KEY_ID
                label: qsTr("Numeric Key")
            }
        ]
        // qmllint enable unresolved-type
    }
    Mixxx.ControlProxy {
        id: keyNotationControl

        group: "[Library]"
        key: "key_notation"

        onValueChanged: {
            if (searchField.text.trim().length > 0) {
                root.applySearchFilter(false);
            }
        }
    }
    Mixxx.ControlProxy {
        id: libraryViewControl

        group: "[Skin]"
        key: "show_maximized_library"

        onValueChanged: value => {
            if (value > 0) {
                focusedWidgetControl.value = root.libraryViewFocus;
                trackList.forceActiveFocus();
                Qt.callLater(root.ensureSelection);
            }
        }
    }
    Mixxx.ControlProxy {
        id: numPreviewDecksControl

        group: "[App]"
        key: "num_preview_decks"
    }
    Mixxx.ControlProxy {
        id: focusedWidgetControl

        group: "[Library]"
        key: "focused_widget"
    }
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "GoToItem"

        onValueChanged: value => {
            if (value > 0 && libraryViewControl.value > 0 && focusedWidgetControl.value === root.libraryViewFocus) {
                root.loadUrlIntoNextAvailableDeck(root.selectedUrl);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Playlist]"
        key: "LoadSelectedIntoFirstStopped"

        onValueChanged: value => {
            if (value > 0 && libraryViewControl.value > 0 && focusedWidgetControl.value === root.libraryViewFocus) {
                root.loadUrlIntoNextAvailableDeck(root.selectedUrl);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Playlist]"
        key: "SelectTrackKnob"

        onValueChanged: value => {
            if (value !== 0 && libraryViewControl.value > 0) {
                focusedWidgetControl.value = root.libraryViewFocus;
                root.moveSelection(value);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Playlist]"
        key: "SelectPrevTrack"

        onValueChanged: value => {
            if (value > 0 && libraryViewControl.value > 0) {
                focusedWidgetControl.value = root.libraryViewFocus;
                root.moveSelection(-1);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Playlist]"
        key: "SelectNextTrack"

        onValueChanged: value => {
            if (value > 0 && libraryViewControl.value > 0) {
                focusedWidgetControl.value = root.libraryViewFocus;
                root.moveSelection(1);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "MoveVertical"

        onValueChanged: value => {
            if (value !== 0 && libraryViewControl.value > 0) {
                focusedWidgetControl.value = root.libraryViewFocus;
                root.moveSelection(value);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "MoveUp"

        onValueChanged: value => {
            if (value > 0 && libraryViewControl.value > 0 && focusedWidgetControl.value === root.libraryViewFocus) {
                root.moveSelection(-1);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "MoveDown"

        onValueChanged: value => {
            if (value > 0 && libraryViewControl.value > 0 && focusedWidgetControl.value === root.libraryViewFocus) {
                root.moveSelection(1);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Channel1]"
        key: "LoadSelectedTrack"

        onValueChanged: value => {
            if (value > 0) {
                root.loadSelectedIntoDeck("[Channel1]");
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Channel2]"
        key: "LoadSelectedTrack"

        onValueChanged: value => {
            if (value > 0) {
                root.loadSelectedIntoDeck("[Channel2]");
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Channel1]"
        key: "LoadSelectedTrackAndPlay"

        onValueChanged: value => {
            if (value > 0) {
                root.loadSelectedIntoDeck("[Channel1]", true);
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Channel2]"
        key: "LoadSelectedTrackAndPlay"

        onValueChanged: value => {
            if (value > 0) {
                root.loadSelectedIntoDeck("[Channel2]", true);
            }
        }
    }
    Mixxx.ControlProxy {
        group: root.previewDeckGroup
        key: "LoadSelectedTrackAndPlay"

        onValueChanged: value => {
            if (value > 0) {
                root.loadUrlIntoPreviewDeck(root.selectedUrl);
            }
        }
    }
    ItemSelectionModel {
        id: sourceSelection

        model: root.sourceModel
    }
    Connections {
        target: root.sourceModel

        function onSelectIndex(index, scrollTo) {
            sourceSelection.setCurrentIndex(index, ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Rows);
            sourceTreeView.expandToIndex(index);
        }
        function onDataChanged() {
            root.sourceLabelRevision++;
        }
        function onModelReset() {
            root.sourceLabelRevision++;
        }
    }
    Connections {
        target: root.trackModel

        function onDataChanged(topLeft, bottomRight, roles) {
            if (roles.length > 0 && roles.every(role =>
                    role === Mixxx.LibraryTrackListModel.LoadedDeckMask ||
                    role === Mixxx.LibraryTrackListModel.PreviewDeckLoaded)) {
                return;
            }
            root.metadataRevision++;
            root.scheduleSearchFilter();
        }
        function onLayoutAboutToBeChanged() {
            root.preserveBrowsePosition();
            root.scheduleSearchFilter();
        }
        function onLayoutChanged() {
            root.metadataRevision++;
            root.scheduleSearchFilter();
        }
        function onModelAboutToBeReset() {
            root.preserveBrowsePosition();
            root.scheduleSearchFilter();
        }
        function onRowsAboutToBeRemoved() {
            root.preserveBrowsePosition();
            root.scheduleSearchFilter();
        }
        function onRowsAboutToBeInserted() {
            root.preserveBrowsePosition();
            root.scheduleSearchFilter();
        }
        function onRowsAboutToBeMoved() {
            root.preserveBrowsePosition();
            root.scheduleSearchFilter();
        }
        function onRowsInserted() {
            root.metadataRevision++;
            root.scheduleSearchFilter();
        }
        function onRowsRemoved() {
            root.metadataRevision++;
            root.scheduleSearchFilter();
        }
        function onRowsMoved() {
            root.metadataRevision++;
            root.scheduleSearchFilter();
        }
        function onModelReset() {
            root.metadataRevision++;
            root.scheduleSearchFilter();
        }
        function onSourceModelChanged() {
            if (!root.sourceActivationInProgress) {
                root.resetSourceTrackState();
            }
        }
    }
    Connections {
        target: Mixxx.Config

        function onLibraryBpmColumnPrecisionChanged() {
            root.metadataRevision++;
        }
    }
    Timer {
        // ApplyPlayedTrackColor has no QML property or notification. Re-read
        // the model's foreground role while visible to pick up preferences.
        interval: 1000
        repeat: true
        running: root.visible && root.trackModel !== null

        onTriggered: root.appearanceRevision++
    }
    Timer {
        id: searchFilterTimer

        interval: 120

        onTriggered: {
            const resetSelection = root.resetSelectionOnFilter;
            root.resetSelectionOnFilter = false;
            root.applySearchFilter(resetSelection);
        }
    }
    Connections {
        function onCountChanged() {
            root.scheduleSearchFilter();
        }

        target: filteredTrackModel.items
    }
    Connections {
        function onCountChanged() {
            Qt.callLater(root.ensureSelection);
        }

        target: searchResultsGroup
    }
    DelegateModel {
        id: filteredTrackModel

        filterOnGroup: "searchResults"
        model: root.trackModel

        delegate: TrackRow {
            id: visualTrackRow

            bpmColumnWidth: root.bpmColumnWidth
            commentColumnWidth: root.commentColumnWidth
            displayBpm: root.columnText(visualTrackRow.index, 3, root.metadataRevision, visualTrackRow.file_url)
            displayKey: root.formattedKey(visualTrackRow.track)
            displayLastPlayed: root.columnText(visualTrackRow.index, 7, root.metadataRevision, visualTrackRow.file_url)
            durationColumnWidth: root.durationColumnWidth
            foregroundColor: root.rowForeground(visualTrackRow.index, root.metadataRevision, root.appearanceRevision, visualTrackRow.file_url)
            genreColumnWidth: root.genreColumnWidth
            keyColumnWidth: root.keyColumnWidth
            lastPlayedColumnWidth: root.lastPlayedColumnWidth
            loadEnabled: root.canLoadToDeck
            previewEnabled: root.canLoadToPreviewDeck
            ratingColumnWidth: root.ratingColumnWidth
            selected: root.selectedUrl.toString() === file_url.toString()
            width: trackList.width

            onLoadNextRequested: root.loadUrlIntoNextAvailableDeck(file_url)
            onLoadRequested: group => {
                root.selectTrack(file_url, visualTrackRow);
                root.loadUrlIntoDeck(file_url, group);
            }
            onMenuClosed: row => {
                if (root.openSwipeRow === row) {
                    root.openSwipeRow = null;
                }
            }
            onMenuOpenRequested: row => {
                if (root.openSwipeRow && root.openSwipeRow !== row) {
                    root.openSwipeRow.closeMenu();
                }
                root.openSwipeRow = row;
            }
            onPreviewRequested: row => {
                root.selectTrack(file_url, row);
                root.loadUrlIntoPreviewDeck(file_url);
            }
            onSelectRequested: row => root.selectTrack(file_url, row)
        }
        groups: DelegateModelGroup {
            id: searchResultsGroup

            includeByDefault: true
            name: "searchResults"
        }
    }
    Rectangle {
        id: searchBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        color: TouchTheme.libraryHeaderBackground
        height: 56

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            PreviewDeck {
                Layout.preferredHeight: TouchTheme.minimumTouchSize
                Layout.preferredWidth: 320
                group: root.previewDeckGroup
                visible: numPreviewDecksControl.value > 0
            }
            TextField {
                id: searchField

                Layout.fillWidth: true
                Layout.preferredHeight: TouchTheme.minimumTouchSize
                color: TouchTheme.primaryText
                font.family: TouchTheme.fontFamily
                font.pixelSize: 16
                leftPadding: 44
                placeholderText: qsTr("Search title, artist, genre, comment, or key")
                placeholderTextColor: TouchTheme.mutedText
                selectByMouse: true
                selectionColor: TouchTheme.deck1Accent

                background: Rectangle {
                    border.color: searchField.activeFocus ? TouchTheme.deck1Accent : TouchTheme.border
                    border.width: 1
                    color: TouchTheme.controlBackground

                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        height: TouchTheme.navigationIconSize
                        source: Qt.resolvedUrl("../Icons/search.svg")
                        sourceSize.height: TouchTheme.navigationIconSize
                        sourceSize.width: TouchTheme.navigationIconSize
                        width: TouchTheme.navigationIconSize
                    }
                }

                onTextChanged: root.scheduleSearchFilter(true)
            }
            Rectangle {
                Layout.preferredHeight: TouchTheme.minimumTouchSize
                Layout.preferredWidth: visible ? 80 : 0
                border.color: TouchTheme.border
                border.width: 1
                color: clearTapHandler.pressed ? TouchTheme.controlPressedBackground : TouchTheme.controlBackground
                visible: searchField.text.length > 0

                Text {
                    anchors.centerIn: parent
                    color: TouchTheme.secondaryText
                    font.family: TouchTheme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    text: qsTr("CLEAR")
                }
                TapHandler {
                    id: clearTapHandler

                    onTapped: searchField.clear()
                }
            }
            Rectangle {
                Layout.preferredHeight: TouchTheme.minimumTouchSize
                Layout.preferredWidth: 156
                border.color: sourcePicker.visible ? TouchTheme.deck1Accent : TouchTheme.border
                border.width: 1
                color: sourceButtonTap.pressed ? TouchTheme.controlPressedBackground : TouchTheme.controlBackground

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        height: 20
                        source: Qt.resolvedUrl("../Icons/browse.svg")
                        sourceSize.height: 20
                        sourceSize.width: 20
                        width: 20
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: TouchTheme.primaryText
                        elide: Text.ElideRight
                        font.family: TouchTheme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        text: root.selectedSourceLabel.toLocaleUpperCase()
                        width: 104
                    }
                }
                TapHandler {
                    id: sourceButtonTap

                    onTapped: sourcePicker.open()
                }
            }
        }
    }
    Rectangle {
        id: columnHeader

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchBar.bottom
        color: TouchTheme.deckStatusAlternateBackground
        height: TouchTheme.minimumTouchSize

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 64
            anchors.rightMargin: 16
            spacing: 12

            ColumnHeader {
                Layout.fillWidth: true
                columnIndex: 0
                label: qsTr("TRACK")
            }
            ColumnHeader {
                Layout.preferredWidth: root.genreColumnWidth
                columnIndex: 1
                highlighted: root.selectedGenreFilter.length > 0
                holdEnabled: root.trackModel !== null
                label: qsTr("GENRE")

                onHeld: {
                    root.applySearchFilter();
                    genrePicker.open();
                }
            }
            ColumnHeader {
                Layout.preferredWidth: root.commentColumnWidth
                columnIndex: 2
                label: qsTr("COMMENT")
            }
            ColumnHeader {
                Layout.preferredWidth: root.bpmColumnWidth
                columnIndex: 3
                label: qsTr("BPM")
            }
            ColumnHeader {
                Layout.preferredWidth: root.ratingColumnWidth
                columnIndex: 4
                label: qsTr("RATING")
            }
            ColumnHeader {
                Layout.preferredWidth: root.keyColumnWidth
                columnIndex: 5
                label: qsTr("KEY")
            }
            ColumnHeader {
                Layout.preferredWidth: root.durationColumnWidth
                columnIndex: 6
                horizontalAlignment: Text.AlignRight
                label: qsTr("TIME")
            }
            ColumnHeader {
                Layout.preferredWidth: root.lastPlayedColumnWidth
                columnIndex: 7
                label: qsTr("LAST")
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            color: TouchTheme.border
            height: 1
        }
    }
    ListView {
        id: trackList

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: columnHeader.bottom
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        currentIndex: -1
        focus: libraryViewControl.value > 0
        highlightFollowsCurrentItem: false
        model: filteredTrackModel
        reuseItems: true

        onMovementStarted: root.cancelPendingPositionRestore()

        Keys.onDownPressed: event => {
            root.moveSelection(1);
            event.accepted = true;
        }
        Keys.onEnterPressed: event => {
            root.loadUrlIntoNextAvailableDeck(root.selectedUrl);
            event.accepted = true;
        }
        Keys.onReturnPressed: event => {
            root.loadUrlIntoNextAvailableDeck(root.selectedUrl);
            event.accepted = true;
        }
        Keys.onUpPressed: event => {
            root.moveSelection(-1);
            event.accepted = true;
        }

        ScrollBar.vertical: ScrollBar {
            id: trackScrollBar

            policy: ScrollBar.AsNeeded

            onPressedChanged: {
                if (pressed) {
                    root.cancelPendingPositionRestore();
                }
            }
        }
    }
    Text {
        anchors.centerIn: trackList
        color: TouchTheme.mutedText
        font.family: TouchTheme.fontFamily
        font.pixelSize: 18
        text: root.trackModel === null ? qsTr("Loading library…") : searchField.text.length > 0 || root.selectedGenreFilter.length > 0 ? qsTr("No tracks match current filters") : qsTr("No tracks in the library")
        visible: trackList.count === 0
    }
    Popup {
        id: genrePicker

        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(400, parent.width - 32)
        height: Math.min(520, 56 + (root.availableGenres.length + 1) * TouchTheme.minimumTouchSize, parent.height - 32)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnReleaseOutside
        focus: true
        modal: true
        padding: 0

        Overlay.modal: Rectangle {
            color: "#80000000"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                preventStealing: true

                onClicked: genrePicker.close()
                onWheel: wheel => wheel.accepted = true
            }
        }
        background: Rectangle {
            border.color: TouchTheme.deck1Accent
            border.width: 1
            color: TouchTheme.libraryBackground
        }
        contentItem: Item {
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons

                onWheel: wheel => wheel.accepted = true
            }

            Rectangle {
                id: genrePickerHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                color: TouchTheme.libraryHeaderBackground
                height: 56

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: closeGenrePicker.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: TouchTheme.primaryText
                    elide: Text.ElideRight
                    font.family: TouchTheme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    text: qsTr("Genre Filter")
                }
                Rectangle {
                    id: closeGenrePicker

                    anchors.right: parent.right
                    anchors.top: parent.top
                    color: closeGenrePickerTap.pressed ? TouchTheme.controlPressedBackground : "transparent"
                    height: parent.height
                    width: 56

                    Text {
                        anchors.centerIn: parent
                        color: TouchTheme.secondaryText
                        font.family: TouchTheme.fontFamily
                        font.pixelSize: 22
                        text: "x"
                    }
                    TapHandler {
                        id: closeGenrePickerTap

                        gesturePolicy: TapHandler.WithinBounds

                        onTapped: genrePicker.close()
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    color: TouchTheme.border
                    height: 1
                    width: parent.width
                }
            }
            ListView {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: genrePickerHeader.bottom
                clip: true
                model: [""].concat(root.availableGenres)

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    id: genreDelegate

                    required property int index
                    required property string modelData
                    readonly property bool selected: root.selectedGenreFilter === modelData

                    color: selected ? TouchTheme.libraryRowSelectedBackground : genreDelegateTap.pressed ? TouchTheme.controlPressedBackground : index % 2 === 0 ? TouchTheme.libraryRowBackground : TouchTheme.libraryRowAlternateBackground
                    height: TouchTheme.minimumTouchSize
                    width: ListView.view.width

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: genreDelegate.selected ? TouchTheme.deck1Accent : TouchTheme.primaryText
                        elide: Text.ElideRight
                        font.family: TouchTheme.fontFamily
                        font.pixelSize: 15
                        font.weight: genreDelegate.selected ? Font.DemiBold : Font.Normal
                        text: genreDelegate.modelData.length > 0 ? genreDelegate.modelData : qsTr("ALL GENRES")
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        color: TouchTheme.border
                        height: 1
                        width: parent.width
                    }
                    TapHandler {
                        id: genreDelegateTap

                        gesturePolicy: TapHandler.WithinBounds

                        onTapped: {
                            root.selectedGenreFilter = genreDelegate.modelData;
                            root.applySearchFilter(true);
                            genrePicker.close();
                        }
                    }
                }
            }
        }
    }
    Popup {
        id: sourcePicker

        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(440, parent.width - 32)
        height: Math.min(520, parent.height - 32)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnReleaseOutside
        focus: true
        modal: true
        padding: 0

        Overlay.modal: Rectangle {
            color: "#80000000"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                preventStealing: true

                onClicked: sourcePicker.close()
                onWheel: wheel => wheel.accepted = true
            }
        }
        background: Rectangle {
            border.color: TouchTheme.deck1Accent
            border.width: 1
            color: TouchTheme.libraryBackground
        }
        contentItem: Item {
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons

                onWheel: wheel => wheel.accepted = true
            }

            Rectangle {
                id: sourcePickerHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                color: TouchTheme.libraryHeaderBackground
                height: 56

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: closeSourcePicker.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: TouchTheme.primaryText
                    elide: Text.ElideRight
                    font.family: TouchTheme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    text: qsTr("Library Source")
                }
                Rectangle {
                    id: closeSourcePicker

                    anchors.right: parent.right
                    anchors.top: parent.top
                    color: closeSourcePickerTap.pressed ? TouchTheme.controlPressedBackground : "transparent"
                    height: parent.height
                    width: 56

                    Text {
                        anchors.centerIn: parent
                        color: TouchTheme.secondaryText
                        font.family: TouchTheme.fontFamily
                        font.pixelSize: 22
                        text: "x"
                    }
                    TapHandler {
                        id: closeSourcePickerTap

                        gesturePolicy: TapHandler.WithinBounds

                        onTapped: sourcePicker.close()
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    color: TouchTheme.border
                    height: 1
                    width: parent.width
                }
            }
            TreeView {
                id: sourceTreeView

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: sourcePickerHeader.bottom
                clip: true
                model: root.sourceModel
                selectionModel: sourceSelection

                onExpanded: (row, depth) => root.sourceModel.expand(root.sourceTreeIndex(row, 0))

                delegate: Rectangle {
                    id: sourceDelegate

                    required property int column
                    required property int depth
                    required property bool expanded
                    required property bool hasChildren
                    required property bool isTreeNode
                    required property string label
                    required property bool selected
                    required property int row
                    required property TreeView treeView
                    readonly property var modelIndex: root.sourceTreeIndex(row, column)

                    color: selected ? TouchTheme.libraryRowSelectedBackground : sourceDelegateTap.pressed ? TouchTheme.controlPressedBackground : depth === 0 ? TouchTheme.controlBackground : TouchTheme.libraryRowBackground
                    implicitHeight: 52
                    implicitWidth: treeView.width

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16 + sourceDelegate.depth * 24
                        anchors.verticalCenter: parent.verticalCenter
                        color: TouchTheme.secondaryText
                        font.family: TouchTheme.fontFamily
                        font.pixelSize: 18
                        rotation: sourceDelegate.expanded ? 90 : 0
                        text: ">"
                        visible: sourceDelegate.isTreeNode && sourceDelegate.hasChildren > 0
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 44 + sourceDelegate.depth * 24
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: sourceDelegate.selected ? TouchTheme.deck1Accent : TouchTheme.primaryText
                        elide: Text.ElideRight
                        font.family: TouchTheme.fontFamily
                        font.pixelSize: 15
                        font.weight: sourceDelegate.depth === 0 ? Font.DemiBold : Font.Normal
                        text: sourceDelegate.label
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        color: TouchTheme.border
                        height: 1
                        width: parent.width
                    }
                    TapHandler {
                        id: sourceDelegateTap

                        gesturePolicy: TapHandler.WithinBounds

                        onTapped: {
                            if (sourceDelegate.isTreeNode && sourceDelegate.hasChildren) {
                                sourceDelegate.treeView.toggleExpanded(sourceDelegate.row);
                                if (sourceDelegate.depth === 0 && sourceDelegate.modelIndex.row === 0) {
                                    root.activateSource(sourceDelegate.modelIndex);
                                }
                            } else if (sourceDelegate.depth > 0 || sourceDelegate.modelIndex.row === 0) {
                                if (root.activateSource(sourceDelegate.modelIndex)) {
                                    sourcePicker.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component ColumnHeader: Text {
        required property int columnIndex
        property bool highlighted: false
        property bool holdEnabled: false
        property bool holdTriggered: false
        required property string label
        property bool sortEnabled: root.canSort

        signal held

        color: highlighted ? TouchTheme.activeLeader : TouchTheme.mutedText
        enabled: sortEnabled || holdEnabled
        elide: Text.ElideRight
        font.family: TouchTheme.fontFamily
        font.pixelSize: 11
        font.weight: Font.DemiBold
        opacity: !enabled ? 0.42 : headerTapHandler.pressed ? 0.62 : 1.0
        text: root.sortColumn === columnIndex ?
            label + (root.sortOrder === Qt.AscendingOrder ? "  ^" : "  v") : label
        verticalAlignment: Text.AlignVCenter

        TapHandler {
            id: headerTapHandler

            enabled: parent.enabled
            longPressThreshold: 0.5

            onLongPressed: {
                if (parent.holdEnabled) {
                    parent.holdTriggered = true;
                    parent.held();
                }
            }
            onPressedChanged: {
                if (pressed) {
                    parent.holdTriggered = false;
                }
            }
            onTapped: {
                if (parent.holdTriggered) {
                    parent.holdTriggered = false;
                    return;
                }
                if (parent.sortEnabled) {
                    root.sortByColumn(parent.columnIndex);
                }
            }
        }
    }
}
