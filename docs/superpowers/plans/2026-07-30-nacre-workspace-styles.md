# Nacre Workspace Styles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add dots, Arabic numbers, and Obi kanji workspace faces to Nacre and make widget drops show their exact destination.

**Architecture:** Extend the existing pure Nacre configuration model with one normalized `workspaceStyle` enum. Keep one workspace widget and switch only its delegate face. Preserve the editor's Flow-owned chip slots while adding lane-local preview state, insertion geometry, and empty/removal affordances.

**Tech Stack:** Qt 6 QML, Quickshell, JavaScript model tests, shell QML probes

## Global Constraints

- Modify only `/home/nero/Work/ryoku-arch-unstable`.
- Use main only as a read-only visual and behavioral reference.
- Keep production QML concise and avoid narrative comments.
- Commit locally and do not push.
- Deploy through `ryoku dev switch unstable-dev`.

---

### Task 1: Normalize and stage the workspace style

**Files:**
- Modify: `ryoku/shell/framebars/NacreConfig.js:39-143`
- Modify: `ryoku/shell/framebars/NacreConfig.test.mjs:21-110`

**Interfaces:**
- Consumes: the existing `defaultConfig()`, `normalize(raw)`, and `setValue(config, key, value)` configuration seam.
- Produces: `workspaceStyle: "dots" | "numbers" | "kanji"` on every normalized Nacre object.

- [ ] **Step 1: Write failing enum tests**

Add assertions that define the configuration contract:

```js
eq(defaults.workspaceStyle, "dots", "workspace style defaults to dots");
eq(Nacre.normalize({ workspaceStyle: "numbers" }).workspaceStyle,
    "numbers", "number workspaces survive normalization");
eq(Nacre.normalize({ workspaceStyle: "kanji" }).workspaceStyle,
    "kanji", "kanji workspaces survive normalization");
eq(Nacre.normalize({ workspaceStyle: "letters" }).workspaceStyle,
    "dots", "unknown workspace styles restore dots");
eq(Nacre.setValue(defaults, "workspaceStyle", "kanji").workspaceStyle,
    "kanji", "workspace style can be staged");
```

- [ ] **Step 2: Run the model test and confirm the red state**

Run:

```bash
node ryoku/shell/framebars/NacreConfig.test.mjs
```

Expected: failures reporting missing or unchanged `workspaceStyle`.

- [ ] **Step 3: Implement the enum**

Add:

```js
const workspaceStyles = ["dots", "numbers", "kanji"];
```

Add `workspaceStyle: "dots"` to `defaultConfig()`. In `normalize(raw)`, retain
the supplied value only when `workspaceStyles.includes(source.workspaceStyle)`.
In `setValue`, accept `workspaceStyle` alongside the existing booleans and pass
the result back through `normalize`.

- [ ] **Step 4: Run the model test and confirm green**

Run:

```bash
node ryoku/shell/framebars/NacreConfig.test.mjs
```

Expected: `All tests PASSED`.

- [ ] **Step 5: Commit the configuration contract**

```bash
git add ryoku/shell/framebars/NacreConfig.js \
  ryoku/shell/framebars/NacreConfig.test.mjs
git commit -m "[global] shell: add nacre workspace modes"
```

### Task 2: Render dots, numbers, and Obi kanji

**Files:**
- Modify: `tests/ui/nacre-popup-probe.qml:76-112,234-248`
- Modify: `ryoku/shell/quickshell/pill/barstyles/nacre/widgets/Workspaces.qml:7-90`

**Interfaces:**
- Consumes: `Config.normalizedNacre.workspaceStyle`, active workspace ID, occupancy, and Obi's `["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]` labels.
- Produces: writable `workspaceStyle` for test injection and `label(id)` for deterministic face text.

- [ ] **Step 1: Write the failing QML face probe**

Create one workspace widget and assert its public label behavior:

```qml
const workspaceFace = nacreWorkspaces.createObject(root, {
    workspaceStyle: "dots"
});
if (!workspaceFace || workspaceFace.label(1) !== "")
    throw new Error("NACRE-WORKSPACE-DOTS-PROBE-FAIL");
workspaceFace.workspaceStyle = "numbers";
if (workspaceFace.label(3) !== "3")
    throw new Error("NACRE-WORKSPACE-NUMBERS-PROBE-FAIL");
workspaceFace.workspaceStyle = "kanji";
if (workspaceFace.label(3) !== "三" || workspaceFace.label(11) !== "11")
    throw new Error("NACRE-WORKSPACE-KANJI-PROBE-FAIL");
workspaceFace.destroy();
```

- [ ] **Step 2: Run the popup probe and confirm the red state**

Run:

```bash
tests/ui/nacre-popup-probe.sh
```

