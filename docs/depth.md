# Depth (奥行)

The wallpaper's subject, cut out and drawn **in front of** the desktop widgets,
so the clock reads as sitting *inside* the scene rather than on top of it. It is
turned on, tuned and composed from its own **Depth** tab in the Super+Escape
quick-settings sidebar, the way the audio spectrum is placed.

Depth is not a depth map or a 3D effect. It is two images and a strict layer
order: the wallpaper behind, the widgets in the middle, and a transparent PNG of
the wallpaper's foreground subject on top. The illusion is entirely composition,
so the two things that decide whether it looks deliberate are (1) the cutout
staying pixel-locked to the wallpaper and (2) the clock sitting in the subject's
negative space. Both are handled below.

## How the parts fit

```
ryoku-shell daemon                     shell (QML)
------------------                     -----------
wallpaper apply / depth refresh        depth/Singletons/Config.qml  (depth.json)
  -> scheduleDepth (async worker)          |  enabled, model, alphaMatting, feather, lift, front
  -> ryoku-depth cutout <wp> <out.png>     v
  -> wallEntry.depthPath                QuickSettingsDepth.qml (on/off, model, edge, COMPOSE)
  -> wall.republish()                      |
        |  wallpaper topic (+ "depth")     v
        +------------------------------> Wallpaper.qml -> depthUrl -> Desktop.qml
                                             |
                                             v
                                         DepthForeground.qml  (cutout above widgets)
```

- **The daemon owns generation.** Producing the cutout is slow and must never
  touch a frame, so it runs on a coalescing worker off the wallpaper hot path,
  the same way `scheduleTheme`/`paintWorker` runs matugen (`ipc/matugen.go`).
  The cutout path rides the existing wallpaper topic as a new `depth` field, so
  no second socket or surface is introduced.
- **QML only renders.** `DepthForeground` draws the published cutout above the
  widget slots with the wallpaper's own fill mode. It runs no model and makes no
  policy decision.
- **The segmentation engine is opt-in.** The base desktop ships the UI, the
  daemon plumbing and the `ryoku-depth` helper, but **not** the model or its
  runtime. The first time depth is switched on, the Depth tab offers to
  install the engine. Nothing heavy lands in the base ISO, matching how Extras
  and Rashin are opt-in.

## Configuration: `~/.config/ryoku/depth.json`

A self-seeded, watched, GUI-managed file, mirroring `visualizer.json` exactly
(`depth/Singletons/Config.qml`, a `FileView` + `JsonAdapter` with a `settle`
coalescer). Because the package ships no file at this path, `ryoku materialize`
never clobbers it and an update never resets a user's choice - the same
update-safety `visualizer.json` already relies on (`docs/updates.md`). No
`shell.json` key, no doctor reconciler, no delivery-check orphan.

| Key | Type | Default | What it is |
|---|---|---|---|
| `enabled` | bool | `false` | Master on/off. Also the daemon's cue to generate. |
| `model` | string | `u2netp` | Segmentation model. The UI offers only the curated set the installed engine actually carries. |
| `alphaMatting` | bool | `false` | Edge refinement. Traces finer edges (hair, fur) at some cost in generation time. Regenerates the cutout when changed. |
| `feather` | real 0..1 | `0.15` | Edge softness of the cutout, a mask blur at the silhouette. |
| `lift` | real 0..1 | `1.0` | Foreground strength. Below 1 lets a hint of the background through the subject for a softer set-in. |
| `front` | list\<string\> | `[]` | Widget ids that draw *above* the cutout (default: every widget behind the subject). Each widget's right-click menu toggles its own; the compose bar also quick-toggles the clock. |

`available` is **not** config; it is reported live by `DepthBackend` (below).

Setter API on the singleton (each an immediate or settled write, mirroring the
visualiser): `setEnabled(on)`, `setModel(m)`, `setFeather(v)`, `setLift(v)`,
`toggleFront(widgetId)`. `setEnabled(true)` and `setModel` also nudge the daemon
to (re)generate for the current wallpaper via `ryoku-shell depth refresh`.

