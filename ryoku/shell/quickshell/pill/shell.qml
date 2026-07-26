//@ pragma UseQApplication
// threaded render loop: the blob melt is a per-frame spring (plugin/blobrect.cpp)
// plus scene-graph animations; threaded is vsync-locked and frees the GUI thread, so
// the spring gets regular frame deltas and never stutters behind layout/JS. (basic
// idled ~5% cheaper on NVIDIA with the island's live MultiEffects in the scene, but
// smoothness wins and blobs snap to rest when idle.)
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Ryoku.Blobs
import Ryoku.Ui
import "Singletons"
import "framebars/RailGeometry.js" as RailGeometry

// Per monitor the shell maps exclusive-zone frame rails, a
// full-screen transparent overlay for the frame and retained surfaces, and the
// standalone volume/brightness OSD. The overlay mask catches only the bar and
// active surfaces; all other clicks pass through.
ShellRoot {
    id: root
    signal menuRequested(string id, rect ownerRect)
    signal surfaceRequested(string id, rect ownerRect)
    signal actionRequested(string id)
    signal surfaceRequestedForMonitor(string id, string monitor, var context)
    signal surfaceCloseRequested(string id, string monitor)
    signal barMenuRequested(string monitor, string id)
    signal keyringPromptChanged(int promptId)

    function runBarAction(id, mon) {
        switch (id) {
        case "lock": Quickshell.execDetached(["ryoku-shell", "lock"]); break;
        // logout / reboot / shutdown confirm first (contract 13 sec 2c); the
        // action runs from the confirmation dialog, never straight off the click.
        case "logout":
        case "reboot":
        case "shutdown": root.askSessionAction(id, mon); return;
        case "screenshot": Quickshell.execDetached(["sh", "-c", "flock -n -o /tmp/ryoshot.lock qs -c ryoshot"]); break;
        case "wallpaper": Quickshell.execDetached(["ryoku-shell", "wallpaper-switcher"]); break;
        case "color-picker": Quickshell.execDetached(["ryoku-cmd-color-picker"]); break;
        case "app-launcher": Quickshell.execDetached(["ryoku-shell", "launcher"]); break;
        default: return;
        }
        root.actionRequested(id);
    }

    // Session-action confirmation (contract 13 sec 2c, 8). A frame-bar
    // logout/reboot/shutdown click asks for confirmation on its own monitor; the
    // RyokuConfirmationDialog runs the action (SessionActions -> the daemon) only
    // when the positive button is pressed. The shutdown copy is corrected here:
    // the reference shutdown dialog wrongly asks "log out" / "Logout" (a source
    // copy-paste that still powers off); Ryoku asks "shut down" / "Shutdown".
    property string sessionAction: ""            // "" | "logout" | "reboot" | "shutdown"
    property string sessionActionMonitor: ""
    readonly property var sessionCopy: ({
        "logout":   { message: "Are you sure you want to log out?",  positive: "Logout" },
        "reboot":   { message: "Are you sure you want to reboot?",   positive: "Reboot" },
        "shutdown": { message: "Are you sure you want to shut down?", positive: "Shutdown" }
    })
    readonly property string sessionMessage: root.sessionAction !== "" ? root.sessionCopy[root.sessionAction].message : ""
    readonly property string sessionPositive: root.sessionAction !== "" ? root.sessionCopy[root.sessionAction].positive : ""

    function askSessionAction(id, mon) {
        root.sessionActionMonitor = (mon && mon !== "") ? mon
            : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
        root.sessionAction = id;
    }
    function clearSessionAction() {
        root.sessionAction = "";
        root.sessionActionMonitor = "";
    }

    // --- Frame reservation model (contracts 01 and 02) ---------------------
    // The single ryoku-frame overlay hosts every bar and menu as content. Four
    // ryoku-frame-edge background surfaces reserve screen space, one per edge,
    // so tiled windows clear the revealed bars. Reserve = the bar's thickness
    // (its widgets' fixed band, or a 1px collapsed strip when the bar is empty)
    // plus the frame border. A hidden bar reserves nothing and releases its
    // edge; hover reveals a hidden bar inside the frame without re-reserving.
    readonly property real frameBorderPx: Theme.borderWidth
    property var edgeRevealed: ({ top: false, bottom: false, left: false, right: false })
    function railHasWidgets(rail, edge) {
        if (!rail)
            return false;
        const zs = (edge === "top" || edge === "bottom") ? ["start", "center", "end"] : ["top", "center", "bottom"];
        for (let i = 0; i < zs.length; ++i)
            if (Array.isArray(rail[zs[i]]) && rail[zs[i]].length > 0)
                return true;
        return false;
    }
    function edgeReserve(edge) {
        const rail = Config.normalizedFrameBars.rails[edge];
        if (!rail || !root.edgeRevealed[edge])
            return 0;
        return (root.railHasWidgets(rail, edge) ? rail.size : 1) + root.frameBorderPx;
    }
    // CLI/daemon bar control (ryoku-shell bar <edge|all> <toggle|reveal|hide>).
    // A hidden bar drops its edge reserve; the frame overlay stays mapped.
    function setBar(edge, action) {
        const edges = edge === "all" ? ["top", "bottom", "left", "right"] : [edge];
        const next = Object.assign({}, root.edgeRevealed);
        for (let i = 0; i < edges.length; ++i) {
            const e = edges[i];
            if (next[e] === undefined)
                continue;
            next[e] = action === "toggle" ? !next[e]
                : action === "reveal" ? true
                : action === "hide" ? false
                : next[e];
        }
        root.edgeRevealed = next;
    }


    function refresh() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: {
        refresh();
        Devices.restore();
        // re-arm the durable idle inhibitor for the persisted flag. on a
        // shell reload the external inhibitor is usually still up (lives
        // outside this process), so "start" = idempotent confirm; "stop"
        // clears a stray when Keep-Awake is off.
        root.syncCaffeine(Flags.keepAwake ? "start" : "stop");
        // re-assert Game Mode if it persisted on. relogin brings Hyprland
        // up fresh from the lua config, so the compositor tuning has to be
        // re-applied (start is idempotent and preserves the saved WiFi
        // value). only "start", never "stop": a reload is expensive and the
        // desktop already sits in its normal config when game mode is off.
        if (Flags.gameMode)
            root.syncGameMode("start");
    }

    Binding {
        target: Notifs
        property: "dnd"
        value: Flags.dnd
    }

    PanelWindow {
        id: inhibitWin
        visible: Flags.keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "ryoku-frame-inhibit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        IdleInhibitor { window: inhibitWin; enabled: Flags.keepAwake }
    }

    // keyboard-return bounce. the pill overlay never unmaps, and dropping an
    // Exclusive grab on a mapped layer strands the keyboard (the window looks
    // active but can't type; focus dispatches don't recover it). this 1x1 helper
    // takes the grab and unmaps, which makes Hyprland hand the keyboard back.
    property bool kbBounce: false
    Timer {
        id: kbBounceTimer
        interval: 90
        onTriggered: root.kbBounce = false
    }
    PanelWindow {
        id: kbBounceWin
        visible: root.kbBounce
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ryoku-frame-kbfocus"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; left: true }
    }

    // Keep-Awake's durable inhibitor lives outside the shell so it survives
    // a reload/restart. ryoku-cmd-caffeine runs systemd-inhibit via
    // systemd-run (setsid fallback), independent of our lifetime. the
    // Wayland IdleInhibitor above only gives compositor-level effect and
    // dies with the pill on every respawn; this bridge keeps Keep-Awake
    // unbroken across the swap. every surface toggle just flips
    // Flags.keepAwake.
    readonly property string caffeineScript: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-caffeine"

    function syncCaffeine(action) {
        Quickshell.execDetached([root.caffeineScript, action]);
    }

    Connections {
        target: Flags
        function onKeepAwakeChanged() {
            root.syncCaffeine(Flags.keepAwake ? "start" : "stop");
        }
    }

    // game mode's compositor + WiFi tuning lives outside the shell, same
    // shape as Keep-Awake. ryoku-cmd-game-mode drives hyprctl and
    // NetworkManager so the tuning survives a shell reload and re-applies
    // after a relogin. DND is the shell's own (handled in Flags); deck
    // toggle just flips Flags.gameMode.
    readonly property string gameModeScript: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-game-mode"

    function syncGameMode(action) {
        Quickshell.execDetached([root.gameModeScript, action]);
    }

    Connections {
        target: Flags
        function onGameModeChanged() {
            root.syncGameMode(Flags.gameMode ? "start" : "stop");
        }
    }

    // only these raw events change what the pill renders (per-monitor
    // active workspace, minimized toplevels, monitor hotplug). everything
    // else (window drags, resizes, title spam) MUST NOT trigger the triple
    // model refresh: three Hyprland IPC round-trips a pop.
    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // a workspace switch fires several whitelisted events at once;
            // Qt.callLater dedups them to one refresh (three IPC calls) per turn.
            if (root.refreshEvents[event.name])
                Qt.callLater(root.refresh);
        }
    }

    // pulse the kbBounce helper so a dismissed keyboard popout hands the keyboard back.
    function restoreFocus() {
        root.kbBounce = true;
        kbBounceTimer.restart();
    }

    FrameSurfaceLifecycle {
        id: surfaceLifecycle
        keyring: Keyring
        onFocusRestored: root.restoreFocus()
    }


    Connections {
        target: Stash
        function onAuthStepAside(mon, id) { root.surfaceCloseRequested(id, mon); }
    }

    function requestSurface(id, mon, context) {
        root.surfaceRequestedForMonitor(id, mon, context);
    }

    IpcHandler {
        target: "pill"
        function openSurface(mon: string, id: string): void { root.requestSurface(id, mon); }
        function closeSurface(mon: string, id: string): void { root.surfaceCloseRequested(id, mon); }
        function power(mon: string): void { root.requestSurface("power", mon); }
        function keyringPrompt(payload: string): void {
            Keyring.apply(payload);
            root.keyringPromptChanged(Keyring.promptId);
            root.requestSurface("keyring", Keyring.mon !== "" ? Keyring.mon
                : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""),
                { promptId: Keyring.promptId });
        }
        function keyringHide(): void {
            Keyring.clear();
            root.surfaceCloseRequested("keyring", "");
        }
        function voiceShow(mon: string): void { root.requestSurface("voice", mon); }
        function voiceOff(mon: string): void { root.requestSurface("voice-off", mon); }
        function voiceHide(): void { root.surfaceCloseRequested("voice", ""); }
        function pluginPopout(mon: string, id: string): void { root.requestSurface("plugin:" + id, mon); }
        function bar(mon: string, id: string): void { root.requestSurface(id, mon); }
        function closeAllMenus(mon: string): void { root.surfaceCloseRequested("", mon); }
        function setBar(mon: string, edge: string, action: string): void { root.setBar(edge, action); }
        function sessionConfirm(mon: string, action: string): void { root.askSessionAction(action, mon); }
    }

    // The daemon writes surface commands to this socket to toggle pill surfaces
    // without spawning a `qs ipc call` client on the keybind hot path. The pill
    // is a persistent component, so the socket is up whenever the daemon needs
    // it; a miss makes the daemon fall back to the qs client.
    readonly property string pillSockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-pill.sock"

    // runPillCommand mirrors the IpcHandler above for the socket fast path:
    function runPillCommand(line) {
        var parts = line.trim().split(" ");
        var fn = parts[0];
        var mon = parts.length > 1 ? parts[1] : "";
        var id = parts.length > 2 ? parts[2] : "";
        switch (fn) {
        case "openSurface":
            root.requestSurface(id, mon); return true;
        case "closeSurface":
            root.surfaceCloseRequested(id, mon); return true;
        case "power":
            root.requestSurface("power", mon); return true;
        case "pluginPopout":
            root.requestSurface("plugin:" + id, mon); return true;
        case "voiceShow":
            root.requestSurface("voice", mon); return true;
        case "voiceOff":
            root.requestSurface("voice-off", mon); return true;
        case "voiceHide":
            root.surfaceCloseRequested("voice", mon); return true;
        case "bar":
            root.requestSurface(id, mon); return true;
        case "closeAllMenus":
            root.surfaceCloseRequested("", mon); return true;
        case "setBar":
            root.setBar(id, parts.length > 3 ? parts[3] : ""); return true;
        default:
            return false;
        }
    }

    SocketServer {
        active: true
        path: root.pillSockPath
        handler: Socket {
            id: cmdSock
            parser: SplitParser {
                onRead: line => cmdSock.write((root.runPillCommand(line) ? "ok" : "err") + "\n")
            }
        }
    }

    // Bars configured reveal-by-default slide in 1000 ms after startup
    // (contract 02 sec 3); until then every edge is collapsed and reserves
    // nothing. reduce->0 makes the reveal instant.
    Timer {
        interval: Motion.startupReveal
        running: true
        repeat: false
        onTriggered: {
            const rails = Config.normalizedFrameBars.rails;
            const next = ({ top: false, bottom: false, left: false, right: false });
            for (const e in next)
                next[e] = !!(rails[e] && rails[e].reveal);
            root.edgeRevealed = next;
        }
    }

    // ryoku-frame-root: a 1x1 background anchor pinned to the frame's inner
    // corner (it reserves nothing, so the edge reservations push it inward). It
    // draws nothing and takes no input; it mirrors the reference's hidden root
    // that holds shared state, kept so the layer topology matches.
    PanelWindow {
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "ryoku-frame-root"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        mask: Region {}
    }

    // Four ryoku-frame-edge background surfaces, one per edge per screen. They
    // reserve screen space equal to the revealed bar's thickness plus the frame
    // border and take no input; the bars and menus are drawn in the overlay
    // below. A hidden bar reserves nothing, releasing its edge.
    Variants {
        model: Quickshell.screens
        FrameEdge {
            required property var modelData
            edge: "top"
            screen: modelData
            reserve: root.edgeReserve("top")
        }
    }
    Variants {
        model: Quickshell.screens
        FrameEdge {
            required property var modelData
            edge: "bottom"
            screen: modelData
            reserve: root.edgeReserve("bottom")
        }
    }
    Variants {
        model: Quickshell.screens
        FrameEdge {
            required property var modelData
            edge: "left"
            screen: modelData
            reserve: root.edgeReserve("left")
        }
    }
    Variants {
        model: Quickshell.screens
        FrameEdge {
            required property var modelData
            edge: "right"
            screen: modelData
            reserve: root.edgeReserve("right")
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))

            readonly property var frameBars: Config.normalizedFrameBars
            // Read through `overlay.` and keep the rail host's id distinct: an id
            // shadows a same-named property in this scope, which once left every
            // rail rect at zero and swallowed all bar input.
            readonly property var rails: overlay.frameBars.rails
            readonly property real frameLip: root.frameBorderPx
            readonly property real sidebarTopGap: railClearance("top") + 14 * s
            readonly property real sidebarBotGap: railClearance("bottom") + 14 * s
            readonly property var topRailRect: RailGeometry.edgeRect("top", railThickness("top"), width, height)
            readonly property var leftRailRect: RailGeometry.edgeRect("left", railThickness("left"), width, height)
            readonly property var bottomRailRect: RailGeometry.edgeRect("bottom", railThickness("bottom"), width, height)
            readonly property var rightRailRect: RailGeometry.edgeRect("right", railThickness("right"), width, height)
            function railRecord(edge) { return rails[edge] || ({ size: 0, enabled: false }); }
            function railThickness(edge) { return Math.max(0, root.edgeReserve(edge) - root.frameBorderPx); }
            function railEnabled(edge) { return railRecord(edge).enabled === true; }
            function railClearance(edge) {
                const reserve = root.edgeReserve(edge);
                return reserve > 0 ? reserve : frameLip;
            }

            readonly property bool surfaceModal: frameMenus.surfaceModal

            // true when this monitor's visible workspace holds a fullscreen
            // window. Fullscreen owns the id -> fullscreen map (hyprctl-backed,
            // fork-proof); the monitor -> active workspace hop stays event-driven.
            readonly property bool monFullscreen: {
                var mons = Hyprland.monitors.values;
                for (var i = 0; i < mons.length; i++)
                    if (mons[i].name === modelData.name)
                        return mons[i].activeWorkspace ? (Fullscreen.byWs[mons[i].activeWorkspace.id] === true) : false;
                return false;
            }

            onMonFullscreenChanged: if (monFullscreen) frameMenus.closeAll()

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: frameMenus.keyboardMode === "exclusive" ? WlrKeyboardFocus.Exclusive
                : frameMenus.keyboardMode === "ondemand" ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None
            WlrLayershell.namespace: "ryoku-frame"

            anchors { top: true; left: true; right: true; bottom: true }

            // recHud.dragging widens the mask to the whole surface: the island
            // clamps at the frame lips, so the pointer can slide off its rect
            // mid-drag; losing the region there kills the grab and the island
            // snaps home while the button is still held.
            mask: monFullscreen ? hiddenRegion
                : ((surfaceModal || recHud.dragging) ? fullRegion : railRegion)

            function inRail(x, y) {
                const edges = ["top", "left", "bottom", "right"];
                for (let i = 0; i < edges.length; i++) {
                    const edge = edges[i];
                    const rect = RailGeometry.edgeRect(edge, railThickness(edge), width, height);
                    if (railEnabled(edge) && x >= rect.x && x < rect.x + rect.width
                            && y >= rect.y && y < rect.y + rect.height)
                        return true;
                }
                return false;
            }
            Region { id: hiddenRegion }
            Region {
                id: fullRegion
                width: overlay.width
                height: overlay.height
            }
            Region {
                id: railRegion
                Region { x: overlay.topRailRect.x; y: overlay.topRailRect.y; width: overlay.railEnabled("top") ? overlay.topRailRect.width : 0; height: overlay.railEnabled("top") ? overlay.topRailRect.height : 0 }
                Region { x: overlay.leftRailRect.x; y: overlay.leftRailRect.y; width: overlay.railEnabled("left") ? overlay.leftRailRect.width : 0; height: overlay.railEnabled("left") ? overlay.leftRailRect.height : 0 }
                Region { x: overlay.bottomRailRect.x; y: overlay.bottomRailRect.y; width: overlay.railEnabled("bottom") ? overlay.bottomRailRect.width : 0; height: overlay.railEnabled("bottom") ? overlay.bottomRailRect.height : 0 }
                Region { x: overlay.rightRailRect.x; y: overlay.rightRailRect.y; width: overlay.railEnabled("right") ? overlay.rightRailRect.width : 0; height: overlay.railEnabled("right") ? overlay.rightRailRect.height : 0 }
                // 1px hover strips at each screen edge, always exposed so a
                // hidden bar (reserve released, band mask gone) can still be
                // revealed by pointer proximity (contract 02 sec 4).
                Region { x: 0; y: 0; width: overlay.railEnabled("top") ? overlay.width : 0; height: overlay.railEnabled("top") ? 1 : 0 }
                Region { x: 0; y: overlay.height - 1; width: overlay.railEnabled("bottom") ? overlay.width : 0; height: overlay.railEnabled("bottom") ? 1 : 0 }
                Region { x: 0; y: 0; width: overlay.railEnabled("left") ? 1 : 0; height: overlay.railEnabled("left") ? overlay.height : 0 }
                Region { x: overlay.width - 1; y: 0; width: overlay.railEnabled("right") ? 1 : 0; height: overlay.railEnabled("right") ? overlay.height : 0 }
                // frame menus: each open menu unions its trigger (owner) and body
                // rects so the click target and the open body keep catching input;
                // idle anchors stay zero-size and click through.
                Region { x: frameMenus.masks["top"].tx; y: frameMenus.masks["top"].ty; width: frameMenus.masks["top"].tw; height: frameMenus.masks["top"].th }
                Region { x: frameMenus.masks["top"].bx; y: frameMenus.masks["top"].by; width: frameMenus.masks["top"].bw; height: frameMenus.masks["top"].bh }
                Region { x: frameMenus.masks["top-left"].tx; y: frameMenus.masks["top-left"].ty; width: frameMenus.masks["top-left"].tw; height: frameMenus.masks["top-left"].th }
                Region { x: frameMenus.masks["top-left"].bx; y: frameMenus.masks["top-left"].by; width: frameMenus.masks["top-left"].bw; height: frameMenus.masks["top-left"].bh }
                Region { x: frameMenus.masks["top-right"].tx; y: frameMenus.masks["top-right"].ty; width: frameMenus.masks["top-right"].tw; height: frameMenus.masks["top-right"].th }
                Region { x: frameMenus.masks["top-right"].bx; y: frameMenus.masks["top-right"].by; width: frameMenus.masks["top-right"].bw; height: frameMenus.masks["top-right"].bh }
                Region { x: frameMenus.masks["left"].tx; y: frameMenus.masks["left"].ty; width: frameMenus.masks["left"].tw; height: frameMenus.masks["left"].th }
                Region { x: frameMenus.masks["left"].bx; y: frameMenus.masks["left"].by; width: frameMenus.masks["left"].bw; height: frameMenus.masks["left"].bh }
                Region { x: frameMenus.masks["right"].tx; y: frameMenus.masks["right"].ty; width: frameMenus.masks["right"].tw; height: frameMenus.masks["right"].th }
                Region { x: frameMenus.masks["right"].bx; y: frameMenus.masks["right"].by; width: frameMenus.masks["right"].bw; height: frameMenus.masks["right"].bh }
                Region { x: frameMenus.masks["bottom"].tx; y: frameMenus.masks["bottom"].ty; width: frameMenus.masks["bottom"].tw; height: frameMenus.masks["bottom"].th }
                Region { x: frameMenus.masks["bottom"].bx; y: frameMenus.masks["bottom"].by; width: frameMenus.masks["bottom"].bw; height: frameMenus.masks["bottom"].bh }
                Region { x: frameMenus.masks["bottom-left"].tx; y: frameMenus.masks["bottom-left"].ty; width: frameMenus.masks["bottom-left"].tw; height: frameMenus.masks["bottom-left"].th }
                Region { x: frameMenus.masks["bottom-left"].bx; y: frameMenus.masks["bottom-left"].by; width: frameMenus.masks["bottom-left"].bw; height: frameMenus.masks["bottom-left"].bh }
                Region { x: frameMenus.masks["bottom-right"].tx; y: frameMenus.masks["bottom-right"].ty; width: frameMenus.masks["bottom-right"].tw; height: frameMenus.masks["bottom-right"].th }
                Region { x: frameMenus.masks["bottom-right"].bx; y: frameMenus.masks["bottom-right"].by; width: frameMenus.masks["bottom-right"].bw; height: frameMenus.masks["bottom-right"].bh }
                Region { x: recHud.hudX; y: recHud.hudY; width: ((Recorder.anyActive || Recorder.chooserOpen) && recHud.prog > 0.25) ? recHud.hudW : 0; height: ((Recorder.anyActive || Recorder.chooserOpen) && recHud.prog > 0.25) ? recHud.hudH : 0 }
                Region { x: recHud.trigX; y: recHud.trigY; width: Recorder.anyActive ? recHud.trigW : 0; height: Recorder.anyActive ? recHud.trigH : 0 }
            }

            MouseArea {
                anchors.fill: parent
                enabled: overlay.surfaceModal
                acceptedButtons: Qt.AllButtons
                onPressed: mouse => {
                    if (!overlay.inRail(mouse.x, mouse.y)) frameMenus.closeAll();
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: frameMenus.anyOpen
                visible: !overlay.monFullscreen
                Keys.onEscapePressed: if (frameMenus.keyboardMode === "exclusive") frameMenus.closeAll()

                // frame and pill share one blob field, so the pill reads
                // as the frame swelling open at top-centre, not a bar on top.
                BlobGroup {
                    id: blobGroup
                    color: Theme.surface
                    borderColor: Theme.outline
                    borderWidth: Theme.borderWidth
                    smoothing: Config.frameSmoothing
                    shadowStrength: Config.shadowStrength
                    shadowSize: Config.shadowSize
                }

                BlobInvertedRect {
                    // The painted frame band: one continuous inverted-rect over
                    // the whole surface, per-edge thickness = that edge's reserve
                    // (bar band + border), inner corners rounded at radiusWindow.
                    // Menus notch inward by growing a body into the same blob
                    // field. This is the single paint pass of contract 01 sec 2b.
                    anchors.fill: parent
                    group: blobGroup
                    radius: Theme.radiusWindow
                    borderTop: root.edgeReserve("top")
                    borderBottom: root.edgeReserve("bottom")
                    borderLeft: root.edgeReserve("left")
                    borderRight: root.edgeReserve("right")
                    opacity: Theme.windowOpacity
                    visible: !overlay.monFullscreen && Config.frameEnabled
                }


                Bar {
                    id: frameRails
                    anchors.fill: parent
                    z: 1
                    visible: !overlay.monFullscreen
                    // Fixed reference px: the frame does not scale with the
                    // monitor or fontScale, so the bar band matches the reserve.
                    railScale: 1
                    revealState: root.edgeRevealed
                    frameBars: overlay.frameBars
                    style: ({ group: blobGroup })
                    onMenuRequested: (id, ownerRect) => root.menuRequested(id, ownerRect)
                    onSurfaceRequested: (id, ownerRect) => root.surfaceRequested(id, ownerRect)
                    onActionRequested: id => root.runBarAction(id, overlay.modelData.name)
                }

                // per-monitor frame menu manager: a bar widget asks for a menu via
                // root.menuRequested; only the owning monitor's manager opens it on
                // the shared Popout scene. The backdrop press above dismisses a
                // click outside, and Escape closes through the FocusScope.
                FrameMenuManager {
                    id: frameMenus
                    // Above the rails: a surface grows out of a rail and must
                    // cover it, or the rail chrome clips the body's first rows.
                    z: 2
                    monitorName: overlay.modelData.name
                    scale: overlay.s
                    group: blobGroup
                    railClearances: ({
                        top: overlay.railClearance("top"),
                        left: overlay.railClearance("left"),
                        bottom: overlay.railClearance("bottom"),
                        right: overlay.railClearance("right")
                    })
                    active: !overlay.monFullscreen
                    sidebarTopInset: overlay.sidebarTopGap
                    sidebarBottomInset: overlay.sidebarBotGap
                    onSurfaceClosed: (id, context) => surfaceLifecycle.handleClosed(id, context)

                    Connections {
                        target: root
                        function onMenuRequested(id, ownerRect) { frameMenus.openSurface(id, ownerRect, ""); }
                        function onSurfaceRequested(id, ownerRect) { frameMenus.openSurface(id, ownerRect, ""); }
                        function onSurfaceRequestedForMonitor(id, mon, context) { frameMenus.openSurface(id, null, mon, context); }
                        function onSurfaceCloseRequested(id, mon) { frameMenus.closeSurface(id, mon); }
                        function onBarMenuRequested(mon, id) { frameMenus.openSurface(id, null, mon); }
                        function onKeyringPromptChanged(promptId) { frameMenus.retireKeyringPrompt(promptId); }
                    }
                }


                // No HyprlandFocusGrab here. A modal surface already takes the
                // layer's exclusive keyboard focus, and Hyprland clears a grab the
                // moment that focus moves to the grabbing layer: the two together
                // closed every surface a few milliseconds after it opened. The
                // full-screen mask plus the backdrop press above dismisses a click
                // outside, and Escape closes through the FocusScope.


                RecordHud {
                    id: recHud
                    group: blobGroup
                    s: overlay.s
                    smoothing: Config.frameSmoothing
                    barEdge: overlay.railEnabled("top") ? "top" : ""
                    barBand: overlay.railEnabled("top") ? overlay.railThickness("top") : 0
                }

            }
        }
    }

    // volume / brightness OSD, re-homed from the floating pill into its own
    // small bottom-centre layer window, just above the bar.
    Variants {
        model: Quickshell.screens
        OsdWindow {}
    }

    // persistent region-capture boundary shown while a region recording runs.
    Variants {
        model: Quickshell.screens
        RegionOverlay {}
    }

    // capture selection overlays (contract 09): one per output while the
    // screenshot menu is picking a region, monitor or window.
    Variants {
        model: Quickshell.screens
        CaptureOverlay {}
    }

    // Session-action confirmation dialog (contract 13 sec 2c): a ryoku-dialog
    // layer surface, one per screen but shown only on the monitor whose frame bar
    // was clicked. The positive button runs the power action through the daemon.
    Variants {
        model: Quickshell.screens
        RyokuConfirmationDialog {
            action: (root.sessionActionMonitor === modelData.name) ? root.sessionAction : ""
            message: root.sessionMessage
            positiveLabel: root.sessionPositive
            negativeLabel: "Cancel"
            onConfirmed: a => { SessionActions.run(a); root.clearSessionAction(); }
            onCancelled: root.clearSessionAction()
        }
    }

    // the self-view is a recording companion: when the last capture stops, clear
    // it so it does not linger. a plain mirror toggled on with no recording just
    // stays until toggled off (no anyActive transition to clear it).
    Connections {
        target: Recorder
        function onAnyActiveChanged() {
            if (!Recorder.anyActive)
                Camera.active = false;
        }
    }

    // draggable, shaped webcam bubble; stays across workspaces, captured by gsr.
    Variants {
        model: Quickshell.screens
        CameraOverlay {}
    }

}
