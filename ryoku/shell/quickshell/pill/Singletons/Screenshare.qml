pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// QML view of the daemon `screenshare` topic. The desktop portal drives the
// share picker: xdph runs the ryoku-share helper, which asks the daemon over the
// socket, and the daemon streams the parsed candidate windows here while it
// blocks for a choice. The picker menu reads `programs` and, on a selection or a
// dismissal, calls reply() once. The selection strings are the portal's own wire
// format, sent back verbatim (contracts 09 and 15); QML never speaks to the
// portal directly.
Singleton {
    id: root

    // The current request. active is true while the daemon is blocked waiting;
    // requestId keys the reply so a stale menu cannot answer a newer request.
    property bool active: false
    property int requestId: 0
    property var programs: []
    // The last request this view already answered, so a selection and the
    // dismissal fallback never both reply.
    property int resolvedFor: 0

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    function apply(line) {
        try {
            const frame = JSON.parse(line);
            root.active = frame.active === true;
            root.requestId = frame.requestId || 0;
            root.programs = Array.isArray(frame.programs) ? frame.programs : [];
        } catch (e) {
            // A malformed frame must never wedge the picker; keep the last set.
        }
    }

    // Answer the in-flight request exactly once. sel is a portal reply string
    // ("[SELECTION]/screen:...", "/window:...", "/region:...") or "" to cancel.
    function reply(sel) {
        if (!root.active || root.requestId === 0 || root.requestId === root.resolvedFor)
            return;
        root.resolvedFor = root.requestId;
        root.send("screenshare.reply", { requestId: root.requestId, selection: sel });
    }

    function send(method, args) {
        ctl.queued += "call " + method + " " + JSON.stringify(args) + "\n";
        if (ctl.connected)
            ctl.flushQueued();
        else
            ctl.connected = true;
    }

    // Subscription: connect, ask once, then stream. A second write to this
    // connection would half-close the stream (daemon rule), so replies use ctl.
    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser { onRead: line => root.apply(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe screenshare\n");
                flush();
            } else {
                root.active = false;
                root.programs = [];
                retry.restart();
            }
        }
    }

    // The daemon may be down when the shell loads (or restart under it); retry
    // quietly so the picker works again once it returns.
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
