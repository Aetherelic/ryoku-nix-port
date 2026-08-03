# Ryoku Shell Consolidation Implementation Plan

> **For agentic workers:** execute this plan phase by phase. Each phase ends at a
> committed, independently testable, and revertible state. Do NOT do more than one
> phase before verifying it live. Steps use `- [ ]` for tracking.

**Goal:** Replace the ~7-process Quickshell shell with ONE resident Quickshell
instance whose surfaces are QML modules toggled by a shared state singleton and
driven by in-QML global shortcuts, sharing one set of service singletons. Retire
the legacy `pill` name and rename every surface/file/folder to match what it does.

**Why (measured, see Baseline):** today the shell is heavy (one full Qt/QML
runtime *per surface*, ~300-470 MB each) and slow (every keybind spawns a Go
client + a `qs ipc call`, ~130 ms before a resident surface reacts; ~1.4 s cold
start for on-demand surfaces/apps). One resident instance shares a single runtime
(expected ~4-5x memory drop) and turns surface toggles into in-process property
flips (~1 ms), matching caelestia / end-4 / iNiR.

**Architecture:** a single `ShellRoot` instance. `modules/` hold UI surfaces,
`services/` hold `pragma Singleton` state/providers shared across all surfaces,
`components/` hold reusable primitives, `utils/` hold JS helpers. A `ShellState`
singleton (per-monitor `PersistentProperties`) carries every open/close flag;
surfaces are resident and bind `visible`/activation to it. A `GlobalShortcut`
wrapper registers Hyprland global-shortcuts-v1 handlers in QML, so keybinds hit
the running instance with zero process spawn. Genuinely separate apps (settings
hub, screenshot editor, VM console, wallpaper browser, store, first-run welcome)
stay their own `qs -c <app>` processes.

**Tech stack:** Quickshell 0.3.0, Qt 6.11, QML, Hyprland (global-shortcuts-v1),
Ryoku.PluginKit/FrameBars/Blobs/Ui QML modules, a slimmed Go `ryoku-shell` daemon.

---

## Global Constraints

- Pass all git hooks; NEVER `--no-verify`. Commit subjects start with one of
  `[global|installation|system|ryoku|docs|test|tooling|release]`. No em-dash in
  text files or messages, no attribution trailers, no filler comments.
- The Hyprland config is authored in Lua under `ryoku/hyprland/`; never hand-write
  `hyprland.conf`.
- One concern per file; one purpose per path; never two copies of the same thing.
- The repo is the source of truth; deploy is one-way (repo -> `~/.config`,
  `~/.local`). Every user-facing config must reach users via a package/deploy path
  (`ryoku-dev-verify-delivery`). A removed/renamed `shell.json` key needs a doctor
  reconciler in `ryoku/cli/internal/doctor/`.
- **Never leave the live desktop unbootable.** The old multi-process shell stays
  fully runnable until the new instance is proven; every deploy is snapshotted and
  revertible with one command (see Backup & Rollback).
- Do ONE phase at a time; verify live; commit; only then continue.

---

## Baseline (BEFORE) - measured 2026-08-03 on this machine

Reproduce with the Phase 0 bench (`bin/ryoku-dev-shell-bench`). Snapshot saved at
`/tmp/ryoku-perf-before.txt`; copy into `docs/plans/perf/shell-before.txt` in
Phase 0.

- **Memory:** `qs -c pill` 332-473 MB, `qs -c backdrop` 200-328 MB, daemon ~52 MB.
  **~614-900 MB with only 2 of 7 surfaces resident**; full resident set projects
  to ~1.5-2 GB. Each surface pays a full Qt runtime; 6 of 7 configs use the heavy
  `pragma UseQApplication` (Qt Widgets).
- **Launch latency:** `ryoku-shell` client roundtrip ~46-52 ms; `qs` Qt-init floor
  ~81-84 ms per `qs ipc call` spawn; keybind chain ~130 ms+ before a *resident*
  surface reacts; **~1.4 s cold start** for an on-demand surface/flock app
  (`qs -c hub`). In-QML `GlobalShortcut` usage: **0** (all 22 binds are external
  spawns via `ryoku-shell`/`ryoku-app`/`flock qs -c`).
