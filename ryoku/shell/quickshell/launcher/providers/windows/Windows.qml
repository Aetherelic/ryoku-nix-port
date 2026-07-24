import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Hyprland
import "../../Singletons"
import "../../lib/fuzzy.js" as Fuzzy
import ".."

// Open-window switcher: lists Hyprland toplevels, fuzzy-matched by title and
// class, and focuses the picked one. Default-ranked just below apps so "fire"
// surfaces a running Firefox window under the app entry.
Provider {
    id: windows

    providerId: "windows"

    // Hyprland events keep the model live. This short coalescing gate only
    // fills the initial IPC snapshot; it never turns the window rail into a
    // visible once-a-second poll while the user is navigating results.
    Timer { id: refreshGate; interval: 120; repeat: false }

    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { Dispatcher.notifyAsync(); }
    }

    Instantiator {
        model: Hyprland.toplevels
        delegate: Connections {
            required property var modelData
            target: modelData
            function onLastIpcObjectChanged() { Dispatcher.notifyAsync(); }
            function onTitleChanged() { Dispatcher.notifyAsync(); }
            function onWorkspaceChanged() { Dispatcher.notifyAsync(); }
        }
    }

    // Focusing must wait until the palette's close morph unmaps its exclusive-
    // focus layer: focusing earlier gets overridden when the unmap hands focus
    // to the window under the cursor (input:mouse_refocus).
    property var pendingFocus: null
    Timer {
        id: focusDelay
        interval: Motion.close + 110
        repeat: false
        onTriggered: {
            var e = windows.pendingFocus;
            windows.pendingFocus = null;
            if (!e)
                return;
            var w = e.toplevel ? e.toplevel.wayland : null;
            if (w)
                w.activate();
            else
                windows.focusWindow(e.address);
        }
    }

    function normAddr(addr) {
        var a = String(addr || "");
        return a.indexOf("0x") === 0 ? a : "0x" + a;
    }

    function focusWindow(addr) {
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + normAddr(addr) + '" })');
    }

    function entries() {
        var out = [];
        var tl = Hyprland.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var t = tl[i];
            var o = t && t.lastIpcObject;
            if (!o || !o.address)
                continue;
            if (o.workspace && String(o.workspace.name).indexOf("special:") === 0)
                continue;
            out.push({
                address: o.address,
                toplevel: t,
                title: o.title || o.class || "Window",
                cls: o.class || "",
                keywords: [o.class || ""]
            });
        }
        return out;
    }

    function rowFor(e) {
        return {
            id: "window:" + e.address,
            windowAddress: e.address,
            appId: e.cls,
            title: e.title,
            subtitle: e.cls,
            icon: e.cls ? Quickshell.iconPath(e.cls, "application-x-executable") : "",
            type: "Window",
            score: 5,
            actions: [{
                id: "focus",
                name: "Focus",
                icon: "",
                execute: function () {
                    windows.pendingFocus = e;
                    focusDelay.restart();
                }
            }]
        };
    }

    function query(text) {
        if (!refreshGate.running) {
            Hyprland.refreshToplevels();
            refreshGate.start();
        }
        var list = windows.entries();
        var q = (text || "").trim().toLowerCase();
        var rows = [];
        for (var i = 0; i < list.length; i++)
            if (q.length === 0 || Fuzzy.score({ name: list[i].title, keywords: list[i].keywords }, q) < 99)
                rows.push(windows.rowFor(list[i]));
        return rows;
    }

    Component.onCompleted: Dispatcher.register(windows);
}
