pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Needle: resident state of the Super+S chat, held in a singleton (not the
// sidebar body) so the thread and any in-flight answer survive a close/reopen;
// a new chat starts only after idleResetMs away. Turns run `ryoku-rashin chat`,
// streaming the shared hermes session as JSONL.
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
    // Session model picker: the models hermes offers, and the current one.
    property var models: []
    property string currentModel: ""

    // Emitted whenever the transcript changes so the view can scroll to end.
    signal touched()

    function noteOpened() {
        if (!busy && messages.count > 0 && lastSeen > 0 && (Date.now() - lastSeen) > root.idleResetMs)
            root.newChat();
        root.lastSeen = Date.now();
        root.loadModels();
    }

    function noteClosed() {
        root.lastSeen = Date.now();
    }

    // A new chat clears the transcript AND resets the hermes session, so the
    // next turn starts with no memory of the last one.
    function newChat() {
        if (root.busy)
            root.cancel();
        Quickshell.execDetached(["ryoku-rashin", "chat", "--new"]);
        messages.clear();
        root.liveIdx = -1;
        root.lastSeen = Date.now();
        root.touched();
    }

    function send(text, imagePaths) {
        var q = String(text).trim();
        var imgs = imagePaths || [];
        if ((q.length === 0 && imgs.length === 0) || root.busy)
            return;
        messages.append({ who: "user", body: q, imagesJson: JSON.stringify(imgs),
            working: "", streaming: false, failed: false });
        messages.append({ who: "agent", body: "", imagesJson: "[]",
            working: "waking the needle", streaming: true, failed: false });
        root.liveIdx = messages.count - 1;
        root.busy = true;
        root.lastSeen = Date.now();

        var cmd = ["ryoku-rashin", "chat"];
        for (var i = 0; i < imgs.length; i++) {
            cmd.push("--image");
            cmd.push(String(imgs[i]));
        }
        if (q.length > 0)
            cmd.push(q);
        chatProc.command = cmd;
        chatProc.running = true;
        root.touched();
    }

    function cancel() {
        chatProc.running = false;
        Quickshell.execDetached(["ryoku-rashin", "chat", "--cancel"]);
        if (root.liveIdx >= 0 && root.liveIdx < messages.count && messages.get(root.liveIdx).streaming) {
            messages.setProperty(root.liveIdx, "working", "");
            messages.setProperty(root.liveIdx, "streaming", false);
            if (messages.get(root.liveIdx).body.length === 0) {
                messages.setProperty(root.liveIdx, "failed", true);
                messages.setProperty(root.liveIdx, "body", "cancelled");
            }
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

    function loadModels() { modelsProc.running = true; }

    function setModel(id) {
        if (!id || id === root.currentModel)
            return;
        root.currentModel = String(id);
        Quickshell.execDetached(["ryoku-rashin", "chat", "--set-model", String(id)]);
    }

    ListModel { id: messages }

    Process {
        id: chatProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (root.liveIdx < 0 || root.liveIdx >= messages.count)
                    return;
                var i = root.liveIdx;
                var f;
                try {
                    f = JSON.parse(String(line));
                } catch (e) {
                    return;
                }
                if (!f || !f.type)
                    return;
                switch (f.type) {
                case "working":
                    messages.setProperty(i, "working", String(f.label || ""));
                    break;
                case "delta":
                    messages.setProperty(i, "body", messages.get(i).body + String(f.text || ""));
                    if (messages.get(i).working.length > 0)
                        messages.setProperty(i, "working", "");
                    root.touched();
                    break;
                case "perm":
                    messages.setProperty(i, "working", "waiting for approval: " + String(f.title || ""));
                    break;
                case "models":
                    root.models = f.models || [];
                    if (f.current)
                        root.currentModel = String(f.current);
                    break;
                case "done":
                    var imgs = f.images || [];
                    if (imgs.length > 0)
                        messages.setProperty(i, "imagesJson", JSON.stringify(imgs));
                    if (messages.get(i).body.length === 0 && imgs.length === 0) {
                        messages.setProperty(i, "body", "(no response)");
                        messages.setProperty(i, "failed", true);
                    }
                    messages.setProperty(i, "working", "");
                    messages.setProperty(i, "streaming", false);
                    root.busy = false;
                    root.liveIdx = -1;
                    root.lastSeen = Date.now();
                    root.touched();
                    break;
                case "error":
                    if (messages.get(i).body.length === 0)
                        messages.setProperty(i, "body", String(f.message || "failed"));
                    messages.setProperty(i, "failed", true);
                    messages.setProperty(i, "working", "");
                    messages.setProperty(i, "streaming", false);
                    root.busy = false;
                    root.liveIdx = -1;
                    root.lastSeen = Date.now();
                    root.touched();
                    break;
                }
            }
        }
        onExited: (code) => {
            if (root.liveIdx >= 0 && root.liveIdx < messages.count && messages.get(root.liveIdx).streaming) {
                messages.setProperty(root.liveIdx, "working", "");
                messages.setProperty(root.liveIdx, "streaming", false);
                if (messages.get(root.liveIdx).body.length === 0) {
                    messages.setProperty(root.liveIdx, "failed", true);
                    messages.setProperty(root.liveIdx, "body", code === 0 ? "no answer" : "chat failed");
                }
            }
            root.busy = false;
            root.liveIdx = -1;
            root.lastSeen = Date.now();
            root.touched();
        }
    }

    Process {
        id: modelsProc
        command: ["ryoku-rashin", "chat", "--models"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                var f;
                try { f = JSON.parse(String(line)); } catch (e) { return; }
                if (f && f.type === "models") {
                    root.models = f.models || [];
                    if (f.current) root.currentModel = String(f.current);
                }
            }
        }
    }
}
