pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Needle: the resident state of the Super+S chat with the Rashin agent. It
// lives in a singleton, not the sidebar body, so the conversation and any
// in-flight answer survive the sidebar closing and reopening (the body is torn
// down every close). A fresh chat starts only when the sidebar has been away
// longer than idleResetMs; a quick close/reopen keeps the thread. The ask
// Process also lives here, so a long answer keeps streaming into the
// transcript even while the sidebar is shut.
Singleton {
    id: root

    // How long the sidebar must be gone before reopening starts a new chat.
    readonly property int idleResetMs: 10 * 60 * 1000

    readonly property alias convo: messages
    property bool busy: false
    // Index of the agent bubble the live stream is filling.
    property int liveIdx: -1
    // Wall-clock ms of the last open/close/turn; drives the idle reset.
    property double lastSeen: 0

    // Emitted whenever the transcript changes so the view can scroll to end.
    signal touched()

    // Called by the sidebar body when it mounts. Resets to a new chat only if
    // the sidebar has been away past the idle window and nothing is streaming.
    function noteOpened() {
        if (!busy && messages.count > 0 && lastSeen > 0 && (Date.now() - lastSeen) > root.idleResetMs)
            root.newChat();
        root.lastSeen = Date.now();
    }

    // Called by the body on teardown (close or tab switch); starts the idle clock.
    function noteClosed() {
        root.lastSeen = Date.now();
    }

    function newChat() {
        if (root.busy)
            root.cancel();
        messages.clear();
        root.liveIdx = -1;
        root.lastSeen = Date.now();
        root.touched();
    }

    function send(text) {
        var q = String(text).trim();
        if (q.length === 0 || root.busy)
            return;
        messages.append({ who: "user", body: q, imagesJson: "[]",
            working: "", streaming: false, failed: false });
        messages.append({ who: "agent", body: "", imagesJson: "[]",
            working: "waking the needle", streaming: true, failed: false });
        root.liveIdx = messages.count - 1;
        root.busy = true;
        root.lastSeen = Date.now();
        askProc.command = ["ryoku-rashin", "ask", q];
        askProc.running = true;
        root.touched();
    }

    function cancel() {
        askProc.running = false;
        Quickshell.execDetached(["ryoku-rashin", "ask", "--cancel"]);
        if (root.liveIdx >= 0 && root.liveIdx < messages.count && messages.get(root.liveIdx).streaming) {
            messages.setProperty(root.liveIdx, "working", "");
            messages.setProperty(root.liveIdx, "streaming", false);
            messages.setProperty(root.liveIdx, "failed", true);
            messages.setProperty(root.liveIdx, "body", "cancelled");
        }
        root.busy = false;
        root.liveIdx = -1;
        root.lastSeen = Date.now();
    }

    function copyText(t) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", String(t)]);
    }

    function openDashboard() {
        Quickshell.execDetached(["xdg-open", "http://127.0.0.1:3600/#/chat"]);
    }

    ListModel { id: messages }

    Process {
        id: askProc
        stdout: SplitParser {
            onRead: (line) => {
                if (root.liveIdx < 0 || root.liveIdx >= messages.count)
                    return;
                var i = root.liveIdx;
                line = String(line);
                if (line.indexOf("@working ") === 0) {
                    messages.setProperty(i, "working", line.slice(9));
                } else if (line.indexOf("@perm ") === 0) {
                    messages.setProperty(i, "working", "waiting for approval: " + line.slice(6));
                } else if (line.indexOf("@answer ") === 0) {
                    try {
                        var a = JSON.parse(line.slice(8));
                        messages.setProperty(i, "body", String(a.text || ""));
                        messages.setProperty(i, "imagesJson", JSON.stringify(a.images || []));
                        messages.setProperty(i, "working", "");
                        messages.setProperty(i, "streaming", false);
                    } catch (e) {
                        messages.setProperty(i, "body", "unreadable answer");
                        messages.setProperty(i, "failed", true);
                        messages.setProperty(i, "streaming", false);
                    }
                    root.lastSeen = Date.now();
                    root.touched();
                } else if (line.indexOf("@error ") === 0) {
                    messages.setProperty(i, "body", line.slice(7));
                    messages.setProperty(i, "failed", true);
                    messages.setProperty(i, "streaming", false);
                }
            }
        }
        onExited: (code) => {
            if (root.liveIdx >= 0 && root.liveIdx < messages.count && messages.get(root.liveIdx).streaming) {
                messages.setProperty(root.liveIdx, "working", "");
                messages.setProperty(root.liveIdx, "streaming", false);
                messages.setProperty(root.liveIdx, "failed", true);
                messages.setProperty(root.liveIdx, "body", code === 0 ? "no answer" : "ask failed");
            }
            root.busy = false;
            root.liveIdx = -1;
            root.lastSeen = Date.now();
            root.touched();
        }
    }
}
