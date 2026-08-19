pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "lib/dock.js" as DockList

// Shared dock model: running-window + pinned-app data and the activate action,
// one source for every dock surface (framebars RailDock, qsbar DockSlot). The
// list maths live in the tested lib/dock.js; each consumer owns its own pins.
QtObject {
    id: root

    // Toplevels as { className, address, pid }, pid-sorted for a stable order.
    readonly property var clients: {
        const result = [];
        const toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (let i = 0; i < toplevels.length; ++i) {
            const data = toplevels[i] && toplevels[i].lastIpcObject;
            const className = data && (data.class || data.initialClass);
            if (typeof className === "string" && className)
                result.push({ className: className, address: data.address || "", pid: (typeof data.pid === "number" ? data.pid : 0) });
        }
        result.sort((a, b) => a.pid - b.pid);
        return result;
    }

    readonly property string activeClass: {
        const active = Hyprland.activeToplevel && Hyprland.activeToplevel.lastIpcObject;
        return active ? (active.class || active.initialClass || "") : "";
    }

    // Pinned first, then running-unpinned in pid order. Omit clients for live.
    function resolve(pinned, activeClients) {
        const p = (pinned === undefined || pinned === null) ? [] : Array.from(pinned);
        return DockList.resolve(p, activeClients === undefined ? root.clients : activeClients);
    }
    function pin(pinned, className) { return DockList.pin(pinned, className); }
    function unpin(pinned, className) { return DockList.unpin(pinned, className); }

    function countFor(className) {
        const list = root.clients;
        let n = 0;
        for (let i = 0; i < list.length; ++i)
            if (list[i].className === className) ++n;
        return n;
    }

    // Fallback pins so an empty dock is not mistaken for a missing one.
    function starterPins() {
        const out = [];
        for (const className of ["kitty", "chromium", "nautilus"])
            if (DesktopEntries.heuristicLookup(className)) out.push(className);
        return out;
    }

    // Desktop-entry icon, then class-as-icon-name; "" so callers can fall back.
    function iconFor(className) {
        const desktop = DesktopEntries.heuristicLookup(className);
        const byEntry = (desktop && desktop.icon) ? Quickshell.iconPath(desktop.icon, true) : "";
        return byEntry !== "" ? byEntry : Quickshell.iconPath(String(className).toLowerCase(), true);
    }

    // No clients -> launch; focused already -> cycle by address; else focus,
    // preferring a client on the active workspace.
    function activate(className) {
        const toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        const matches = [];
        for (let i = 0; i < toplevels.length; ++i) {
            const d = toplevels[i] && toplevels[i].lastIpcObject;
            if (d && (d.class === className || d.initialClass === className) && d.address)
                matches.push(d);
        }
        if (matches.length === 0) {
            const entry = DesktopEntries.heuristicLookup(className);
            if (entry)
                entry.execute();
            return;
        }
        matches.sort((a, b) => a.address < b.address ? -1 : (a.address > b.address ? 1 : 0));
        const active = Hyprland.activeToplevel && Hyprland.activeToplevel.lastIpcObject ? Hyprland.activeToplevel.lastIpcObject.address : "";
        const idx = matches.findIndex(m => m.address === active);
        let target;
        if (idx >= 0)
            target = matches[(idx + 1) % matches.length];
        else {
            const ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
            target = matches.find(m => m.workspace && m.workspace.id === ws) || matches[0];
        }
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + target.address + '" })');
    }
}
