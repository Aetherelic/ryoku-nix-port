pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Quick-capture controller for the frame's screenshot menu: the menu takes the
// shot and is done, with no confirmation and no editor step (that workflow is
// ryoshot's job, and it stays). This owns the screenshot pipeline (grim capture
// then PNG save and/or a plain Wayland clipboard write), the shared state of the
// per-output selection overlays, and the delay rules from contract 09.
//
// Screen RECORDING is deliberately NOT owned here. The menu's record controls
// drive the existing Recorder singleton (gpu-screen-recorder with a wf-recorder
// fallback, the record island, Studio, Discord, camera). Building a second
// recording path was rejected: Ryoku already ships the more capable one, and two
// would break the never-two-copies rule. The only recording thing this file does
// is hand a picked region to Recorder.start.
//
// Divergence (contract 09 sec 9): the capture backend shells out to grim +
// wl-copy rather than a bespoke zwlr_screencopy_v1 client. grim speaks exactly
// that protocol over its own wl_display, and Ryoku already shells out to wl-copy
// and wf-recorder for the same reasons; a hand-rolled screencopy client in Go
// would be a second copy of a solved problem.
Singleton {
    id: root

    // "" while idle; otherwise "region" | "monitor" | "window" naming the active
    // selection-overlay family. Every output's overlay is mapped while this is
    // set, and a commit or Escape on any one clears it, tearing them all down.
    property string selecting: ""

    // What the current selection is for: "shot" runs grim, "record" hands the
    // region to Recorder. Set before `selecting`.
    property string _purpose: "shot"
    property int _delayMs: 0
    property string _save: "both"          // "both" | "clipboard" | "file"
    property var _recordAudio: []           // extra Recorder args for a region record
    property var _pending: null             // { flag, val } grim target for the pending shot

    // Ryoku owns its screenshot location; the filename pattern is the reference
    // UTC stamp. XDG_PICTURES_DIR honoured, else ~/Pictures, matching ryoshot.
    readonly property string shotsDir: (Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures")) + "/Screenshots"

    // Screenshot entry from the menu. mode: "all" | "monitor" | "window" | "region".
    // "all" captures immediately after a floor delay (500ms minimum so the menu
    // is gone from the frame before the whole desktop is grabbed). The other
    // three raise the selection overlays and apply the delay AFTER the selection.
    function shoot(mode, delaySec, save) {
        root._purpose = "shot";
        root._save = save;
        if (mode === "all") {
            root._pending = { flag: "", val: "" };
            fireTimer.interval = Math.max(delaySec * 1000, 500);
            fireTimer.restart();
        } else {
            root._delayMs = delaySec * 1000;
            root.selecting = mode;
        }
    }

    // Region-record entry from the menu: reuse the region overlay, then hand the
    // global geometry to the existing Recorder (no capture of our own).
    function recordRegion(audioArgs) {
        root._purpose = "record";
        root._recordAudio = audioArgs || [];
        root.selecting = "region";
    }

    // Called by an overlay when a selection commits. result carries the output
    // name, its logical layout origin (monX/monY) and, for region/window, the
    // output-local rect, so we resolve global logical coordinates for grim.
    function commit(result) {
        root.selecting = "";
        if (root._purpose === "record") {
            var rgx = Math.round(result.monX + result.x);
            var rgy = Math.round(result.monY + result.y);
            var geom = Math.round(result.w) + "x" + Math.round(result.h) + "+" + rgx + "+" + rgy;
            Recorder.start(["--region", "--geometry", geom].concat(root._recordAudio));
            return;
        }
        if (result.mode === "monitor") {
            root._pending = { flag: "-o", val: result.output };
        } else {
            var gx = Math.round(result.monX + result.x);
            var gy = Math.round(result.monY + result.y);
            root._pending = { flag: "-g", val: gx + "," + gy + " " + Math.round(result.w) + "x" + Math.round(result.h) };
        }
        fireTimer.interval = root._delayMs;
        fireTimer.restart();
    }

    function cancel() {
        root.selecting = "";
    }

    // Delay gate: 500ms floor for All (set in shoot), else the picked delay.
    Timer {
        id: fireTimer
        onTriggered: root._run()
    }

    function _run() {
        if (!root._pending)
            return;
        // grim capture, then clipboard and/or PNG save, the shutter cue and the
        // result toast, all gated on grim succeeding. A failed capture is silent,
        // matching the reference (eprintln, no toast). $1 flag, $2 value, $3 dir,
        // $4 save mode. The filename is stamped at capture time (UTC), after any
        // delay, so it reflects when the pixels were taken.
        var script = [
            "set -e",
            'FLAG="$1"; VAL="$2"; DIR="$3"; MODE="$4"',
            'cue() { ryoku-shell sound shutter >/dev/null 2>&1 || true; }',
            'note() { notify-send -a ryoku "$@" >/dev/null 2>&1 || true; }',
            'if [ "$MODE" != clipboard ]; then mkdir -p "$DIR"; OUT="$DIR/$(date -u +%Y_%m_%d_%H_%M_%S)_screenshot.png"; fi',
            'case "$MODE" in',
            'clipboard) if [ -n "$FLAG" ]; then grim "$FLAG" "$VAL" -; else grim -; fi | wl-copy --type image/png; cue; note "Screenshot copied to clipboard" ;;',
            'file) if [ -n "$FLAG" ]; then grim "$FLAG" "$VAL" "$OUT"; else grim "$OUT"; fi; cue; note "Screenshot saved" "Saved to $OUT" ;;',
            '*) if [ -n "$FLAG" ]; then grim "$FLAG" "$VAL" "$OUT"; else grim "$OUT"; fi; wl-copy --type image/png < "$OUT"; cue; note "Screenshot saved & copied" "Saved to $OUT" ;;',
            'esac'
        ].join("\n");
        proc.command = ["sh", "-c", script, "sh", root._pending.flag, root._pending.val, root.shotsDir, root._save];
        proc.running = true;
    }

    Process {
        id: proc
        onExited: code => {
            if (code !== 0)
                console.warn("capture: grim pipeline exited " + code);
        }
    }
}
