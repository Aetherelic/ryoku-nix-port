# Selectable app launcher variants

## Summary

Ryoku will keep three app launcher designs and let the user select one from Ryoku Settings:

- **Main**: the compact image-backed `RestDashboard` launcher preserved on the `main` branch.
- **Hero**: the full `HeroShutter` command palette selected during design review.
- **OkShell**: the current applications-only stand-in.

Hero becomes the default. Existing installs whose `launcher.json` has no variant key therefore return to Hero without a migration. The launcher remains one daemon-supervised Quickshell component and keeps the existing `Super+Space` entrypoint.

## Goals

1. Preserve all three launcher designs as supported implementations.
2. Make Hero the shipped default while retaining Main and OkShell as user choices.
3. Add one simple, mutually exclusive launcher selector to the App Launcher page in Ryoku Settings.
4. Organize launcher-specific files into isolated folders so a future launcher requires one folder and one catalog entry.
5. Keep providers, configuration, art, and reusable panels in one shared location.
6. Switch variants without leaving compositor blur or input-focus overrides active.

## Non-goals

- Giving OkShell command-palette providers. Its apps-only behavior is intentional.
- Forking or preserving historical provider implementations for Main.
- Adding a plugin marketplace or user-downloaded launcher code.
- Changing the `Super+Space` binding or the `ryoku-shell launcher` command.
- Redesigning any of the three launchers while moving them.

## Directory structure

```text
ryoku/shell/quickshell/launcher/
├── shell.qml
├── catalog.json
├── shared/
│   ├── art/
│   ├── lib/
│   ├── providers/
│   ├── Singletons/
│   └── reusable QML panels
├── variants/
│   ├── main/
│   │   ├── Main.qml
│   │   └── launcher-specific views
│   ├── hero/
│   │   ├── Main.qml
│   │   └── launcher-specific views
│   └── okshell/
│       └── Main.qml
└── qa/
```

`shell.qml` is a stable selector, not a launcher design. Each variant entrypoint is a Quickshell `Scope` and exposes the same contract:

- `show(string monitor)`
- `hide()`
- `toggle(string monitor)`
- `shown`
- `stateDump()`

The selector owns the stable `launcher` IPC handler and delegates these operations to the loaded variant. The daemon continues to supervise the single `launcher` Quickshell config.

## Catalog

`catalog.json` is the source of truth for the available variants. Each entry contains:

- stable `id`
- user-facing `name`
- concise `description`
- relative QML `entrypoint`
- settings capabilities used by the Hub to show only relevant controls

The initial IDs are `main`, `hero`, and `okshell`. The catalog has exactly one default, `hero`.

The selector and Hub read the same catalog. Adding a future launcher means adding its folder and one catalog row. The selector itself does not gain another conditional branch.

Catalog validation rejects duplicate IDs, an absent entrypoint field, unsafe relative paths, and a missing or ambiguous default. File existence and QML instantiation remain runtime checks handled by the selector fallback.

## Variant boundaries

### Main

Main restores the compact image-backed launcher from the `main` branch. Its launcher-specific view files live under `variants/main/`. It uses the current shared Dispatcher, provider set, configuration, and art rather than copying the historical backend stack.

Main retains the separate search row and compact `RestDashboard` image card. Its command palette uses the current provider behavior and action contracts.

### Hero

Hero restores the complete entrypoint from immediately before commit `e7901f06`. Its existing `HeroShutter`, launcher surface, result drawer, lead result, action shelf, window rail, and lifecycle views move under `variants/hero/`.

Hero retains the full image header, overlaid search field, mode keys, current providers, actions, and command-palette behavior.

### OkShell

OkShell moves the current self-contained launcher into `variants/okshell/Main.qml`. It keeps its existing search icon, hidden-entry toggle, scrolling application list, and selection motion. It remains applications-only.

## Shared code

Only code used by more than one variant belongs under `shared/`. This includes the current provider stack, shared singletons and configuration, shared JavaScript helpers, common panels, and the shipped hero art.

Historical Main code is adapted to the current shared contracts. The implementation must not copy provider directories, configuration singletons, or art into a variant folder.

## Configuration and Hub behavior

`launcher.json` gains an additive string key:

```json
{
  "variant": "hero"
}
```

`LauncherConfig` and the Hub's adapter both default it to `hero`. Existing user files without the key therefore select Hero. Because the key is additive and absence has a defined default, no doctor reconciler is required.

The App Launcher page adds a registry-driven, mutually exclusive selector with Main, Hero, and OkShell. The page preview follows the draft selection before Save. The catalog's capabilities control which setting groups are visible:

- Main and Hero expose their applicable image, weather, blur, geometry, and search controls.
- OkShell hides settings it does not consume.

Save continues to use the existing atomic `FileView` write. Reset to Defaults selects Hero.

## Switching lifecycle

The selector watches `launcher.json` through the shared config singleton.

1. If the selected variant changes while the launcher is closed, the selector replaces the loaded `Scope` immediately.
2. If it changes while the launcher is open, the selector records the pending variant and calls `hide()` on the active implementation.
3. The selector waits until `shown` becomes false, then replaces the loaded `Scope`.
4. The next delegated IPC call opens the new variant on the requested monitor.

The stable selector retains the IPC endpoint throughout the swap. Each variant must clean up compositor blur, keyboard focus, pointer-focus overrides, sockets, and transient processes when it closes or is destroyed.

## Failure behavior

- An absent, unknown, or retired variant ID resolves to the catalog default, Hero.
- If a selected entrypoint fails to instantiate, the selector reports the loader error and falls back once to OkShell.
- The fallback is single-shot so a broken fallback cannot create a load loop.
- A failed variant never leaves the prior variant partially active.

## Delivery

All launcher QML, catalog, shared files, and variant folders remain under `ryoku/shell/quickshell/launcher/`, so the existing shell package and materialization path deliver them to users. The additive `launcher.json` key remains user-owned and update-safe.

## Verification

The implementation is accepted when all of the following are directly observed:

1. Ryoku Settings lists exactly Main, Hero, and OkShell from the catalog.
2. Reset to Defaults selects Hero.
3. Saving each selection changes the launcher opened by `Super+Space`.
4. Main renders the compact centered image card and can search current shared providers.
5. Hero renders the full HeroShutter image header and its modes, providers, actions, and result navigation work.
6. OkShell renders its current application list and remains applications-only.
7. Switching while closed works immediately.
8. Switching while open first closes the old surface and leaves compositor blur and focus policy restored.
9. An unknown configured ID selects Hero.
10. Temporarily pointing a non-default catalog entry at a syntactically valid but unloadable QML path falls back once to OkShell during focused verification.
11. Moved QML passes `qmllint`, the existing launcher JavaScript and QA checks pass, and the delivery check recognizes every new path.
12. The behavior is exercised from the checkout with the shell development loop, not only through static checks.

## Documentation and changelog

After the live behavior works, update `docs/launcher.md` to describe the selector, variant folders, shared provider boundary, defaults, and extension procedure. Update `ryoku/shell/CHANGELOG.md` with the user-visible launcher choice.
