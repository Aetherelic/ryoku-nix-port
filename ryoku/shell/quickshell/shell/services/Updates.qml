pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live view of the daemon "updates" topic (ryoku status --json). The background
// check lives in the daemon; this just parses the streamed frame so the bar glyph
// reflects it without polling.
Singleton {
    id: root

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    property var frame: ({})
    readonly property bool available: root.frame.available === true
    readonly property int pending: root.frame.pendingUpdates || 0
    readonly property string channel: root.frame.channel || ""
    readonly property string installed: root.frame.installedVersion || ""
    readonly property string latest: root.frame.latestVersion || ""
    readonly property var commits: root.frame.updates || []
    readonly property var packages: root.frame.packages || []

    function check() { root.send("updates.check", {}); }

    function apply(line) {
        try {
            root.frame = JSON.parse(line);
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
}