## The segmentation helper: `ryoku-depth`

A bash system helper shipped to `/usr/bin` (like `ryoku-reload-cover`), the one
place model logic lives. It keeps the heavy runtime out of the base by
provisioning a self-contained backend on demand.

| Subcommand | Contract |
|---|---|
| `ryoku-depth check` | Exit 0 and print `available` when a working backend + at least one model is present; else exit non-zero and print `missing`. |
| `ryoku-depth models` | Print the usable model ids, one per line (for the UI's curated pick). |
| `ryoku-depth cutout <in> <out.png> [--model <id>] [--alpha-matting]` | Write a transparent PNG of the foreground; exit non-zero on any failure (never write a partial file). |
| `ryoku-depth install` | Provision the backend (a Ryoku-managed venv at `~/.local/state/ryoku/depth/venv` with `rembg[cpu]` + a prefetched model), streaming progress to stdout. Opt-in; never run automatically. |

Backend resolution: a Python that can `import rembg`, the Ryoku-managed venv
first, then a system `python3.11`-`3.13` (rembg needs that range, and the API is
called so the CLI extra is not required). CPU is the contract; a GPU is never
required (generation is a one-shot, off-frame job, per
`beta19features/depth-stack-versus-lightweight-models.md`).
The default model is `u2netp` (~4.6 MB); heavier models are offered only if the
engine reports them.

## Daemon integration (`ipc/`)

- **Topic.** `wallEntry` gains `depthPath` and `depthRev` (the cutout's mtime);
  `wallFrameEntry` gains `Depth string json:"depth"` and `DepthRev` (contract
  08). `republish()` and the publish path carry them; an empty `depth` means no
  cutout (disabled, still generating, video, or the engine is absent).
- **Reading intent.** `depthConfig()` reads `enabled`/`model`/`alphaMatting` from
  `depth.json` per apply, mirroring `wallpaperContentFit()` reading `shell.json`.
- **Worker.** `scheduleDepth()` -> `depthWorker()` coalesces like the theme
  worker: for each on-screen still wallpaper (read from the saved per-output
  state), if enabled and `ryoku-depth check` passes, resolve its cutout in
  `~/Pictures/Depth` (reusing the saved file when it still matches, else
  `ryoku-depth cutout <wallpaper> <out> --model <m>`), then `setDepth` and
  `republish()`. Videos are skipped (a static cutout over motion drifts). A
  failure leaves the cutout empty and is logged, never fatal.
- **Triggers.** Every wallpaper apply/repaint schedules depth when enabled; the
  `depth refresh` IPC subcommand (called by the Config singleton on enable or
  model change) sets a force flag so the current wallpaper regenerates in place.

## Where cutouts live: `~/Pictures/Depth`

Cutouts are not a hidden cache; they are the user's, kept where they can be found
and reused. Each is a PNG named after its wallpaper (`<wallpaper>-depth.png`), one
per wallpaper, together in `~/Pictures/Depth`. A hidden `.index.json` records the
source and model each was made from, so a returning wallpaper is shown instantly
while a change (a new model, an edited image) regenerates in place; the published
`depthRev` (the file's mtime) refreshes a regenerated file at the same path.
Nothing prunes them - they persist for reuse - and the Depth tab's **Saved
cutouts / SHOW FILES** action opens the folder.

## Rendering (`modules/depth/`, `modules/desktop/`, `shell.qml`)

- `Wallpaper.qml` parses `depth` + `depthRev` and exposes `depthUrl`
  (`file://<path>?v=<depthRev>`), alongside `wallpaperUrl`.
- `shell.qml` passes `depthUrl: wallpaper.depthUrl` into `Desktop` beside the
  existing `wallpaperUrl`/`wallpaperFit`.
- `desktop/DepthForeground.qml`: a full-surface `Image` of the cutout, `fillMode`
  resolved through the wallpaper's fit (the same switch as
  `wallpaper/Backdrop.fillModeFor`, mirrored inline and kept in sync so the cutout and
  the wallpaper can never crop differently), `sourceSize` set, a short opacity
  crossfade on url change, `opacity: Config.lift`, and an edge feather via a
  single `MultiEffect` mask pass driven by `Config.feather`. No `MouseArea`, so
  widget drag and the desktop menu pass straight through.
- `Desktop.qml` places `DepthForeground` above the widget slots. A widget id in
  `Config.front` raises that slot's `z` above the cutout, so "in front of subject"
  is a `z` swap, not a second renderer. Every built-in slot binds it, and a
  widget's right-click menu (or the clock's compose-bar toggle) edits the set.

## Compose mode (the "place the visualiser" analogue)

- `ShellState` gains a per-screen `depthComposing` flag beside `visualizerPlacing`.
- The Depth tab's **COMPOSE** button enables depth, sets
  `ShellState.forActive().depthComposing = true`, and closes the panel -
  the exact shape of the visualiser's PLACE button (`QuickSettingsDepth.qml`).
- While composing, `Desktop.qml` shows the cutout at full strength (even mid-tune),
  frees every widget for dragging (locks suspended like visualiser placement,
  restored on Done), and raises `depth/DepthEditBar.qml`: a compact toolbar
  mirroring the visualiser's `EditBar` chrome with only the honest knobs - a
  **Feather** slider, a **Foreground** (lift) slider, a **Clock in front** toggle,
  a **Regenerate** action (re-run the model for the current wallpaper), and
  **Done** (or Esc/Enter, since the layer holds the keyboard while composing). The
  user nestles the clock (or any widget) into the subject's negative space with the
  ordinary widget drag, seeing the overlap live. There is no cutout move/resize and
  no image editor: the cutout is locked to the wallpaper by contract.

## Availability + install (`depth/Singletons/DepthBackend.qml`)

A tiny singleton that runs `ryoku-depth check` (a `Process`) and exposes
`available`, `installing`, and the installed `models`. The DEPTH card binds to it:
when unavailable it shows an **Install engine** action (`ryoku-depth install`,
streamed progress) that fetches the small default model; once available a **Higher
quality** action fetches the larger `birefnet-general-lite` on demand, and the
**Model** picker (labelled Fast / Quality) appears once more than one is present.
Generation degrades safely without it - the daemon's `cutout` simply fails and
`depthUrl` stays empty, so the desktop is never broken by a missing engine.

## Delivery

- QML (`modules/depth/`, the `DepthForeground`, the card edits) and the daemon
  changes ship in the normal shell tree that `deploy.sh` lays and the
  `ryoku-shell` package builds - no new config path to seed.
- `ryoku-depth` installs to `/usr/bin` from both `ryoku/shell/deploy.sh` and the
  `ryoku-shell` PKGBUILD, beside `ryoku-livewall` and `ryoku-reload-cover`.
- The model + runtime are provisioned by `ryoku-depth install` on first enable,
  never shipped in the base image.
- Every user-visible string goes through `I18n.tr`; new strings land in
  `ryoku/ui/translations/en.json`. The shell CHANGELOG gets a `Note: New:` line.

## Verification

`go build ./...` (daemon) and its unit tests (topic carries `depth`, worker
coalesces, `depthConfig` parses); `qmllint` on the new/edited QML; `bash -n` +
shellcheck on `ryoku-depth`; `ryoku-dev-verify-delivery`. The live visual result
and the real cutout quality require a running session with the engine
provisioned, exercised on the dev box via `dev-run.sh`; the model-quality
acceptance corpus is in `beta19features/depth-stack-versus-lightweight-models.md`.

## Design references

- `beta19features/nibras-clock-and-depth-trace.md` - the proven two-image stack.
- `beta19features/ryoku-widget-and-depth-adaptation.md` - the integration seam.
- `beta19features/depth-stack-versus-lightweight-models.md` - the model/runtime call.
