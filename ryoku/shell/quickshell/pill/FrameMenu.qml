pragma ComponentBehavior: Bound

import QtQuick
import "popouts"
import "framebars/menus"
import "Singletons"

// One menu body riding the shared Popout. Openness is owned by FrameMenuManager
// (menuOpen), never a private boolean, so a busy anchor's content is replaced by
// flipping which record is active.
//
// A reference frame menu (kind "menu") is placed by the exact contract-05 sec 7
// formulas, not by the Ryoku popout's trigger-follow: it is EXACTLY minimumWidth
// wide (no natural-width growth, no horizontal scroll), rendered at fixed
// reference pixels (scale 1) to match the unscaled frame band, and its vertical
// band placement obeys the four expansion modes. Ryoku's own surfaces (power,
// voice, keyring, stash, system) keep the trigger-centred, monitor-scaled
// behaviour untouched.
Popout {
    id: root

    property var record: null
    property string anchor: "left"
    property bool menuOpen: false
    property var manager: null
    // Per-edge clearance from the screen to the inside of each rail, so the
    // formulas can reference all four bar thicknesses (L/R/T/B), not just the
    // anchor's own.
    property var clearances: null
    // The trigger centre the manager derives for Ryoku surfaces; menus ignore it.
    property real triggerAlong: -1

    signal requestClose()

    readonly property var widgetIds: record && record.widgets ? record.widgets : []
    readonly property real fallbackMinWidth: 200
    readonly property real minWidth: record && record.minWidth ? record.minWidth : fallbackMinWidth
    readonly property string kind: record && record.kind ? record.kind : "menu"
    readonly property bool isMenu: root.kind === "menu"
    readonly property string expansion: record && record.expansion ? record.expansion : "always"
    // stays true through the close melt so the body tears down only once flush.
    readonly property bool effectiveOpen: menuOpen || prog > 0.004

    // Reference menus render at fixed reference pixels, matching the railScale-1
    // frame band; surfaces keep the per-monitor UI scale.
    readonly property real bodyScale: root.isMenu ? 1 : root.s

    edge: anchor.indexOf("top") === 0 ? "top"
        : anchor.indexOf("bottom") === 0 ? "bottom"
        : anchor
    align: (anchor.indexOf("-left") >= 0) ? "start"
         : (anchor.indexOf("-right") >= 0) ? "end"
         : "center"
    fullSpan: record && record.fullSpan === true
    hoverOpen: false
    pinned: root.menuOpen
    // A reference menu abuts its bar band exactly; a surface keeps the popout inset.
    edgeInsetOverride: root.isMenu ? 0 : -1

    readonly property real clL: root.clearances && typeof root.clearances.left === "number" ? root.clearances.left : 0
    readonly property real clR: root.clearances && typeof root.clearances.right === "number" ? root.clearances.right : 0
    readonly property real clT: root.clearances && typeof root.clearances.top === "number" ? root.clearances.top : 0
    readonly property real clB: root.clearances && typeof root.clearances.bottom === "number" ? root.clearances.bottom : 0
    // Band height available to a side menu = monitor height minus the top and
    // bottom bar thicknesses (contract 05 sec 7, H = MH - T - B).
    readonly property real bandH: Math.max(0, root.height - root.clT - root.clB)

    // Width rule (contract 05 sec 2a): a reference menu is EXACTLY minimumWidth;
    // natural width never propagates. Surfaces keep their scaled/natural width.
    openW: root.isMenu ? root.minWidth : Math.max(root.minWidth * root.s, body.item ? body.item.implicitWidth : 0)
    // Height = content, capped at the band; overflow scrolls inside the panel.
    openH: root.fullSpan ? root.height
         : root.isMenu ? Math.min(body.item ? body.item.implicitHeight : 0, root.bandH)
         : (body.item ? body.item.implicitHeight : 0)

    readonly property bool sideMenu: root.edge === "left" || root.edge === "right"

    // Contract 05 sec 7 top-left corner, expressed as the along-axis centre the
    // Popout consumes. Side menus place vertically by the four expansion modes;
    // top/bottom and corner menus place horizontally by their anchor, flush to
    // the hole edge (L or MW-R) or centred on the hole.
    readonly property real menuAlong: {
        if (root.sideMenu) {
            const hm = root.openH;
            if (root.expansion === "up")
                return (root.height - root.clB) - hm / 2;      // ExpandUp: bottom-pinned
            if (root.expansion === "both")
                return (root.clT + root.height - root.clB) / 2; // ExpandBothWays: centred
            return root.clT + hm / 2;                           // AlwaysExpanded / ExpandDown: top-pinned
        }
        const wm = root.openW;
        if (root.align === "start")
            return root.clL + wm / 2;                            // flush to the hole's left edge (x = L)
        if (root.align === "end")
            return (root.width - root.clR) - wm / 2;            // flush to the hole's right edge (x = MW - R)
        return (root.clL + root.width - root.clR) / 2;          // centred on the hole (cx)
    }
    alongCenter: root.isMenu ? root.menuAlong : root.triggerAlong

    // Reveal envelope by position: side menus slide (menuSlide, 250 ms
    // ease-out-cubic), corner and edge menus grow diagonally (diagonal, 200 ms
    // ease-in-out-quad), matching the reference (contracts 01 and 05). Overrides
    // the shared morph transition; a re-trigger retargets prog from its current
    // value, reproducing the reverse/restart-from-current interrupt.
    transitions: [
        Transition {
            to: "open"
            NumberAnimation { property: "prog"; duration: root.sideMenu ? Motion.menuSlide : Motion.diagonal; easing.type: root.sideMenu ? Motion.menuSlideCurve : Motion.diagonalCurve }
        },
        Transition {
            from: "open"
            NumberAnimation { property: "prog"; duration: root.sideMenu ? Motion.menuSlide : Motion.diagonal; easing.type: root.sideMenu ? Motion.menuSlideCurve : Motion.diagonalCurve }
        }
    ]

    Loader {
        id: body
        width: root.openW
        height: root.openH
        sourceComponent: root.kind === "power" ? powerBody
            : root.kind === "voice" ? voiceBody
            : root.kind === "keyring" ? keyringBody
            : root.kind === "stash" ? stashBody
            : root.kind === "system" ? systemBody
            : root.record && root.record.id === "screenshare" ? screenshareBody
            : menuBody
    }

    Component {
        id: menuBody
        MenuColumn {
            width: root.openW
            height: root.openH
            scale: root.bodyScale
            open: root.effectiveOpen
            widgets: root.widgetIds
            onRequestClose: root.requestClose()
        }
    }
    Component {
        id: screenshareBody
        MenuScreenshare {
            width: root.openW
            height: root.openH
            s: root.bodyScale
            open: root.effectiveOpen
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
            monitorName: root.manager ? root.manager.monitorName : ""
            surfaceId: root.record ? root.record.id : ""
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
