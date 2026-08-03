//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic
pragma ComponentBehavior: Bound

import Quickshell
import "services"
import "components"
import "modules/bar"

/**
 * The single resident Ryoku shell instance (Phase 1 skeleton).
 *
 * One ShellRoot for the whole desktop. It brings the shared service singletons
 * online, holds the per-monitor ShellState every surface binds its visibility
 * to, and registers the shell's in-QML Hyprland global shortcuts. The frame bar
 * is the first migrated surface (Phase 2): one instance per monitor, revealed
 * through ShellState and toggled by a global shortcut. It is built ALONGSIDE the
 * live per-surface configs and the ryoku-shell daemon does not launch it yet;
 * surfaces move in one module per phase (see
 * docs/plans/2026-08-03-shell-consolidation.md).
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

    // One frame bar per monitor, the first migrated surface. Each instance reads
    // its reveal from ShellState.forScreen(modelData) and reserves its edges so
    // tiled windows clear the rails.
    Variants {
        model: Quickshell.screens

        Frame {}
    }

    // The frame bar reveal toggle: flips the focused monitor's ShellState master
    // reveal in-process, where the old path spawned a ryoku-shell client per
    // press. More actions register here as their surfaces migrate.
    CustomShortcut {
        name: "barToggle"
        description: "Toggle the Ryoku frame bar on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.barRevealed = !st.barRevealed;
        }
    }
}
