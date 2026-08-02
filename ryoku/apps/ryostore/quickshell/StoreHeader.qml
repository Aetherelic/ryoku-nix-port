import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: header

    property string view: "discover"
    property string categoryID: ""
    property var categories: []
    property string query: ""
    property int libraryCount: 0
    property int updateCount: 0
    property bool offline: false

    signal routeRequested(string view, string categoryID)
    signal searchRequested()

    readonly property string libraryLabel: "LIBRARY " + libraryCount
            + (updateCount > 0 ? " / " + updateCount + " UPDATE" + (updateCount === 1 ? "" : "S") : "")

    implicitHeight: 64

    function activateDiscover() {
        routeRequested("discover", "");
    }

    function activateCategory(id) {
        routeRequested("discover", id);
    }

    function activateSearch() {
        searchRequested();
    }

    function activateLibrary() {
        routeRequested("library", "");
    }

    component NavAction: Item {
        id: action

        required property string label
        property string description: ""
        property bool current: false
        signal triggered()

        implicitWidth: actionLabel.implicitWidth + Tokens.s5 * 2
        implicitHeight: header.height
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.description: description
        Accessible.onPressAction: triggered()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                action.triggered();
                event.accepted = true;
            }
        }

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: action.label
            color: action.current || action.activeFocus ? Tokens.ink : Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: Tokens.fMicro
            font.weight: Font.Medium
            font.letterSpacing: Tokens.trackLabel
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Tokens.border * 2
            color: Tokens.ink
            visible: action.current || action.activeFocus
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: action.triggered() }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Tokens.border
        color: Tokens.line
    }

    NavAction {
        id: discoverAction
        objectName: "ryostore-header-discover"
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        label: "DISCOVER"
        current: header.view === "discover" && header.categoryID === "" && header.query === ""
        onTriggered: header.activateDiscover()
    }

    Flickable {
        id: categoryScroll
        objectName: "ryostore-header-categories"
        anchors {
            left: discoverAction.right
            right: searchAction.left
            top: parent.top
            bottom: parent.bottom
        }
        clip: true
        contentWidth: categoryRow.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        function reveal(itemX, itemWidth) {
            const maximum = Math.max(0, contentWidth - width);
            if (itemX < contentX)
                contentX = Math.max(0, itemX);
            else if (itemX + itemWidth > contentX + width)
                contentX = Math.min(maximum, itemX + itemWidth - width);
        }

        Row {
            id: categoryRow
            height: parent.height

            Repeater {
                model: header.categories

                delegate: NavAction {
                    required property var modelData
                    required property int index
                    objectName: "ryostore-header-category-" + String(modelData.id || "")
                    label: String(modelData.name || modelData.id || "").toUpperCase()
                    current: header.view === "discover" && header.categoryID === String(modelData.id || "")
                    onTriggered: header.activateCategory(String(modelData.id || ""))
                    onActiveFocusChanged: {
                        if (activeFocus)
                            categoryScroll.reveal(x, width);
                    }
                }
            }
        }
    }

    NavAction {
        id: searchAction
        objectName: "ryostore-header-search"
        anchors { right: libraryAction.left; top: parent.top; bottom: parent.bottom }
        label: header.offline ? "SEARCH / OFFLINE" : "SEARCH"
        description: header.query === "" ? "Search the Store" : "Search query: " + header.query
        current: header.query !== ""
        onTriggered: header.activateSearch()
    }

    NavAction {
        id: libraryAction
        objectName: "ryostore-header-library"
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        label: header.libraryLabel
        current: header.view === "library"
        onTriggered: header.activateLibrary()
    }
}
