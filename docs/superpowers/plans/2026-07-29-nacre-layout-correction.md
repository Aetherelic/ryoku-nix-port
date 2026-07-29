# Nacre Layout Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make live Nacre islands hug populated widgets and make Bar Studio's widget lanes wrap without overlap.

**Architecture:** Keep the existing registry and configuration model. Correct the live island's intrinsic visibility and anchor lifecycle, then change the editor from three fixed columns to stacked auto-height lanes with bounded chips.

**Tech Stack:** Qt 6 QML, Quickshell, JavaScript model tests, shell QML probes

## Global Constraints

- Modify only `/home/nero/Work/ryoku-arch-unstable`.
- Keep every existing Nacre/Obi widget available.
- Commit locally and do not push.
- Add no narrative production comments.

---

### Task 1: Live island geometry

**Files:**
- Modify: `ryoku/shell/quickshell/pill/barstyles/nacre/components/Island.qml`
- Modify: `ryoku/shell/quickshell/pill/barstyles/nacre/Scene.qml`
- Test: `tests/ui/nacre-popup-probe.qml`
- Test: `tests/ui/nacre-popup-probe.sh`

**Interfaces:**
- Consumes: `widgetIds`, `naturalWidth`, and the existing three scene positions.
- Produces: `hasWidgets`, zero-sized empty islands, and safe delegate alignment.

- [ ] Add a probe that creates empty and populated islands, changes their models, and destroys them.
- [ ] Run `tests/ui/nacre-popup-probe.sh` and confirm the current null-anchor warning or empty-island mismatch fails.
- [ ] Make island width, height, surface, border, and scene mask participation depend on visible content.
- [ ] Replace the delegate's transient `parent.verticalCenter` dereference with stable alignment.
- [ ] Run the popup probe and confirm it passes without QML warnings.
- [ ] Commit with `[global] shell: correct nacre island geometry`.

### Task 2: Responsive Bar Studio lanes

**Files:**
- Modify: `ryoku/hub/quickshell/barstudio/NacreEditor.qml`
- Modify: `ryoku/hub/quickshell/barstudio/NacreIslandLane.qml`
- Modify: `ryoku/hub/quickshell/barstudio/NacreWidgetChip.qml`
- Modify: `ryoku/hub/quickshell/barstudio/NacrePalette.qml`
- Test: `tests/ui/nacre-editor-probe.qml`
- Test: `tests/ui/nacre-editor-probe.sh`

**Interfaces:**
- Consumes: existing `moved` and `removed` drag/drop signals.
- Produces: stacked full-width lanes, content-driven height, and bounded elided chips.

- [ ] Extend the editor probe to require vertical lane order, content-driven heights, and bounded chip width.
- [ ] Run `tests/ui/nacre-editor-probe.sh` and confirm it fails.
- [ ] Replace the three-column editor row with a column of full-width lanes.
- [ ] Bind lane and palette heights to their wrapping flows.
- [ ] Cap chip width, elide labels, and keep drag reset inside the source layout.
- [ ] Run editor, keyboard, model, and popup probes.
- [ ] Commit with `[global] hub: make nacre editor responsive`.

### Task 3: Deploy and live verification

**Files:**
- Modify only if a live-only defect is reproduced.

**Interfaces:**
- Consumes: committed Nacre layout corrections.
- Produces: a clean live `unstable-dev` pill and Bar Studio session.

- [ ] Run JavaScript tests, all Nacre/Bar Studio probes, relevant Go tests, delivery verification, and `git diff --check`.
- [ ] Run `ryoku/shell/deploy.sh`.
- [ ] Restart `ryoku-shell`, keep `barStyle` set to `nacre`, and open Hub at `bar-studio`.
- [ ] Inspect fresh pill and Hub logs for QML warnings, unresolved types, and failed widgets.
- [ ] Confirm the worktree is clean and do not push.