Expected: `NACRE-WORKSPACE-DOTS-PROBE-FAIL` because the component has no
`workspaceStyle` or `label` interface.

- [ ] **Step 3: Implement one adaptive workspace delegate**

Add:

```qml
property string workspaceStyle: Config.normalizedNacre.workspaceStyle
readonly property var kanji: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

function label(id) {
    if (root.workspaceStyle === "dots")
        return "";
    if (root.workspaceStyle === "kanji" && id >= 1 && id <= 10)
        return root.kanji[id];
    return String(id);
}
```

Keep the existing ring geometry for `dots`. For `numbers` and `kanji`, use
26-pixel circular cells, fill the active cell with `Theme.primary`, give
occupied cells the existing subtle surface treatment, render `root.label(id)`,
and select `Theme.fontJp` only for kanji. Preserve click and wheel behavior.

- [ ] **Step 4: Run model and popup probes**

Run:

```bash
node ryoku/shell/framebars/NacreConfig.test.mjs
tests/ui/nacre-popup-probe.sh
```

Expected: both pass without QML errors or warnings.

- [ ] **Step 5: Commit the workspace faces**

```bash
git add ryoku/shell/quickshell/pill/barstyles/nacre/widgets/Workspaces.qml \
  tests/ui/nacre-popup-probe.qml
git commit -m "[global] shell: render nacre workspace modes"
```

### Task 3: Add the Bar Studio workspace selector

**Files:**
- Modify: `tests/ui/nacre-editor-probe.qml:13-134`
- Modify: `ryoku/hub/quickshell/barstudio/NacreAppearance.qml:5-147`

**Interfaces:**
- Consumes: normalized `config.workspaceStyle` and the existing
  `changed(string key, var value)` signal.
- Produces: `objectName: "nacre-workspace-style"` and stages lowercase enum
  values through `root.changed("workspaceStyle", value)`.

- [ ] **Step 1: Write the failing editor selector probe**

Add `workspaceStyle: "dots"` to the probe config and these assertions:

```qml
require(root.findObject(editor, "nacre-workspace-style"),
    "workspace style control");
editor.setAppearance("workspaceStyle", "kanji");
require(root.staged.workspaceStyle === "kanji",
    "workspace style stages");
```

- [ ] **Step 2: Run the editor probe and confirm the red state**

Run:

```bash
tests/ui/nacre-editor-probe.sh
```

Expected: `NACRE-EDITOR-PROBE-FAIL workspace style control`.

- [ ] **Step 3: Add the segmented control**

Add a responsive `Cell` to `NacreAppearance.qml`:

```qml
Cell {
    width: (root.width - Tokens.s2) / 2
    height: implicitHeight
    controlWidth: 174
    label: qsTr("Workspace style")
    value: root.config.workspaceStyle.toUpperCase()
    source: "shell.json"

    Seg {
        objectName: "nacre-workspace-style"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        options: ["DOTS", "NUMBERS", "KANJI"]
        current: root.config.workspaceStyle.toUpperCase()
        onChose: key => root.changed("workspaceStyle", key.toLowerCase())
    }
}
```

- [ ] **Step 4: Run the editor and model probes**

Run:

```bash
tests/ui/nacre-editor-probe.sh
node ryoku/shell/framebars/NacreConfig.test.mjs
```

Expected: both pass.

- [ ] **Step 5: Commit the editor setting**

```bash
git add ryoku/hub/quickshell/barstudio/NacreAppearance.qml \
  tests/ui/nacre-editor-probe.qml
git commit -m "[global] hub: expose nacre workspace modes"
```

### Task 4: Show exact drag destinations

**Files:**
- Modify: `tests/ui/nacre-editor-probe.qml:38-134`
- Modify: `ryoku/hub/quickshell/barstudio/NacreIslandLane.qml:6-72`
- Modify: `ryoku/hub/quickshell/barstudio/NacrePalette.qml:6-52`

**Interfaces:**
- Consumes: the current `insertionIndex(x, y)`, `moved(...)`, and `removed(...)`
  interfaces and fixed `NacreWidgetChip` layout slots.
- Produces: `dropIndex`, `dragPreview`, `showDropPreview(x, y)`,
  `hideDropPreview()`, `markerX`, `markerY`, and palette `removalPreview`.

- [ ] **Step 1: Write failing drop-feedback probes**

Add an empty lane and exercise the public preview seam:

```qml
BarStudio.NacreIslandLane {
    id: emptyLane
    width: 260
    islandId: "center"
    items: []
    labelFor: root.labelFor
}
```

Add assertions:

