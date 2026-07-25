pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property var widgets: []
    property bool open: false
    property real scale: 1
    signal requestClose()

    // Rows never touch the body edge: the surface grows out of a rail, and a
    // flush row loses its first characters under that rail's material or gets
    // cut by the body's own rounded edge.
    readonly property real pad: 14 * scale
    implicitWidth: column.implicitWidth + pad * 2
    implicitHeight: column.implicitHeight + pad * 2

    Column {
        id: column
        x: root.pad
        y: root.pad
        width: Math.max(0, root.width - root.pad * 2)
        spacing: 6 * root.scale

        Repeater {
            model: root.open ? root.widgets : []
            delegate: MenuHostLoader {
                required property var modelData
                width: column.width
                widget: modelData
                scale: root.scale
                open: root.open
                onRequestClose: root.requestClose()
            }
        }
    }
}
