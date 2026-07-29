# Nacre Folder Bar Style Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Nacre as a configurable folder bar style with drag-and-drop island layout and popup components shared with Obi.

**Architecture:** A tested JavaScript model owns Nacre defaults, normalization, and layout moves. Nacre renders one scene per monitor from small widget components. Popup shells and content are extracted from Obi so both styles use the same implementations.

**Tech Stack:** Qt 6 QML, Quickshell, JavaScript, Node.js tests, shell QML probes.

## Global Constraints

- Write only in `/home/nero/Work/ryoku-arch-unstable`.
- Keep `/home/nero/Work/ryoku-arch` read-only.
- One QML component per file.
- Comments explain only non-obvious reasons.
- Never bypass git hooks.
- Deploy only through the repository development workflow.

---

### Task 1: Nacre configuration and layout model

**Files:**
- Create: `ryoku/shell/quickshell/pill/barstyles/nacre/NacreConfig.js`
- Create: `ryoku/shell/quickshell/pill/barstyles/nacre/NacreConfig.test.mjs`
- Modify: `ryoku/shell/quickshell/pill/Singletons/Config.qml`
- Modify: `ryoku/hub/quickshell/Hub.qml`

**Interfaces:**
- Produces: `defaultConfig()`, `normalize(raw)`, `move(config, widgetId, sourceIsland, targetIsland, targetIndex)`, `remove(config, widgetId)`, `setValue(config, key, value)`, `widgetIds()`, and `unused(config)`.
- Produces: `Config.nacre` and `Config.normalizedNacre`.

- [ ] **Step 1: Write failing model tests**

Cover literal expected values for missing defaults, unknown and duplicate IDs,
numeric clamps, same-island reorder, cross-island move, palette add, removal,
invalid moves, source immutability, and unused widget order.

```js
const moved = Nacre.move(Nacre.defaultConfig(), "brand", "left", "right", 1);
eq(moved.islands.left, ["media", "activeWindow"], "move removes source");
eq(moved.islands.right, ["connectivity", "brand", "audio", "battery", "tray"], "move inserts at target");
```

- [ ] **Step 2: Run the test and verify RED**

Run: `node ryoku/shell/quickshell/pill/barstyles/nacre/NacreConfig.test.mjs`

Expected: failure because `NacreConfig.js` does not exist.

- [ ] **Step 3: Implement the pure model**

Use JSON cloning, a fixed widget catalog, first-occurrence duplicate removal,
and these ranges:

```js
height: [32, 56]
opacity: [0.45, 1]
padding: [6, 24]
spacing: [2, 18]
islandGap: [6, 32]
```

Same-island moves must adjust the insertion index after source removal.

- [ ] **Step 4: Run model tests and verify GREEN**

Run: `node ryoku/shell/quickshell/pill/barstyles/nacre/NacreConfig.test.mjs`

Expected: `All tests PASSED`.

- [ ] **Step 5: Wire the settings adapters**

Import the model in `Config.qml`, add `property alias nacre`, add the JSON
adapter property, and expose `readonly property var normalizedNacre:
NacreConfig.normalize(nacre)`. Add the same default object to Hub defaults and
add `nacre` to `liveKeys`.

- [ ] **Step 6: Commit**

```bash
git add ryoku/shell/quickshell/pill/barstyles/nacre/NacreConfig.js \
  ryoku/shell/quickshell/pill/barstyles/nacre/NacreConfig.test.mjs \
  ryoku/shell/quickshell/pill/Singletons/Config.qml \
  ryoku/hub/quickshell/Hub.qml
git commit -m "[global] shell: add nacre layout model"
```

### Task 2: Shared popup components

**Files:**
- Create: `ryoku/shell/quickshell/pill/barstyles/shared/Popout.qml`
- Create: `ryoku/shell/quickshell/pill/barstyles/shared/popouts/{Audio,Battery,Calendar,Connectivity,Media,Resources,Weather}Popout.qml`
- Modify: `ryoku/shell/quickshell/pill/barstyles/obi/widgets/{Audio,Battery,Clock,Connectivity,Media,Resources,Weather}.qml`
- Delete: `ryoku/shell/quickshell/pill/barstyles/obi/components/Popout.qml`

**Interfaces:**
- `Popout`: `target`, `targetHovered`, `barHeight`, `namespace`, and `content`.
- Popup content components receive only the singleton-backed properties they
  cannot read directly, such as `date`, `sink`, `source`, or `open`.

- [ ] **Step 1: Add a failing shared-popup QML probe**

Create a temporary probe under `tests/ui/` that loads `shared/Popout.qml` and
each popup content component offscreen.

- [ ] **Step 2: Run the probe and verify RED**

Run the probe script and confirm it fails because the shared components are
missing.

- [ ] **Step 3: Extract the popup shell and content**

Move the existing card bodies without visual changes. Keep the popup files
focused and remove the embedded `Component` blocks from Obi widgets. Each Obi
widget creates a `Component` containing the corresponding shared popup and
passes its required properties.

- [ ] **Step 4: Run the popup probe and existing UI probes**

Run:

```bash
tests/ui/nacre-popup-probe.sh
tests/ui/bar-studio-keyboard-probe.sh
tests/ui/framebars-variant-probe.sh
```

Expected: all pass without QML component errors.

- [ ] **Step 5: Commit**

```bash
git add ryoku/shell/quickshell/pill/barstyles/shared \
  ryoku/shell/quickshell/pill/barstyles/obi tests/ui/nacre-popup-probe.*
git commit -m "[global] shell: share obi popup components"
```

### Task 3: Nacre scene and widget faces

