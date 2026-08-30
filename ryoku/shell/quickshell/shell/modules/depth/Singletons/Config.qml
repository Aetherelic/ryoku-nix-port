pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live config for the wallpaper depth effect (docs/depth.md): the wallpaper's
// subject, cut out and drawn in front of the desktop widgets. Mirrors the
// visualiser's Config exactly - a watched, atomically-written, GUI-managed
// depth.json under ~/.config/ryoku, self-seeded on first run. Because the
// package ships no file here, an update never clobbers it (docs/updates.md).
//
// enabled/model changes need a fresh cutout, so they nudge the daemon to
// regenerate; feather/lift/front are pure render knobs and only settle to disk.
Singleton {
    id: root

    property alias enabled: adapter.enabled // master on/off (also the daemon's cue)
    property alias model: adapter.model     // segmentation model id
    property alias feather: adapter.feather // edge softness, 0..1
    property alias lift: adapter.lift        // foreground strength, 0.2..1
    property alias front: adapter.front      // widget ids drawn ABOVE the cutout

    // The models the UI may offer; DepthBackend filters this to what is actually
    // installed, so the pick never lists a model the engine can't run.
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

    // Ask the daemon to (re)generate the cutout for the current wallpaper. The
    // daemon owns the slow model run; this is a cheap, immediate ack.
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
