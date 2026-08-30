pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper depth config: a watched, self-seeded ~/.config/ryoku/depth.json,
// mirroring the visualiser (docs/depth.md). enabled/model changes ask the daemon
// to regenerate the cutout; feather/lift/front are render-only.
Singleton {
    id: root

    property alias enabled: adapter.enabled
    property alias model: adapter.model
    property alias feather: adapter.feather
    property alias lift: adapter.lift
    property alias front: adapter.front

    // Filtered to what the engine actually carries by DepthBackend.
    readonly property var knownModels: ["u2netp", "birefnet-general-lite"]

    function isFront(id) {
        return (adapter.front || []).indexOf(id) >= 0;
    }

    function setEnabled(on) {
        adapter.enabled = on === true;
        file.writeAdapter();
        root.refresh();
    }
    function setModel(m) {
        if (root.knownModels.indexOf(m) < 0)
            return;
        adapter.model = m;
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

    function refresh() {
        refreshProc.running = false;
        refreshProc.running = true;
    }
    Process {
        id: refreshProc
        command: ["ryoku-shell", "depth", "refresh"]
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
            property bool enabled: false
            property string model: "u2netp"
            property real feather: 0.15
            property real lift: 1.0
            property var front: []
        }
    }

    Component.onCompleted: if (!file.text())
        file.writeAdapter()
}
