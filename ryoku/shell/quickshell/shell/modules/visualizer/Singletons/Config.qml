pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// live config for the desktop visualiser. single source of truth for the
// knobs Ryoku Settings' Shell section edits + the defaults it falls back to.
// JSON at ~/.config/ryoku/visualizer.json, watched, so a save in Ryoku
// Settings (or a Super+M toggle) retunes the running spectrum on the next
// file event, no reload. defaults here are canonical; Ryoku Settings mirrors
// them for reset-to-default.
//
// fractions are of the monitor height or the per-band slot, matching how the
// spectrum sizes itself, so they stay right across resolutions.
Singleton {
    id: root

    property alias enabled:    adapter.enabled     // master on/off (also Super+M)
    property alias bars:       adapter.bars        // cava band count
    property alias height:     adapter.height      // tallest bar, fraction of screen height
    property alias thickness:  adapter.thickness   // bar width, fraction of its slot
    property alias bloom:      adapter.bloom       // glow behind bars while playing
    property alias reflection: adapter.reflection  // mirrored band height, fraction of screen (0 = off)
    property alias idleWave:   adapter.idleWave    // breathing line while silent
    property alias style:      adapter.style       // bars | split | dots | segments | wave | ribbon | line | radial | orb | spiral
    property alias shape:      adapter.shape       // rounded | flat (bar/dot cap)
    property alias position:   adapter.position    // bottom | top | center | left | right
    property alias mirror:     adapter.mirror      // symmetric low->high->low band order
    property alias segments:   adapter.segments    // lit blocks per band in the segments style

    // where the look sits. an edge look covers `span` of its edge, aligned by
    // `align`; a polar look is centred on origin and sized by `size`, which is
    // what makes the ring and the orb placeable at all.
    property alias span:       adapter.span        // fraction of the edge covered
    property alias align:      adapter.align       // start | center | end
    property alias originX:    adapter.originX     // polar centre, fraction of the screen
    property alias originY:    adapter.originY
    property alias size:       adapter.size        // polar radius, fraction of the short edge
    property alias spin:       adapter.spin        // polar rotation, degrees a second

    // motion + budget. fps is the render ceiling (cava is fed at the same rate);
    // adaptive sheds effects and rate under sustained load, never the spectrum.
    property alias fps:        adapter.fps         // 30 default, up to 60
    property alias adaptive:   adapter.adaptive    // auto-throttle under load
    property alias smoothing:  adapter.smoothing   // decay slowness, 0 snappy .. 1 fluid
    property alias gain:       adapter.gain         // level multiplier before clamp
    property alias peaks:      adapter.peaks       // falling peak caps on bars/segments

    // The looks the renderer knows. `circle` grew into `orb` (a lit sphere
    // rather than an outline), so a config written before that reads as orb and
    // is rewritten once, rather than needing a doctor reconciler.
    readonly property var knownStyles: ["bars", "split", "dots", "segments", "wave",
                                        "ribbon", "curtain", "line", "radial", "orb", "spiral"]
    readonly property string styleId: root.knownStyles.indexOf(adapter.style) >= 0 ? adapter.style
        : (adapter.style === "circle" ? "orb" : "bars")

    // persist on/off so the hub toggle and Super+M keybind agree, and it
    // survives a restart.
    function setEnabled(on) {
        adapter.enabled = on;
        file.writeAdapter();
    }

    // Placement from the desktop: the properties move with the pointer so the
    // look follows the drag frame by frame, and the file is written once the
    // gesture settles rather than on every step of it.
    function place(x, y) {
        adapter.originX = Math.max(0, Math.min(1, x));
        adapter.originY = Math.max(0, Math.min(1, y));
        settle.restart();
    }
    function resize(s) {
        adapter.size = Math.max(0.1, Math.min(0.6, s));
        settle.restart();
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: file.writeAdapter()
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/visualizer.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool enabled: true
            property int bars: 64
            property real height: 0.42
            property real thickness: 0.58
            property real bloom: 0.6
            property real reflection: 0.1
            property bool idleWave: true
            property string style: "bars"
            property string shape: "rounded"
            property string position: "bottom"
            property bool mirror: false
            property int segments: 10
            property int fps: 30
            property bool adaptive: true
            property real smoothing: 0.5
            property real gain: 1.0
            property bool peaks: false
            property real span: 1.0
            property string align: "center"
            property real originX: 0.5
            property real originY: 0.5
            property real size: 0.30
            property real spin: 0
        }
    }

    Component.onCompleted: {
        if (!file.text()) {
            file.writeAdapter();
            return;
        }
        if (adapter.style === "circle") {
            adapter.style = "orb";
            file.writeAdapter();
        }
    }
}
