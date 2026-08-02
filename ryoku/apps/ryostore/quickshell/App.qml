pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"
import "lib/store.js" as StoreLogic

Rectangle {
    id: app

    implicitWidth: 1180
    implicitHeight: 760
    color: Tokens.paper
    focus: true

    property string view: "discover"
    property string categoryID: ""
    property string query: ""
    property bool searchOpen: false
    property string selectedKey: ""
    property var previewItem: null
    property var detailItem: null
    property bool detailOpen: false
    property real filmstripOffset: 0
    property var searchContext: null
    property var detailContext: null
    property rect detailOriginRect: Qt.rect(0, 0, 0, 0)
    property bool reducedMotion: performance.lowPowerMode || performance.reduceMotion
    readonly property bool catalogLoading: Store.loading && Store.items.length === 0
    readonly property bool catalogError: !Store.loading && Store.items.length === 0 && Store.error !== ""

    readonly property var searchableItems: Store.items.map(item => {
        const copy = {};
        Object.keys(item).forEach(key => copy[key] = item[key]);
        const category = Store.category(item.category);
        copy.categoryName = category ? category.name : item.category;
        return copy;
    })
    readonly property var navigationCategories: StoreLogic.sortCategories(Store.categories)
    readonly property var collection: StoreLogic.collection(searchableItems, {
        view: view,
        categoryID: categoryID,
        query: query
    })
    readonly property var selectedItem: itemForKey(selectedKey, collection)
    readonly property var resolvedDetail: detailItem
            ? itemForKey(StoreLogic.itemKey(detailItem), searchableItems) || detailItem
            : null
    readonly property int selectedIndex: indexForKey(selectedKey, collection)
    readonly property int libraryCount: StoreLogic.installed(searchableItems).length
    readonly property int updateCount: searchableItems.filter(item => item.updateAvailable === true).length
    readonly property string positionText: collection.length > 0 && selectedIndex >= 0
            ? String(selectedIndex + 1) + " / " + String(collection.length)
            : ""

    function itemForKey(key, items) {
        const source = Array.isArray(items) ? items : [];
        for (let i = 0; i < source.length; i++)
            if (StoreLogic.itemKey(source[i]) === key)
                return source[i];
        return null;
    }

    function indexForKey(key, items) {
        const source = Array.isArray(items) ? items : [];
        for (let i = 0; i < source.length; i++)
            if (StoreLogic.itemKey(source[i]) === key)
                return i;
        return -1;
    }

    function reconcileSelection(fallbackIndex) {
        selectedKey = StoreLogic.selectionKey(collection, selectedKey,
                                                fallbackIndex === undefined ? 0 : fallbackIndex);
    }

    function validRoute(route) {
        return ["discover", "library", "rices", "lockscreens", "barstyles",
                "fastfetch", "plugins", "bundles"].indexOf(route) !== -1;
    }

    function currentFocusObject() {
        return app.Window.window ? app.Window.window.activeFocusItem : null;
    }

    function snapshotContext() {
        return {
            view: view,
            categoryID: categoryID,
            query: query,
            selectedKey: selectedKey,
            filmstripOffset: filmstripOffset,
            focusObject: currentFocusObject()
        };
    }

    function restoreContext(context) {
        if (!context)
            return;
        view = context.view;
        categoryID = context.categoryID;
        query = context.query;
        selectedKey = context.selectedKey;
        filmstripOffset = context.filmstripOffset;
        Qt.callLater(function() {
            app.reconcileSelection(0);
            Qt.callLater(function() {
                filmstrip.restoreOffset(context.filmstripOffset);
                app.filmstripOffset = filmstrip.contentOffset;
                if (context.focusObject && context.focusObject.forceActiveFocus)
                    context.focusObject.forceActiveFocus();
                else
                    filmstrip.forceActiveFocus();
            });
        });
    }

    function openRoute(route) {
        if (!validRoute(route))
            return;
        detailClear.stop();
        detailOpen = false;
        detailItem = null;
        detailContext = null;
        searchOpen = false;
        searchContext = null;
        query = "";
        previewItem = null;
        if (route === "discover" || route === "library") {
            view = route;
            categoryID = "";
        } else {
            view = "discover";
            categoryID = route;
        }
        reconcileSelection(0);
        Qt.callLater(function() { filmstrip.forceActiveFocus(); });
    }

    function selectKey(key) {
        selectedKey = StoreLogic.selectionKey(collection, key, 0);
        previewItem = null;
    }

    function selectedCoverRect() {
        const index = filmstrip.positionFor(selectedKey);
        if (index < 0)
            return Qt.rect(0, 0, 0, 0);
        const localX = index * filmstrip.step - filmstrip.contentOffset;
        const point = filmstrip.mapToItem(productDetail, localX, 0);
        return Qt.rect(point.x, point.y, filmstrip.cardWidth, filmstrip.height);
    }

    function openSelectedDetail() {
        if (!selectedItem)
            return;
        detailClear.stop();
        detailContext = snapshotContext();
        detailOriginRect = selectedCoverRect();
        detailItem = selectedItem;
        detailOpen = true;
        previewItem = null;
        Qt.callLater(function() { productDetail.focusInitialAction(); });
    }

    function closeDetail() {
        if (!detailOpen)
            return;
        const context = detailContext;
        detailOpen = false;
        detailContext = null;
        restoreContext(context);
        if (reducedMotion)
            detailItem = null;
        else
            detailClear.restart();
    }

    function openSearch() {
        if (searchOpen) {
            searchLayer.focusField();
            return;
        }
        searchContext = snapshotContext();
        searchOpen = true;
        query = "";
        previewItem = null;
        reconcileSelection(0);
    }

    function setQuery(value) {
        query = value;
        previewItem = null;
        reconcileSelection(0);
    }

    function closeSearch() {
        if (!searchOpen)
            return;
        const context = searchContext;
        searchOpen = false;
        searchContext = null;
        restoreContext(context);
    }

    function escapeLayer() {
        if (detailOpen)
            closeDetail();
        else if (searchOpen)
            closeSearch();
        else if (view !== "discover" || categoryID !== "")
            openRoute("discover");
    }

    function requestQuit() {
        if (Store.busyKey !== "" && !quitArm.running) {
            quitArm.restart();
            return;
        }
        Qt.quit();
    }

    onCollectionChanged: reconcileSelection(0)
    onSearchableItemsChanged: {
        reconcileSelection(0);
        if (detailItem)
            detailItem = itemForKey(StoreLogic.itemKey(detailItem), searchableItems) || detailItem;
    }

    Keys.onEscapePressed: event => {
        escapeLayer();
        event.accepted = true;
    }
    Keys.onPressed: event => {
        if (event.text === "/" && event.modifiers === Qt.NoModifier) {
            openSearch();
        } else if (!detailOpen && !searchOpen && event.key === Qt.Key_Left) {
            filmstrip.move(-1);
            filmstrip.commitPending();
        } else if (!detailOpen && !searchOpen && event.key === Qt.Key_Right) {
            filmstrip.move(1);
            filmstrip.commitPending();
        } else if (!detailOpen && !searchOpen && event.key === Qt.Key_Home) {
            filmstrip.moveBoundary(false);
            filmstrip.commitPending();
        } else if (!detailOpen && !searchOpen && event.key === Qt.Key_End) {
            filmstrip.moveBoundary(true);
            filmstrip.commitPending();
        } else if (!detailOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            openSelectedDetail();
        } else {
            return;
        }
        event.accepted = true;
    }

    Shortcut { sequence: "Ctrl+K"; onActivated: app.openSearch() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: app.requestQuit() }

    Timer { id: quitArm; interval: 3000 }
    Timer {
        id: detailClear
        interval: Tokens.swap
        onTriggered: app.detailItem = null
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
              + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: performance
            property bool lowPowerMode: false
            property bool reduceMotion: false
        }
    }

    StoreHeader {
        id: header
        objectName: "ryostore-header"
        anchors { left: parent.left; top: parent.top; right: parent.right }
        height: implicitHeight
        view: app.view
        categoryID: app.categoryID
        categories: app.navigationCategories
        query: app.query
        libraryCount: app.libraryCount
        updateCount: app.updateCount
        offline: Store.offline
        onRouteRequested: (routeView, routeCategory) => app.openRoute(routeCategory || routeView)
        onSearchRequested: app.openSearch()
    }

    ShowroomStage {
        id: stage
        objectName: "ryostore-stage"
        anchors { left: parent.left; top: header.bottom; right: parent.right; bottom: filmstrip.top }
        item: app.selectedItem
        previewItem: app.previewItem
        busyKey: Store.busyKey
        installStage: Store.installStage
        installErrorKey: Store.installErrorKey
        installError: Store.installError
        positionText: app.positionText
        offline: Store.offline
        reducedMotion: app.reducedMotion
        onInstallRequested: item => Store.install(item)
        onDetailsRequested: item => app.openSelectedDetail()
        onSettingsRequested: item => Store.openSettings(item)
    }

    Filmstrip {
        id: filmstrip
        objectName: "ryostore-filmstrip"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Tokens.s5 }
        height: Math.max(160, Math.min(220, (app.height - header.height) * 0.31))
        items: app.collection
        selectedKey: app.selectedKey
        reducedMotion: app.reducedMotion
        onContentOffsetChanged: app.filmstripOffset = contentOffset
        onPreviewRequested: item => app.previewItem = item
        onSelectionRequested: item => app.selectKey(StoreLogic.itemKey(item))
    }

    // initial catalogue fetch: show progress, never the empty plate, so a slow
    // network never reads as "there is nothing here".
    Column {
        id: loadingState
        anchors.centerIn: stage
        spacing: Tokens.s4
        visible: app.catalogLoading
        z: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "LOADING CATALOGUE"
            color: Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: Tokens.fSmall
            font.letterSpacing: Tokens.trackLabel
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 220
            height: 2
            color: Tokens.lineSoft
            clip: true

            Rectangle {
                width: 74
                height: parent.height
                radius: 1
                color: Tokens.sun
                x: app.reducedMotion ? (parent.width - width) / 2 : -width
                XAnimator on x {
                    from: -74
                    to: 220
                    duration: 1100
                    loops: Animation.Infinite
                    running: loadingState.visible && !app.reducedMotion
                }
            }
        }
    }

    // catalogue source failed with nothing cached to fall back on.
    Column {
        anchors.centerIn: stage
        spacing: Tokens.s3
        visible: app.catalogError
        z: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "CATALOGUE UNAVAILABLE"
            color: Tokens.ink
            font.family: Tokens.mono
            font.pixelSize: Tokens.fSmall
            font.letterSpacing: Tokens.trackLabel
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(stage.width - Tokens.s7 * 2, 420)
            text: Store.error
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            color: Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Btn {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "RETRY"
            armed: true
            onAct: Store.refresh(true)
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: Store.refresh(true)
        }
    }

    Column {
        anchors.centerIn: stage
        spacing: Tokens.s3
        visible: app.collection.length === 0 && !app.catalogLoading && !app.catalogError
        z: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: app.view === "library" ? "YOUR LIBRARY IS EMPTY"
                  : (app.query !== "" ? "NO SEARCH RESULTS" : "NO PRODUCTS AVAILABLE")
            color: Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: Tokens.fSmall
            font.letterSpacing: Tokens.trackLabel
        }

        Btn {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "RETURN TO DISCOVER"
            visible: app.view === "library"
            armed: visible
            onAct: app.openRoute("discover")
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: app.openRoute("discover")
        }
    }

    SearchLayer {
        id: searchLayer
        objectName: "ryostore-search"
        anchors.fill: header
        z: 10
        open: app.searchOpen
        query: app.query
        resultCount: app.collection.length
        onQueryEdited: value => app.setQuery(value)
        onCloseRequested: app.closeSearch()
    }

    ProductDetail {
        id: productDetail
        objectName: "ryostore-detail"
        anchors { left: parent.left; top: header.bottom; right: parent.right; bottom: parent.bottom }
        z: 20
        item: app.resolvedDetail
        open: app.detailOpen
        originRect: app.detailOriginRect
        busyKey: Store.busyKey
        installStage: Store.installStage
        installErrorKey: Store.installErrorKey
        installError: Store.installError
        reducedMotion: app.reducedMotion
        onCloseRequested: app.closeDetail()
        onInstallRequested: item => Store.install(item)
        onRetryRequested: item => Store.retryInstall(item)
        onSettingsRequested: item => Store.openSettings(item)
    }
}
