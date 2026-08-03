pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland

// Shared per-monitor open/close state for every shell surface: the single source
// of truth the CustomShortcut handlers flip and each resident surface binds its
// visibility to, replacing the old per-surface process plus `ryoku-shell state`
// round-trip. One PersistentProperties object per screen (built by Variants over
// Quickshell.screens, the caelestia ScreenState pattern) so a flag set on one
// monitor never leaks to another; a hotplugged monitor gains its own state on the
// fly. Surfaces read forScreen(modelData); keybinds usually target forActive().
Singleton {
    id: root

    // State for a specific screen, or null before its per-monitor instance is
    // built (a binding can evaluate ahead of screen hotplug).
    function forScreen(screen) {
        const list = states.instances;
        for (let i = 0; i < list.length; i++) {
            if (list[i].modelData === screen)
                return list[i];
        }
        return null;
    }

    // State for the monitor Hyprland currently focuses; falls back to the first
    // screen so a caller before focus is known still gets a live target.
    function forActive() {
        const mon = Hyprland.focusedMonitor;
        const name = mon && mon.name ? mon.name : "";
        const list = states.instances;
        for (let i = 0; i < list.length; i++) {
            if (list[i].modelData && list[i].modelData.name === name)
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    Variants {
        id: states
        model: Quickshell.screens

        PersistentProperties {
            required property var modelData

            // Surface toggles, one per today's IpcHandler target so each keybind
            // becomes an in-process flip:
            property bool launcherOpen: false           // launcher
            property bool overviewOpen: false           // overview (Super+Tab expo)
            property bool wallpaperSwitcherOpen: false  // wallpaper-switcher
            property bool boardOpen: false              // board (was ryolayer, Super+G)

            // The bar reveal. A single flag for now; split per edge
            // (top/bottom/left/right) when the frame migrates in Phase 2 if edges
            // reveal independently.
            property bool barRevealed: false

            // Desktop audio visualiser mode: "off" | "desktop" | "overlay".
            property string visualizerMode: "off"

            // A place for the on-screen-display and notification surfaces to
            // signal activity when they migrate (Phase 5).
            property bool osdVisible: false
            property bool notificationsVisible: false
        }
    }
}
