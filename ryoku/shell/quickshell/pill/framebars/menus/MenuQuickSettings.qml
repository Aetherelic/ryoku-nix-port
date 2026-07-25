pragma ComponentBehavior: Bound

import QtQuick
import "../MenuCatalog.js" as MenuCatalog

// Quick-settings frame menu: composes its child menus through explicit registry
// ids (the catalogued quick-settings content over the fixed quick-action
// catalogue) via the shared MenuColumn host path, so it owns no service logic of
// its own.
Item {
    id: root

    required property real s
    required property bool open

    readonly property var childIds: {
        const menu = MenuCatalog.menu("quick-settings");
        const base = (menu && menu.widgets) ? menu.widgets : [];
        return base.concat(["quick-actions"]);
    }

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    MenuColumn {
        id: body
        width: root.width
        scale: root.s
        open: root.open
        widgets: root.childIds
    }
}
