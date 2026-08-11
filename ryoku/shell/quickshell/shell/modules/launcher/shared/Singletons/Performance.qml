pragma Singleton
import Quickshell
import shell.services

// Thin forwarder to the shared performance policy. The launcher reads the derived
// blur switch to drop its now-playing album-art blur; the policy (performance.json
// folded with the active power profile and battery) lives once in
// shell.services.Perf, so Power Saver (or lowPowerMode) drops the blur without a
// second performance.json watcher here.
Singleton {
    readonly property bool lowPower: Perf.lowPower
    readonly property bool blurDisabled: Perf.blurDisabled
}