```qml
require(root.findObject(emptyLane, "nacre-empty-drop-center"),
    "empty lane drop affordance");
crowdedLane.showDropPreview(12, 44);
require(crowdedLane.dragPreview && crowdedLane.dropIndex >= 0,
    "lane tracks insertion preview");
const marker = root.findObject(crowdedLane, "nacre-drop-marker-right");
require(marker && marker.visible && marker.x >= 0
    && marker.x <= crowdedLane.width,
    "insertion marker stays inside lane");
crowdedLane.hideDropPreview();
require(!crowdedLane.dragPreview && crowdedLane.dropIndex === -1,
    "lane clears insertion preview");
const palette = root.findObject(editor, "nacre-palette");
palette.showRemovalPreview();
require(palette.removalPreview,
    "palette exposes removal preview");
palette.hideRemovalPreview();
```

- [ ] **Step 2: Run the editor probe and confirm the red state**

Run:

```bash
tests/ui/nacre-editor-probe.sh
```

Expected: `NACRE-EDITOR-PROBE-FAIL empty lane drop affordance`.

- [ ] **Step 3: Implement lane preview state and insertion marker**

Add `property int dropIndex: -1` and `property bool dragPreview: false`.
Implement:

```qml
function showDropPreview(x, y) {
    root.dragPreview = true;
    root.dropIndex = root.insertionIndex(x, y);
}

function hideDropPreview() {
    root.dragPreview = false;
    root.dropIndex = -1;
}
```

Derive `markerX`, `markerY`, and `markerHeight` from the chip at `dropIndex`, or
the final chip when inserting at the end. Clamp marker coordinates within the
lane. Add the named accent `Rectangle` and a named centred empty-lane `Text`.
Wire `DropArea.onEntered`, `onPositionChanged`, `onExited`, and `onDropped` to
the preview methods, clearing preview after a drop.

- [ ] **Step 4: Implement the palette removal affordance**

Add `property bool removalPreview: false`, `showRemovalPreview()`, and
`hideRemovalPreview()`. Bind the palette's active border/background to that
state, show `REMOVE WIDGET` during a drag, and show `ALL WIDGETS PLACED` when
the unused list is empty. Wire the DropArea signals and retain the existing
`removed(widgetId)` behavior.

- [ ] **Step 5: Run the editor probe and confirm green**

Run:

```bash
tests/ui/nacre-editor-probe.sh
```

Expected: `nacre-editor-probe: layout and appearance stage`.

- [ ] **Step 6: Run the focused regression set**

Run:

```bash
node ryoku/shell/framebars/NacreConfig.test.mjs
tests/ui/nacre-editor-probe.sh
tests/ui/nacre-popup-probe.sh
tests/ui/bar-studio-keyboard-probe.sh
git diff --check
```

Expected: all pass with no QML errors.

- [ ] **Step 7: Commit drag feedback**

```bash
git add ryoku/hub/quickshell/barstudio/NacreIslandLane.qml \
  ryoku/hub/quickshell/barstudio/NacrePalette.qml \
  tests/ui/nacre-editor-probe.qml
git commit -m "[global] hub: clarify nacre widget drops"
```

### Task 5: Document, verify, and deploy

**Files:**
- Modify: `ryoku/shell/CHANGELOG.md`

**Interfaces:**
- Consumes: committed workspace modes and drag feedback.
- Produces: a deployed and visually verified `unstable-dev` Nacre session.

- [ ] **Step 1: Add the user-facing changelog entry**

Add a concise entry describing the Nacre workspace selector and exact
drag-position feedback.

- [ ] **Step 2: Run the complete relevant suite**

Run:

```bash
node ryoku/shell/framebars/NacreConfig.test.mjs
for test in tests/ui/*.sh; do "$test"; done
bin/ryoku-dev-verify-delivery
git diff --check
```

Expected: every command exits zero.

- [ ] **Step 3: Commit the changelog**

```bash
git add ryoku/shell/CHANGELOG.md
git commit -m "[docs] describe nacre workspace choices"
```

- [ ] **Step 4: Deploy the exact unstable-dev worktree**

Run:

```bash
env RYOKU_DEV_HEARTBEAT_SECONDS=10 RYOKU_DEV_NO_LOGOUT=1 \
  fish -lc 'ryoku dev switch unstable-dev'
systemctl --user start ryoku-shell.service
ryoku-shell reload
```

Expected: the switch finishes, reports `unstable-dev`, and the pill restarts.

- [ ] **Step 5: Verify the live result**

Confirm all three workspace modes repaint immediately in Bar Studio. Drag one
widget across wrapped rows and into an empty island; confirm the marker tracks
the insertion point, the chip slot never overlaps its neighbors, and Save /
Revert remain correct. Inspect the current pill and Hub logs for QML errors.

- [ ] **Step 6: Record the machine-vault note**

Append the setting name, accepted values, commits, deployment result, and probe
result to `/home/nero/.local/share/ryoku/rashin/journal/2026-07-30.md`.
