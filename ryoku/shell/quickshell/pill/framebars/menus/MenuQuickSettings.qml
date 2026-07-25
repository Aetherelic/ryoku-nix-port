pragma ComponentBehavior: Bound

import QtQuick
import "../MenuCatalog.js" as MenuCatalog

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
