pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "../../Singletons"

// Global workspace strip: every non-special workspace across all monitors, sorted
// by (monitor name, id), with a 2px divider between monitor groups. A button has
// only active/inactive states (a filled vs hollow glyph, no bg change), several
// can be active at once (one per monitor), and an empty non-persistent workspace
// simply has no button. Left click focuses the workspace; a hover-gated vertical
// wheel steps relative (up -> r-1, down -> r+1). Contract 03 sec 2.3/2.4/4.3/4.4.
Item {
    id: root

    required property string edge
    required property real scale

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real cross: 48 * scale

    // Non-special workspaces sorted by (monitor name, id). Parsed properties are
    // preferred with the raw IPC object as a fallback, since the fork can leave
    // either lagging; a workspace with no monitor metadata is grouped first
    // rather than dropped, so the strip is never needlessly blank.
    readonly property var entries: {
        const list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        const out = [];
        const seen = {};
        for (let i = 0; i < list.length; ++i) {
            const w = list[i];
            if (!w)
                continue;
            const o = w.lastIpcObject || ({});
            const id = (typeof w.id === "number" && w.id !== 0) ? w.id : (typeof o.id === "number" ? o.id : 0);
            if (id <= 0)
                continue;
            const name = (typeof w.name === "string" && w.name.length) ? w.name : (o.name || "");
            if (name.indexOf("special") === 0)
                continue;
            if (seen[id])
                continue;
            seen[id] = true;
            const mon = w.monitor;
            const monName = (mon && mon.name) ? mon.name : (o.monitor || "");
            const monId = (mon && typeof mon.id === "number") ? mon.id : (typeof o.monitorID === "number" ? o.monitorID : 0);
            out.push({ id: id, monName: monName, monId: monId });
        }
        // The fork can leave the workspace model empty until a live event; never
        // render a blank strip while a focused workspace is known.
        if (out.length === 0 && Workspaces.activeId > 0)
            out.push({ id: Workspaces.activeId, monName: "", monId: 0 });
        out.sort((a, b) => a.monName < b.monName ? -1 : (a.monName > b.monName ? 1 : a.id - b.id));
        return out;
    }

    // Active set is per-monitor (multiple active at once), seeded from each
    // monitor's active workspace plus the probed focused id (fork-safe fallback).
    readonly property var activeIds: {
        const s = {};
        const mons = Hyprland.monitors ? Hyprland.monitors.values : [];
        for (let i = 0; i < mons.length; ++i) {
            const m = mons[i];
            if (!m)
                continue;
            const aw = m.activeWorkspace;
            if (aw && typeof aw.id === "number") {
                s[aw.id] = true;
            } else {
                const mo = m.lastIpcObject;
                if (mo && mo.activeWorkspace && typeof mo.activeWorkspace.id === "number")
                    s[mo.activeWorkspace.id] = true;
            }
        }
        if (Workspaces.activeId > 0)
            s[Workspaces.activeId] = true;
        return s;
    }

    // Flatten to a render list with divider markers between monitor groups.
    readonly property var cells: {
        const e = entries;
        const out = [];
        let lastMon = null;
        for (let i = 0; i < e.length; ++i) {
            if (lastMon !== null && e[i].monId !== lastMon)
                out.push({ divider: true, id: -1 });
            out.push({ divider: false, id: e[i].id });
            lastMon = e[i].monId;
        }
        return out;
    }

    implicitWidth: horizontal ? strip.implicitWidth : Math.max(cross, strip.implicitWidth)
    implicitHeight: horizontal ? Math.max(cross, strip.implicitHeight) : strip.implicitHeight

    function focusWorkspace(id) {
        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })');
    }

    Loader {
        id: strip
        anchors.centerIn: parent
        sourceComponent: root.horizontal ? rowComp : colComp
    }

    Component {
        id: rowComp
        Row {
            spacing: 0
            Repeater {
                model: root.cells
                delegate: cellLoader
            }
        }
    }
    Component {
        id: colComp
        Column {
            spacing: 0
            Repeater {
                model: root.cells
                delegate: cellLoader
            }
        }
    }

    Component {
        id: cellLoader
        Loader {
            required property var modelData
            sourceComponent: modelData.divider ? dividerComp : buttonComp
            onLoaded: if (!modelData.divider) item.wsId = modelData.id
        }
    }

    Component {
        id: dividerComp
        Rectangle {
            width: root.horizontal ? Theme.borderWidth * root.scale : root.cross
            height: root.horizontal ? root.cross : Theme.borderWidth * root.scale
            color: Theme.outline
        }
    }

    Component {
        id: buttonComp
        RailButton {
            id: wsButton
            property int wsId: -1
            readonly property bool wsActive: root.activeIds[wsId] === true
            edge: root.edge
            scale: root.scale
            onClicked: root.focusWorkspace(wsId)

            // active/inactive is a filled vs hollow glyph (contract: on-surface in
            // both states, no bg change), so the button never flips to primary.
            Rectangle {
                width: Theme.iconSm * root.scale
                height: Theme.iconSm * root.scale
                radius: 3 * root.scale
                color: wsButton.wsActive ? Theme.onSurface : "transparent"
                border.width: Math.max(1, Math.round(1.5 * root.scale))
                border.color: Theme.onSurface
            }
        }
    }

    // Hover-gated vertical wheel: up -> r-1, down -> r+1 (contract 03 sec 4.4).
    WheelHandler {
        onWheel: event => root.focusWorkspace(event.angleDelta.y > 0 ? "r-1" : "r+1")
    }
}