**Files:**
- Create: `ryoku/shell/quickshell/pill/barstyles/nacre/Scene.qml`
- Create: `ryoku/shell/quickshell/pill/barstyles/nacre/components/{Island,WidgetHost}.qml`
- Create: `ryoku/shell/quickshell/pill/barstyles/nacre/widgets/{ActiveWindow,Audio,Battery,Brand,Clock,Connectivity,Media,Resources,Tray,Utils,Weather,Workspaces}.qml`
- Create: `ryoku/shell/quickshell/pill/barstyles/nacre/widgets/registry.js`
- Modify: `tests/ui/nacre-popup-probe.qml`

**Interfaces:**
- `Scene.qml` reads `Config.normalizedNacre` and receives `modelData` as its
  monitor.
- `WidgetHost.qml` receives `widgetId` and `barHeight`.
- Each Nacre widget exposes intrinsic size and owns any shared popup host.
- `registry.js` produces `entry(id)` and `component(id)`.

- [ ] **Step 1: Extend the QML probe and verify RED**

Load `Scene.qml` and every widget component. Expect failure while those
components are absent.

- [ ] **Step 2: Implement the scene and islands**

Use one top `PanelWindow`, a top hairline, three `Island` instances, a centered
middle island, side-width limits, an island-only input mask, and config-driven
height, opacity, padding, spacing, and gap.

- [ ] **Step 3: Implement Nacre faces**

Keep legacy faces for brand, hollow-ring workspaces, textual resources, compact
clock, media, active title, and status glyphs. Use the shared popup components
for media, clock, resources, audio, battery, connectivity, and weather. Dynamic
widgets collapse when their backing singleton is unavailable.

- [ ] **Step 4: Run the QML probe**

Run: `tests/ui/nacre-popup-probe.sh`

Expected: pass with every Nacre component loadable.

- [ ] **Step 5: Commit**

```bash
git add ryoku/shell/quickshell/pill/barstyles/nacre tests/ui/nacre-popup-probe.*
git commit -m "[global] shell: add nacre folder bar"
```

### Task 4: Bar Studio drag editor and style registration

**Files:**
- Create: `ryoku/hub/quickshell/barstudio/NacreEditor.qml`
- Modify: `ryoku/hub/quickshell/pages/BarStudioPage.qml`
- Modify: `ryoku/shell/quickshell/pill/barstyles/registry.js`
- Modify: `ryoku/hub/quickshell/barstudio/BarStudioModel.test.mjs`
- Modify: `tests/ui/bar-studio-keyboard-probe.qml`

**Interfaces:**
- `NacreEditor`: `config` input and `staged(var next)` signal.
- Drag payload: `{widgetId, sourceIsland, sourceIndex}`.
- Every drop calls `NacreConfig.move` or `NacreConfig.remove` and emits one
  normalized object.

- [ ] **Step 1: Add failing editor integration assertions**

Extend the probe to require a Nacre style card, three island drop areas, an
unused palette, and the six appearance controls. Add model assertions that a
staged move preserves appearance values.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
node ryoku/hub/quickshell/barstudio/BarStudioModel.test.mjs
tests/ui/bar-studio-keyboard-probe.sh
```

Expected: failure because Nacre controls do not exist.

- [ ] **Step 3: Build the editor**

Render three horizontal drop lanes and an unused palette with QML `Drag` and
`DropArea`. Insert before, between, or after cards based on pointer position.
Add sliders for numeric settings and a switch for occupied workspaces. Stage
with `page.fedit("nacre", next)`.

- [ ] **Step 4: Register Nacre in shell and Hub**

Add the matching Nacre entry to both style lists. Show `NacreEditor` only when
`activeStyle === "nacre"`.

- [ ] **Step 5: Run tests and probes**

Expected: model and QML probes pass.

- [ ] **Step 6: Commit**

```bash
git add ryoku/hub/quickshell ryoku/shell/quickshell/pill/barstyles/registry.js tests/ui
git commit -m "[global] shell: add nacre bar studio editor"
```

### Task 5: Documentation, integration, and live deployment

**Files:**
- Modify: `ryoku/shell/CHANGELOG.md`
- Modify: `docs/barstyles.md`

**Interfaces:**
- The documented Nacre settings and folder contract match the shipped registry,
  defaults, and Bar Studio controls.

- [ ] **Step 1: Update user-facing documentation**

Add a concise Nacre entry and explain that Obi and Nacre share popup
implementations.

- [ ] **Step 2: Run focused verification**

Run:

```bash
node ryoku/shell/quickshell/pill/barstyles/nacre/NacreConfig.test.mjs
node ryoku/hub/quickshell/barstudio/BarStudioModel.test.mjs
tests/ui/nacre-popup-probe.sh
tests/ui/bar-studio-keyboard-probe.sh
tests/ui/framebars-variant-probe.sh
qmllint <each changed QML file>
prowl-agent changed
prowl-agent doctor
ryoku-dev-verify-delivery
```

If prowl-agent remains unavailable in this worktree, record that fact and use
the repository hooks plus targeted tests.

- [ ] **Step 3: Commit documentation**

```bash
git add ryoku/shell/CHANGELOG.md docs/barstyles.md
git commit -m "[docs] describe nacre folder bar"
```

- [ ] **Step 4: Deploy the unstable worktree**

Run the documented repository deploy command from
`/home/nero/Work/ryoku-arch-unstable`. Do not copy live files manually.

- [ ] **Step 5: Verify the live machine**

Confirm the active track is `unstable-dev`, restart or reload only what the
deploy workflow requires, inspect shell and Hyprland logs, select Nacre, and
exercise drag layout, Save/Revert, and shared popups on the running desktop.
