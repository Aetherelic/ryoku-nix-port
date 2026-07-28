pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Quick-capture controller for the frame's capture card: pick a delay, a save
// target and a mode, take the shot and be done. With "Beautify after" on, the
// saved shot then opens in ryoshot's beautify editor (RYOSHOT_OPEN) for polish
// instead of ending at the file. The delay / save / beautify choices persist
// (capture.json) so the card remembers them across sessions, shared across every
// daemon that reads this singleton.
//
// Screen RECORDING is deliberately NOT owned here. The card's record zone drives
// the existing Recorder singleton (gpu-screen-recorder with a wf-recorder
// fallback, the record island, Studio, Discord, camera). The only recording
// thing this file does is hand a picked region to Recorder.start.
//
// Divergence: the capture backend shells out to grim + wl-copy rather than a
// bespoke zwlr_screencopy_v1 client -- grim speaks exactly that protocol, and
// Ryoku already shells out to wl-copy / wf-recorder for the same reasons.
Singleton {
    id: root

    // "" while idle; otherwise "region" | "monitor" | "window" naming the active
    // selection-overlay family. Every output's overlay is mapped while this is
    // set, and a commit or Escape on any one clears it, tearing them all down.
    property string selecting: ""

    // Remembered card options, persisted to capture.json (see the FileView below).
    property alias delay: prefs.delay          // seconds: 0 | 1 | 3 | 5 | 10
    property alias save: prefs.save            // "both" | "clipboard" | "file"
    property alias beautify: prefs.beautify    // open the shot in ryoshot after

    // What the current selection is for: "shot" runs grim, "record" hands the
    // region to Recorder. Set before `selecting`.
    property string _purpose: "shot"
    property int _delayMs: 0
    property string _save: "both"          // save mode latched for the pending shot
    property bool _beautify: false         // beautify choice latched for the pending shot
    property string _outPath: ""           // resolved PNG path ("" = clipboard-only stream)
    property var _recordAudio: []          // extra Recorder args for a region record
    property var _pending: null            // { flag, val } grim target for the pending shot

    // Ryoku owns its screenshot location; the filename pattern is the reference
    // UTC stamp. XDG_PICTURES_DIR honoured, else ~/Pictures, matching ryoshot.
    readonly property string shotsDir: (Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures")) + "/Screenshots"

    // Persisted card options, shared across daemons and surviving a restart. Same
    // shape as Flags: watch for outside edits, write back on any change, seed only
    // on a real first run so a slow load never clobbers a present file.
    FileView {
        id: prefsFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/capture.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: prefs
            property int delay: 0
            property string save: "both"
            property bool beautify: false
        }
    }
    Component.onCompleted: if (!prefsFile.text()) prefsFile.writeAdapter();

    // Screenshot entry from the card. mode: "all" | "monitor" | "window" | "region".
    // "all" captures immediately after a floor delay (500ms minimum so the card is
    // gone from the frame before the whole desktop is grabbed). The other three
    // raise the selection overlays and apply the delay AFTER the selection.
    function shoot(mode) {
        root._purpose = "shot";
        root._save = root.save;
        root._beautify = root.beautify;
        if (mode === "all") {
            root._pending = { flag: "", val: "" };
            fireTimer.interval = Math.max(root.delay * 1000, 500);
            fireTimer.restart();
        } else {
            root._delayMs = root.delay * 1000;
            root.selecting = mode;
        }
    }

    // Region-record entry from the card: reuse the region overlay, then hand the
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

    // UTC capture stamp, matching ryoshot's filename pattern. Resolved in QML (not
    // the shell) so the beautify hand-off already knows the exact path to open.
    function _stamp() {
        var d = new Date();
        function p(n) { return (n < 10 ? "0" : "") + n; }
        return d.getUTCFullYear() + "_" + p(d.getUTCMonth() + 1) + "_" + p(d.getUTCDate())
            + "_" + p(d.getUTCHours()) + "_" + p(d.getUTCMinutes()) + "_" + p(d.getUTCSeconds());
    }

    function _run() {
        if (!root._pending)
            return;
        // beautify needs a real file to hand to ryoshot, so a clipboard-only shot
        // still writes one when beautify is on; otherwise clipboard streams direct.
        var needFile = root._save !== "clipboard" || root._beautify;
        root._outPath = needFile ? (root.shotsDir + "/" + root._stamp() + "_screenshot.png") : "";
        // grim capture, then clipboard and/or PNG save, the shutter cue and the
        // result toast, all gated on grim succeeding. A failed capture is silent,
        // matching the reference. $1 flag, $2 value, $3 save mode, $4 out path
        // ("" means clipboard-only, no file on disk).
        var script = [
            "set -e",
            'FLAG="$1"; VAL="$2"; MODE="$3"; OUT="$4"',
            'cue() { ryoku-shell sound shutter >/dev/null 2>&1 || true; }',
            'note() { notify-send -a ryoku "$@" >/dev/null 2>&1 || true; }',
            'shoot() { if [ -n "$FLAG" ]; then grim "$FLAG" "$VAL" "$1"; else grim "$1"; fi; }',
            '[ -n "$OUT" ] && mkdir -p "$(dirname "$OUT")"',
            'case "$MODE" in',
            'clipboard)',
            '  if [ -n "$OUT" ]; then shoot "$OUT"; wl-copy --type image/png < "$OUT";',
            '  else if [ -n "$FLAG" ]; then grim "$FLAG" "$VAL" -; else grim -; fi | wl-copy --type image/png; fi',
            '  cue; note "Screenshot copied to clipboard" ;;',
            'file) shoot "$OUT"; cue; note "Screenshot saved" "Saved to $OUT" ;;',
            '*) shoot "$OUT"; wl-copy --type image/png < "$OUT"; cue; note "Screenshot saved & copied" "Saved to $OUT" ;;',
            'esac'
        ].join("\n");
        proc.command = ["sh", "-c", script, "sh", root._pending.flag, root._pending.val, root._save, root._outPath];
        proc.running = true;
    }

    Process {
        id: proc
        onExited: code => {
            if (code !== 0) {
                console.warn("capture: grim pipeline exited " + code);
                return;
            }
            // beautify: hand the saved shot to ryoshot's editor. flock guards a
            // second instance; RYOSHOT_OPEN loads the file straight into beautify.
            if (root._beautify && root._outPath.length > 0)
                Quickshell.execDetached(["sh", "-c",
                    'RYOSHOT_OPEN="$1" flock -n -o /tmp/ryoshot.lock qs -c ryoshot', "sh", root._outPath]);
        }
    }
}
