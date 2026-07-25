pragma ComponentBehavior: Bound

import QtQuick
import "framebars/MenuState.js" as MenuState
import "framebars/MenuCatalog.js" as MenuCatalog
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
    required property real frameThickness
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
            { id: "keyring", kind: "keyring", anchor: "top", minWidth: 420 }
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
    signal surfaceClosed(string id)

    readonly property bool anyOpen: {
        const mon = menuState[monitorName];
        if (!mon) return false;
        for (const a in mon) if (mon[a]) return true;
        return false;
    }
    readonly property bool modal: {
        const mon = menuState[monitorName];
        if (!mon) return false;
        for (const anchor in mon)
            if (mon[anchor] && mon[anchor].id !== "voice") return true;
        return false;
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

    function openSurface(id, ownerRect, requestedMonitor) {
        if (requestedMonitor !== undefined && requestedMonitor !== "" && requestedMonitor !== root.monitorName) return;
        const voiceOff = id === "voice-off";
        const surfaceID = voiceOff ? "voice" : id;
        if (surfaceID.indexOf("plugin:") === 0) {
            root.openPlugin(surfaceID.substring(7));
            return;
        }
        const rec = MenuState.recordFor(root.records, surfaceID);
        if (!rec) return;
        if (surfaceID === "power" && root.activeIdAt(rec.anchor) === surfaceID) {
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
        const previous = MenuState.activeAt(root.menuState, root.monitorName, rec.anchor);
        if (previous && previous.id !== surfaceID) root.surfaceClosed(previous.id);
        root.menuState = MenuState.open(root.menuState, root.monitorName,
            Object.assign({}, rec, { id: surfaceID, anchor: rec.anchor, along: along, trigger: trigger, off: voiceOff }));
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
        const previous = MenuState.activeAt(root.menuState, root.monitorName, "top");
        if (previous) root.surfaceClosed(previous.id);
        const rec = { id: id, anchor: "top", along: root.width / 2,
            trigger: { x: root.width / 2, y: root.height / 2, width: 1, height: 1 } };
        root.menuState = MenuState.open(root.menuState, root.monitorName, rec);
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

    function closeAt(anchor) {
        const active = MenuState.activeAt(root.menuState, root.monitorName, anchor);
        if (!active) return;
        root.surfaceClosed(active.id);
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
            frameThickness: root.frameThickness
            radius: Config.frameRadius
            smoothing: Config.frameSmoothing
            s: root.scale
            active: root.active
            manager: root
            record: modelData
            anchor: modelData.anchor
            menuOpen: root.active && root.activeIdAt(modelData.anchor) === modelData.id
            alongCenter: root.alongAt(modelData.anchor)
            onRequestClose: root.closeMenu(modelData.id)
        }
    }

    PluginPopouts {
        id: pluginPopouts
        group: root.group
        s: root.scale
        active: root.active
        frameThickness: root.frameThickness
        radius: Config.frameRadius
        smoothing: Config.frameSmoothing
        pinnedId: {
            const id = root.activeIdAt("top");
            return id.indexOf("plugin:") === 0 ? id.substring(7) : "";
        }
        onUnpinRequested: root.closeAt("top")
    }
}
