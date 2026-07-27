pragma ComponentBehavior: Bound

import QtQuick

// The shared menu panel body (contract 05 sec 2a): a vertical stack of the
// menu's widgets inside a 20px margin, exactly minimumWidth wide (the width is
// set by the host and never grows to content). Content taller than the band
// scrolls vertically with no visible scrollbar chrome; there is no horizontal
// scrolling.
Item {
    id: root

    property var widgets: []
    property bool open: false
    property real scale: 1
    // Forwarded to the sole quick-settings widget: an initial sidebar page to
    // open on (a bar indicator deep-linking into a page). "" opens the main view.
    property string initialPage: ""
    signal requestClose()

    readonly property real pad: 20 * scale
    implicitWidth: column.implicitWidth + pad * 2
    implicitHeight: column.implicitHeight + pad * 2

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + root.pad * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Only steal drags when there is overflow to scroll.
        interactive: contentHeight > height

        Column {
            id: column
            x: root.pad
            y: root.pad
            width: root.width - root.pad * 2
            spacing: 0

            Repeater {
                model: root.open ? root.widgets : []
                delegate: MenuHostLoader {
                    required property var modelData
                    width: column.width
                    widget: modelData
                    scale: root.scale
                    open: root.open
                    // A sole widget owns the whole band (the sidebar fills it);
                    // stacked widgets keep natural heights.
                    avail: root.widgets.length === 1 ? root.height - root.pad * 2 : 0
                    initialPage: root.initialPage
                    onRequestClose: root.requestClose()
                }
            }
        }
    }
}
