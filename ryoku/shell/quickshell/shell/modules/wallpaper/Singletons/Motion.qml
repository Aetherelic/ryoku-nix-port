pragma Singleton

import QtQuick
import Quickshell
import shell.services

// Desktop backdrop motion. Only the wallpaper swap is animated: a 200 ms linear
// crossfade on each revision (contract 08 sec 5, TRANSITION_DURATION_MS; the
// shell's Motion.wallpaperFade). reduce motion or low power collapses it to an
// instant cut, matching the shell Motion so a weak GPU stops repainting.
Singleton {
    readonly property bool reduce: Perf.reduceMotion
    readonly property int wallpaperFade: reduce ? 0 : 200

}
