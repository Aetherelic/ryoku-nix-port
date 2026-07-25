pragma ComponentBehavior: Bound

import QtQuick
import "framebars/MenuState.js" as MenuState
import "framebars/MenuCatalog.js" as MenuCatalog
import "Singletons"

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

    // configured menus as a repeatable list of {id, anchor, minWidth, widgets, ...}.
    readonly property var menus: {
        const src = Config.normalizedFrameBars.menus || ({});
        const out = [];
        for (const id in src) out.push(Object.assign({ id: id }, src[id]));
        return out;
    }

    // { [monitor]: { [anchor]: record } }, driven by the pure MenuState model.
    property var menuState: ({})

    readonly property bool anyOpen: {
        const mon = menuState[monitorName];
        if (!mon) return false;
        for (const a in mon) if (mon[a]) return true;
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

    // Open a catalogued menu at its anchor for this monitor. ownerRect is the
    // trigger's global rect; requests from another monitor's overlay map outside
    // this item and are ignored, so every monitor's manager sees one broadcast
    // signal but only the owning monitor reacts.
    function openMenu(id, ownerRect) {
        const rec = MenuState.recordFor(root.menus, id);
        if (!rec) return;
        const local = root.mapFromGlobal(ownerRect.x, ownerRect.y);
        if (local.x < 0 || local.y < 0 || local.x >= root.width || local.y >= root.height) return;
        const anchor = rec.anchor;
        const horiz = anchor.indexOf("top") === 0 || anchor.indexOf("bottom") === 0;
        const along = horiz ? local.x + ownerRect.width / 2 : local.y + ownerRect.height / 2;
        const trigger = { x: local.x, y: local.y, width: ownerRect.width, height: ownerRect.height };
        root.menuState = MenuState.open(root.menuState, root.monitorName,
            { id: id, anchor: anchor, along: along, trigger: trigger });
    }

    function closeAt(anchor) {
        root.menuState = MenuState.closeAt(root.menuState, root.monitorName, anchor);
    }
    function closeMenu(id) {
        const rec = MenuCatalog.menu(id);
        if (rec) root.closeAt(rec.anchor);
    }
    function closeAll() {
        const mon = root.menuState[root.monitorName];
        if (!mon) return;
        let next = root.menuState;
        for (const anchor in mon) next = MenuState.closeAt(next, root.monitorName, anchor);
        root.menuState = next;
    }

    Repeater {
        id: menuRepeater
        model: root.menus
        delegate: FrameMenu {
            required property var modelData
            group: root.group
            frameThickness: root.frameThickness
            radius: Config.frameRadius
            smoothing: Config.frameSmoothing
            s: root.scale
            active: root.active
            record: modelData
            anchor: modelData.anchor
            menuOpen: root.active && root.activeIdAt(modelData.anchor) === modelData.id
            alongCenter: root.alongAt(modelData.anchor)
        }
    }
}
