pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

/**
 * ~/Downloads/Stash: the download landing plus the compress/install backends.
 * A live FolderListModel tracks the folder (created on first load); cobalt
 * drives a one-at-a-time download queue through stash-cobalt.sh, and
 * requestInstall/requestCompress raise a confirm then run the helper.
 * hasMedia / hasInstallable read the live file types so the tools only light
 * when they apply.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: home + "/Downloads/Stash"
    readonly property string scriptDir: home + "/.config/hypr/scripts"
    readonly property string cobaltScript: scriptDir + "/stash-cobalt.sh"

    readonly property alias files: files
    readonly property int count: files.count
    readonly property alias queueModel: queueModel

    // Live file-type read so the tools light only what applies.
    readonly property bool hasMedia: {
        var n = files.count;
        for (var i = 0; i < n; i++) {
            var nm = ("" + files.get(i, "fileName")).toLowerCase();
            var e = nm.substring(nm.lastIndexOf(".") + 1);
            if (/^(mp4|mkv|webm|mov|avi|m4v|mp3|flac|wav|ogg|opus|m4a|aac|png|jpe?g|webp|gif|bmp|tif|tiff)$/.test(e))
                return true;
        }
        return false;
    }
    readonly property bool hasInstallable: {
        var n = files.count;
        for (var i = 0; i < n; i++) {
            var nm = ("" + files.get(i, "fileName")).toLowerCase();
            if (/\.(appimage|flatpak|deb|rpm|tar\.gz|tgz|tar\.xz|tar\.bz2|tar\.zst|tar)$/.test(nm))
                return true;
        }
        return false;
    }

    // Install / compress confirm state.
    property string task: ""              // "" | install | compress
    property string taskState: "idle"     // idle | confirm | running | done | error
    property string taskMsg: ""
    signal authStepAside(string monitor, string surfaceId)
    property string taskMonitor: ""
    property string taskSurfaceId: ""

    // Cobalt download queue.
    property string dlMode: "auto"        // auto | audio | mute
    property int activeJob: -1            // index of the running queue entry, -1 idle

    function openFile(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }

    function removeFile(path) {
        Quickshell.execDetached(["rm", "-f", path]);
    }

    function clearAll() {
        Quickshell.execDetached(["sh", "-c", "rm -f \"$1\"/*", "--", root.dir]);
    }

    // ── Install / compress ──────────────────────────────────────────────
    function requestInstall(monitor, surfaceId) {
        if (root.hasInstallable) {
            root.task = "install";
            root.taskMsg = "";
            root.taskState = "confirm";
            root.taskMonitor = monitor || "";
            root.taskSurfaceId = surfaceId || "";
        }
    }

    function requestCompress(monitor, surfaceId) {
        if (root.hasMedia) {
            root.task = "compress";
            root.taskMsg = "";
            root.taskState = "confirm";
            root.taskMonitor = monitor || "";
            root.taskSurfaceId = surfaceId || "";
        }
    }

    function confirmTask() {
        if (root.task === "install")
            runTask("install", ["bash", root.scriptDir + "/stash-install.sh"]);
        else if (root.task === "compress")
            runTask("compress", ["bash", root.scriptDir + "/stash-compress.sh"]);
    }

    function runTask(name, cmd) {
        root.task = name;
        root.taskMsg = "";
        root.taskState = "running";
        taskProc.command = cmd;
        taskProc.running = true;
    }

    function dismissTask() {
        root.task = "";
        root.taskState = "idle";
        root.taskMsg = "";
        root.taskMonitor = "";
        root.taskSurfaceId = "";
    }

    // ── Cobalt download + remux ─────────────────────────────────────────
    function enqueueDownload(url, mode) {
        var u = ("" + url).trim();
        if (u.length === 0)
            return;
        queueModel.append({ kind: "download", arg: u, mode: mode || root.dlMode,
            name: "link", state: "queued", pct: 0, msg: "" });
        pumpQueue();
    }

    function enqueueRemux(file) {
        queueModel.append({ kind: "remux", arg: file, mode: "",
            name: ("" + file).split("/").pop(), state: "queued", pct: 0, msg: "" });
        pumpQueue();
    }

    // One worker at a time walks the queue, so a burst of links downloads in
    // order instead of fighting over the network.
    function pumpQueue() {
        if (root.activeJob >= 0)
            return;
        for (var i = 0; i < queueModel.count; i++) {
            if (queueModel.get(i).state === "queued") {
                root.activeJob = i;
                queueModel.setProperty(i, "state", "running");
                var e = queueModel.get(i);
                workerProc.command = e.kind === "remux"
                    ? ["bash", root.cobaltScript, "remux", e.arg]
                    : ["bash", root.cobaltScript, "download", e.arg, e.mode];
                workerProc.running = true;
                return;
            }
        }
    }

    function onWorkerLine(line) {
        if (root.activeJob < 0)
            return;
        var i = root.activeJob;
        var t = ("" + line).split("\t");
        if (t[0] === "START") {
            if (t[1]) queueModel.setProperty(i, "name", t[1]);
        } else if (t[0] === "PROGRESS") {
            queueModel.setProperty(i, "pct", parseInt(t[1]) || 0);
        } else if (t[0] === "SAVED") {
            if (t[1]) queueModel.setProperty(i, "name", t[1]);
            queueModel.setProperty(i, "state", "done");
        } else if (t[0] === "ERROR") {
            queueModel.setProperty(i, "msg", t[1] || "failed");
            queueModel.setProperty(i, "state", "error");
        }
    }

    function clearQueueDone() {
        for (var i = queueModel.count - 1; i >= 0; i--) {
            var s = queueModel.get(i).state;
            if (s === "done" || s === "error")
                queueModel.remove(i);
        }
    }

    FolderListModel {
        id: files
        folder: "file://" + root.dir
        showDirs: false
        showHidden: false
        nameFilters: ["*"]
    }

    ListModel {
        id: queueModel
    }

    Process {
        id: taskProc
        property string lastLine: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                var l = ("" + line).trim();
                if (l === "@AUTH") {
                    root.authStepAside(root.taskMonitor, root.taskSurfaceId);
                    return;
                }
                if (l.length > 0)
                    taskProc.lastLine = l;
            }
        }
        onExited: (exitCode) => {
            root.taskMsg = taskProc.lastLine;
            root.taskState = exitCode === 0 ? "done" : "error";
        }
    }

    Process {
        id: workerProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.onWorkerLine(line)
        }
        onExited: (code) => {
            if (root.activeJob >= 0) {
                var st = queueModel.get(root.activeJob).state;
                if (st === "running")
                    queueModel.setProperty(root.activeJob, "state", code === 0 ? "done" : "error");
            }
            root.activeJob = -1;
            root.pumpQueue();
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])
}
