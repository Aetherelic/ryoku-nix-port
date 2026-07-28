pragma ComponentBehavior: Bound

import QtQuick
import "framebars/MenuState.js" as MenuState
import Ryoku.FrameBars
import "Singletons"
import "popouts"

// The single per-monitor frame menu manager. It repeats the configured menu
// records and owns which record is active at each anchor for THIS monitor.
// Opening a second menu at a busy anchor replaces the first; each monitor keeps
// its own slice of state, so the same anchor stays independent across monitors.
// shell.qml unions each open menu's trigger and body rects (masks) into the one
// overlay input mask; released regions fall through to applications.
Item {
    id: root

    anchors.fill: parent

    required property string monitorName
    required property real scale
    required property var group
    // Clearance from the screen edge to the inside of each rail, per edge. A
    // surface grows out of its own anchor's edge, so it must clear THAT rail;
    // a single top-rail figure tucked every left and right body under the side
    // rails.
    required property var railClearances
    readonly property real frameThickness: root.clearanceFor("top")
    function clearanceFor(anchor) {
        const edge = anchor.indexOf("top") === 0 ? "top"
            : anchor.indexOf("bottom") === 0 ? "bottom"
            : anchor;
        const value = root.railClearances ? root.railClearances[edge] : undefined;
        return typeof value === "number" ? value : 0;
    }
    property bool active: true

    readonly property var menus: {
        const src = Config.normalizedFrameBars.menus || ({});
        const out = [];
        for (const id in src) {
            // "screenshot" migrated from an in-band menu to the Super+S capture
            // card (a surface). Ignore any lingering screenshot_menu in a config
            // the doctor has not yet reconciled, so the surface -- not the retired
            // menu -- answers `menu screenshot`.
            if (id === "screenshot") continue;
            out.push(Object.assign({ id: id, kind: "menu" }, src[id]));
        }
        return out;
    }
    readonly property var surfaces: {
        const src = Config.normalizedFrameBars.surfaces || ({});
        const out = [];
        for (const id in src) out.push(Object.assign({ id: id, kind: id, fullSpan: true }, src[id]));
        out.push(
            { id: "power", kind: "power", anchor: "top", minWidth: 480 },
            { id: "voice", kind: "voice", anchor: "bottom", minWidth: 380 },
            { id: "keyring", kind: "keyring", anchor: "top", minWidth: 420 },
            // the rail spectrum's music card: a pointer-only popout, so it
            // joins the surfaces without taking the keyboard.
            { id: "music", kind: "music", anchor: "left", minWidth: 264 },
            // the rail bluetooth widget's device card: a left-anchored sliding
            // card, opening and dismissing exactly like the music card.
            { id: "bluetooth", kind: "bluetooth", anchor: "left", minWidth: 272 },
            // the rail battery + network widgets' cards: left-anchored sliding
            // cards like the others; network takes on-demand keyboard for a
            // Wi-Fi password, battery is pointer-only.
            { id: "battery", kind: "battery", anchor: "left", minWidth: 244 },
            { id: "network", kind: "network", anchor: "left", minWidth: 250 },
            // the rail system-monitor widget's card: CPU / memory / temp gauges
            // on a left-anchored sliding card like the others.
            { id: "sysmon", kind: "sysmon", anchor: "left", minWidth: 260 },
            // the rail speaker/mic widgets' card: the audio mixer -- output,
            // input, per-app playback and capture -- on a left-anchored
            // sliding card like the others, pointer-only (faders, no keys).
            { id: "audio", kind: "audio", anchor: "left", minWidth: 300 },
            // the Super+S capture card: a left-anchored sliding card like the
            // other rail cards, opened by the screenshot keybind / IPC. Pointer-only.
            { id: "screenshot", kind: "screenshot", anchor: "left", minWidth: 300 }
        );
        return out;
    }
    readonly property var records: menus.concat(surfaces)
    property string stashPane: ""
    property string systemPane: ""
    property real sidebarTopInset: 0
    property real sidebarBottomInset: 0

    // { [monitor]: { [anchor]: record } }, driven by the pure MenuState model.
    property var menuState: ({})
    signal surfaceClosed(string id, var context)
    signal pluginUnpinRequested(string pluginId)

    readonly property bool anyOpen: {
        const mon = menuState[monitorName];
        if (!mon) return false;
        for (const a in mon) if (mon[a]) return true;
        return false;
    }
    // A Ryoku surface (sidebar, power, keyring, plugin) is open. These keep
    // Ryoku's outside-click dismissal and take keyboard; the reference frame
    // menus deliberately do not (contract 05 sec 4). The passive voice toast is
    // never modal.
    readonly property bool surfaceModal: {
        const mon = menuState[monitorName];
        if (!mon) return false;
        for (const anchor in mon)
            if (mon[anchor] && mon[anchor].kind && mon[anchor].kind !== "menu" && mon[anchor].id !== "voice" && mon[anchor].id !== "music" && mon[anchor].id !== "bluetooth" && mon[anchor].id !== "battery" && mon[anchor].id !== "network" && mon[anchor].id !== "sysmon" && mon[anchor].id !== "audio" && mon[anchor].id !== "screenshot") return true;
        return false;
    }
    // Keyboard focus the frame raises while something is open (contract 05 sec
    // 4): Exclusive for the screenshare picker, OnDemand for the wallpaper menu,
    // None for every pointer-only menu. Ryoku's own modal surfaces take
    // Exclusive too; the voice toast takes none.
    readonly property string keyboardMode: {
        const mon = menuState[monitorName];
        if (!mon) return "none";
        for (const anchor in mon) {
            const rec = mon[anchor];
            if (!rec) continue;
            if (rec.id === "screenshare") return "exclusive";
            if (rec.id === "wallpaper") return "ondemand";
            if (rec.id === "network") return "ondemand";
            if (rec.kind && rec.kind !== "menu" && rec.id !== "voice" && rec.id !== "music" && rec.id !== "bluetooth" && rec.id !== "battery" && rec.id !== "network" && rec.id !== "sysmon" && rec.id !== "audio" && rec.id !== "screenshot") return "exclusive";
        }
        return "none";
    }

    // The single reference menu (kind "menu") open on this monitor, or null.
    // Ryoku-own surfaces (power/voice/keyring/stash/system) and plugins keep
    // their own blob popouts and never feed the chrome band.
    readonly property var activeMenu: {
        const mon = menuState[monitorName];
        if (!mon) return null;
        for (const a in mon)
            if (mon[a] && mon[a].kind === "menu") return mon[a];
        return null;
    }

    // Latched chrome-band source: the open menu's resting panel rect + anchor,
    // held through the close so the band retracts along the right edge instead
    // of vanishing. A side menu (left/right) slides; an edge/corner menu scales.
    property var chromeRest: ({ x: 0, y: 0, w: 0, h: 0 })
    property string chromeAnchor: ""
    property bool chromeSide: true
    // 0 closed .. 1 open. Side menus slide 250 ms ease-out-cubic, edge/corner
    // menus scale 200 ms ease-in-out-quad; a Behavior retarget reverses (slide)
    // or restarts (scale) from the current value on interrupt (contract 05 sec 5).
    property real chromeReveal: 0
    Behavior on chromeReveal {
        NumberAnimation {
            duration: root.chromeSide ? Motion.menuSlide : Motion.diagonal
            easing.type: root.chromeSide ? Motion.menuSlideCurve : Motion.diagonalCurve
        }
    }

    // FrameMenu calls this while its menu is open: it latches the band source
    // and drives the reveal to 1 with the current edge's curve. A same-region
    // swap pushes an identical rect so the band does not blink; a fresh open
    // animates in from the band. On close (activeMenu -> null) the reveal falls
    // to 0 along the held edge.
    function setChromeSource(anchor, x, y, w, h, isSide) {
        root.chromeAnchor = anchor;
        root.chromeRest = { x: x, y: y, w: w, h: h };
        root.chromeSide = isSide;
        root.chromeReveal = 1;
    }
    onActiveMenuChanged: if (!root.activeMenu) root.chromeReveal = 0;

    // The animated band rect + anchor FrameChrome carves out of the desktop
    // hole and each menu body clips into. Interpolated from the latched rest
    // rect by the reveal: side menus slide their inner edge inward; edge and
    // corner menus scale from the anchor origin.
    readonly property var chromePanel: {
        const r = root.chromeRest;
        const p = root.chromeReveal;
        const a = root.chromeAnchor;
        const rr = r.x + r.w;
        const rb = r.y + r.h;
        const cx = r.x + r.w / 2;
        const wp = r.w * p;
        const hp = r.h * p;
        if (a === "left")         return { anchor: a, x: r.x,         y: r.y,     w: wp, h: r.h };
        if (a === "right")        return { anchor: a, x: rr - wp,     y: r.y,     w: wp, h: r.h };
        if (a === "top")          return { anchor: a, x: cx - wp / 2, y: r.y,     w: wp, h: hp };
        if (a === "bottom")       return { anchor: a, x: cx - wp / 2, y: rb - hp, w: wp, h: hp };
        if (a === "top-left")     return { anchor: a, x: r.x,         y: r.y,     w: wp, h: hp };
        if (a === "top-right")    return { anchor: a, x: rr - wp,     y: r.y,     w: wp, h: hp };
        if (a === "bottom-left")  return { anchor: a, x: r.x,         y: rb - hp, w: wp, h: hp };
        if (a === "bottom-right") return { anchor: a, x: rr - wp,     y: rb - hp, w: wp, h: hp };
        return { anchor: "", x: r.x, y: r.y, w: 0, h: 0 };
    }

    // per-anchor trigger (owner) and body (Popout) mask rects, in window
    // coordinates. Zero rects for idle anchors contribute nothing to the mask.
    readonly property var masks: {
        const out = ({});
        const list = MenuCatalog.anchors();
        for (let k = 0; k < list.length; ++k) {
            const a = list[k];
            const rec = MenuState.activeAt(menuState, monitorName, a);
            const t = rec && rec.trigger ? rec.trigger : null;
            out[a] = {
                tx: t ? t.x : 0, ty: t ? t.y : 0, tw: t ? t.width : 0, th: t ? t.height : 0,
                bx: 0, by: 0, bw: 0, bh: 0
            };
        }
        const n = menuRepeater.count;
        for (let i = 0; i < n; ++i) {
            const fm = menuRepeater.itemAt(i);
            if (!fm || fm.maskW <= 0 || fm.maskH <= 0 || !out[fm.anchor]) continue;
            out[fm.anchor].bx = fm.maskX;
            out[fm.anchor].by = fm.maskY;
            out[fm.anchor].bw = fm.maskW;
            out[fm.anchor].bh = fm.maskH;
        }
        const plugin = pluginPopouts.first;
        if (plugin && plugin.pinned && out[plugin.edge]) {
            out[plugin.edge].tx = plugin.triggerX;
            out[plugin.edge].ty = plugin.triggerY;
            out[plugin.edge].tw = plugin.triggerW;
            out[plugin.edge].th = plugin.triggerH;
            out[plugin.edge].bx = plugin.maskX;
            out[plugin.edge].by = plugin.maskY;
            out[plugin.edge].bw = plugin.maskW;
            out[plugin.edge].bh = plugin.maskH;
        }
        if (dockPreviewHost.maskW > 0 && dockPreviewHost.maskH > 0 && out[dockPreviewHost.edge]) {
            out[dockPreviewHost.edge].bx = dockPreviewHost.maskX;
            out[dockPreviewHost.edge].by = dockPreviewHost.maskY;
            out[dockPreviewHost.edge].bw = dockPreviewHost.maskW;
            out[dockPreviewHost.edge].bh = dockPreviewHost.maskH;
        }
        return out;
    }

    function activeIdAt(anchor) {
        const rec = MenuState.activeAt(menuState, monitorName, anchor);
        return rec ? rec.id : "";
    }
    function alongAt(anchor) {
        const rec = MenuState.activeAt(menuState, monitorName, anchor);
        return rec && rec.along !== undefined ? rec.along : -1;
    }
    // The live (menuState) record active at this anchor when its id matches, so
    // a delegate can read the dynamic open-time fields (off, page) that the
    // static config record does not carry. Null when this record is not open.
    function openRecordAt(anchor, id) {
        const rec = MenuState.activeAt(root.menuState, root.monitorName, anchor);
        return rec && rec.id === id ? rec : null;
    }

    // The anchor where a record id is currently open on this monitor, or "" if
    // it is closed. A record's live anchor can differ from its config anchor
    // because a rail widget opens its popout on the rail's own edge.
    function liveAnchorFor(id) {
        const mon = root.menuState[root.monitorName];
        if (!mon) return "";
        for (const anchor in mon) if (mon[anchor] && mon[anchor].id === id) return anchor;
        return "";
    }
    // The screen edge (top/bottom/left/right) nearest a point, so a popout welds
    // to the rail edge its trigger widget hugs.
    function edgeNearest(x, y) {
        const d = { top: y, bottom: root.height - y, left: x, right: root.width - x };
        let best = "top";
        for (const e in d) if (d[e] < d[best]) best = e;
        return best;
    }

    // The rail edge a trigger widget sits ON. A rail is a thin strip along one
    // screen edge (railClearances is its inside depth), so a widget within a
    // rail's depth welds its popout to THAT rail -- even a left-rail widget at
    // the very bottom, which edgeNearest would mis-assign to the bottom edge and
    // melt with the wrong (dipping, centre-narrowing) geometry. Only edges that
    // carry a live rail (clearance > 0) qualify; otherwise fall back to nearest.
    // Corner ownership decides the order. A horizontal rail spans the full width
    // and owns both shared corners (Bar.qml gives it leadInset 0); a vertical one
    // is inset to fit BETWEEN them. So a point in a shared corner belongs to the
    // horizontal rail, and top/bottom must be tested first -- testing left first
    // stole every top/bottom widget sitting within a side rail's depth and opened
    // its menu welded to the wrong edge.
    function edgeForTrigger(x, y) {
        const c = root.railClearances || ({});
        const cl = c.left || 0, cr = c.right || 0, ct = c.top || 0, cb = c.bottom || 0;
        if (ct > 0 && y <= ct) return "top";
        if (cb > 0 && root.height - y <= cb) return "bottom";
        if (cl > 0 && x <= cl) return "left";
        if (cr > 0 && root.width - x <= cr) return "right";
        return root.edgeNearest(x, y);
    }

    // Single-open invariant (contract 05 sec 4): before revealing a menu or
    // surface, close every other open one on this monitor, so at most one is
    // ever shown per frame. Daemon-lifecycle toasts (voice, keyring) are exempt
    // and are neither closed here nor closed by opening a menu.
    function closeOtherUsers(state, keepId) {
        const mon = state[root.monitorName];
        if (!mon) return state;
        let next = state;
        for (const anchor in mon) {
            const rec = mon[anchor];
            if (!rec || rec.id === keepId || rec.id === "voice" || rec.id === "keyring") continue;
            root.surfaceClosed(rec.id, rec);
            next = MenuState.closeAt(next, root.monitorName, anchor);
        }
        return next;
    }
    function openSurface(id, ownerRect, requestedMonitor, context) {
        if (requestedMonitor !== undefined && requestedMonitor !== "" && requestedMonitor !== root.monitorName) return;
        // A "#page" suffix on the id carries an initial sidebar page (a bar
        // indicator deep-linking into quick-settings), stripped before the id
        // is matched to a surface record.
        const hash = id.indexOf("#");
        const page = hash >= 0 ? id.substring(hash + 1) : "";
        const reqId = hash >= 0 ? id.substring(0, hash) : id;
        const voiceOff = reqId === "voice-off";
        const surfaceID = voiceOff ? "voice" : reqId;
        if (surfaceID.indexOf("plugin:") === 0) {
            root.openPlugin(surfaceID.substring(7));
            return;
        }
        const rec = MenuState.recordFor(root.records, surfaceID);
        if (!rec) return;
        // Asking again for the surface that already owns this anchor closes it:
        // a bar button and its command both read as one toggle. Keyring and
        // voice are daemon lifecycle surfaces, not user toggles: a fresh prompt
        // or a re-show must replace the live record, never dismiss it.
        const daemonOwned = surfaceID === "keyring" || surfaceID === "voice";
        // Where this surface is currently open. Its live anchor may differ from
        // the config anchor: a rail widget welds its popout to its own edge, so
        // the toggle must find it wherever it lives. Re-asking closes it; a new
        // page switches in place, so a bar button and its command read as one
        // toggle.
        const openAnchor = root.liveAnchorFor(surfaceID);
        if (!daemonOwned && openAnchor !== "") {
            const cur = MenuState.activeAt(root.menuState, root.monitorName, openAnchor);
            if (page !== "" && cur && cur.page !== page) {
                root.menuState = MenuState.open(root.menuState, root.monitorName, Object.assign({}, cur, { page: page }));
                return;
            }
            root.closeAt(openAnchor);
            return;
        }
        let local;
        if (ownerRect && ownerRect.width > 0 && ownerRect.height > 0) {
            local = root.mapFromGlobal(ownerRect.x, ownerRect.y);
            if (local.x < 0 || local.y < 0 || local.x >= root.width || local.y >= root.height) return;
        } else {
            local = { x: root.width / 2, y: root.height / 2 };
            ownerRect = { width: 1, height: 1 };
        }
        // A surface opened from a rail widget grows out of THAT rail's edge, so
        // the popout stays welded to its trigger wherever the user placed the
        // rail. The edge is the screen side the trigger hugs; a corner config
        // anchor (wallpaper, recording) collapses to that edge. A command or IPC
        // open carries no widget rect, so it keeps the record's config anchor.
        const cx = local.x + ownerRect.width / 2;
        const cy = local.y + ownerRect.height / 2;
        const realTrigger = ownerRect.width > 1 || ownerRect.height > 1;
        const anchor = realTrigger ? root.edgeForTrigger(cx, cy) : rec.anchor;
        const horiz = anchor.indexOf("top") === 0 || anchor.indexOf("bottom") === 0;
        const along = horiz ? cx : cy;
        const trigger = { x: local.x, y: local.y, width: ownerRect.width, height: ownerRect.height };
        const base = daemonOwned ? root.menuState : root.closeOtherUsers(root.menuState, surfaceID);
        root.menuState = MenuState.open(base, root.monitorName,
            Object.assign({}, rec, { id: surfaceID, anchor: anchor, along: along, trigger: trigger,
                off: voiceOff, page: page, promptId: surfaceID === "keyring" && context ? context.promptId : undefined }));
    }
    function openMenu(id, ownerRect) {
        root.openSurface(id, ownerRect, root.monitorName);
    }
    function openMenuAt(id, x, y) {
        root.openSurface(id, { x: x, y: y, width: 1, height: 1 }, root.monitorName);
    }
    function openPlugin(pluginID) {
        if (pluginID === "") return;
        const id = "plugin:" + pluginID;
        if (root.activeIdAt("top") === id) {
            root.closeAt("top");
            return;
        }
        const base = root.closeOtherUsers(root.menuState, id);
        const rec = { id: id, kind: "plugin", anchor: "top", along: root.width / 2,
            trigger: { x: root.width / 2, y: root.height / 2, width: 1, height: 1 } };
        root.menuState = MenuState.open(base, root.monitorName, rec);
    }
    function closeSurface(id, requestedMonitor) {
        if (requestedMonitor !== undefined && requestedMonitor !== "" && requestedMonitor !== root.monitorName) return;
        if (id === "" || id === undefined) {
            root.closeAll();
            return;
        }
        if (id.indexOf("plugin:") === 0) {
            if (root.activeIdAt("top") === id) root.closeAt("top");
            return;
        }
        root.closeMenu(id === "voice-off" ? "voice" : id);
    }
    function retireKeyringPrompt(promptId) {
        const active = MenuState.activeAt(root.menuState, root.monitorName, "top");
        if (active && active.id === "keyring" && active.promptId !== promptId) root.closeAt("top");
    }

    function closeAt(anchor) {
        const active = MenuState.activeAt(root.menuState, root.monitorName, anchor);
        if (!active) return;
        root.surfaceClosed(active.id, active);
        root.menuState = MenuState.closeAt(root.menuState, root.monitorName, anchor);
    }
    function closeMenu(id) {
        const anchor = root.liveAnchorFor(id);
        if (anchor !== "") root.closeAt(anchor);
    }
    function closeAll() {
        const mon = root.menuState[root.monitorName];
        if (!mon) return;
        for (const anchor in mon) root.closeAt(anchor);
    }

    onActiveChanged: if (!root.active) root.closeAll()

    Repeater {
        id: menuRepeater
        model: root.records
        delegate: FrameMenu {
            required property var modelData
            // A record renders wherever it is open (its live anchor), which a
            // rail widget pins to its own edge; the config anchor is only the
            // resting fallback while the record is closed.
            readonly property string liveAnchor: root.liveAnchorFor(modelData.id)
            // Latched through the close, the same way the manager holds
            // chromeRest and Popout holds heldAlong. Snapping straight back to
            // the config anchor moved the resting rect mid-close, and that moved
            // rect re-entered pushChrome and drove the reveal back to 1 -- the
            // band stranded open as an empty panel on the config anchor's edge,
            // long after the menu it belonged to was gone.
            property string heldAnchor: ""
            onLiveAnchorChanged: if (liveAnchor !== "") heldAnchor = liveAnchor
            readonly property string effectiveAnchor: liveAnchor !== "" ? liveAnchor
                : (heldAnchor !== "" ? heldAnchor : modelData.anchor)
            group: root.group
            frameThickness: root.clearanceFor(effectiveAnchor)
            clearances: root.railClearances
            radius: Theme.radiusWindow
            smoothing: 0
            s: root.scale
            active: root.active
            manager: root
            record: modelData
            anchor: effectiveAnchor
            menuOpen: root.active && liveAnchor !== ""
            openRecord: liveAnchor !== "" ? root.openRecordAt(liveAnchor, modelData.id) : null
            triggerAlong: liveAnchor !== "" ? root.alongAt(liveAnchor) : -1
            onRequestClose: root.closeMenu(modelData.id)
        }
    }

    PluginPopouts {
        id: pluginPopouts
        group: root.group
        s: root.scale
        active: root.active
        frameThickness: root.frameThickness
        radius: Theme.radiusWindow
        smoothing: 0
        pinnedId: {
            const id = root.activeIdAt("top");
            return id.indexOf("plugin:") === 0 ? id.substring(7) : "";
        }
        onUnpinRequested: pluginId => root.pluginUnpinRequested(pluginId)
    }

    // The dock's hover window-preview strip: one self-hovering Popout per
    // monitor, driven by the DockPreview singleton the dock writes on icon
    // hover. Not a menu-state surface; its body mask is unioned above so the
    // live tiles are clickable over the desktop hole.
    DockPreviewPopout {
        id: dockPreviewHost
        group: root.group
        s: root.scale
        active: root.active
        frameThickness: root.clearanceFor(DockPreview.edge)
    }
    onPluginUnpinRequested: pluginId => root.closeSurface("plugin:" + pluginId, root.monitorName)
}
