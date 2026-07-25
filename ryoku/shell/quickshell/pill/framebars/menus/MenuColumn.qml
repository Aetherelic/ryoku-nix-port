pragma ComponentBehavior: Bound

import QtQuick

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
