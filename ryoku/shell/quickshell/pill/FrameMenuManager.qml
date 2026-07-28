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
        for (const id in src) out.push(Object.assign({ id: id, kind: "menu" }, src[id]));
        return out;
    }
    readonly property var surfaces: {
        const src = Config.normalizedFrameBars.surfaces || ({});
        const out = [];
        for (const id in src) out.push(Object.assign({ id: id, kind: id, fullSpan: true }, src[id]));
        out.push(
            { id: "power", kind: "power", anchor: "top", minWidth: 480 },
            { id: "voice", kind: "voice", anchor: "top", minWidth: 420 },
            { id: "keyring", kind: "keyring", anchor: "top", minWidth: 420 },
            // the rail spectrum's music card: a pointer-only popout, so it
            // joins the surfaces without taking the keyboard.
            { id: "music", kind: "music", anchor: "left", minWidth: 320 }
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
            if (mon[anchor] && mon[anchor].kind && mon[anchor].kind !== "menu" && mon[anchor].id !== "voice" && mon[anchor].id !== "music") return true;
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
            if (rec.kind && rec.kind !== "menu" && rec.id !== "voice" && rec.id !== "music") return "exclusive";
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
        if (!daemonOwned && root.activeIdAt(rec.anchor) === surfaceID) {
            // Re-asking with a different page switches to it in place; re-asking
            // for the page already shown (or with no page) toggles the surface
            // shut, so a bar button and its command still read as one toggle.
            const cur = MenuState.activeAt(root.menuState, root.monitorName, rec.anchor);
            if (page !== "" && cur && cur.page !== page) {
                root.menuState = MenuState.open(root.menuState, root.monitorName, Object.assign({}, cur, { page: page }));
                return;
            }
            root.closeAt(rec.anchor);
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
        const horiz = rec.anchor.indexOf("top") === 0 || rec.anchor.indexOf("bottom") === 0;
        const along = horiz ? local.x + ownerRect.width / 2 : local.y + ownerRect.height / 2;
        const trigger = { x: local.x, y: local.y, width: ownerRect.width, height: ownerRect.height };
        const daemon = surfaceID === "keyring" || surfaceID === "voice";
        const base = daemon ? root.menuState : root.closeOtherUsers(root.menuState, surfaceID);
        root.menuState = MenuState.open(base, root.monitorName,
            Object.assign({}, rec, { id: surfaceID, anchor: rec.anchor, along: along, trigger: trigger,
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
        const rec = MenuState.recordFor(root.records, id);
        if (rec && root.activeIdAt(rec.anchor) === id) root.closeAt(rec.anchor);
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
            group: root.group
            frameThickness: root.clearanceFor(modelData.anchor)
            clearances: root.railClearances
            radius: Theme.radiusWindow
            smoothing: 0
            s: root.scale
            active: root.active
            manager: root
            record: modelData
            anchor: modelData.anchor
            menuOpen: root.active && root.activeIdAt(modelData.anchor) === modelData.id
            openRecord: root.openRecordAt(modelData.anchor, modelData.id)
            triggerAlong: root.alongAt(modelData.anchor)
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
