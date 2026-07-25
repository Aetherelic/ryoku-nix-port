pragma ComponentBehavior: Bound

import QtQuick

// Ordered vertical stack of menu widgets. The list is built only while the menu
// is effectively open, so a closed menu holds no widget instances.
Column {
    id: root

    property var widgets: []
    property bool open: false
    property real scale: 1
    spacing: 6 * scale

    Repeater {
        model: root.open ? root.widgets : []
        delegate: MenuHostLoader {
            required property var modelData
            width: root.width
            widget: modelData
            scale: root.scale
            open: root.open
        }
    }
}
