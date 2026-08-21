pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/menupoll.js" as MenuPoll

// Live GPU / network / disk / fan stats for the desktop system-stats panel.
// GPU utilisation, power and temperature come from nvidia-smi (absent on a
// machine with no NVIDIA card, then gpuAvailable stays false and the readouts
// read zero); network throughput is the RX/TX byte delta of every non-loopback
// interface across the poll interval; disk usage is df on /; the fan speed is
// the first readable hwmon fan tacho. Like Sysinfo it polls on a 1.5s tick only
// while a visible owner claims it (setActive, owner-refcounted like AudioBars),
// so an unseen panel costs nothing. Short down/up histories feed the chart.
//
// A runtime-suspended discrete GPU is treated as absent: probing it with
// nvidia-smi would pull the card back out of D3 (about 10 W on a hybrid laptop),
// and on a 1.5s tick this panel alone would pin it awake the whole time it is
// open. So the poll checks the driver's runtime_status first and reports nothing
// while the card sleeps, landing on the same "no GPU" path as a machine without
// nvidia-smi. Same guard the bar's GPU telemetry and the Hub's plate use.
//
// The properties below are written from the poll handlers (as in Sysinfo), so
// they are plain properties; consumers treat them as read-only.
Singleton {
    id: root

    property var owners: []
    readonly property bool active: root.owners.length > 0
    function setActive(owner, on) { root.owners = MenuPoll.setOwnership(root.owners, owner, on); }

    // poll cadence; also the time base for the network byte-rate delta, so the
    // rate needs no wall clock (Date.now throws in the QML engine).
    readonly property int pollMs: 1500

    // GPU: utilisation 0..100, draw in W, package temp in C. gpuAvailable is
    // false when nvidia-smi is missing or errors, and the values stay zero.
    property real gpuPct: 0
    property real gpuPowerW: 0
    property real gpuTempC: 0
    property bool gpuAvailable: false

    // network throughput in bytes/s, plus recent histories for the chart.
    property real downBps: 0
    property real upBps: 0
    property var netDownHist: []
    property var netUpHist: []

    // root filesystem usage in GiB.
    property real diskUsedGiB: 0
    property real diskTotalGiB: 0

    // first readable hwmon fan tacho, in RPM (0 when none is exposed).
    property real fanRpm: 0

    // previous cumulative RX/TX totals; _haveNet gates the first (baseline) read.
    property real _prevRx: 0
    property real _prevTx: 0
    property bool _haveNet: false

    // nvidia-smi CSV first line: "<util>, <power>, <temp>" (nounits). A missing
    // binary yields empty stdout (2>/dev/null, sh exits nonzero) -> unavailable.
    function _readGpu(text) {
        var line = ((text || "").trim().split("\n")[0] || "").trim();
        var p = line.length > 0 ? line.split(",") : [];
        if (p.length < 3) {
            root.gpuAvailable = false;
            root.gpuPct = 0; root.gpuPowerW = 0; root.gpuTempC = 0;
            return;
        }
        var u = Number((p[0] || "").trim());
        var w = Number((p[1] || "").trim());
        var t = Number((p[2] || "").trim());
        root.gpuPct = isNaN(u) ? 0 : Math.max(0, Math.min(100, u));
        root.gpuPowerW = isNaN(w) ? 0 : Math.max(0, w);
        root.gpuTempC = isNaN(t) ? 0 : t;
        root.gpuAvailable = true;
    }

    // /proc/net/dev: each data line is "iface: rxbytes ... txbytes ...". Sum RX
    // (field 1) and TX (field 9) over every interface but lo, then rate = delta
    // over the fixed poll interval. Header lines have no ':' and fall through.
    function _readNet(text) {
        var lines = (text || "").split("\n");
        var rx = 0, tx = 0;
        for (var i = 0; i < lines.length; i++) {
            var ci = lines[i].indexOf(":");
            if (ci < 0)
                continue;
            var name = lines[i].slice(0, ci).trim();
            if (name === "" || name === "lo")
                continue;
            var f = lines[i].slice(ci + 1).trim().split(/\s+/);
            if (f.length < 9)
                continue;
            rx += Number(f[0]) || 0;
            tx += Number(f[8]) || 0;
        }
        if (root._haveNet) {
            var dt = root.pollMs / 1000;
            root.downBps = Math.max(0, (rx - root._prevRx) / dt);
            root.upBps = Math.max(0, (tx - root._prevTx) / dt);
            var dh = root.netDownHist.slice();
            dh.push(root.downBps);
            while (dh.length > 48)
                dh.shift();
            root.netDownHist = dh;
            var uh = root.netUpHist.slice();
            uh.push(root.upBps);
            while (uh.length > 48)
                uh.shift();
            root.netUpHist = uh;
        }
        root._prevRx = rx;
        root._prevTx = tx;
        root._haveNet = true;
    }

    // df -B1 --output=used,size /: header row then "<used> <size>" in bytes.
    function _readDisk(text) {
        var lines = (text || "").trim().split("\n");
        if (lines.length < 2)
            return;
        var f = lines[lines.length - 1].trim().split(/\s+/);
        if (f.length < 2)
            return;
        var used = Number(f[0]), size = Number(f[1]);
        var giB = 1073741824;
        if (!isNaN(used))
            root.diskUsedGiB = used / giB;
        if (!isNaN(size))
            root.diskTotalGiB = size / giB;
    }

    function _readFan(text) {
        var v = parseInt((text || "").trim(), 10);
        root.fanRpm = (!isNaN(v) && v >= 0) ? v : 0;
    }

    FileView { id: netFile; path: "/proc/net/dev"; blockLoading: true; printErrors: false; onLoaded: root._readNet(netFile.text()) }

    Process {
        id: gpuProc
        running: false
        command: ["sh", "-c",
            "for st in /sys/bus/pci/drivers/nvidia/*/power/runtime_status; do "
            + "[ -r \"$st\" ] || continue; IFS= read -r s < \"$st\"; "
            + "[ \"$s\" = suspended ] && exit 0; break; done; "
            + "nvidia-smi --query-gpu=utilization.gpu,power.draw,temperature.gpu --format=csv,noheader,nounits 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root._readGpu(this.text) }
    }

    Process {
        id: diskProc
        running: false
        command: ["sh", "-c", "df -B1 --output=used,size / 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root._readDisk(this.text) }
    }

    // first hwmon exposing a readable fan1_input tacho; none -> empty -> 0 RPM.
    Process {
        id: fanProc
        running: false
        command: ["sh", "-c", "for f in /sys/class/hwmon/hwmon*/fan1_input; do [ -r \"$f\" ] && cat \"$f\" 2>/dev/null && exit 0; done"]
        stdout: StdioCollector { onStreamFinished: root._readFan(this.text) }
    }

    Timer {
        interval: root.pollMs
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netFile.reload();
            gpuProc.running = false;
            gpuProc.running = true;
            diskProc.running = false;
            diskProc.running = true;
            fanProc.running = false;
            fanProc.running = true;
        }
    }
    // drop the stale byte baseline on close so the next open measures a fresh
    // interval rather than one spanning the idle gap.
    onActiveChanged: if (!root.active) root._haveNet = false;
}
