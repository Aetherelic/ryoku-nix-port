pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../services"
import "framebars/RailGeometry.js" as RailGeometry

// One monitor's frame bar. It maps four exclusive-zone background surfaces that
// reserve the revealed bar's thickness (so tiled windows clear the rails) and a
// full-screen transparent overlay that hosts the painted frame chrome plus the
// rail widgets. Reveal binds to this monitor's ShellState: the bar toggle
// shortcut flips ShellState.barRevealed and each edge then follows its Config
// reveal flag, so the resting desktop shows exactly the configured edges. Frame
// menus and popouts (FrameMenuManager, FrameSurface) are a later migration
// phase, so the rails emit their menu and surface intents with no consumer yet.
Scope {
    id: root

    // The screen this frame bar draws on, injected by the per-screen Variants in
    // shell.qml; null only for the instant before that binding lands.
    property var modelData: null

    readonly property real frameBorderPx: Config.frameThickness

    // The built-in Sumi frame scene draws only while the active bar style is the
    // built-in one; a receipt-owned style would load its own scene without rails.
    readonly property bool sumiActive: BarProducts.sceneUrl(Config.barStyle) === ""

    readonly property var state: root.modelData ? ShellState.forScreen(root.modelData) : null
    readonly property bool revealed: root.state ? root.state.barRevealed : true

    // The frame bar's rail-action handler. Session-confirm actions
    // (logout/reboot/shutdown) route through the confirmation dialog, which
    // migrates in a later phase, so they stay inert here.
    function runBarAction(id) {
        switch (id) {
        case "lock": Quickshell.execDetached(["ryoku-shell", "lock"]); break;
        case "screenshot": Quickshell.execDetached(["sh", "-c", "flock -n -o /tmp/ryoshot.lock qs -c ryoshot"]); break;
        case "wallpaper": Quickshell.execDetached(["ryoku-shell", "wallpaper-switcher"]); break;
        case "color-picker": Quickshell.execDetached(["ryoku-cmd-color-picker"]); break;
        case "app-launcher": Quickshell.execDetached(["ryoku-shell", "launcher"]); break;
        default: return;
        }
    }

    // Whether an edge's bar is revealed: this monitor's master reveal gated by
    // that edge's Config reveal flag. A hidden bar still reveals on hover, which
    // FrameRail handles from its own 1px strip.
    function edgeRevealed(edge) {
        if (!root.revealed)
            return false;
        const rail = Config.normalizedFrameBars.rails[edge];
        return !!(rail && rail.reveal);
    }

    function railHasWidgets(rail, edge) {
        if (!rail)
            return false;
        const zs = (edge === "top" || edge === "bottom") ? ["start", "center", "end"] : ["top", "center", "bottom"];
        for (let i = 0; i < zs.length; ++i)
            if (Array.isArray(rail[zs[i]]) && rail[zs[i]].length > 0)
                return true;
        return false;
    }

    // The exclusive zone an edge reserves: the bar band plus the frame border
    // when the edge is revealed and holds widgets, else a 1px lip, so a hidden or
    // empty edge releases its screen space.
    function edgeReserve(edge) {
        const rail = Config.normalizedFrameBars.rails[edge];
        if (!rail)
            return 0;
        if (!root.edgeRevealed(edge))
            return 1;
        return ((rail.enabled && root.railHasWidgets(rail, edge)) ? rail.size : 1) + root.frameBorderPx;
    }

    // Four background reservation surfaces, mapped top, bottom, left, right in
    // that fixed order so the horizontal edges own the shared corners.
    FrameEdge { edge: "top";    screen: root.modelData; reserve: root.sumiActive ? root.edgeReserve("top") : 0 }
    FrameEdge { edge: "bottom"; screen: root.modelData; reserve: root.sumiActive ? root.edgeReserve("bottom") : 0 }
    FrameEdge { edge: "left";   screen: root.modelData; reserve: root.sumiActive ? root.edgeReserve("left") : 0 }
    FrameEdge { edge: "right";  screen: root.modelData; reserve: root.sumiActive ? root.edgeReserve("right") : 0 }

    PanelWindow {
        id: overlay

        readonly property real s: (root.modelData ? root.modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))
        readonly property var frameBars: Config.normalizedFrameBars
        readonly property var rails: overlay.frameBars.rails
        readonly property var edgeReveal: ({
            top: root.edgeRevealed("top"),
            bottom: root.edgeRevealed("bottom"),
            left: root.edgeRevealed("left"),
            right: root.edgeRevealed("right")
        })
        readonly property var topRailRect: RailGeometry.edgeRect("top", overlay.railThickness("top"), width, height)
        readonly property var leftRailRect: RailGeometry.edgeRect("left", overlay.railThickness("left"), width, height)
        readonly property var bottomRailRect: RailGeometry.edgeRect("bottom", overlay.railThickness("bottom"), width, height)
        readonly property var rightRailRect: RailGeometry.edgeRect("right", overlay.railThickness("right"), width, height)
        function railRecord(edge) { return overlay.rails[edge] || ({ size: 0, enabled: false }); }
        function railThickness(edge) { return Math.max(0, root.edgeReserve(edge) - root.frameBorderPx); }
        function railEnabled(edge) { return overlay.railRecord(edge).enabled === true; }

        // True when this monitor's active workspace holds a fullscreen window;
        // the frame then unmaps its input and hides so the window is unobstructed.
        readonly property bool monFullscreen: {
            if (!root.modelData)
                return false;
            const mons = Hyprland.monitors.values;
            for (let i = 0; i < mons.length; i++)
                if (mons[i].name === root.modelData.name)
                    return mons[i].activeWorkspace ? (Fullscreen.byWs[mons[i].activeWorkspace.id] === true) : false;
            return false;
        }

        screen: root.modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ryoku-frame"
        anchors { top: true; left: true; right: true; bottom: true }

        // Input catches only the drawn rails and a 1px hover strip per enabled
        // edge (so a hidden bar can still be revealed by pointer proximity);
        // everything else clicks through to the desktop.
        mask: overlay.monFullscreen ? hiddenRegion : railRegion

        Region { id: hiddenRegion }
        Region {
            id: railRegion
            Region { x: overlay.topRailRect.x; y: overlay.topRailRect.y; width: overlay.railEnabled("top") ? overlay.topRailRect.width : 0; height: overlay.railEnabled("top") ? overlay.topRailRect.height : 0 }
            Region { x: overlay.leftRailRect.x; y: overlay.leftRailRect.y; width: overlay.railEnabled("left") ? overlay.leftRailRect.width : 0; height: overlay.railEnabled("left") ? overlay.leftRailRect.height : 0 }
            Region { x: overlay.bottomRailRect.x; y: overlay.bottomRailRect.y; width: overlay.railEnabled("bottom") ? overlay.bottomRailRect.width : 0; height: overlay.railEnabled("bottom") ? overlay.bottomRailRect.height : 0 }
            Region { x: overlay.rightRailRect.x; y: overlay.rightRailRect.y; width: overlay.railEnabled("right") ? overlay.rightRailRect.width : 0; height: overlay.railEnabled("right") ? overlay.rightRailRect.height : 0 }
            Region { x: 0; y: 0; width: overlay.railEnabled("top") ? overlay.width : 0; height: overlay.railEnabled("top") ? 1 : 0 }
            Region { x: 0; y: overlay.height - 1; width: overlay.railEnabled("bottom") ? overlay.width : 0; height: overlay.railEnabled("bottom") ? 1 : 0 }
            Region { x: 0; y: 0; width: overlay.railEnabled("left") ? 1 : 0; height: overlay.railEnabled("left") ? overlay.height : 0 }
            Region { x: overlay.width - 1; y: 0; width: overlay.railEnabled("right") ? 1 : 0; height: overlay.railEnabled("right") ? overlay.height : 0 }
        }

        FrameChrome {
            anchors.fill: parent
            reserveTop: root.sumiActive ? root.edgeReserve("top") : root.frameBorderPx
            reserveBottom: root.sumiActive ? root.edgeReserve("bottom") : root.frameBorderPx
            reserveLeft: root.sumiActive ? root.edgeReserve("left") : root.frameBorderPx
            reserveRight: root.sumiActive ? root.edgeReserve("right") : root.frameBorderPx
            holeRadius: Config.frameCorner
            surface: Theme.surface
            outline: Theme.outline
            strokeWidth: Theme.borderWidth
            opacity: Theme.windowOpacity
            visible: !overlay.monFullscreen && Config.frameEnabled && root.sumiActive
        }

        Bar {
            id: frameRails
            anchors.fill: parent
            z: 1
            visible: !overlay.monFullscreen && root.sumiActive
            railScale: 1
            revealState: overlay.edgeReveal
            frameBars: overlay.frameBars
            style: ({})
            onActionRequested: id => root.runBarAction(id)
        }
    }
}
