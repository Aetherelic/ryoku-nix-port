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
import "popouts"
import "framebars/RailGeometry.js" as RailGeometry

// Per monitor the shell maps an exclusive-zone strip for the atoll bar, a
// full-screen transparent overlay for the frame and retained surfaces, and the
// standalone volume/brightness OSD. The overlay mask catches only the bar and
// active surfaces; all other clicks pass through.
ShellRoot {
    id: root
    signal menuRequested(string id, rect ownerRect)
    signal surfaceRequested(string id, rect ownerRect)
    signal actionRequested(string id)
    signal barMenuRequested(string monitor, string id)

    function runBarAction(id) {
        switch (id) {
        case "lock": Quickshell.execDetached(["ryoku-shell", "lock"]); break;
        case "logout": Hyprland.dispatch("hl.dsp.exit()"); break;
        case "reboot": Quickshell.execDetached(["systemctl", "reboot"]); break;
        case "shutdown": Quickshell.execDetached(["systemctl", "poweroff"]); break;
        case "screenshot": Quickshell.execDetached(["sh", "-c", "flock -n -o /tmp/ryoshot.lock qs -c ryoshot"]); break;
        case "wallpaper": Quickshell.execDetached(["ryoku-shell", "wallpaper-switcher"]); break;
        case "color-picker": Quickshell.execDetached(["ryoku-cmd-color-picker"]); break;
        default: return;
        }
        root.actionRequested(id);
    }



    // The one pinned bar popup (power) and the monitor it belongs to. Voice,
    // keyring and plugin surfaces share the same state but open through their
    // dedicated service paths rather than from the bar.
    property string popout: ""
    property string popoutMon: ""
    property bool voiceOff: false
    // Along-axis centre of the atoll power icon. Service-driven surfaces use -1
    // so Popout centres itself on the configured edge.
    property real popoutCenter: 0
    // Sidebar pane state and content remain intact for the later opener rebuild.
    property string sidebarLeftPane: ""
    property string sidebarRightPane: ""

    // Keyring is the only surviving keyboard popout. Voice stays focus-passive;
    // sidebars remain mounted but have no entry path.
    readonly property var kbPopouts: ["keyring"]
    property string prevPopout: ""
    onPopoutChanged: {
        if (kbPopouts.indexOf(prevPopout) >= 0 && kbPopouts.indexOf(popout) < 0)
            restoreFocus();
        // dismissing the keyring popout cancels the pending prompt (a no-op if the
        // daemon already cleared it via keyringHide).
        if (prevPopout === "keyring" && popout !== "keyring")
            Keyring.dismiss();
        prevPopout = popout;
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
        WlrLayershell.namespace: "pill-inhibit"
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
        WlrLayershell.namespace: "pill-kbbounce"
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


    // a stash install hitting a sudo/polkit prompt asks the deck to step
    // aside so the prompt (a window beneath our keyboard grab) takes focus
    // instead of landing behind the open deck.
    Connections {
        target: Stash
        function onAuthStepAside() { root.popout = ""; }
    }

    // Pin or unpin a service-driven surface on one monitor.
    function togglePopout(mon, name) {
        if (root.popout === name && root.popoutMon === mon) {
            root.popout = "";
            return;
        }
        // unpin the old popout before moving the anchor: a pinned popout tracks
        // popoutCenter live, so writing the new centre first teleports the old
        // body along the bar instead of letting it melt where it opened.
        root.popout = "";
        root.popoutMon = mon;
        root.popoutCenter = -1;   // keybind/IPC: no owning icon, so centre on the bar
        root.popout = name;
    }

    // open a popout at a bar icon: record the icon's along-axis centre so the
    // blob grows from the icon on any bar edge.
    function togglePopoutAt(mon, name, center) {
        if (root.popout === name && root.popoutMon === mon) {
            root.popout = "";
            return;
        }
        root.popout = "";         // same unpin-first order as togglePopout
        root.popoutMon = mon;
        root.popoutCenter = center;
        root.popout = name;
    }



    IpcHandler {
        target: "pill"
        function power(mon: string): void { root.togglePopout(mon, "power"); }
        function keyringPrompt(payload: string): void {
            Keyring.apply(payload);
            var m = Keyring.mon !== "" ? Keyring.mon
                : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
            root.popout = "";
            root.popoutMon = m;
            root.popoutCenter = -1;
            root.popout = "keyring";
        }
        function keyringHide(): void {
            // Daemon-driven teardown (unlock resolved). clear() first so the
            // popout's dismiss path cannot cancel the resolved prompt.
            Keyring.clear();
            if (root.popout === "keyring")
                root.popout = "";
        }
        function voiceShow(mon: string): void { root.voiceOff = false; root.popout = ""; root.popoutMon = mon; root.popoutCenter = -1; root.popout = "voice"; }
        function voiceOff(mon: string): void { root.voiceOff = true; root.popout = ""; root.popoutMon = mon; root.popoutCenter = -1; root.popout = "voice"; }
        function voiceHide(): void { if (root.popout === "voice") root.popout = ""; }
        function pluginPopout(mon: string, id: string): void { root.togglePopout(mon, "plugin:" + id); }
        function bar(mon: string, id: string): void { root.barMenuRequested(mon, id); }
    }

    // The daemon writes surface commands to this socket to toggle pill surfaces
    // without spawning a `qs ipc call` client on the keybind hot path. The pill
    // is a persistent component, so the socket is up whenever the daemon needs
    // it; a miss makes the daemon fall back to the qs client.
    readonly property string pillSockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-pill.sock"

    // runPillCommand mirrors the IpcHandler above for the socket fast path:
    // "<fn> <mon> [arg]" runs the same surface toggle. Returns false on an
    // unknown command so the daemon falls back to the qs client.
    function runPillCommand(line) {
        var parts = line.trim().split(" ");
        var fn = parts[0];
        var mon = parts.length > 1 ? parts[1] : "";
        switch (fn) {
        case "power":
            root.togglePopout(mon, "power"); return true;
        case "pluginPopout":
            root.togglePopout(mon, "plugin:" + (parts.length > 2 ? parts[2] : ""));
            return true;
        case "voiceShow":
            root.voiceOff = false; root.popout = ""; root.popoutMon = mon; root.popoutCenter = -1; root.popout = "voice"; return true;
        case "voiceOff":
            root.voiceOff = true; root.popout = ""; root.popoutMon = mon; root.popoutCenter = -1; root.popout = "voice"; return true;
        case "voiceHide":
            if (root.popout === "voice") root.popout = "";
            return true;
        case "bar":
            root.barMenuRequested(mon, parts.length > 2 ? parts[2] : "");
            return true;
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))
            readonly property var rail: Config.normalizedFrameBars.rails.top
            readonly property real zone: RailGeometry.reserve("top", Math.max(0, Config.effectiveFrameBorder - 50), rail.size * s, rail.enabled)

            screen: modelData
            visible: rail.enabled
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: zone
            aboveWindows: true
            anchors { top: true; left: true; right: true }
            implicitHeight: zone
            mask: Region {}
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))
            readonly property var rail: Config.normalizedFrameBars.rails.left
            readonly property real zone: RailGeometry.reserve("left", Math.max(0, Config.effectiveFrameBorder - 50), rail.size * s, rail.enabled)

            screen: modelData
            visible: rail.enabled
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: zone
            aboveWindows: true
            anchors { top: true; bottom: true; left: true }
            implicitWidth: zone
            mask: Region {}
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))
            readonly property var rail: Config.normalizedFrameBars.rails.bottom
            readonly property real zone: RailGeometry.reserve("bottom", Math.max(0, Config.effectiveFrameBorder - 50), rail.size * s, rail.enabled)

            screen: modelData
            visible: rail.enabled
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: zone
            aboveWindows: true
            anchors { bottom: true; left: true; right: true }
            implicitHeight: zone
            mask: Region {}
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))
            readonly property var rail: Config.normalizedFrameBars.rails.right
            readonly property real zone: RailGeometry.reserve("right", Math.max(0, Config.effectiveFrameBorder - 50), rail.size * s, rail.enabled)

            screen: modelData
            visible: rail.enabled
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: zone
            aboveWindows: true
            anchors { top: true; bottom: true; right: true }
            implicitWidth: zone
            mask: Region {}
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))

            readonly property var frameBars: Config.normalizedFrameBars
            readonly property var rails: frameBars.rails
            readonly property var stashSurface: frameBars.surfaces.stash
            readonly property var systemSurface: frameBars.surfaces.system
            readonly property real frameLip: Math.max(0, Config.effectiveFrameBorder - 50)
            readonly property string popoutEdge: "top"
            readonly property real surfaceFrameThickness: frameLip + railThickness("top")
            readonly property real sidebarTopGap: railClearance("top") + 14 * s
            readonly property real sidebarBotGap: railClearance("bottom") + 14 * s
            readonly property var topRailRect: RailGeometry.edgeRect("top", railThickness("top"), width, height)
            readonly property var leftRailRect: RailGeometry.edgeRect("left", railThickness("left"), width, height)
            readonly property var bottomRailRect: RailGeometry.edgeRect("bottom", railThickness("bottom"), width, height)
            readonly property var rightRailRect: RailGeometry.edgeRect("right", railThickness("right"), width, height)
            function railThickness(edge) { return rails[edge].size * s; }
            function railEnabled(edge) { return rails[edge].enabled; }
            function railClearance(edge) {
                return railEnabled(edge)
                    ? RailGeometry.reserve(edge, frameLip, railThickness(edge), true)
                    : frameLip;
            }

            readonly property bool kbPopout: root.popoutMon === modelData.name
                && root.kbPopouts.indexOf(root.popout) >= 0
            readonly property bool modal: kbPopout

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

            onMonFullscreenChanged: if (monFullscreen) {
                if (root.popoutMon === modelData.name) root.popout = "";
            }

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            // None, not OnDemand: this layer is always mapped, so OnDemand would
            // hold the keyboard after a popout closes and a launched window can't type.
            WlrLayershell.keyboardFocus: kbPopout ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "pill"

            anchors { top: true; left: true; right: true; bottom: true }

            // recHud.dragging widens the mask to the whole surface: the island
            // clamps at the frame lips, so the pointer can slide off its rect
            // mid-drag; losing the region there kills the grab and the island
            // snaps home while the button is still held.
            mask: monFullscreen ? hiddenRegion
                : ((modal || recHud.dragging) ? fullRegion : railRegion)

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
                Region { x: powerPop.triggerX; y: powerPop.triggerY; width: powerPop.triggerW; height: powerPop.triggerH }
                Region { x: powerPop.maskX; y: powerPop.maskY; width: powerPop.maskW; height: powerPop.maskH }
                Region { x: voicePop.maskX; y: voicePop.maskY; width: voicePop.maskW; height: voicePop.maskH }
                Region { x: keyringPop.maskX; y: keyringPop.maskY; width: keyringPop.maskW; height: keyringPop.maskH }
                Region { x: pluginPops.maskTrigX; y: pluginPops.maskTrigY; width: pluginPops.maskTrigW; height: pluginPops.maskTrigH }
                Region { x: pluginPops.maskBodyX; y: pluginPops.maskBodyY; width: pluginPops.maskBodyW; height: pluginPops.maskBodyH }
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
                enabled: overlay.modal
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => {
                    if (overlay.inRail(mouse.x, mouse.y)) return;
                    if (overlay.kbPopout) root.popout = "";
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: overlay.kbPopout || frameMenus.anyOpen
                // whole shell hides while a window is fullscreen.
                visible: !overlay.monFullscreen

                Keys.onEscapePressed: {
                    if (overlay.kbPopout) root.popout = "";
                    else if (frameMenus.anyOpen) frameMenus.closeAll();
                }

                // Ryoku brand grain: one fine matte over the whole overlay -- the
                // frame, the bar, every popout, and (through the transparent body)
                // the apps behind it. Topmost so it reads on every surface; an
                // Image carries no input, so clicks still reach the chrome and the
                // windows below. Hidden on fullscreen with the rest of the scope.
                Item {
                    id: grainLayer
                    anchors.fill: parent
                    z: 10000
                    readonly property var monObj: {
                        var ms = Hyprland.monitors.values;
                        for (var i = 0; i < ms.length; i++)
                            if (ms[i] && ms[i].name === overlay.modelData.name)
                                return ms[i].lastIpcObject;
                        return null;
                    }
                    readonly property real monX: (monObj && typeof monObj.x === "number") ? monObj.x : 0
                    readonly property real monY: (monObj && typeof monObj.y === "number") ? monObj.y : 0
                    // the ryoku apps carry their own grain; cut their windows out
                    // of this overlay so they are never doubled (matched by title).
                    readonly property var holes: {
                        var out = [];
                        var tl = Hyprland.toplevels.values;
                        for (var i = 0; i < tl.length; i++) {
                            var o = tl[i] && tl[i].lastIpcObject;
                            if (!o || !o.at || !o.size || o.mapped === false) continue;
                            if (["ryovm", "ryowalls", "Ryoku Settings"].indexOf(o.title) < 0) continue;
                            out.push({ hx: o.at[0] - grainLayer.monX, hy: o.at[1] - grainLayer.monY, hw: o.size[0], hh: o.size[1] });
                        }
                        return out;
                    }
                    Grain { id: grainSrc; anchors.fill: parent; opacity: 1; visible: false }
                    Item {
                        id: grainMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Repeater {
                            model: grainLayer.holes
                            Rectangle {
                                x: modelData.hx; y: modelData.hy
                                width: modelData.hw; height: modelData.hh
                                color: "white"
                            }
                        }
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: grainSrc
                        opacity: Config.grainStrength
                        maskEnabled: grainLayer.holes.length > 0
                        maskSource: grainMask
                        maskThresholdMin: 0.5
                        maskInverted: true
                    }
                }

                // frame and pill share one blob field, so the pill reads
                // as the frame swelling open at top-centre, not a bar on top.
                BlobGroup {
                    id: blobGroup
                    color: Config.matchWallpaper ? Wallust.surface : Config.surfaceColor
                    borderColor: Wallust.border
                    borderWidth: 1.5
                    smoothing: Config.frameSmoothing
                    shadowStrength: Config.shadowStrength
                    shadowSize: Config.shadowSize
                }

                BlobInvertedRect {
                    // rounded screen border, sits in Hyprland's gaps_out
                    // ring. oversized 50px so the outer edge clips
                    // off-screen and only the inner (window) edge shows;
                    // borders grow to keep the hole at gaps_out.
                    anchors.fill: parent
                    anchors.margins: -50
                    group: blobGroup
                    radius: Config.frameEnabled ? Config.frameRadius : 0
                    borderTop: Config.effectiveFrameBorder
                    borderBottom: Config.effectiveFrameBorder
                    borderLeft: Config.effectiveFrameBorder
                    borderRight: Config.effectiveFrameBorder
                    opacity: Config.frameOpacity
                    visible: !overlay.monFullscreen
                }


                Bar {
                    id: frameBars
                    anchors.fill: parent
                    z: 1
                    visible: !overlay.monFullscreen
                    railScale: overlay.s
                    frameBars: overlay.frameBars
                    style: ({ group: blobGroup })
                    onMenuRequested: (id, ownerRect) => root.menuRequested(id, ownerRect)
                    onSurfaceRequested: (id, ownerRect) => root.surfaceRequested(id, ownerRect)
                    onActionRequested: id => root.runBarAction(id)
                }

                // per-monitor frame menu manager: a bar widget asks for a menu via
                // root.menuRequested; only the owning monitor's manager opens it on
                // the shared Popout scene. The focus grab below dismisses on a
                // backdrop click, and Escape closes through the FocusScope.
                FrameMenuManager {
                    id: frameMenus
                    monitorName: overlay.modelData.name
                    scale: overlay.s
                    group: blobGroup
                    frameThickness: overlay.surfaceFrameThickness
                    active: !overlay.monFullscreen

                    Connections {
                        target: root
                        function onMenuRequested(id, ownerRect) { frameMenus.openMenu(id, ownerRect); }
                        function onBarMenuRequested(mon, id) {
                            if (mon === overlay.modelData.name)
                                frameMenus.openMenuAt(id, overlay.width / 2, overlay.height / 2);
                        }
                    }
                }

                // power popout: the session menu, grown from the bar edge. The
                // one surviving popup (Super+Esc and the atoll power icon).
                Popout {
                    id: powerPop
                    group: blobGroup
                    frameThickness: overlay.surfaceFrameThickness
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.popoutEdge
                    align: "center"
                    alongCenter: root.popoutCenter
                    hoverOpen: false
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "power" && root.popoutMon === overlay.modelData.name
                    openW: powerContent.implicitWidth
                    openH: powerContent.implicitHeight

                    PowerPanel {
                        id: powerContent
                        s: overlay.s
                        open: powerPop.prog > 0.5
                        onCloseRequested: root.popout = ""
                    }
                }

                // voice popout: the dictation overlay. grabs nothing (excluded
                // from the focus grab below) so dictation lands in the focused app.
                Popout {
                    id: voicePop
                    group: blobGroup
                    frameThickness: overlay.surfaceFrameThickness
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.popoutEdge
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "voice" && root.popoutMon === overlay.modelData.name
                    openW: voiceContent.implicitWidth
                    openH: voiceContent.implicitHeight

                    VoicePopout {
                        id: voiceContent
                        s: overlay.s
                        off: root.voiceOff
                        open: voicePop.prog > 0.5
                        onCloseRequested: root.popout = ""
                    }
                }

                // keyring popout: the secret-service password prompt. a keyboard
                // popout; dismissing it cancels the prompt (onPopoutChanged).
                Popout {
                    id: keyringPop
                    group: blobGroup
                    frameThickness: overlay.surfaceFrameThickness
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.popoutEdge
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "keyring" && root.popoutMon === overlay.modelData.name
                    openW: keyringContent.implicitWidth
                    openH: keyringContent.implicitHeight

                    KeyringPopout {
                        id: keyringContent
                        s: overlay.s
                        open: keyringPop.prog > 0.5
                        onCloseRequested: root.popout = ""
                    }
                }

                Popout {
                    id: sidebarLeftPop
                    group: blobGroup
                    frameThickness: overlay.frameLip
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.stashSurface.anchor
                    hoverOpen: false
                    closeDelay: 300
                    s: overlay.s
                    active: false
                    fullSpan: true
                    openW: overlay.stashSurface.minWidth * overlay.s
                    openH: overlay.height

                    SidebarFeatures {
                        id: sidebarLeftContent
                        s: overlay.s
                        topInset: overlay.sidebarTopGap
                        botInset: overlay.sidebarBotGap
                        open: sidebarLeftPop.prog > 0.5
                        panes: overlay.stashSurface.panes
                        pane: root.sidebarLeftPane
                        onPaneSelected: (k) => root.sidebarLeftPane = k
                    }
                }

                Popout {
                    id: sidebarRightPop
                    group: blobGroup
                    frameThickness: overlay.frameLip
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.systemSurface.anchor
                    hoverOpen: false
                    closeDelay: 300
                    s: overlay.s
                    active: false
                    fullSpan: true
                    openW: overlay.systemSurface.minWidth * overlay.s
                    openH: overlay.height

                    SidebarSystem {
                        s: overlay.s
                        topInset: overlay.sidebarTopGap
                        botInset: overlay.sidebarBotGap
                        open: sidebarRightPop.prog > 0.5
                        panes: overlay.systemSurface.panes
                        pane: root.sidebarRightPane
                        onPaneSelected: (k) => root.sidebarRightPane = k
                        onDismiss: { if (root.popout === "sidebarRight" && root.popoutMon === overlay.modelData.name) root.popout = ""; }
                    }
                }

                HyprlandFocusGrab {
                    active: !overlay.kbPopout && (frameMenus.anyOpen
                        || (root.popout !== "" && root.popoutMon === overlay.modelData.name && root.popout !== "voice"))
                    windows: [overlay]
                    onCleared: {
                        if (root.popoutMon === overlay.modelData.name) root.popout = "";
                        frameMenus.closeAll();
                    }
                }

                // Plugin frame popouts fuse into the same blob field as Power.
                PluginPopouts {
                    id: pluginPops
                    group: blobGroup
                    s: overlay.s
                    active: !overlay.monFullscreen
                    frameThickness: 16
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    pinnedId: (root.popoutMon === overlay.modelData.name && root.popout.indexOf("plugin:") === 0)
                              ? root.popout.substring(7) : ""
                    onUnpinRequested: {
                        if (root.popout.indexOf("plugin:") === 0 && root.popoutMon === overlay.modelData.name)
                            root.popout = "";
                    }
                }

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
