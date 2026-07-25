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
    property var manager: null

    signal requestClose()
    readonly property var widgetIds: record && record.widgets ? record.widgets : []
    readonly property real fallbackMinWidth: 200
    readonly property real minWidth: record && record.minWidth ? record.minWidth : fallbackMinWidth
    // stays true through the close melt so the body tears down only once flush.
    readonly property string kind: record && record.kind ? record.kind : "menu"
    readonly property bool effectiveOpen: menuOpen || prog > 0.004

    edge: anchor.indexOf("top") === 0 ? "top"
        : anchor.indexOf("bottom") === 0 ? "bottom"
        : anchor
    align: (anchor.indexOf("-left") >= 0) ? "start"
         : (anchor.indexOf("-right") >= 0) ? "end"
         : "center"
    fullSpan: record && record.fullSpan === true
    hoverOpen: false
    pinned: root.menuOpen
    openW: Math.max(root.minWidth * root.s, body.item ? body.item.implicitWidth : 0)
    openH: root.fullSpan ? root.height : (body.item ? body.item.implicitHeight : 0)

    Loader {
        id: body
        width: root.openW
        height: root.openH
        sourceComponent: root.kind === "power" ? powerBody
            : root.kind === "voice" ? voiceBody
            : root.kind === "keyring" ? keyringBody
            : root.kind === "stash" ? stashBody
            : root.kind === "system" ? systemBody
            : menuBody
    }

    Component {
        id: menuBody
        MenuColumn {
            width: root.openW
            scale: root.s
            open: root.effectiveOpen
            widgets: root.widgetIds
            onRequestClose: root.requestClose()
        }
    }
    Component {
        id: powerBody
        PowerPanel {
            s: root.s
            open: root.effectiveOpen
            onCloseRequested: root.requestClose()
        }
    }
    Component {
        id: voiceBody
        VoicePopout {
            s: root.s
            off: root.record && root.record.off === true
            open: root.effectiveOpen
            onCloseRequested: root.requestClose()
        }
    }
    Component {
        id: keyringBody
        KeyringPopout {
            s: root.s
            open: root.effectiveOpen
            onCloseRequested: root.requestClose()
        }
    }
    Component {
        id: stashBody
        SidebarFeatures {
            s: root.s
            topInset: root.manager ? root.manager.sidebarTopInset : 0
            botInset: root.manager ? root.manager.sidebarBottomInset : 0
            open: root.effectiveOpen
            panes: root.record ? root.record.panes : []
            pane: root.manager ? root.manager.stashPane : ""
            onPaneSelected: key => { if (root.manager) root.manager.stashPane = key; }
        }
    }
    Component {
        id: systemBody
        SidebarSystem {
            s: root.s
            topInset: root.manager ? root.manager.sidebarTopInset : 0
            botInset: root.manager ? root.manager.sidebarBottomInset : 0
            open: root.effectiveOpen
            panes: root.record ? root.record.panes : []
            pane: root.manager ? root.manager.systemPane : ""
            onPaneSelected: key => { if (root.manager) root.manager.systemPane = key; }
            onDismiss: root.requestClose()
        }
    }
}
