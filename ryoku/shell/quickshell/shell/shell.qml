//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic
pragma ComponentBehavior: Bound

import Quickshell
import "services"
import "components"
import "modules/wallpaper"
import "modules/wallpaper/switcher"
import "modules/desktop"
import "modules/visualizer"
import "modules/bar"
import "modules/launcher"
import "modules/overview"
import "modules/board"

/**
 * The single resident Ryoku shell instance.
 *
 * One ShellRoot for the whole desktop. It brings the shared service singletons
 * online, holds the per-monitor ShellState every surface binds its visibility
 * to, and registers the shell's in-QML Hyprland global shortcuts. Each monitor
 * gets one Scope carrying that screen's ShellState slice (st); every migrated
 * surface is instantiated once inside it and binds its screen and its visibility
 * to the slice, so a keybind that flips a flag on the active monitor reveals or
 * hides exactly this monitor's copy in-process, where the old shell spawned a
 * ryoku-shell client per press across separate surface processes.
 *
 * The surfaces run ALONGSIDE the live per-surface configs; the ryoku-shell
 * daemon does not launch this instance yet (cutover is Phase 11, see
 * docs/plans/2026-08-03-shell-consolidation.md), so the migrated surfaces' legacy
 * daemon round-trips are neutralized and the compositor binds still call
 * ryoku-shell until Phase 10 rewires them to global:ryoku:<name>.
 *
 * UseQApplication is declared once for the whole shell (the tray needs Qt
 * Widgets), replacing the six per-surface copies the old multi-process shell paid.
 */
ShellRoot {
    id: root

    // Construct the shared services (ShellState's per-monitor state now, heavier
    // providers as surfaces migrate) at load rather than on the first keybind.
    ServiceLoader {
        services: [ShellState]
    }

    // One per-monitor surface stack. Each screen gets a Scope carrying its
    // ShellState slice (st); every resident surface binds its screen and its
    // visibility to that slice, so flipping a flag on the active monitor reveals
    // or hides this monitor's copy. The order here reads top-to-bottom only; the
    // Wayland layer each surface maps on decides the real stacking.
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData
            readonly property var st: ShellState.forScreen(modelData)

            // Always-on backdrop and desktop widget layer.
            Wallpaper {
                screen: perScreen.modelData
            }
            Desktop {
                screen: perScreen.modelData
                active: true
            }
            Visualizer {
                screen: perScreen.modelData
                mode: perScreen.st ? perScreen.st.visualizerMode : "off"
            }

            // The frame bar (Phase 2): reads its own reveal from this slice.
            Frame {
                modelData: perScreen.modelData
            }

            // Toggle-driven overlays, each bound to a ShellState flag.
            Launcher {
                screen: perScreen.modelData
                active: perScreen.st ? perScreen.st.launcherOpen : false
            }
            OverviewSurface {
                screen: perScreen.modelData
                active: perScreen.st ? perScreen.st.overviewOpen : false
            }
            Board {
                screen: perScreen.modelData
                active: perScreen.st ? perScreen.st.boardOpen : false
            }
            Switcher {
                screen: perScreen.modelData
                active: perScreen.st ? perScreen.st.wallpaperSwitcherOpen : false
                onRequestClose: if (perScreen.st) perScreen.st.wallpaperSwitcherOpen = false
            }
        }
    }

    // In-process global shortcuts. Each flips the focused monitor's ShellState
    // flag that the per-screen surfaces above bind their visibility to, so a
    // keybind is a property write, not the old ryoku-shell client spawn. Names
    // match the compositor binds (rewired to global:ryoku:<name> in Phase 10) so
    // `hyprctl dispatch global ryoku:<name>` lands here.
    CustomShortcut {
        name: "barToggle"
        description: "Toggle the Ryoku frame bar on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.barRevealed = !st.barRevealed;
        }
    }
    CustomShortcut {
        name: "launcher"
        description: "Toggle the app launcher on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.launcherOpen = !st.launcherOpen;
        }
    }
    CustomShortcut {
        name: "overview"
        description: "Toggle the workspace overview on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.overviewOpen = !st.overviewOpen;
        }
    }
    CustomShortcut {
        name: "wallpaper-switcher"
        description: "Toggle the wallpaper switcher on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.wallpaperSwitcherOpen = !st.wallpaperSwitcherOpen;
        }
    }
    CustomShortcut {
        name: "board"
        description: "Toggle the board tool overlay on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.boardOpen = !st.boardOpen;
        }
    }
    // Legacy Super+G name for the board (was ryolayer); same in-process flip.
    CustomShortcut {
        name: "ryolayer"
        description: "Toggle the board tool overlay on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.boardOpen = !st.boardOpen;
        }
    }
    CustomShortcut {
        name: "visualizer"
        description: "Cycle the desktop audio visualiser off and on"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.visualizerMode = st.visualizerMode === "off" ? "desktop" : "off";
        }
    }
    CustomShortcut {
        name: "visualizer-overlay"
        description: "Toggle the audio visualiser overlay over windows"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.visualizerMode = st.visualizerMode === "overlay" ? "desktop" : "overlay";
        }
    }
}