- **Idle CPU:** ~0% when static (so the problem is memory + spawn latency, not
  idle burn; the pill's threaded render loop only spins while animating).
- **Leaks/cruft:** 6 stuck `ryoku-shell __clip-ingest` helpers (one > 1 day old).

---

## Reference patterns (all single-process; cited by the two research passes)

| Aspect | caelestia | end-4 dots | iNiR | Ryoku today |
|---|---|---|---|---|
| Process model | 1 `ShellRoot` | 1 `ShellRoot` (`ii/shell.qml:17`) | 1 `ShellRoot` | **~7 `qs -c` processes** |
| Keybind path | `GlobalShortcut` (CustomShortcut) + IpcHandler | `GlobalShortcut` in QML (`shell.qml:70`) | `GlobalShortcut` (`GlobalStates.qml:307`) | **`ryoku-shell` -> daemon -> `qs ipc` spawn** |
| Surface toggle | `ScreenState` singleton (per-monitor) | `GlobalStates` booleans | `GlobalStates` booleans | separate process + IPC / cold start |
| Shared state | ~18 `services/` singletons | ~30 singletons | ~40 singletons | 37 singletons **per process, unshared** |
| Folders | `modules/ services/ components/ utils/` | `modules/common/` + families | tiered singletons + 3 loaders | per-surface config dirs |
| Heavy/settings window | on-demand `WindowFactory` (Nexus) | LazyLoader | OnDemandPanelLoader | separate `qs -c hub` |
| Startup | eager `ServiceLoader`; `caelestia shell -d` | flat LazyLoader | tiered init T+0/500/1500 ms | Go daemon supervises N configs |

Takeaways we adopt: **caelestia's folder convention** (`modules/services/components/utils`),
**a `ShellState` per-monitor state singleton**, **`GlobalShortcut` in QML**, and
**iNiR's tiered/deferred service init** so first frame stays instant.

---

## Naming & Path Map  (defaults applied; override before Phase 1)

The single instance's config name and the module names are load-bearing. Proposed
(retiring `pill` and other legacy names); veto/adjust any row.

### The single resident instance
- Config name: **`shell`** -> launched `qs -c shell`, deployed `~/.config/quickshell/shell/`.
  (Alternatives: `ryoku`, `desktop`. Pick one; the whole plan uses `shell`.)
- Checkout home: `ryoku/shell/quickshell/shell/`.

### Surfaces that MERGE into the single instance (`modules/<name>/`)

| Today (`ryoku/shell/quickshell/`) | New module | Why the name |
|---|---|---|
| `pill/` (frame + rails + menus) | `modules/bar/` | it is the frame-bar instrument; "pill" is dead vocabulary |
| `pill/` OSD parts (`Osd*`, `RecordHud`, `BrightnessControl`) | `modules/osd/` | on-screen displays |
| `pill/` notifications (`Notification*`) | `modules/notifications/` | notification popups |
| `pill/popouts/`, `pill/FrameMenu*` | `modules/bar/popouts/`, `modules/bar/menus/` | they belong to the bar |
| `launcher/` | `modules/launcher/` | unchanged meaning |
| `overview/` | `modules/overview/` | unchanged meaning |
| `widgets/` | `modules/desktop/` | the desktop widget layer (disambiguate from `components/`) |
| `backdrop/` + `wallpaper/` | `modules/wallpaper/` (`/switcher` sub) | renderer + switcher are one concern |
| `visualizer/` | `modules/visualizer/` | unchanged meaning |
| `ryolayer/` | `modules/board/` | the Super+G tool board; "ryolayer" is legacy |
| all `*/Singletons/` | `services/` | caelestia convention; deduped/shared |
| shared primitives across surfaces | `components/` | reusable UI |
| `framebars/*.js`, helpers | `utils/` | JS helpers |

### Surfaces that STAY standalone apps (own `qs -c <app>` process, moved to `ryoku/apps/`)

| Today | New path | Why standalone |
|---|---|---|
| `ryoku/shell/quickshell/ryoshot/` | `ryoku/apps/ryoshot/quickshell/` | heavy, on-demand editor, not shell chrome |
| `ryoku/shell/quickshell/welcome/` | `ryoku/apps/welcome/quickshell/` | one-shot first-run window |
| `ryoku/hub/` | unchanged (settings app) | large settings surface |
| `ryoku/apps/{ryovm,ryowalls,ryostore}/` | unchanged | genuine apps |

### Shared QML modules (unchanged homes)
- `ryoku/shell/quickshell/plugins/kit/` -> `Ryoku.PluginKit` (already a module).
- `ryoku/ui/` -> `Ryoku.Ui`; `ryoku/shell/framebars/` -> `Ryoku.FrameBars`;
  `ryoku/shell/plugin/` -> `Ryoku.Blobs`.

### Target tree (checkout)
```
ryoku/shell/quickshell/
  shell/                       # THE single resident instance
    shell.qml                  # ShellRoot; loads services then modules
    modules/
      bar/  osd/  notifications/  launcher/  overview/
      desktop/  wallpaper/  visualizer/  board/
    services/                  # pragma Singleton providers (shared)
    components/                # reusable primitives
    utils/                     # *.js helpers + tests
  apps/                        # standalone qs apps
    ryoshot/quickshell/  welcome/quickshell/
  plugins/kit/                 # Ryoku.PluginKit (module)
```

---

## Backup & Rollback strategy

Three layers, all in place before any surface migrates:

1. **Git isolation.** All refactor work lands as small commits on `unstable-dev`
   (or a `shell-consolidation` branch if preferred). Any phase is `git revert`-able.
   The plan doc + baseline are committed first so the "before" is recorded.
2. **Live snapshot + one-command restore** (Phase 0 deliverable):
   - `bin/ryoku-shell-snapshot` -> tars `~/.config/quickshell` and
     `~/.local/lib/qt6/qml/Ryoku` to `~/.local/state/ryoku/shell-backups/<ts>.tar.zst`.
   - `bin/ryoku-shell-rollback [<ts>]` -> restores the latest (or named) snapshot
     and `systemctl --user restart ryoku-shell`. Run before every deploy; if a
     phase breaks the live shell, one command returns to the last good state.
3. **Parallel-instance safety (the important one).** The new `shell` instance is
   built and deployed ALONGSIDE the old configs. Until the cutover phase, the Go
   daemon keeps launching the old `pill`/`launcher`/... surfaces; the new instance
   is exercised only via a manual `qs -c shell` (a spare display / nested / or the
   at-rest monitor) and the bench. The live desktop is never driven by unproven
   code. Cutover (Phase 11) flips the daemon to the single instance and keeps the
   old configs on disk for one release as an instant fallback.
4. **Login fallback.** During cutover, the daemon's launch of `qs -c shell` is
   guarded: if it dies-fast N times (reuse the existing supervise backoff), the
   daemon falls back to launching the retained old `pill` config so the user
   always gets a usable bar at login. Removed only after a stable release.

---

## Performance protocol (before / after)

Phase 0 commits `bin/ryoku-dev-shell-bench`, one script both snapshots use, so the
numbers are comparable. It records, to `docs/plans/perf/shell-<label>.txt`:
- total shell RSS + per-process RSS + process count (with ALL default surfaces up);
- `ryoku-shell`/keybind trigger latency and cold-start time (or, post-cutover, the
  GlobalShortcut round-trip and the in-process toggle frame cost);
- idle CPU over a fixed window;
- clip-ingest helper count.

Protocol: capture `shell-before.txt` now (from `/tmp/ryoku-perf-before.txt`), then
re-run after Phase 11 (cutover) into `shell-after.txt`, and again after Phase 13
(cleanup). Success target: total resident RSS down >=3x; keybind-to-visible under
~30 ms for resident surfaces; no cold-start for merged surfaces; clip-ingest = 1.

---

## Phases

Each phase: **Goal / Files / Steps / Verify / Commit / Rollback.** "Verify" is the
gate; do not proceed until it passes. QML has no unit-test harness here, so
verification is: `qmllint` clean, `qs -c shell` (or the target) loads with no
`Failed to load`/`not a type`/`unavailable` in its log, renders correctly (screenshot),
and `bash tests/ui/wire-probe.sh` passes where config keys are touched.

### Phase 0: Safety net, bench, baseline (no behavior change)
- **Files:** create `bin/ryoku-shell-snapshot`, `bin/ryoku-shell-rollback`,
  `bin/ryoku-dev-shell-bench`; create `docs/plans/perf/shell-before.txt`.
- **Steps:**
  - [ ] Write `ryoku-shell-snapshot` (tar `~/.config/quickshell` + `~/.local/.../Ryoku` to a timestamped `.tar.zst`; keep last 10).
  - [ ] Write `ryoku-shell-rollback` (restore latest/named + `systemctl --user restart ryoku-shell`).
  - [ ] Write `ryoku-dev-shell-bench` (RSS/procs/latency/idle-CPU/clip-ingest -> a labeled file).
  - [ ] Take a snapshot; run the bench; save `docs/plans/perf/shell-before.txt`.
- **Verify:** `ryoku-shell-snapshot` produces a restorable archive; `ryoku-shell-rollback --dry-run` lists it; `ryoku-dev-shell-bench before` reproduces the baseline numbers; `shellcheck` clean on the new scripts.
- **Commit:** `[tooling] shell: snapshot, rollback, and perf bench for the consolidation`.
- **Rollback:** delete the three scripts; nothing else touched.

### Phase 1: Single-instance skeleton (dark, alongside the old shell)
- **Goal:** an empty `qs -c shell` that loads a `ShellRoot`, initializes shared
  services and `ShellState`, and registers a no-op GlobalShortcut, proving the
  foundation without drawing anything.
- **Files:** create `ryoku/shell/quickshell/shell/shell.qml` (ShellRoot);
  `services/ShellState.qml` (pragma Singleton, per-monitor `PersistentProperties`
  via `Variants`); `services/ServiceLoader.qml` (eager/tiered init);
  `components/CustomShortcut.qml` (GlobalShortcut wrapper, appid `ryoku`);
  `utils/` (seed from `pill/framebars/RailGeometry.js` etc. as they are needed);
  add `shell` to `ryoku/shell/deploy.sh` install (deploy the dir, do NOT add it to
  the daemon component list yet).
- **Steps:**
  - [ ] Author `ShellState` with the full flag set (barVisible, launcherOpen, overviewOpen, wallpaperOpen, boardOpen, osd state, per-monitor) mirroring today's surfaces; `forScreen()/forActive()` accessors.
  - [ ] Author `shell.qml` ShellRoot: instantiate `ServiceLoader`, one per-screen `Variants` scope (empty for now), and a `CustomShortcut { name: "noop" }`.
  - [ ] Deploy `shell` dir (install.sh) next to the old configs.
- **Verify:** `qmllint` clean; `qs -c shell` loads with no errors (log shows Configuration Loaded), draws nothing, uses one process; live shell (old `pill`) still runs untouched; `ryoku-dev-shell-bench probe-shell` shows one clean process.
- **Commit:** `[ryoku] shell: single-instance skeleton (ShellState, ServiceLoader, GlobalShortcut)`.
- **Rollback:** `git revert`; remove `~/.config/quickshell/shell`; old shell unaffected.

### Phase 2: Migrate the bar/frame (retire `pill` core)
- **Goal:** the frame + rails + masthead render inside `qs -c shell`, toggled by
  `ShellState`, keybind via GlobalShortcut. Old `pill` still drives the live desktop.
- **Files:** move `pill/FrameChrome.qml FrameSurface.qml FrameMenu*.qml framebars/`
  and bar deps -> `shell/modules/bar/`; move `pill/Singletons/*` that the bar needs
  -> `shell/services/` (dedupe as you go); wire the bar to `ShellState`; register
  the bar reveal GlobalShortcut. Update imports (`import "../widgets"` etc. become
  in-instance relative or module imports; apply the cross-config lesson: no
  cross-config relative imports).
- **Steps:**
  - [ ] Move bar files; fix imports; register bar services in `services/`.
  - [ ] Bind bar `visible`/reveal to `ShellState`; add `CustomShortcut` for bar toggle.
  - [ ] `qmllint`; load `qs -c shell`; screenshot the bar.
- **Verify:** `qs -c shell` shows the frame/bar correctly on all monitors, no log errors, one process; old `pill` still live; bench shows the shell process RSS (record it).
- **Commit:** `[ryoku] shell: migrate the frame bar into the single instance`.
- **Rollback:** `git revert`; old `pill` untouched and still live.

### Phases 3-8: Migrate remaining surfaces, one per phase
Same shape as Phase 2, in this order (each: move -> rename -> import-fix -> bind to
`ShellState` -> GlobalShortcut -> qmllint -> load -> screenshot -> commit -> the old
config stays as fallback):
- [ ] **Phase 3:** `launcher/` -> `modules/launcher/` (bind `ShellState.launcherOpen`).
- [ ] **Phase 4:** `overview/` -> `modules/overview/`.
- [ ] **Phase 5:** OSD + notifications out of `pill` -> `modules/osd/`, `modules/notifications/`.
- [ ] **Phase 6:** `widgets/` -> `modules/desktop/`.
- [ ] **Phase 7:** `backdrop/` + `wallpaper/` -> `modules/wallpaper/` (+ `/switcher`).
- [ ] **Phase 8:** `visualizer/` -> `modules/visualizer/`; `ryolayer/` -> `modules/board/`.
Each phase commit: `[ryoku] shell: migrate <surface> into the single instance`.

### Phase 9: Consolidate services into shared singletons
- **Goal:** one instance of each provider (audio, media, sysinfo, notifs, hypr,
  workspaces, apps, colours) in `services/`, shared by all modules; delete the
  per-surface duplicates. Add iNiR-style tiered/deferred init in `ServiceLoader`.
- **Steps:**
  - [ ] Merge duplicate singletons (`Scheme`, `Config`, `Theme`, `BrandMark`, providers) into single `services/` copies; update all module imports.
  - [ ] Tier init: critical services eager, heavy providers deferred (Timer/T+500ms).
  - [ ] `qmllint`; load; verify every surface still populates.
- **Verify:** `qs -c shell` fully functional (bar, launcher, overview, notifs, osd, desktop, wallpaper, visualizer, board), one process, no duplicate providers; bench RSS recorded.
- **Commit:** `[ryoku] shell: unify service singletons and defer heavy init`.
- **Rollback:** `git revert`; old configs still present.

### Phase 10: Keybind cutover to GlobalShortcut + daemon slim
- **Goal:** keybinds hit the running instance directly; drop the per-press process spawns.
- **Files:** `ryoku/hyprland/modules/binds.lua` (replace `ryoku-shell <cmd>` binds
  with the compositor's `global:` shortcut dispatch bound to the shell's registered
  names); `shell/modules/**` (register each `CustomShortcut`); `ryoku/shell/ipc/`
  (keep `ryoku-shell` for non-keybind duties: clipboard, wallpaper engine, settings
  store; remove the surface-toggle IPC routing that GlobalShortcut now owns).
- **Steps:**
  - [ ] Register every user action as a `CustomShortcut` in the relevant module.
  - [ ] Rewrite `binds.lua` to Hyprland `global:ryoku:<action>` bindings.
  - [ ] Remove the now-dead surface routing in `daemon.go`/`actions.go`/`control.go`.
- **Verify:** each keybind toggles its surface with no `ryoku-shell`/`qs ipc`
  process spawn (`pgrep` before/after a keypress); measure keybind-to-visible with
  the bench (target < ~30 ms).
- **Commit:** `[ryoku] shell: drive keybinds via in-QML global shortcuts` + `[global] hyprland: bind shell actions to global shortcuts`.
- **Rollback:** `git revert` both; binds.lua returns to `ryoku-shell` calls.

### Phase 11: Login cutover (single instance becomes the shell) with fallback
- **Goal:** the daemon launches `qs -c shell` instead of the old N configs; old
  configs retained as fallback.
- **Files:** `ryoku/shell/ipc/daemon.go` (`components` list -> the single `shell`
  instance + the still-separate helpers backdrop-if-split, plus the fallback guard).
- **Steps:**
  - [ ] Snapshot (`ryoku-shell-snapshot`).
  - [ ] Point the daemon at `qs -c shell`; add die-fast fallback to old `pill`.
  - [ ] Deploy; `systemctl --user restart ryoku-shell`; log out/in.
- **Verify:** full login brings up the single instance; `pgrep qs` shows ONE shell
  process (+ standalone apps only when opened); run `ryoku-dev-shell-bench after`
  -> `docs/plans/perf/shell-after.txt`; compare to before (RSS >=3x lower).
- **Commit:** `[ryoku] shell: cut the daemon over to the single instance with fallback`.
- **Rollback:** `ryoku-shell-rollback` (restores prior deploy) OR flip the daemon
  list back; both fully restore the old shell.

### Phase 12: Retire the old world + fix leaks + rename cleanup
- **Goal:** delete the superseded configs and dead code once the new shell is
  stable; fix the clip-ingest leak; purge remaining `pill`/legacy vocabulary.
- **Files:** remove `ryoku/shell/quickshell/{pill,launcher,overview,widgets,backdrop,wallpaper,visualizer,ryolayer}`;
  move `ryoshot`/`welcome` to `ryoku/apps/`; fix `ryoku/shell/ipc/clipboard.go`
  (bound/reaped clip-ingest); grep-purge `pill`/`ryolayer` names in code, docs,
  `shell.json` keys (+ doctor reconciler for any renamed key); update
  `ryoku/hyprland/modules/window_rules.lua` namespaces if surface layer names changed.
- **Steps:**
  - [ ] Only after >=1 stable session on the new shell: remove old config dirs.
  - [ ] Fix clip-ingest lifetime; verify a single helper after many clipboard events.
  - [ ] `grep -ri pill ryoku/` -> 0 legacy references; add doctor reconcilers for renamed keys.
  - [ ] Run `ryoku-dev-verify-delivery`, `ryoku-dev-scan-slop`, `tests/ui/wire-probe.sh`.
- **Verify:** clean login; delivery + wire-probe + slop pass; `pgrep __clip-ingest` = 1.
- **Commit:** `[ryoku] shell: retire the legacy multi-process configs and pill naming`, `[ryoku] shell: bound the clipboard-ingest helper lifetime`.
- **Rollback:** `git revert` (old configs return from history) + `ryoku-shell-rollback`.

### Phase 13: Record after, document, changelog
- **Steps:**
  - [ ] `ryoku-dev-shell-bench after` again; write a before/after table into the shell CHANGELOG and `docs/`.
  - [ ] Update `docs/structure.md`, `docs/ui-ux.md`, `docs/bar.md` for the new layout/names.
  - [ ] `[ryoku] shell: <summary>` + `[docs] document the consolidated shell`.
- **Verify:** docs match reality; before/after recorded; goal metrics met.

---

## Risks & mitigations
- **Cross-config import blackholes** (the bug that broke the pill): inside one
  instance all modules are same-tree, so `import "../x"` cross-config instantiation
  disappears; shared code goes through `services/`/`components/` or a real module.
- **qmldir/scan races** (the other pill bug): the single instance uses pure
  implicit scanning (no stray `module` qmldirs in the config tree) or complete
  ones; audited in Phase 1.
- **Per-monitor correctness:** `ShellState` is per-screen via `Variants` (caelestia
  pattern); test on the multi-monitor path in each migration phase.
- **`UseQApplication`:** keep it once, on the single instance (tray needs it),
  instead of 6x; revisit if the tray can use QtQuick-only.
- **Big-bang risk:** eliminated by parallel-instance + one-surface-per-phase +
  snapshot/rollback + login fallback.

---

## Decisions (common-sense defaults applied per the brief; override before Phase 1)
These are locked into the plan above so it is executable now; change any one and
the doc re-threads to match.
1. Single-instance config name: **`shell`** (alt: `ryoku`, `desktop`).
2. `pill` bar module: **`bar`** (alt: `frame`).
3. `ryolayer` -> **`board`** (alt: `tools`, keep).
4. `widgets` -> **`desktop`** (alt: keep `widgets`).
5. `ryoshot`/`welcome` -> **`ryoku/apps/`** (alt: leave under `shell/quickshell/`).
6. Branch: **`unstable-dev` directly** (alt: a `shell-consolidation` branch).
