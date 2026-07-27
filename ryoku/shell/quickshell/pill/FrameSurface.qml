pragma ComponentBehavior: Bound

import QtQuick
import "popouts"
import "Singletons"

// One Ryoku-own surface (power, voice, keyring, stash sidebar, system sidebar)
// riding the shared Popout. These are NOT the reference frame menus: they keep
// the trigger-centred, monitor-scaled Popout behaviour so their content
// (wallpaper hero, dictation overlay, password prompt, sidebars) renders as
// built. Openness is owned by FrameMenuManager (menuOpen); the manager reads
// maskX/Y/W/H off this item to union the body into the overlay input mask.
//
// This is the pass's one remaining frame-chrome blob user: the reference menus
// moved to the crisp composite-hole FrameChrome band, these surfaces have not.
Popout {
    id: root

    property var record: null
    property string anchor: "top"
    property bool menuOpen: false
    property var manager: null
    // The trigger centre the manager derives for the surface (its owning bar
    // widget or the screen centre for an IPC open).
    property real triggerAlong: -1

    signal requestClose()

    readonly property real fallbackMinWidth: 200
    readonly property real minWidth: record && record.minWidth ? record.minWidth : fallbackMinWidth
    readonly property string kind: record && record.kind ? record.kind : "power"
    // stays true through the close melt so the body tears down only once flush.
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
    alongCenter: root.triggerAlong

    // Surfaces size to their content at the monitor UI scale (unlike the fixed
    // reference-pixel menus). A full-span sidebar fills the frame top-to-bottom.
    openW: Math.max(root.minWidth * root.s, body.item ? body.item.implicitWidth : 0)
    openH: root.fullSpan ? root.height : (body.item ? body.item.implicitHeight : 0)

    readonly property bool sideMenu: root.edge === "left" || root.edge === "right"

    // Reveal envelope: side surfaces slide (menuSlide, 250 ms ease-out-cubic),
    // top/bottom surfaces grow diagonally (diagonal, 200 ms ease-in-out-quad),
    // matching the frame menus. A re-trigger retargets prog from its current
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
            : systemBody
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
