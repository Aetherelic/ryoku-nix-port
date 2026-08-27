pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "lib/screens.js" as Screens

// screen recording state + control. drives ryoku-cmd-screenrecord
// (gpu-screen-recorder, falling back to wf-recorder on multi-GPU machines) and
// reconciles against the live process, so a failed launch or an external stop
// can't strand the UI. pause is optimistic, gsr only (wf-recorder can't pause).
// the Super+S capture card and floating record island share this source of truth.
Singleton {
    id: root

    property bool active: false
    property bool paused: false
    // The capture card opens the floating island in its pre-record chooser,
    // where the Quick / Studio / Edit actions live.
    property bool chooserOpen: false
    // studio capture records with gpu-screen-recorder (below) and hands the clip
    // to the ryomotion editor; our island is the toolbar and drives start/stop.
    property bool studioActive: false
    readonly property bool anyActive: root.active || root.studioActive
    // owning backend: "gsr" | "wf" | "" when idle.
    property string backend: ""
    readonly property bool canPause: backend === "gsr"
    property int startedAt: 0
    property int elapsedSec: 0
    property real pulse: 1
    readonly property string elapsedText: fmt(elapsedSec)

    // full path: ~/.config/hypr/scripts isn't on the shell's PATH, a bare name
    // wouldn't resolve and recording would silently never start.
    readonly property string script: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-screenrecord"

    // studio uses gpu-screen-recorder + a cursor track (this wrapper), then opens
    // the clip in the ryomotion editor; a bare name wouldn't resolve on PATH.
    readonly property string studioScript: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-studiorecord"

    // region capture: the box the user drew as gsr's "WxH+X+Y" (logical coords),
    // "" = full monitor. slurp must launch detached (a managed Process gets its
    // session killed before it can grab the seat), so it writes the box to a state
    // file the FileView reads back -- QML (the overlay) and the recorder scripts
    // then share one geometry. regionPicking gates it so a fresh pick applies but a
    // stale file left from a past session does not.
    property string regionGeom: ""
    property bool regionPicking: false
    // A remembered region is a box in GLOBAL logical coordinates, valid only for
    // the monitor layout it was drawn in. After a hotplug or resolution change the
    // logical origins shift, so that box can land off-screen or on an output that
    // no longer exists and gsr would crop the capture to nothing. Stamp the region
    // with the layout it was picked in (a cheap string signature, compared for
    // equality -- never geometry arithmetic) and drop it the moment the live layout
    // stops matching, so a stale box is never reused.
    property string regionLayoutSig: ""
    readonly property string layoutSig: {
        var out = Screens.uniqueByName(Quickshell.screens);
        var parts = [];
        for (var i = 0; i < out.length; i++) {
            var s = out[i];
            parts.push(s.name + "@" + s.x + "," + s.y + ":" + s.width + "x" + s.height);
        }
        // sort so a reordered output announce alone never invalidates the region.
        parts.sort();
        return parts.join("|");
    }
    onLayoutSigChanged: {
        if (root.regionGeom !== "" && root.regionLayoutSig !== root.layoutSig)
            root.regionGeom = "";
    }
    // clear the stamp whenever the region clears (a manual clear, or the drop
    // above), so it is only ever consulted alongside a live region.
    onRegionGeomChanged: if (root.regionGeom === "") root.regionLayoutSig = "";
    readonly property string regionFilePath: (Quickshell.env("RYOKU_STATE_PATH") || (Quickshell.env("HOME") + "/.local/state/ryoku")) + "/region-pick"
    function pickRegion() {
        root.regionPicking = true;
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname '" + root.regionFilePath + "')\"; "
            + "g=$(slurp -f '%wx%h+%x+%y' 2>/dev/null); "
            + "printf '%s' \"$g\" > '" + root.regionFilePath + ".tmp'; "
            + "mv '" + root.regionFilePath + ".tmp' '" + root.regionFilePath + "'"]);
    }
    FileView {
        id: regionFile
        path: root.regionFilePath
        blockLoading: true
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (!root.regionPicking)
                return;
            root.regionPicking = false;
            var g = (regionFile.text() || "").trim();
            if (/^\d+x\d+\+\d+\+\d+$/.test(g)) {
                root.regionGeom = g;
                // stamp the layout it was drawn in, so a later change drops it.
                root.regionLayoutSig = root.layoutSig;
            } else {
                root.regionGeom = "";
            }
        }
    }

    // discord-nitro quick compress: when the record chooser's Discord toggle is
    // on, a finished Quick capture is re-encoded to best-effort 10MB or under
    // (native resolution and audio kept) so it drops straight into a chat.
    // Studio never compresses. pendingDiscord latches the toggle at start, so a
    // mid-capture change can't retarget the clip; discordMode persists.
    readonly property string discordScript: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-discord-compress"
    property bool discordMode: false
    property bool pendingDiscord: false
    readonly property string discordFile: (Quickshell.env("RYOKU_STATE_PATH") || (Quickshell.env("HOME") + "/.local/state/ryoku")) + "/discord-record"
    FileView {
        id: discordPref
        path: root.discordFile
        blockLoading: true
        printErrors: false
        onLoaded: root.discordMode = ((discordPref.text() || "").trim() === "1")
    }
    onDiscordModeChanged: Quickshell.execDetached(["sh", "-c",
        "mkdir -p \"${1%/*}\"; printf '%s' \"$2\" > \"$1\"", "sh", root.discordFile, root.discordMode ? "1" : "0"])

    // Remembered capture options the record island's chooser and the capture card
    // both read, persisted to record.json: the desktop-audio / mic toggles and
    // "edit after" -- when a Quick recording ends it opens the clip in ryomotion.
    // Studio always routes through ryomotion, so it ignores editMode. Shape
    // mirrors Flags: watch for outside edits, write back on change, seed once.
    property alias optDesktopAudio: recPrefs.desktopAudio
    property alias optMic: recPrefs.mic
    property alias editMode: recPrefs.edit
    FileView {
        id: recPrefsFile
        path: (Quickshell.env("RYOKU_STATE_PATH") || (Quickshell.env("HOME") + "/.local/state/ryoku")) + "/record.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: recPrefs
            // Seeded only into a fresh record.json; an existing file keeps whatever
            // the user last chose. A first recording should capture the application
            // being demonstrated (desktop audio), not the user's voice -- and
            // recording a microphone by default is a privacy surprise.
            property bool desktopAudio: true
            property bool mic: false
            property bool edit: false
        }
    }
    Component.onCompleted: if (!recPrefsFile.text()) recPrefsFile.writeAdapter();

    // Persist the capture's start time so a shell reload mid-recording keeps
    // counting from the real start instead of resetting the clock. Written when a
    // capture begins and cleared when it ends; the process poll below reads it
    // back on reload. A capture started outside the shell has no stamp and falls
    // back to counting from when the shell first saw it.
    readonly property string sessionFile: (Quickshell.env("RYOKU_STATE_PATH") || (Quickshell.env("HOME") + "/.local/state/ryoku")) + "/record-session"
    function writeSession(v) {
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"${1%/*}\"; printf '%s' \"$2\" > \"$1\"", "sh", root.sessionFile, v]);
    }
    function readSessionStart() {
        const n = parseInt((sessionView.text() || "").trim(), 10);
        return (isFinite(n) && n > 0) ? n : 0;
    }
    FileView {
        id: sessionView
        path: root.sessionFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    // desktop-audio + mic flags -> ryoku-cmd-screenrecord args, shared by the card
    // and the island so the two never build the argument list differently.
    function recordArgs() {
        var a = [];
        if (root.optDesktopAudio) a.push("--with-desktop-audio");
        if (root.optMic) a.push("--with-microphone-audio");
        return a;
    }

    // edit-after: when a Quick recording ends, hand the clip to ryomotion. Latched
    // at start so a mid-capture toggle can't retarget it; Studio never uses it.
    readonly property string editScript: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-edit-recording"
    property bool pendingEdit: false

    // pre-record countdown: the capture card can arm a delay (Capture.delay,
    // 0/1/3/5/10s) so the desktop is framed before capture begins. startAfter ticks
    // that delay down in the record island, then calls start(), so the count is
    // honest -- it reflects a real wait, not a guess. countdownSec is the remaining
    // whole seconds the island renders; countingDown gates that view.
    property int countdownSec: 0
    property bool countingDown: false
    // args latched for the deferred start so a mid-count option change can't
    // retarget the pending capture.
    property var pendingArgs: []
    function startAfter(args, secs) {
        // secs <= 0 is exactly today's path: no countdown state, no added delay.
        if (secs <= 0) {
            root.start(args);
            return;
        }
        root.pendingArgs = args || [];
        root.countdownSec = secs;
        root.countingDown = true;
        countdown.restart();
    }
    // a stop or an explicit cancel during the count aborts it and leaves no timer
    // running: nothing launched yet, so there is nothing to --stop.
    function cancelCountdown() {
        countdown.stop();
        root.countingDown = false;
        root.countdownSec = 0;
        root.pendingArgs = [];
    }
    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdownSec--;
            if (root.countdownSec <= 0) {
                countdown.stop();
                root.countingDown = false;
                var a = root.pendingArgs;
                root.pendingArgs = [];
                root.start(a);
            }
        }
    }

    function start(extraArgs) {
        // latch the persisted post-capture actions so a mid-capture toggle can't
        // retarget the just-finished Quick clip.
        root.pendingDiscord = root.discordMode;
        root.pendingEdit = root.editMode;
        Quickshell.execDetached([root.script, ...(extraArgs || [])]);
        root.paused = false;
        root.active = true;
        root.startedAt = Math.floor(Date.now() / 1000);
        root.elapsedSec = 0;
        root.writeSession(String(root.startedAt));
        confirm.restart();
    }

    function stop() {
        // a stop during the pre-record countdown just cancels it: the recorder
        // never launched, so there is nothing to --stop, compress or edit.
        if (root.countingDown) {
            root.cancelCountdown();
            return;
        }
        Quickshell.execDetached([root.script, "--stop"]);
        root.active = false;
        root.paused = false;
        root.writeSession("");
        // discord-quick: hand the just-finished clip to the compressor, which
        // waits for gsr/wf to finalise the mp4 before re-encoding it in place.
        if (root.pendingDiscord) {
            Quickshell.execDetached([root.discordScript]);
            root.pendingDiscord = false;
        }
        // edit-after: open the just-finished Quick clip in ryomotion; the script
        // waits for the mp4 to finalise before launching the editor.
        if (root.pendingEdit) {
            Quickshell.execDetached([root.editScript]);
            root.pendingEdit = false;
        }
    }

    function togglePause() {
        if (!root.canPause)
            return;
        Quickshell.execDetached([root.script, "--pause"]);
        root.paused = !root.paused;
    }
    // studio: record with gpu-screen-recorder + a cursor track, then open the clip
    // in the ryomotion editor (its auto-zoom reads the cursor track we synthesise).
    // Tracked so our stop can signal the wrapper; anyActive keeps the island up
    // until the gsr poll confirms the capture.
    function startStudio(desktopAudio, mic, regionGeom) {
        var args = [root.studioScript];
        if (regionGeom) { args.push("--region", "--geometry", regionGeom); }
        if (desktopAudio) args.push("--with-desktop-audio");
        if (mic) args.push("--with-microphone-audio");
        studioProc.command = args;
        studioProc.running = true;
        root.studioActive = true;
        root.paused = false;
        root.backend = "studio";
        root.startedAt = Math.floor(Date.now() / 1000);
        root.elapsedSec = 0;
        root.writeSession(String(root.startedAt));
    }
    function stopStudio() {
        // SIGTERM the wrapper (not gsr): it stops the capture, writes the cursor
        // sidecar, and opens the editor, so it needs to run its own shutdown.
        if (studioProc.running && studioProc.processId > 0)
            Quickshell.execDetached(["kill", "-TERM", String(studioProc.processId)]);
        root.studioActive = false;
        root.paused = false;
        root.backend = "";
        root.startedAt = 0;
        root.elapsedSec = 0;
        root.writeSession("");
    }

    Process {
        id: studioProc
        onRunningChanged: {
            // the studio wrapper exited on its own (gsr failed to start, or it
            // finished and opened the editor): don't strand the island counting up.
            if (!studioProc.running && root.studioActive) {
                root.studioActive = false;
                root.backend = "";
                root.startedAt = 0;
                root.elapsedSec = 0;
                root.writeSession("");
            }
        }
    }

    SequentialAnimation on pulse {
        // also pulse through the pre-record countdown, as an "arming" cue.
        running: (root.anyActive || root.countingDown) && !root.paused
        loops: Animation.Infinite
        NumberAnimation { to: 0.18; duration: 620; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
    }

    // reconcile against the live process: surface the owning backend and clear
    // stale state when nothing's recording. pause stays optimistic while active.
    Process {
        id: poll
        // match the full command line, not comm: Linux truncates comm to 15 chars
        // so "gpu-screen-recorder" (19) never matches `pgrep -x`. The [g] bracket
        // keeps this poll's own command from matching itself. A replay buffer (gsr
        // with `-r`) is not a recording -- exclude it so a background buffer never
        // flips the record toolbar on.
        command: ["sh", "-c",
            "rec=off; for p in $(pgrep -f '(^|/)[g]pu-screen-recorder( |$)' 2>/dev/null); do "
            + "cl=\" $(tr '\\0' ' ' < /proc/$p/cmdline 2>/dev/null) \"; "
            + "case \"$cl\" in *' -r '*) : ;; *) rec=gsr ;; esac; done; "
            + "[ \"$rec\" = off ] && pgrep -f '(^|/)[w]f-recorder( |$)' >/dev/null 2>&1 && rec=wf; "
            + "printf '%s' \"$rec\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var b = text.trim();
                var nowActive = b === "gsr" || b === "wf";
                if (nowActive && !root.active) {
                    // A shell reload restarts this process with active=false while
                    // gsr keeps running; restore the real start from the session
                    // stamp so the clock keeps counting instead of resetting to 0.
                    const persisted = root.readSessionStart();
                    if (persisted > 0) {
                        root.startedAt = persisted;
                        root.elapsedSec = Math.max(0, Math.floor(Date.now() / 1000) - persisted);
                    } else {
                        root.startedAt = Math.floor(Date.now() / 1000);
                        root.elapsedSec = 0;
                        root.writeSession(String(root.startedAt));
                    }
                }
                if (!nowActive && !root.studioActive) {
                    root.startedAt = 0;
                    root.elapsedSec = 0;
                    root.pulse = 1;
                    root.paused = false;
                    root.writeSession("");
                }
                root.active = nowActive;
                if (nowActive) root.backend = b;
                else if (!root.studioActive) root.backend = "";
            }
        }
    }

    // reconcile cadence: poll hard (2s) only while a capture is live, so an
    // external stop or crash can't strand the island; idle we poll slowly (30s),
    // enough to catch a capture started outside the shell without spawning a
    // pgrep subprocess every 2s around the clock.
    Timer {
        interval: root.anyActive ? 2000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    // confirm the recorder actually came up after a start; a failed launch
    // would otherwise leave the optimistic running state counting up forever.
    Timer {
        id: confirm
        interval: 2500
        onTriggered: poll.running = true
    }

    // increment, don't recompute from startedAt -- a pause freezes the clock
    // and a resume continues it.
    Timer {
        interval: 1000
        running: root.anyActive && !root.paused
        repeat: true
        onTriggered: root.elapsedSec++
    }

    function fmt(sec) {
        var s = Math.max(0, Math.round(sec));
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        var r = s % 60;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
}
