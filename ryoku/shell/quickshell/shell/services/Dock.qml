pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "lib/dock.js" as DockList

// Shared dock model: running-window + pinned-app data and the activate action,
// one source for every dock surface (framebars RailDock, qsbar DockSlot). The
// list maths live in the tested lib/dock.js; each consumer owns its own pins.
Singleton {
    id: root

    // Live-update: Hyprland events keep the toplevel LIST live, but a newly opened
    // window's lastIpcObject (its class/title) is not populated until a
    // refreshToplevels() runs -- so without a refresh the dock only picks up new
    // apps on a shell reload. Refresh whenever the window COUNT changes (open or
    // close), which is idempotent: the refresh fires valuesChanged again but the
    // count is unchanged, so it never loops. Bump _rev on every list/toplevel/
    // active change so clients/activeClass re-read (a plain .values read in a
    // binding does not track Quickshell's model).
    property int _rev: 0
    property int _primeTries: 0
    // True while some toplevel is in the list without its class yet (a freshly
    // opened window, before its ipc object is populated).
    function _needsPrime() {
        const tls = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tls.length; ++i) {
            const o = tls[i] && tls[i].lastIpcObject;
            if (!o || !(o.class || o.initialClass))
                return true;
        }
        return false;
    }
    // A new window enters the list before a refreshToplevels() fills in its class,
    // and a single refresh can lose the race (rapid opens). Poll-refresh until
    // every toplevel has a class, then stop -- bounded so a genuinely class-less
    // surface cannot spin forever.
    Timer {
        id: primePoll
        interval: 120
        repeat: true
        onTriggered: {
            if (root._primeTries++ > 25 || !root._needsPrime()) {
                primePoll.stop();
                return;
            }
            Hyprland.refreshToplevels();
        }
    }
    Component.onCompleted: Hyprland.refreshToplevels()
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() {
            root._rev++;
            root._primeTries = 0;
            if (root._needsPrime())
                primePoll.restart();
        }
    }
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { root._rev++; }
    }
    Instantiator {
        model: Hyprland.toplevels
        delegate: Connections {
            required property var modelData
            target: modelData
            function onLastIpcObjectChanged() { root._rev++; }
        }
    }

    // Toplevels as { className, address, pid }, pid-sorted for a stable order.
    readonly property var clients: {
        void root._rev;
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
        void root._rev;
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
