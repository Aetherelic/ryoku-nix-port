pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // reduceMotion (or the lowPowerMode master) collapses every animation to an
    // instant cut: durations go to 0, so Behaviors and transitions stop forcing
    // per-frame repaints -- the single biggest shell-animation win on a weak GPU.
    // Read straight from performance.json (the same file Performance and Ryoku
    // Settings use) so Motion stays a self-contained duration source. Dwell and
    // scheduling timers below (osdHide, notifHide, startupReveal) are functional,
    // not motion, so they are deliberately not gated -- reduce removes animation,
    // never the time a surface stays up or waits before appearing.
    readonly property bool reduce: perf.lowPowerMode || perf.reduceMotion

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: perf
            property bool lowPowerMode: false
            property bool reduceMotion: false
        }
    }

    // Bar, spacer, hover and startup reveal/hide. Measured ease-out-cubic over
    // 250 ms (measure/MOTION-MEASURED.md; contract 02 sec 5). Interrupt: reverse
    // from the current position, which a RevealBehavior retarget reproduces.
    readonly property int barReveal: reduce ? 0 : 250
    readonly property int barRevealCurve: Easing.OutCubic

    // Left/right side menu slide. A reveal that reverses rather than restarting, 250 ms, ease-out-cubic,
    // same envelope as the bar (contract 05 sec 5; contract 01 sec 5). Interrupt:
    // reverse from current.
    readonly property int menuSlide: reduce ? 0 : 250
    readonly property int menuSlideCurve: Easing.OutCubic

    // Corner/top/bottom scale grow that restarts from its current position. 200 ms easeInOutQuad, set
    // explicitly in source (contract 01 sec 5; contract 05 sec 5). Interrupt:
    // restart from the current position toward the new target.
    readonly property int diagonal: reduce ? 0 : 200
    readonly property int diagonalCurve: Easing.InOutQuad

    // Menu swap within one stack region: a stacked crossfade, linear opacity,
    // 200 ms (contract 01 sec 5; contract 05 sec 5).
    readonly property int crossfade: reduce ? 0 : 200
    readonly property int crossfadeCurve: Easing.Linear

    // Revealer row/button expand: child height SlideDown, 200 ms ease-out-cubic
    // (contract 16 sec 5; contract 06 sec 5). Notification cards (contract 12
    // sec 5), dynamic-list entries and the weather inner slide share this.
    readonly property int rowReveal: reduce ? 0 : 200
    readonly property int rowRevealCurve: Easing.OutCubic

    // Revealed-content fade and the chevron 0->90 turn: CSS `ease` =
    // cubic-bezier(0.25, 0.1, 0.25, 1) over 200 ms (contract 16 sec 5;
    // contract 06 sec 5). Thumbnail hover is the same curve over 150 ms
    // (contract 08 sec 5).
    readonly property int rowFade: reduce ? 0 : 200
    readonly property int chevronRotate: reduce ? 0 : 200
    readonly property int thumbHover: reduce ? 0 : 150
    readonly property int easeType: Easing.Bezier
    readonly property var easeCurve: [0.25, 0.1, 0.25, 1, 1, 1]

    // Desktop wallpaper swap crossfade, 200 ms (contract 08 sec 5,
    // TRANSITION_DURATION_MS). Linear opacity like the menu crossfade.
    readonly property int wallpaperFade: reduce ? 0 : 200

    // Weather outer-stack crossfade, 250 ms, set in source (contract 08 sec 5).
    readonly property int weatherFade: reduce ? 0 : 250

    // OSD auto-hide hold: the OSD has NO show/hide animation (contract 12 sec 5);
    // only this 1000 ms dwell from the last value update is timed, and a new
    // value resets it. A dwell timer, not motion, so reduce does not gate it.
    readonly property int osdHide: 1000

    // Notification container unmap delay: 260 ms after the popup list empties, so
    // the last card slide-out (rowReveal) finishes before the surface drops
    // (contract 12 sec 5). A scheduling timer, not motion.
    readonly property int notifHide: 260

    // Bars auto-reveal once, 1000 ms after startup (contract 02 sec 5). A one-shot
    // startup delay, not motion, so reduce keeps the timing and only drops the
    // slide.
    readonly property int startupReveal: 1000

    // Pending Ryoku vocabulary: still consumed by surfaces this wave does not
    // touch (Popout, Deck*, Stash*, KeyringSurface, WaveMeter, SidebarSystem).
    // Retained until those surfaces are translated; tracked in the slice report.
    readonly property int fast:     reduce ? 0 : 140
    readonly property int standard: reduce ? 0 : 300
    readonly property int morph:    reduce ? 0 : 420
    readonly property int hover:    reduce ? 0 : 100
    readonly property int spatial:  reduce ? 0 : 500
    readonly property int effects:  reduce ? 0 : 200
    readonly property int easeStandard: Easing.OutCubic
    readonly property var spatialCurve: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var effectsCurve: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property real rSmall: 7
    readonly property real rTile:  13
}
