# Config import

Bring an existing setup onto Ryoku without losing it and without breaking the
desktop. A user arrives with dotfiles from another Hyprland box or another
distro (hypr, kitty, fish, fastfetch, and the other configs people carry), drops
them in, and Ryoku layers their config on top of its own defaults, shows where
the two collide (keybinds above all), lets the user resolve each collision in
the Hub, and can undo the whole import.

Status: implemented (v1). This document is the feature's reference.

## Why this exists

People do not start from nothing. They come from a hand-built rice or another
distro with a config they like, and today Ryoku has no path to carry it over:
they either abandon their setup or hand-merge files and guess at what clashes
with Ryoku's shipped binds. The result is a wall right at the first impression.

The desktop already has the two ingredients this needs: every app loads a
"user override that wins" file, and the Hub already models and conflict-checks
Hyprland keybinds. This feature joins them into one guided, reversible flow.

## The override model this builds on

Every Ryoku app has the same three tiers. Import writes into them; it never
edits the shipped base.

| Tier | What it is | Where | Who edits |
|---|---|---|---|
| Your config | Ryoku-managed, GUI-written, full file | `~/.config/ryoku/hypr.json`, `shell.json` | GUI or hand-edit (GUI reads it back) |
| Raw overrides | Hand-only, loads last, wins, updates never touch | `~/.config/hypr/user.lua`, `kitty/user.conf`, `fish/user.fish` | you, in place |
| Shipped base | Ryoku defaults, replaced every update | `~/.config/hypr/modules/`, packaged app configs | nobody |

The overlay (`~/.config/ryoku/user_edits/`) is a separate, advanced mechanism
for forking a whole shipped file; import does not use it.

### Model clarity fix (ships with, or ahead of, this feature)

The Hub FILES panel currently points "Raw overrides" at
`~/.config/ryoku/user_edits/hypr/user.lua`. Since `hypr/user.lua` became
live-owned (`internal/sys/useredits.go` `LiveOwnedConfig`) and is no longer
laid from the overlay, that path is orphaned: Hyprland loads
`~/.config/hypr/user.lua`, so a user following the Hub edits a dead file.
Repoint `Hub.qml` `settingsFiles()` "Raw overrides" to the live path and reword
the panel to the three tiers above. The import page is the discoverable answer
to "how do I bring my own config in."

## Goals and non-goals

Goals:
- Failsafe: nothing shipped is destroyed; every import is backed up and undoable.
- Drop-and-go: folder, drag-drop, an existing `~/.config`, or a git URL all work.
- Resolve collisions in place: keybind overlaps are shown and fixed in the Hub.
- Hyprland binds and window rules the user brings become first-class Ryoku
  settings (visible in the Keybinds and Window Rules pages, conflict-checked on
  every later edit), not opaque hand config.

Non-goals (v1):
- Translating arbitrary Hyprland settings into `hypr.json`. The option surface is
  huge and a mis-map silently changes behaviour; raw settings layer into
  `user.lua` and win instead.
- Deep ingest for non-Hyprland apps. kitty/fish/fastfetch and others layer on
  top; their file already wins, so there is nothing to reconcile.
- Cloud sync, profile export, theme translation. Rices and `.ryoprofile` already
  cover those.

## User flow

Hub, Advanced on, Tools group, "Import config". A wizard:

1. Source. Four affordances, no dead ends: pick a folder, drop files or a
   folder, paste a git URL (cloned to a temp dir), or accept the banner shown
   when `~/.config` already holds non-Ryoku config from a previous setup.
