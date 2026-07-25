pragma ComponentBehavior: Bound

import QtQuick
import "framebars/MenuCatalog.js" as MenuCatalog
import "framebars/menus"

// Finite host for menu widgets: a closed switch resolves the generic
// composition primitives Task 6 ships. A catalogued but not-yet-implemented
// widget id logs a developer-visible error and renders nothing; Tasks 7-8
// extend the switch with real content components.
Item {
    id: root

    property string widgetId: ""
    property var widgetData: null
    property bool open: false
    property real scale: 1
    property int depth: 0

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    function componentFor(id) {
        switch (id) {
        case "container": return containerComponent;
        case "divider": return dividerComponent;
        case "spacer": return spacerComponent;
        default:
            if (MenuCatalog.widget(id)) console.error("frame menus: no host component for " + id);
            return null;
        }
    }

    Loader {
        id: loader
        width: root.width
        sourceComponent: root.componentFor(root.widgetId)
    }

    Component {
        id: containerComponent
        MenuContainer {
            width: root.width
            scale: root.scale
            open: root.open
            depth: root.depth
            orientation: root.widgetData && root.widgetData.orientation ? root.widgetData.orientation : "vertical"
            widgets: root.widgetData && root.widgetData.widgets ? root.widgetData.widgets : []
        }
    }
    Component { id: dividerComponent; MenuDivider { scale: root.scale } }
    Component { id: spacerComponent; MenuSpacer { scale: root.scale } }
}
