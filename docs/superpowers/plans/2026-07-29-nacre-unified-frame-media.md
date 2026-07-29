# Nacre Unified Frame and Media Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render Nacre's frame and islands as one `FrameChrome` body and keep an assigned music player visible while idle.

**Architecture:** Publish per-monitor island item references through a runtime-only `NacreGeometry` singleton. Extend `FrameChrome` to carve three top lobes into its desktop hole, and suppress the islands' separate surfaces while unified. Keep the media face mounted with an idle label when MPRIS has no player.

**Tech Stack:** Qt 6 QML, Quickshell, Canvas path geometry, QML probes

## Global Constraints

- Modify only `/home/nero/Work/ryoku-arch-unstable`.
- Extend the existing `FrameChrome`; do not add another frame renderer.
- Keep geometry runtime-only and monitor-scoped.
- Commit locally and do not push.
- Add no narrative production comments.

---

### Task 1: Unified frame geometry

**Files:**
- Create: `ryoku/shell/framebars/NacreGeometry.qml`
- Modify: `ryoku/shell/framebars/qmldir`
- Modify: `ryoku/shell/quickshell/pill/FrameChrome.qml`
- Modify: `ryoku/shell/quickshell/pill/shell.qml`
- Test: `tests/ui/nacre-popup-probe.qml`

**Interfaces:**
- Produces: `NacreGeometry.attach(screenName, islands)`, `detach(screenName)`, and `islands(screenName)`.
- Consumes: `FrameChrome.topLobes`, an array of live items with `x`, `y`, `width`, `height`, and `visible`.

- [ ] Add a QML probe that passes three lobe rectangles to `FrameChrome.holePoints()` and requires the hole path to descend below the frame band.

```qml
const points = frame.holePoints(2, 2, 998, 798, [
    { x: 2, y: 0, width: 180, height: 42, visible: true },
    { x: 430, y: 0, width: 140, height: 42, visible: true },
    { x: 820, y: 0, width: 178, height: 42, visible: true }
]);
require(points.some(point => point.y === 42), "frame follows island lobes");
```

- [ ] Run `tests/ui/nacre-popup-probe.sh` and confirm the lobe-path assertion fails.
- [ ] Add the monitor-scoped runtime geometry singleton and export it from `qmldir`.

```qml
pragma Singleton
import QtQuick

QtObject {
    property var layouts: ({})
    function attach(screenName, islands) {
        const next = Object.assign({}, layouts);
        next[screenName] = islands;
        layouts = next;
    }
    function detach(screenName) {
        const next = Object.assign({}, layouts);
        delete next[screenName];
        layouts = next;
    }
    function islands(screenName) { return layouts[screenName] || []; }
}
```

- [ ] Add `topLobes` to `FrameChrome`, normalize visible lobe rectangles, and build the top edge around them before tracing the remaining desktop hole.

```qml
property var topLobes: []

function holePoints(lx, ty, rx, by, lobes) {
    const top = normalizedTopLobes(lx, ty, rx, lobes);
    if (panelAnchor === "" && top.length > 0)
        return topHolePoints(lx, ty, rx, by, top);
    // existing panel path follows
}
```

- [ ] Bind each Nacre frame overlay to `NacreGeometry.islands(overlay.modelData.name)`.
- [ ] Run the popup probe and confirm the multi-lobe path passes.
- [ ] Commit with `[global] shell: unify nacre frame silhouette`.

### Task 2: Content-only framed islands

**Files:**
- Modify: `ryoku/shell/quickshell/pill/barstyles/nacre/Scene.qml`
- Modify: `ryoku/shell/quickshell/pill/barstyles/nacre/components/Island.qml`
- Test: `tests/ui/nacre-popup-probe.qml`

**Interfaces:**
- Consumes: `NacreGeometry.attach/detach` and `Island.unifiedFrame`.
- Produces: live monitor island geometry and transparent island chrome while framed.

- [ ] Extend the probe to require zero island border and transparent island surface in unified mode.

```qml
const island = nacreIsland.createObject(root, {
    widgetIds: ["brand"], unifiedFrame: true
});
require(island.border.width === 0 && island.color.a === 0,
    "unified island paints content only");
```

- [ ] Run the popup probe and confirm it fails.
- [ ] Register the scene's three island items under its monitor name and detach them on destruction.

```qml
Component.onCompleted: NacreGeometry.attach(root.modelData.name,
    [leftIsland, centerIsland, rightIsland])
Component.onDestruction: NacreGeometry.detach(root.modelData.name)
```

- [ ] Add `unifiedFrame`; keep content and input geometry but suppress the island surface and border when true.

```qml
property bool unifiedFrame: false
color: root.unifiedFrame ? "transparent" : Qt.rgba(
    Theme.surface.r, Theme.surface.g, Theme.surface.b, root.surfaceOpacity)
border.width: root.unifiedFrame ? 0 : Theme.borderWidth
```

- [ ] Run the popup and URL-loading probes.
- [ ] Commit with `[global] shell: join nacre islands to frame`.

### Task 3: Persistent music face

**Files:**
- Modify: `ryoku/shell/quickshell/pill/barstyles/nacre/widgets/Media.qml`
- Modify: `ryoku/shell/quickshell/pill/barstyles/shared/popouts/MediaPopout.qml`
- Test: `tests/ui/nacre-popup-probe.qml`

**Interfaces:**
- Consumes: existing `Media.player`, `Media.present`, and shared transport actions.
- Produces: an always-mounted configured Nacre media face with a `No media` idle state.

- [ ] Add a probe that creates Nacre media without MPRIS data and requires it to remain visible with `No media`.

```qml
const media = nacreMedia.createObject(root);
require(media.visible, "configured media remains mounted");
require(root.visibleText(media).includes("No media"), "idle media label");
```

- [ ] Run `tests/ui/nacre-popup-probe.sh` and confirm it fails.
- [ ] Remove the Nacre face's `Media.present` visibility gate and use `No media` when `Media.line` is empty.

```qml
visible: true
text: Media.line.length > 0 ? Media.line : qsTr("No media")
```

- [ ] Give the shared popup an explicit no-player title while leaving transport disabled.
- [ ] Run popup and URL-loading probes.
- [ ] Commit with `[global] shell: keep nacre music player visible`.

### Task 4: Deploy and verify

**Files:**
- Modify user-facing docs only if descriptions need correction.

- [ ] Run focused JavaScript, QML, Go, delivery, and diff checks.
- [ ] Deploy with `ryoku/shell/deploy.sh`.
- [ ] Restart `ryoku-shell`, keep Nacre framed, and open Bar Studio.
- [ ] Inspect fresh pill and Hub logs for QML, geometry, and widget failures.
- [ ] Confirm the active track and clean worktree; do not push.