2. Review. One card per detected app: what was found ("47 keybinds, 12 window
   rules, 30 raw settings" / "kitty: colors + 20 settings"), an include toggle,
   and a conflict badge. A running summary ("6 apps, 8 conflicts").
3. Resolve. A conflict table, Hyprland keybinds first. Each row shows the combo,
   what Ryoku uses it for, what the user's binding does, and a segmented control
   [Keep Ryoku's] [Use mine] [Remap...]. "Remap" opens the existing chord
   recorder. Same-combo duplicates within the user's own config are flagged too.
   Non-keybind items collapse under "these layer on top and win", with the raw
   text visible.
4. Preview. The exact change set: files written, binds ingested into the GUI (N),
   unbinds and rebinds added (M), and the backup location. Apply or Cancel.
5. Done. Peak-end success ("Your keybinds are in the Keybinds page; kitty and
   fish are live"), with [Reload now] and [Undo this import].

## Scope (v1)

Three handling tiers, chosen per detected app:

- Deep (ingest into the GUI model): Hyprland only.
  - `bind` with exec/close/fullscreen/togglefloating, and app-role launches,
    become Ryoku custom binds or app roles.
  - `windowrule`/`windowrulev2` become Ryoku window rules.
  - Everything else (raw settings, animations, decoration, `env`, `monitor`,
    `exec-once`, exotic dispatchers) layers into `hypr/user.lua` verbatim.
- Layer-on-top (into the app's user-include): kitty (`user.conf`), fish
  (`user.fish`), fastfetch.
- Generic drop: any other `~/.config/<app>` the user brought that has a
  user-include or a recognisable single config (starship, other terminals and
  prompts, and similar). Placed into the app's override slot, clearly labelled,
  no parsing. Unknown trees are listed and offered, never silently applied.

Conflict detection runs on every imported bind regardless of tier, so a raw
exotic bind that shadows a Ryoku combo still surfaces. "Use mine" on a shadow
emits the Hyprland `unbind` for the shipped combo before the user's bind, because
Hyprland stacks multiple binds on one key rather than replacing; without the
unbind both would fire. This correctness is the point of resolving in place.

## Architecture

One engine, two front doors, no duplicated logic.

- Engine lives in `ryoku-hub` (`ryoku/hub/backend/import*.go`) because the
  bind-ingest path needs the hypr-overrides writer already there
  (`hypr.go` `writeRebindsLua`, the `Overrides` model, settings.lua generation)
  and the shipped-bind legend (`keybinds.go`). New verbs:
  - `ryoku-hub import scan <path|url>`  print the detected model as JSON.
  - `ryoku-hub import apply <decisions.json>`  back up, then execute.
  - `ryoku-hub import undo [<ts>]`  restore a prior import from its manifest.
- Parsers: a native Hyprland conf reader (bind, windowrule(v2), monitor, env,
  exec, settings), kitty conf, fish, fastfetch jsonc, and a generic user-include
  copier for the drop tier. The combo normalisation and pretty-printing in
  `keybinds.go` are shared; the native reader is the mirror of the existing
  `hl.bind` reader used for `binds.lua`.
- CLI: `ryoku import [path] [--undo]` is a thin wrapper that execs
  `ryoku-hub import`, matching the CLI's role as an orchestrator
  (`ryoku/cli/main.go`) rather than a second implementation. Gives a headless
  and TTY-recovery path.
- Hub UI: a new custom `ryoku/hub/quickshell/pages/ImportPage.qml` (advanced,
  Tools group, registered in the Hub catalogue like `RashinPage`). It reuses the
  conflict logic (`normKeys`, `shippedKeys`, `rowConflict`) and the chord
  recorder from `KeybindsPage.qml`; that logic moves to a shared component so
  both pages consume one copy.

## Data contracts

- scan output (stdout JSON):
  `{ source, apps: [ { id, name, present, path, summary,
     items: [ { kind, raw, combo?, dispatcher?, ingestable } ],
     conflicts: [ { combo, ryoku: { action, desc }, mine: { raw, desc }, kind } ] } ] }`
  where `kind` in a conflict is `shipped` (shadows Ryoku) or `duplicate`.
- decisions (Hub to `apply`, JSON):
  `{ apps: { <id>: { include: bool } },
     conflicts: { <combo>: "ryoku" | "mine" | { remap: "<combo>" } } }`
- backup manifest (`~/.config/ryoku/import-backups/<ts>/manifest.json`):
  `{ ts, snapshot?, files: [ { path, backup } ], overridesBefore }` so undo is a
  pure restore.

## Failsafe and undo

Before writing anything: take a snapper snapshot when snapper is available, and
always copy every file that will be touched into
`~/.config/ryoku/import-backups/<ts>/` with the manifest above. Apply writes to
temp files, validates (Lua parse for `user.lua`), then swaps; any failure rolls
back from the backup. `ryoku import --undo` and the Hub's Undo button restore the
manifest. The Hub surfaces the last import with an Undo affordance.

## Delivery

`ryoku-hub`, `ryoku`, and the Hub QML all ship in the `ryoku-desktop` package
already, so this reaches users through `ryoku update` with no new seeded config.
The backup directory is created on demand. The model-clarity fix rides the same
package. No `shell.json` key is added or removed, so no doctor reconciler is
needed.

## Testing

- Go: parser fixtures (a sample `hyprland.conf`, `kitty.conf`, `fish` config to
  the expected model and conflict set), an apply then undo round-trip that
  asserts files and hypr overrides return byte-identical, conflict
  classification (shipped shadow vs self-duplicate), and idempotency of a
  re-scan.
- Smoke: scan a fixture dotfiles tree into a temp HOME, resolve a conflict both
  ways, apply, and assert the user-include files and the hypr overrides.
- QML: the conflict logic is the already-tested `normKeys` path, now shared.

## Future (post v1)

Deep ingest for more apps (starship, yazi, nvim), private git auth, and an
export counterpart so a Ryoku box can hand its config to another.
