# Nacre Frame, Drag, and Health Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reuse Sumi's frame for Nacre, prevent drag gestures from corrupting Flow geometry, and replace health words with icons.

**Architecture:** Add one normalized Nacre frame boolean, let the existing shell-wide `FrameChrome` render for that state without Sumi rails, and keep Nacre islands joined to its top band. Split each editor chip into a fixed layout slot and a movable visual child. Keep the resources popup unchanged while making the compact face icon-led.

**Tech Stack:** Qt 6 QML, Quickshell, JavaScript configuration tests, QML probes

## Global Constraints

- Modify only `/home/nero/Work/ryoku-arch-unstable`.
- Reuse `FrameChrome`; do not duplicate the Sumi frame.
- Keep Sumi rails disabled while Nacre is active.
- Commit locally and do not push.
- Add no narrative production comments.

---

### Task 1: Stable drag slots

**Files:**
- Modify: `ryoku/hub/quickshell/barstudio/NacreWidgetChip.qml`
- Test: `tests/ui/nacre-editor-probe.qml`

**Interfaces:**
- Consumes: existing chip drag payload and Flow geometry.
- Produces: a fixed delegate slot and independently translated visual child.

- [ ] Add a probe that moves a chip's drag visual and verifies the delegate slot remains at its Flow position.

```qml
const slotX = chip.x;
const visual = root.findObject(chip, "nacre-widget-visual-activeWindow");
visual.x = 80;
require(chip.x === slotX, "drag visual preserves flow slot");
```

- [ ] Run `tests/ui/nacre-editor-probe.sh` and confirm it fails.
- [ ] Move appearance and drag handling into a visual child while leaving the root slot stationary.

```qml
Item {
    width: Math.min(144, visualLabel.implicitWidth + 20)
    height: 32

    Rectangle {
        id: visual
        width: parent.width
        height: parent.height
        Drag.source: root
        DragHandler { id: drag; target: visual }
    }
}
```

- [ ] Run editor, keyboard, and model probes.
- [ ] Commit with `[global] hub: stabilize nacre widget dragging`.

### Task 2: Shared Sumi frame toggle

**Files:**
- Modify: `ryoku/shell/framebars/NacreConfig.js`
- Modify: `ryoku/shell/quickshell/pill/shell.qml`
- Modify: `ryoku/shell/quickshell/pill/barstyles/nacre/Scene.qml`
- Modify: `ryoku/hub/quickshell/barstudio/NacreAppearance.qml`
- Test: `ryoku/shell/framebars/NacreConfig.test.mjs`
- Test: `tests/ui/nacre-editor-probe.qml`
- Test: `tests/ui/framebars-variant-probe.qml`

**Interfaces:**
- Consumes: the existing `FrameChrome` and global frame appearance values.
- Produces: normalized `nacre.frame`, its Bar Studio switch, and Nacre-aware frame visibility/reserves.

- [ ] Add failing model and QML assertions for the default, normalization, staging, and editor switch.

```js
eq(Nacre.defaultConfig().frame, true, "frame defaults on");
eq(Nacre.normalize({ frame: false }).frame, false, "frame false survives normalization");
eq(Nacre.setValue(Nacre.defaultConfig(), "frame", false).frame, false, "frame can be staged");
```

- [ ] Add `frame: true` to the Nacre default and normalization path.

```js
output.frame = typeof source.frame === "boolean" ? source.frame : base.frame;
```

- [ ] Show `FrameChrome` for Sumi or enabled Nacre, using thin global frame reserves for Nacre.

```qml
readonly property bool nacreFrameActive: Config.barStyle === "nacre"
    && Config.normalizedNacre.frame

FrameChrome {
    reserveTop: root.sumiActive ? root.edgeReserve("top") : root.frameBorderPx
    reserveBottom: root.sumiActive ? root.edgeReserve("bottom") : root.frameBorderPx
    reserveLeft: root.sumiActive ? root.edgeReserve("left") : root.frameBorderPx
    reserveRight: root.sumiActive ? root.edgeReserve("right") : root.frameBorderPx
    visible: !overlay.monFullscreen
        && ((Config.frameEnabled && root.sumiActive) || root.nacreFrameActive)
}
```

- [ ] Remove Nacre's independent hairline and attach islands to the shared top band.
- [ ] Add the frame switch to Nacre appearance controls.

```qml
Sw {
    objectName: "nacre-frame"
    on: root.config.frame
    onToggled: value => root.changed("frame", value)
}
```

- [ ] Run model, editor, framebar, and popup probes.
- [ ] Commit with `[global] shell: share sumi frame with nacre`.

### Task 3: Icon-led system health

**Files:**
- Modify: `ryoku/shell/quickshell/pill/barstyles/nacre/widgets/Resources.qml`
- Test: `tests/ui/nacre-popup-probe.qml`

**Interfaces:**
- Consumes: `Sysinfo` values and `Pill.MaterialIcon`.
- Produces: CPU, memory, and temperature icon/value groups with unchanged popup behavior.

- [ ] Add a probe assertion for three health icon groups and no compact CPU/RAM words.

```qml
const resources = nacreResources.createObject(root);
require(root.findObject(resources, "nacre-health-cpu"), "cpu health icon");
require(root.findObject(resources, "nacre-health-memory"), "memory health icon");
require(!root.visibleText(resources).includes("CPU ")
    && !root.visibleText(resources).includes("RAM "), "health face has no word labels");
```

- [ ] Run `tests/ui/nacre-popup-probe.sh` and confirm it fails.
- [ ] Replace compact word labels with `memory`, `memory_alt`, and `thermostat` icons plus numeric values.

```qml
Row {
    HealthValue { glyph: "memory"; value: Math.round(Sysinfo.cpu * 100) + "%" }
    HealthValue { glyph: "memory_alt"; value: Math.round(Sysinfo.mem * 100) + "%" }
    HealthValue { visible: Sysinfo.hasTemp; glyph: "thermostat"; value: Math.round(Sysinfo.tempC) + "°" }
}
```

- [ ] Run popup and URL-loading probes.
- [ ] Commit with `[global] shell: use icons for nacre system health`.

### Task 4: Deploy and verify

**Files:**
- Modify only if a live-only defect is reproduced.

**Interfaces:**
- Consumes: committed Nacre corrections.
- Produces: a clean deployed `unstable-dev` shell and Hub.

- [ ] Run all focused JavaScript, QML, Go, delivery, and diff checks.
- [ ] Deploy with `ryoku/shell/deploy.sh`.
- [ ] Restart `ryoku-shell`, select Nacre, and open Bar Studio.
- [ ] Inspect fresh pill and Hub logs for QML or widget failures.
- [ ] Confirm the active track and clean worktree; do not push.
