# Nacre Outside-Click Dismissal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close a pinned Nacre popup when the user presses outside its body.

**Architecture:** `Scene.qml` temporarily expands the existing overlay input
mask to the monitor while `selectedPopup` is set. A transparent catcher behind
the popup asks the scene whether the press is outside the selected popup and
clears the selection only for an outside press.

**Tech Stack:** QML, Quickshell layer-shell regions, Qt pointer handlers.

## Global Constraints

- Modify only `/home/nero/Work/ryoku-arch-unstable`.
- Treat `/home/nero/Work/ryoku-arch` as read-only.
- Consume the outside press instead of forwarding it to the underlying app.
- Preserve inside-popup controls, island handlers, and hover-only popups.
- Commit locally and do not push.

---

### Task 1: Guarded popup backdrop

**Files:**
- Modify: `tests/ui/nacre-popup-probe.qml`
- Modify: `ryoku/shell/quickshell/pill/barstyles/nacre/Scene.qml`
- Modify: `ryoku/shell/CHANGELOG.md`

**Interfaces:**
- Consumes: `selectedPopup`, each popout's `bodyX`, `bodyY`, `bodyWidth`, and
  `bodyHeight`.
- Produces: `popupBackdropActive: bool`, `selectedPopupBounds(): rect`, and
  `dismissPopupAt(x: real, y: real): bool`.

- [ ] **Step 1: Write the failing regression probe**

After selecting connectivity in `tests/ui/nacre-popup-probe.qml`, require:

```qml
const bounds = scene.item.selectedPopupBounds();
if (!scene.item.popupBackdropActive || bounds.width <= 0 || bounds.height <= 0)
    throw new Error("NACRE-POPUP-BACKDROP-PROBE-FAIL");
if (scene.item.dismissPopupAt(bounds.x + bounds.width / 2,
        bounds.y + bounds.height / 2) || scene.item.selectedPopup !== "connectivity")
    throw new Error("NACRE-POPUP-INSIDE-PRESS-PROBE-FAIL");
if (!scene.item.dismissPopupAt(0, scene.item.barSpan + 100)
        || scene.item.selectedPopup !== "" || scene.item.popupBackdropActive)
    throw new Error("NACRE-POPUP-OUTSIDE-PRESS-PROBE-FAIL");
```

- [ ] **Step 2: Run the probe and verify RED**

Run:

```bash
tests/ui/nacre-popup-probe.sh
```

Expected: failure because `selectedPopupBounds`, `popupBackdropActive`, and
`dismissPopupAt` do not exist.

- [ ] **Step 3: Implement the minimal scene behavior**

In `Scene.qml`, map each selectable popup ID to its existing popout item. Return
the selected body's rectangle from `selectedPopupBounds()`. Make
`dismissPopupAt(x, y)` return false for no selection or an inside point;
otherwise clear `selectedPopup` and return true.

Bind the overlay mask to a full-monitor `Region` while
`popupBackdropActive` is true. Add a full-size `MouseArea` before the existing
`FocusScope`, enable it only for a pinned selection, and call
`dismissPopupAt(mouse.x, mouse.y)` from `onPressed`.

- [ ] **Step 4: Verify GREEN and related probes**

Run:

```bash
node ryoku/shell/framebars/NacreConfig.test.mjs
tests/ui/nacre-editor-probe.sh
tests/ui/nacre-popup-probe.sh
tests/ui/framebars-variant-probe.sh
bin/ryoku-dev-verify-delivery
git diff --check
```

Expected: every command exits zero.

- [ ] **Step 5: Commit, deploy, and test the real pointer path**

Commit:

```bash
git add ryoku/shell/quickshell/pill/barstyles/nacre/Scene.qml \
  ryoku/shell/CHANGELOG.md tests/ui/nacre-popup-probe.qml
git commit -m "[global] shell: dismiss nacre popups on outside click"
```

Deploy with `ryoku dev switch unstable-dev`, restart `ryoku-shell.service`,
open connectivity, click the desktop outside its body, and verify the popup
closes while the underlying app does not receive that first press. Verify a
second click reaches the app and keyboard input still works.
