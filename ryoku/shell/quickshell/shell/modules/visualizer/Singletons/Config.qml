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
    property alias thickness:  adapter.thickness   // bar width, fraction of its slot
    property alias bloom:      adapter.bloom       // glow behind bars while playing
    property alias reflection: adapter.reflection  // mirrored band height, fraction of the box
    property alias idleWave:   adapter.idleWave    // breathing line while silent
    property alias style:      adapter.style       // see knownStyles
    property alias shape:      adapter.shape       // rounded | flat (bar/dot cap)
    property alias mirror:     adapter.mirror      // symmetric low->high->low band order
    property alias segments:   adapter.segments    // lit blocks per band in the segments style
    property alias spin:       adapter.spin        // polar rotation, degrees a second

    // The box the look lives in, as fractions of the screen, and which of its
    // edges the bands grow from. One free rectangle replaced the old anchored
    // position/span/align/height/originX/originY/size set: a look can sit
    // anywhere, and it is dragged and sized on the desktop rather than typed in.
    property alias x:          adapter.x
    property alias y:          adapter.y
    property alias w:          adapter.w
    property alias h:          adapter.h
    property alias grow:       adapter.grow        // up | down | center | left | right
    property alias angle:      adapter.angle       // whole-look turn about the box centre, degrees

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
    // The polar three sit at the tail of the list, so one index decides the family.
    readonly property bool isPolar: root.knownStyles.indexOf(root.styleId) >= 8

    // persist on/off so the hub toggle and Super+M keybind agree, and it
    // survives a restart.
    function setEnabled(on) {
        adapter.enabled = on;
        file.writeAdapter();
    }

    // Placement from the desktop: the properties move with the pointer so the
    // look follows the drag frame by frame, and the file is written once the
    // gesture settles rather than on every step of it.
    function moveBox(nx, ny) {
        adapter.x = Math.max(-0.25, Math.min(1.25 - adapter.w, nx));
        adapter.y = Math.max(-0.25, Math.min(1.25 - adapter.h, ny));
        settle.restart();
    }
    function sizeBox(nw, nh) {
        adapter.w = Math.max(0.04, Math.min(1.5, nw));
        adapter.h = Math.max(0.03, Math.min(1.5, nh));
        settle.restart();
    }
    // A free turn about the box centre, wrapped so a full circle of dragging never
    // runs into a stop.
    function rotate(deg) {
        var d = deg % 360;
        adapter.angle = d < 0 ? d + 360 : d;
        settle.restart();
    }
    // Flip mirrors what is on screen, which is a different thing per family: an
    // edge look swaps the edge its bands grow from, a centred one reverses the band
    // order it is symmetric about, and a polar one reverses the way it turns.
    function flip() {
        if (root.isPolar)
            adapter.spin = -adapter.spin;
        else if (adapter.grow === "up")
            adapter.grow = "down";
        else if (adapter.grow === "down")
            adapter.grow = "up";
        else if (adapter.grow === "left")
            adapter.grow = "right";
        else if (adapter.grow === "right")
            adapter.grow = "left";
        else
            adapter.mirror = !adapter.mirror;
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
            property real thickness: 0.58
            property real bloom: 0.6
            property real reflection: 0.1
            property bool idleWave: true
            property string style: "bars"
            property string shape: "rounded"
            property bool mirror: false
            property int segments: 10
            property int fps: 30
            property bool adaptive: true
            property real smoothing: 0.5
            property real gain: 1.0
            property bool peaks: false
            property real spin: 0
            property real x: 0
            property real y: 0.58
            property real w: 1
            property real h: 0.42
            property string grow: "up"
            property real angle: 0
        }
    }

    // A config written before the box existed carries an anchored position,
    // height, span and origin instead; fold those into the box once so the
    // spectrum stays where its owner put it, then keep only the box.
    function migrate() {
        var o = {};
        try {
            o = JSON.parse(file.text()) || {};
        } catch (e) {
            return false;
        }
        if (o.x !== undefined)
            return o.style === "circle";
        var pos = o.position || "bottom";
        var depth = typeof o.height === "number" ? o.height : 0.42;
        var span = typeof o.span === "number" ? o.span : 1;
        var align = o.align || "center";
        var polar = ["radial", "orb", "spiral", "circle"].indexOf(o.style) >= 0;
        if (polar) {
            var r = (typeof o.size === "number" ? o.size : 0.3);
            var ox = typeof o.originX === "number" ? o.originX : 0.5;
            var oy = typeof o.originY === "number" ? o.originY : 0.5;
            adapter.w = r * 2 * 0.625;   // the radius was a fraction of the short edge
            adapter.h = r * 2;
            adapter.x = ox - adapter.w / 2;
            adapter.y = oy - adapter.h / 2;
            adapter.grow = "center";
        } else {
            var off = align === "start" ? 0 : (align === "end" ? 1 - span : (1 - span) / 2);
            var vertical = pos === "left" || pos === "right";
            adapter.w = vertical ? depth : span;
            adapter.h = vertical ? span : depth;
            adapter.x = pos === "right" ? 1 - depth : (vertical ? 0 : off);
            adapter.y = pos === "top" ? 0
                : (pos === "center" ? (1 - depth) / 2 : (vertical ? off : 1 - depth));
            adapter.grow = pos === "top" ? "down"
                : (pos === "center" ? "center"
                : (pos === "left" ? "right" : (pos === "right" ? "left" : "up")));
        }
        return true;
    }

    Component.onCompleted: {
        if (!file.text()) {
            file.writeAdapter();
            return;
        }
        var write = root.migrate();
        if (adapter.style === "circle") {
            adapter.style = "orb";
            write = true;
        }
        if (write)
            file.writeAdapter();
    }
}
