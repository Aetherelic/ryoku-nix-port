pragma Singleton
import QtQuick
import Quickshell

// Session view state for the switcher: which layout renders the entries and how
// they sort. Held in memory only, so it survives a reopen within a shell session
// but needs no shell.json key and no doctor reconciler (the "focused"
// customization surface). Mode and the type/colour filters are transient body
// state that resets each open; only the view shape and sort order persist here.
Singleton {
    id: root

    // "filmstrip" (tanzaku) | "carousel" (skewed slices) | "grid" | "drift" (two-line)
    property string layout: "filmstrip"
    readonly property var layouts: ["filmstrip", "carousel", "grid", "drift"]
    function cycleLayout() {
        var i = root.layouts.indexOf(root.layout);
        root.layout = root.layouts[(i + 1) % root.layouts.length];
    }
    function layoutLabel(id) {
        return id === "filmstrip" ? "Filmstrip" : id === "carousel" ? "Carousel" : id === "grid" ? "Grid" : "Drift";
    }

    // "colour" (hue buckets, the scan's own order) | "recent" (mtime) | "name"
    property string sort: "colour"
    readonly property var sorts: ["colour", "recent", "name"]
    function cycleSort() {
        var i = root.sorts.indexOf(root.sort);
        root.sort = root.sorts[(i + 1) % root.sorts.length];
    }
    function sortLabel(id) {
        return id === "colour" ? "Colour" : id === "recent" ? "Recent" : "Name";
    }
}
