pragma ComponentBehavior: Bound

import QtQuick
import "popouts"
import "framebars/menus"

// One menu body riding the shared Popout: the anchor maps to a Popout edge and
// alignment, and the body sizes itself from its MenuColumn. Openness is owned
// by FrameMenuManager (menuOpen), never a private boolean, so a busy anchor's
// content is replaced by flipping which record is active.
Popout {
    id: root

    property var record: null
    property string anchor: "left"
    property bool menuOpen: false

    readonly property var widgetIds: record && record.widgets ? record.widgets : []
    readonly property real minWidth: record && record.minWidth ? record.minWidth : 200
    // stays true through the close melt so the body tears down only once flush.
    readonly property bool effectiveOpen: menuOpen || prog > 0.004

    edge: anchor.indexOf("top") === 0 ? "top"
        : anchor.indexOf("bottom") === 0 ? "bottom"
        : anchor
    align: (anchor.indexOf("-left") >= 0) ? "start"
         : (anchor.indexOf("-right") >= 0) ? "end"
         : "center"

    hoverOpen: false
    pinned: root.menuOpen
    openW: Math.max(root.minWidth * root.s, body.implicitWidth)
    openH: body.implicitHeight

    MenuColumn {
        id: body
        width: root.openW
        scale: root.s
        open: root.effectiveOpen
        widgets: root.widgetIds
    }
}
