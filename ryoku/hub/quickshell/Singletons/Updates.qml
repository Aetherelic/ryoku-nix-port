pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Updates view for the Hub, fed by the daemon "updates" topic (ryoku status
// --json). The daemon owns the background check; check() forces a fresh run.
Singleton {
    id: root

    // Some distributions own system updates outside Ryoku.
    readonly property bool externalSystemUpdates:
        Quickshell.env("RYOKU_SYSTEM_UPDATES_EXTERNAL") === "1"

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    property bool available: false
    property string currentVersion: ""
    property string latestVersion: ""
    property string branch: "main"
    property int behind: 0

    // Ryoku channel commits (when behind) and recent history (when current).
    property var updates: []
    property var recent: []
    // system packages a `pacman -Syu` would pull: [{ name, old, new }].
    property var packages: []

    property var lastChecked: null
    property int tick: 0
    readonly property string checkedAgo: {
        root.tick;
        if (!root.lastChecked)
            return "not yet";
        var s = Math.floor((Date.now() - root.lastChecked.getTime()) / 1000);
        if (s < 10)
            return "just now";
        if (s < 60)
            return s + "s ago";
        var m = Math.floor(s / 60);
        if (m < 60)
            return m + "m ago";
        var h = Math.floor(m / 60);
        if (h < 24)
            return h + "h ago";
        return Math.floor(h / 24) + "d ago";
    }

    function check() {
        if (root.externalSystemUpdates)
            return;

        root.send("updates.check", {});
    }

    function apply(t) {
        try {
            var o = JSON.parse(t);
            root.currentVersion = o.installedVersion || "";
            root.latestVersion = o.latestVersion || "";
            root.branch = o.channel || "main";
            root.behind = o.pendingUpdates || 0;
            root.updates = o.updates || [];
            root.recent = o.recent || [];
            root.packages = o.packages || [];
            root.available = o.available === true;
            root.lastChecked = new Date();
        } catch (e) {}
    }

    function send(method, args) {
        ctl.queued += "call " + method + " " + JSON.stringify(args) + "\n";
        if (ctl.connected)
            ctl.flushQueued();
        else
            ctl.connected = true;
    }

    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser { onRead: line => root.apply(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe updates\n");
                flush();
            } else {
                retry.restart();
            }
        }
    }

    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected) sub.connected = true
    }

    Socket {
        id: ctl
        path: root.sockPath
        property string queued: ""
        function flushQueued() {
            if (queued.length === 0)
                return;
            write(queued);
            flush();
            queued = "";
        }
        onConnectionStateChanged: if (connected) flushQueued()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.tick++
    }

    Component.onCompleted: root.check()
}
