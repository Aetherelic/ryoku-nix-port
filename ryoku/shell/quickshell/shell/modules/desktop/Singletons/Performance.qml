pragma Singleton
import Quickshell
import shell.services

// Thin forwarder to the shared performance policy. The desktop-widget layer reads
// the derived shadow and blur switches to drop its per-tile drop shadows and the
// frosted-glass blur pass. The policy itself -- performance.json folded with the
// active power profile and battery state -- lives once in shell.services.Perf, so
// Power Saver (or lowPowerMode) flattens the desktop shadows and glass without a
// second file watcher here.
Singleton {
    readonly property bool lowPower: Perf.lowPower
    readonly property bool shadowsDisabled: Perf.shadowsDisabled
    readonly property bool blurDisabled: Perf.blurDisabled
}
