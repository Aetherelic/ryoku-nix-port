pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// View state for the switcher: which layout renders the entries, how they sort,
// and the live-preview toggle. Persisted to
// ~/.local/state/ryoku/wallpaper-view.json so the chosen scrolling design
// survives a shell refresh or a reboot.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"

    // "strips" (hero preview + shelf) | "hearthstone" (fanned cards) |
    // "drift" (two drifting belts) | "grid" (scan)
    property string layout: "grid"
    readonly property var layouts: ["strips", "hearthstone", "drift", "grid"]
    function cycleLayout() {
        var i = root.layouts.indexOf(root.layout);
        root.layout = root.layouts[(i + 1) % root.layouts.length];
    }
    function layoutLabel(id) {
        return id === "grid" ? "Grid"
            : id === "hearthstone" ? "Hearthstone"
            : id === "drift" ? "Drift" : "Strips";
    }

    // apply the focused wallpaper to the desktop while browsing (live canvas).
    property bool livePreview: true

    // "colour" (hue buckets) | "recent" (mtime) | "name"
    property string sort: "colour"
    readonly property var sorts: ["colour", "recent", "name"]
    function cycleSort() {
        var i = root.sorts.indexOf(root.sort);
        root.sort = root.sorts[(i + 1) % root.sorts.length];
    }
    function sortLabel(id) {
        return id === "colour" ? "Colour" : id === "recent" ? "Recent" : "Name";
    }

    // don't echo the file back into itself while loading it into the properties.
    property bool _loaded: false
    function persist() {
        if (!root._loaded)
            return;
        file.setText(JSON.stringify({ layout: root.layout, sort: root.sort, livePreview: root.livePreview }));
    }
    onLayoutChanged: persist()
    onSortChanged: persist()
    onLivePreviewChanged: persist()

    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: file
        path: root.stateDir + "/wallpaper-view.json"
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                var o = JSON.parse(file.text() || "{}");
                if (root.layouts.indexOf(o.layout) >= 0)
                    root.layout = o.layout;
                if (root.sorts.indexOf(o.sort) >= 0)
                    root.sort = o.sort;
                if (typeof o.livePreview === "boolean")
                    root.livePreview = o.livePreview;
            } catch (e) {}
            root._loaded = true;
        }
        onLoadFailed: root._loaded = true
    }
}
