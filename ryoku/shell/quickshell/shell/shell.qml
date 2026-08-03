//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic
pragma ComponentBehavior: Bound

import Quickshell
import "services"
import "components"

/**
 * The single resident Ryoku shell instance (Phase 1 skeleton).
 *
 * One ShellRoot for the whole desktop. It brings the shared service singletons
 * online, holds the per-monitor ShellState every surface binds its visibility
 * to, and registers the shell's in-QML Hyprland global shortcuts. This phase
 * draws nothing: the per-screen Variants scope below is empty and the single
 * shortcut is a no-op. It is built ALONGSIDE the live per-surface configs and the
 * ryoku-shell daemon does not launch it yet; surfaces move in one module per
 * phase (see docs/plans/2026-08-03-shell-consolidation.md).
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

    // One empty scope per monitor: the host each resident surface is added to as
    // its module lands. Empty in Phase 1 so nothing is drawn; every future surface
    // reads ShellState.forScreen(modelData) for its per-monitor visibility.
    Variants {
        model: Quickshell.screens

        Scope {
            required property var modelData
        }
    }

    // Prove the zero-spawn keybind path end to end: one registered global shortcut
    // (appid "ryoku") that does nothing. Real actions replace this as each surface
    // migrates, flipping a ShellState flag in-process.
    CustomShortcut {
        name: "noop"
        description: "Ryoku shell no-op (Phase 1 skeleton)"
        onPressed: {}
    }
}
