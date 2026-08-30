pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper depth config, mirroring the visualiser (docs/depth.md). depth.json
// (watched, self-seeded) holds the shell-owned render knobs; whether depth is on
// is per-wallpaper and daemon-owned -- `enabled` reflects the current wallpaper's
// effective state, read from the daemon's registry, set through the daemon.
Singleton {
    id: root

    // Effective for the wallpaper on screen now: the daemon's per-wall registry,
    // watched read-only (the daemon is the sole writer, via setEnabled -> IPC).
    readonly property bool enabled: wallsData.current
    property alias model: adapter.model
    property alias feather: adapter.feather
    property alias lift: adapter.lift
    property alias front: adapter.front
    property alias alphaMatting: adapter.alphaMatting
    property alias shadow: adapter.shadow

    // Filtered to what the engine actually carries by DepthBackend.
    readonly property var knownModels: ["u2netp", "birefnet-general-lite"]

    function isFront(id) {
        return (adapter.front || []).indexOf(id) >= 0;
    }

    function setEnabled(on) {
        setEnabledProc.command = ["ryoku-shell", "depth", "set-enabled", on === true ? "1" : "0"];
        setEnabledProc.running = false;
        setEnabledProc.running = true;
    }
    function setModel(m) {
        if (root.knownModels.indexOf(m) < 0)
            return;
        adapter.model = m;
        file.writeAdapter();
        root.refresh();
    }
    function setAlphaMatting(on) {
        adapter.alphaMatting = on === true;
        file.writeAdapter();
        root.refresh();
    }
    function setFeather(v) {
        adapter.feather = Math.max(0, Math.min(1, v));
        settle.restart();
    }
    function setLift(v) {
        adapter.lift = Math.max(0.2, Math.min(1, v));
        settle.restart();
    }
    function toggleFront(id) {
        var arr = (adapter.front || []).slice();
        var i = arr.indexOf(id);
        if (i >= 0)
            arr.splice(i, 1);
        else
            arr.push(id);
        adapter.front = arr;
        settle.restart();
    }
    // Quality folds the model and edge-matting knobs into three plain tiers, so
    // the UI never exposes "u2netp" or "alpha matting".
    function setQuality(level) {
        if (level === "fine") {
            adapter.model = "birefnet-general-lite";
            adapter.alphaMatting = true;
        } else if (level === "standard") {
            adapter.model = "u2netp";
            adapter.alphaMatting = true;
        } else {
            adapter.model = "u2netp";
            adapter.alphaMatting = false;
        }
        file.writeAdapter();
        root.refresh();
    }
    function qualityLevel() {
        if (adapter.model === "birefnet-general-lite")
            return "fine";
        return adapter.alphaMatting ? "standard" : "draft";
    }
    function setShadow(v) {
        adapter.shadow = Math.max(0, Math.min(1, v));
        settle.restart();
    }

    function refresh() {
        refreshProc.running = false;
        refreshProc.running = true;
    }
    Process {
        id: refreshProc
        command: ["ryoku-shell", "depth", "refresh"]
    }
    Process {
        id: setEnabledProc
        command: ["ryoku-shell", "depth", "set-enabled", "0"]
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: file.writeAdapter()
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/depth.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string model: "u2netp"
            property real feather: 0.15
            property real lift: 1.0
            property var front: []
            property bool alphaMatting: false
            property real shadow: 0.0
        }
    }

    // The daemon's per-wall depth registry: `current` is depth's effective state
    // for the wallpaper on screen now. Read-only here; setEnabled goes through the
    // daemon so the opt-in persists and survives wallpaper switches and reboots.
    FileView {
        id: walls
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/depth-walls.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: wallsData
            property bool current: false
        }
    }

    Component.onCompleted: if (!file.text())
        file.writeAdapter()
}
