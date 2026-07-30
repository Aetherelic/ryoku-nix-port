# Selectable App Launcher Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Main, Hero, and OkShell as selectable app launcher variants, default existing and new installs to Hero, and make future variants a folder plus one catalog entry.

**Architecture:** `launcher/shell.qml` becomes a stable Quickshell selector that owns IPC and loads one `Scope` from `catalog.json`. Variant-specific QML lives under `variants/<id>/`; current providers, state, helpers, and reusable views move once under `shared/`. Ryoku Settings reads the same catalog, writes `launcher.json.variant`, loads each variant's preview, and hides controls unsupported by that variant.

**Tech Stack:** Qt 6 QML, Quickshell `ShellRoot`/`Scope`/`Loader`/`FileView`, JavaScript, JSON, Go-supervised Quickshell configs, Hyprland, shell QA, Node 20 tests.

## Global Constraints

- Preserve exactly three initial IDs: `main`, `hero`, and `okshell`.
- The catalog default is `hero`; the one-shot load fallback is `okshell`.
- Keep one daemon-supervised Quickshell config named `launcher` and one stable IPC target named `launcher`.
- OkShell remains applications-only. Main and Hero use the current shared Dispatcher and providers.
- Never duplicate provider directories, configuration singletons, JavaScript helpers, or the shipped hero art.
- Every variant root is a Quickshell `Scope` exposing `show(string monitor)`, `hide()`, `toggle(string monitor)`, `shown`, and `stateDump()`.
- A variant change while open must close the old variant and wait for `shown === false` before loading the new one.
- An unknown configured ID resolves to Hero. A QML load error falls back once to OkShell and never loops.
- `launcher.json.variant` is additive. Do not add a doctor migration.
- Follow the paper-and-ink tokens and existing launcher visuals; do not redesign any variant during the move.
- Do not touch the unrelated working-tree changes already present in the repository.
- Use the shell development loop for behavioral proof. Permanent tests and documentation are cleanup after the three launchers work live.

---

### Task 1: Add the launcher catalog and persisted selection

**Files:**
- Create: `ryoku/shell/quickshell/launcher/catalog.json`
- Create: `ryoku/shell/quickshell/launcher/lib/catalog.js`
- Modify: `ryoku/shell/quickshell/launcher/Singletons/LauncherConfig.qml`

**Interfaces:**
- Produces: `Catalog.normalize(raw) -> { defaultId, fallbackId, variants }`
- Produces: `Catalog.entry(catalog, requestedId) -> variant entry`
- Produces: `Catalog.defaultEntry(catalog) -> variant entry`
- Produces: `Catalog.fallbackEntry(catalog) -> variant entry`
- Produces: `LauncherConfig.variant: string`, defaulting to `"hero"`
- Consumes: existing `~/.config/ryoku/launcher.json` through `LauncherConfig.qml`

- [ ] **Step 1: Create the catalog with one source of truth for IDs, labels, entrypoints, previews, and capabilities**

Write `catalog.json` with this schema and data:

```json
{
  "version": 1,
  "default": "hero",
  "fallback": "okshell",
  "variants": [
    {
      "id": "main",
      "name": "Main",
      "description": "Compact command palette with a centered RestDashboard image card.",
      "entrypoint": "variants/main/Main.qml",
      "preview": "variants/main/Preview.qml",
      "capabilities": ["shape", "background", "results", "hero"]
    },
    {
      "id": "hero",
      "name": "Hero",
      "description": "Full HeroShutter image header with modes, actions, and provider results.",
      "entrypoint": "variants/hero/Main.qml",
      "preview": "variants/hero/Preview.qml",
      "capabilities": ["shape", "background", "results", "hero"]
    },
    {
      "id": "okshell",
      "name": "OkShell",
      "description": "Fast applications-only list in Ryoku's live palette.",
      "entrypoint": "variants/okshell/Main.qml",
      "preview": "variants/okshell/Preview.qml",
      "capabilities": []
    }
  ]
}
```

- [ ] **Step 2: Implement strict catalog normalization and fallback lookup**

Implement `lib/catalog.js` with these rules:

```javascript
function safeQmlPath(value) {
  return typeof value === "string"
    && /^variants\/[a-z0-9-]+\/[A-Za-z][A-Za-z0-9]*\.qml$/.test(value)
    && value.indexOf("..") < 0;
}

function normalize(raw) {
  if (!raw || raw.version !== 1 || !Array.isArray(raw.variants))
    throw new Error("launcher catalog must be version 1");

  var ids = {};
  var variants = raw.variants.map(function (source) {
    var id = String(source.id || "");
    if (!/^[a-z0-9-]+$/.test(id) || ids[id])
      throw new Error("launcher catalog has an invalid or duplicate id: " + id);
    if (!safeQmlPath(source.entrypoint) || !safeQmlPath(source.preview))
      throw new Error("launcher catalog has an unsafe QML path for: " + id);
    ids[id] = true;
    return {
      id: id,
      name: String(source.name || id),
      description: String(source.description || ""),
      entrypoint: source.entrypoint,
      preview: source.preview,
      capabilities: Array.isArray(source.capabilities)
        ? source.capabilities.map(String) : []
    };
  });

  var defaultId = String(raw.default || "");
  var fallbackId = String(raw.fallback || "");
  if (!ids[defaultId] || !ids[fallbackId])
    throw new Error("launcher catalog default and fallback must name entries");
  return { defaultId: defaultId, fallbackId: fallbackId, variants: variants };
}

function find(catalog, id) {
  for (var i = 0; i < catalog.variants.length; i++)
    if (catalog.variants[i].id === id) return catalog.variants[i];
  return null;
}

function defaultEntry(catalog) { return find(catalog, catalog.defaultId); }
function fallbackEntry(catalog) { return find(catalog, catalog.fallbackId); }
function entry(catalog, requestedId) {
  return find(catalog, String(requestedId || "")) || defaultEntry(catalog);
}

if (typeof module !== "undefined" && module.exports)
  module.exports = { safeQmlPath, normalize, find, entry, defaultEntry, fallbackEntry };
```

- [ ] **Step 3: Add the additive launcher config property**

In `LauncherConfig.qml`, expose `property alias variant: adapter.variant`, then add this adapter property next to the other launcher defaults:

```qml
property string variant: "hero"
```

Do not modify `reconcile_launcher.go`; absent user keys intentionally resolve through this QML default.

- [ ] **Step 4: Run a one-off catalog experiment before integrating QML**

Run:

```bash
node -e 'const fs=require("fs"), c=require("./ryoku/shell/quickshell/launcher/lib/catalog.js"); const x=c.normalize(JSON.parse(fs.readFileSync("ryoku/shell/quickshell/launcher/catalog.json"))); if(c.entry(x,"missing").id!=="hero"||c.fallbackEntry(x).id!=="okshell") process.exit(1); console.log(x.variants.map(v=>v.id).join(","))'
```

Expected output:

```text
main,hero,okshell
```

- [ ] **Step 5: Commit the catalog foundation**

```bash
git add ryoku/shell/quickshell/launcher/catalog.json ryoku/shell/quickshell/launcher/lib/catalog.js ryoku/shell/quickshell/launcher/Singletons/LauncherConfig.qml
git commit -m "[global] launcher: add the variant catalog"
```

---

### Task 2: Cut over to shared runtime, Hero, OkShell, and the stable selector

**Files:**
- Replace: `ryoku/shell/quickshell/launcher/shell.qml`
- Move: `ryoku/shell/quickshell/launcher/art/` to `ryoku/shell/quickshell/launcher/shared/art/`
- Move: `ryoku/shell/quickshell/launcher/lib/` to `ryoku/shell/quickshell/launcher/shared/lib/`
- Move: `ryoku/shell/quickshell/launcher/providers/` to `ryoku/shell/quickshell/launcher/shared/providers/`
- Move: `ryoku/shell/quickshell/launcher/Singletons/` to `ryoku/shell/quickshell/launcher/shared/Singletons/`
- Move shared QML: `AnswerPanel.qml`, `AskPanel.qml`, `CategoryTabs.qml`, `HelpPanel.qml`, `Spinner.qml`, `WeatherGlyph.qml` into `ryoku/shell/quickshell/launcher/shared/`
- Create: `ryoku/shell/quickshell/launcher/variants/hero/Main.qml`
- Move Hero views: `ActionShelf.qml`, `FrostLayer.qml`, `HeroShutter.qml`, `Launcher.qml`, `LauncherSurface.qml`, `LeadResult.qml`, `LocalFrost.qml`, `ModeKey.qml`, `ResultDrawer.qml`, `ResultLedger.qml`, `WindowRail.qml`, `WindowRailSurface.qml` into `ryoku/shell/quickshell/launcher/variants/hero/`
- Create: `ryoku/shell/quickshell/launcher/variants/okshell/Main.qml`
- Modify: `ryoku/hub/quickshell/pages/LauncherPage.qml` only to update the shipped-art path after the move

**Interfaces:**
- Consumes: Task 1 catalog helpers and `LauncherConfig.variant`
- Produces: stable selector IPC functions `toggle(mon)`, `show(mon)`, `hide()`
- Produces: stable command socket at `$XDG_RUNTIME_DIR/ryoku-launcher.sock`
- Produces: selector `stateDump()` including `variant`, `requestedVariant`, `availableVariants`, and the active variant's state
- Produces: working Hero and OkShell variant contract implementations

- [ ] **Step 1: Preserve the active OkShell implementation before replacing `shell.qml`**

Move the current `shell.qml` body into `variants/okshell/Main.qml`, with these mechanical changes:

```qml
// Root type changes from ShellRoot to Scope.
Scope {
    id: root
    property bool openRequested: false
    readonly property bool shown: openRequested || closeSettler.running

    Timer {
        id: closeSettler
        interval: root.pushMs
    }

    function show(mon) {
        closeSettler.stop();
        monitor = mon || "";
        query = "";
        sel = 0;
        openRequested = true;
    }
    function hide() {
        if (!openRequested) return;
        openRequested = false;
        closeSettler.restart();
    }
    function toggle(mon) { openRequested ? hide() : show(mon); }

    function stateDump() {
        return {
            open: openRequested,
            query: query,
            selectedIndex: sel,
            resultCount: rows.length,
            showHidden: showHidden
        };
    }
}
```

Retarget OkShell's window position and animation progress from the old `shown` flag to `openRequested`; keep window visibility tied to the new terminal `shown` flag. This lets the 420 ms slide-out finish before the selector unloads the Scope. Remove OkShell's local `IpcHandler`; the new selector owns it.

- [ ] **Step 2: Restore the Hero entrypoint from the parent of the stand-in commit**

Recover `e7901f06^:ryoku/shell/quickshell/launcher/shell.qml` as `variants/hero/Main.qml`. Change its root from `ShellRoot` to `Scope`, remove its `IpcHandler` and `SocketServer`, and preserve its lifecycle, providers, monitor recovery, focus handling, surfaces, and `stateDump()`. Expose `readonly property bool shown: lifecycleState.phase !== Lifecycle.PHASES.CLOSED`; unlike `openRequested`, this stays true through the close animation and becomes false only after cleanup is complete.

Its imports become:

```qml
import "../../shared/Singletons"
import "../../shared/providers"
import "../../shared/lib/lifecycle.js" as Lifecycle
```

Update Hero view imports so shared references use `../../shared`, `../../shared/Singletons`, and `../../shared/lib/...`. Imports between Hero files stay local.

- [ ] **Step 3: Move shared runtime and Hero files without copying them**

Move the directories and QML files listed above. Preserve provider-relative imports by keeping `providers`, `Singletons`, and `lib` as sibling directories under `shared/`. Update any shared root component that imported `Singletons` or `lib` to use paths relative to `shared/`.

Update Hub's shipped fallback from:

```qml
"/quickshell/launcher/art/hands-adam.png"
```

to:

```qml
"/quickshell/launcher/shared/art/hands-adam.png"
```

and update the installed relative URL to:

```qml
Qt.resolvedUrl("../../launcher/shared/art/hands-adam.png")
```

- [ ] **Step 4: Implement the stable selector**

The replacement `launcher/shell.qml` must:

1. parse `catalog.json` with `shared/lib/catalog.js`;
2. resolve `LauncherConfig.variant` through `Catalog.entry`;
3. keep `activeId`, `requestedId`, and `pendingId` explicit;
4. delegate IPC to `variantLoader.item`;
5. close an open item before changing `Loader.source`;
6. include the active variant's state in the command-socket JSON;
7. fall back once to OkShell on `Loader.Error`.

Use this structure:

```qml
//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "shared/Singletons"
import "shared/lib/catalog.js" as Catalog

ShellRoot {
    id: root

    property var catalog: null
    property string activeId: ""
    property string requestedId: LauncherConfig.variant
    property string pendingId: ""
    property bool fallbackTried: false

    function selectEntry(id) {
        return catalog ? Catalog.entry(catalog, id) : null;
    }

    function activate(id) {
        var next = selectEntry(id);
        if (!next) return;
        activeId = next.id;
        variantLoader.source = Qt.resolvedUrl(next.entrypoint);
    }

    function requestVariant(id) {
        var next = selectEntry(id);
        if (!next || next.id === activeId) return;
        pendingId = next.id;
        if (variantLoader.item && variantLoader.item.shown)
            variantLoader.item.hide();
        else
            finishSwitch();
    }

    function finishSwitch() {
        if (!pendingId) return;
        var next = pendingId;
        pendingId = "";
        fallbackTried = false;
        activate(next);
    }

    function show(mon) {
        if (variantLoader.item) variantLoader.item.show(mon);
    }
    function hide() {
        if (variantLoader.item) variantLoader.item.hide();
    }
    function toggle(mon) {
        if (variantLoader.item) variantLoader.item.toggle(mon);
    }

    function stateDump() {
        var state = variantLoader.item ? variantLoader.item.stateDump() : {};
        state.variant = activeId;
        state.requestedVariant = requestedId;
        state.availableVariants = catalog
            ? catalog.variants.map(function (entry) { return entry.id; }) : [];
        return state;
    }

    FileView {
        id: catalogFile
        path: Qt.resolvedUrl("catalog.json")
        blockLoading: true
        printErrors: true
        onLoaded: {
            root.catalog = Catalog.normalize(JSON.parse(text()));
            root.activate(LauncherConfig.variant);
        }
    }

    onRequestedIdChanged: if (catalog) requestVariant(requestedId)

    Loader {
        id: variantLoader
        asynchronous: false
        onStatusChanged: {
            if (status !== Loader.Error) return;
            var fallback = Catalog.fallbackEntry(root.catalog);
            if (!root.fallbackTried && fallback && root.activeId !== fallback.id) {
                root.fallbackTried = true;
                root.activeId = fallback.id;
                source = Qt.resolvedUrl(fallback.entrypoint);
            }
        }
    }

    Connections {
        target: variantLoader.item
        function onShownChanged() {
            if (!target.shown) root.finishSwitch();
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(mon: string): void { root.toggle(mon); }
        function show(mon: string): void { root.show(mon); }
        function hide(): void { root.hide(); }
    }

    // Preserve the Hero socket protocol: state, toggle, show, and hide.
    SocketServer {
        active: true
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
            + "/ryoku-launcher.sock"
        handler: Socket {
            id: commandSocket
            parser: SplitParser {
                onRead: line => {
                    var command = String(line || "").trim();
                    if (command === "state")
                        commandSocket.write(JSON.stringify(root.stateDump()) + "\n");
                    else {
                        var parts = command.split(" ");
                        var fn = parts[0];
                        var mon = parts.length > 1 ? parts[1] : "";
                        var ok = fn === "show" ? (root.show(mon), true)
                            : fn === "hide" ? (root.hide(), true)
                            : fn === "toggle" ? (root.toggle(mon), true) : false;
                        commandSocket.write(ok ? "ok\n" : "err\n");
                    }
                }
            }
        }
    }
}
```

During implementation, keep the actual socket write syntax and lifecycle helpers from the recovered Hero entrypoint where they are stricter than this structural excerpt.

- [ ] **Step 5: Parse the moved QML before running it**

Run `qmllint` on the new selector, both `Main.qml` files, and every moved root-level shared/Hero QML file. Expected: no import or type resolution errors. Advisory style warnings already present before the move do not justify unrelated edits.

- [ ] **Step 6: Smoke-test Hero and OkShell from the checkout**

Start the real shell with:

```bash
ryoku/shell/dev-run.sh
```

With `launcher.json.variant` absent, invoke `ryoku/shell/ipc/ryoku-shell launcher`. Expected: Hero opens, the center image and mode keys render, and the command socket reports `.variant == "hero"`.

Set `variant` to `okshell` through an atomic edit of the test copy used by the QA fixture, then invoke the same command. Expected: OkShell opens, lists applications only, and the socket reports `.variant == "okshell"`.

Restore the user's launcher config through the QA fixture teardown before stopping the dev shell.

- [ ] **Step 7: Commit the working two-variant cutover**

```bash
git add ryoku/shell/quickshell/launcher ryoku/hub/quickshell/pages/LauncherPage.qml
git commit -m "[global] launcher: isolate hero and okshell variants"
```

---

### Task 3: Restore the Main launcher against current shared providers

**Files:**
- Create from `main`: `ryoku/shell/quickshell/launcher/variants/main/Main.qml`
- Create from `main`: `ActionPanel.qml`, `BrandMark.qml`, `BtConnections.qml`, `Launcher.qml`, `MediaSources.qml`, `NowPlaying.qml`, `RadioAside.qml`, `RestDashboard.qml`, `ResultGrid.qml`, `ResultList.qml`, `SearchRow.qml`, `Squircle.qml` under `variants/main/`
- Reuse: shared `AnswerPanel.qml`, `AskPanel.qml`, `CategoryTabs.qml`, `HelpPanel.qml`, `Spinner.qml`, `WeatherGlyph.qml`
- Reuse: all current `shared/providers/`, `shared/Singletons/`, `shared/lib/`, and `shared/art/`

**Interfaces:**
- Consumes: the stable variant root contract from Task 2
- Consumes: current `shared/providers/Providers.qml` and Dispatcher contracts
- Produces: Main's compact RestDashboard UI with the current provider/action behavior
- Produces: Main `stateDump()` compatible with selector and QA state output

- [ ] **Step 1: Recover only historical Main view files**

For each file in the Create list, recover its exact content from `main:ryoku/shell/quickshell/launcher/<file>`. Do not recover the historical `providers`, `Singletons`, `lib`, `art`, or `qa` directories.

Recover historical `shell.qml` as `variants/main/Main.qml`; change its root to `Scope` and remove its local `IpcHandler` and command socket because Task 2 owns both.

- [ ] **Step 2: Point Main at current shared code**

Update imports in `Main.qml` and its views:

```qml
import "../../shared"
import "../../shared/Singletons"
import "../../shared/providers"
import "../../shared/lib/<module>.js" as <Alias>
```

Keep local imports for Main-only files. Replace the historical art reference with:

```qml
Qt.resolvedUrl("../../shared/art/hands-adam.png")
```

Do not add compatibility copies or aliases under `variants/main/`.

- [ ] **Step 3: Adapt the old view to the current provider result contract**

Use the current result fields and actions already consumed by Hero:

- identity: `providerId` plus stable `id`
- presentation: `title`, `subtitle`, `icon`, optional `preview`
- primary behavior: `actions[0].execute()`
- secondary actions: remaining entries in `actions`
- provider activity: current Dispatcher busy and result notifications

Main's `Launcher.qml`, `ResultList.qml`, `ResultGrid.qml`, and `ActionPanel.qml` must consume those fields directly. Remove historical branches that expect retired result or provider properties rather than adding adapters to shared providers.

- [ ] **Step 4: Expose the standard root and state contract**

Main `Main.qml` must expose `shown`, `show(mon)`, `hide()`, `toggle(mon)`, and `stateDump()`. Define `shown` from Main's terminal surface lifecycle, not merely its open request, so it stays true until the close animation has unmapped the surface and restored blur/focus. Include at least:

```qml
function stateDump() {
    var dump = launcher ? launcher.stateDump() : {};
    dump.open = shown;
    dump.monitor = openMonitor;
    return dump;
}
```

Use the historical Main names when they differ, but return `open`, `monitor`, `query`, `resultCount`, and `selectedIndex` consistently.

- [ ] **Step 5: Parse and smoke-test Main**

Run `qmllint` over `variants/main/*.qml`. Then select `main`, invoke the launcher, and observe all of these:

- separate search row above the compact image-backed RestDashboard;
- configured image focal point and strength;
- app search and one non-app provider query;
- arrow selection and Enter execution;
- close by Escape with focus and blur restored;
- socket state reports `.variant == "main"`.

- [ ] **Step 6: Commit Main as the third working variant**

```bash
git add ryoku/shell/quickshell/launcher/variants/main
git commit -m "[global] launcher: restore the main variant"
```

---

### Task 4: Add variant-owned previews and the Hub selector

**Files:**
- Create: `ryoku/shell/quickshell/launcher/variants/main/Preview.qml`
- Create: `ryoku/shell/quickshell/launcher/variants/hero/Preview.qml`
- Create: `ryoku/shell/quickshell/launcher/variants/okshell/Preview.qml`
- Modify: `ryoku/hub/quickshell/pages/LauncherPage.qml`
- Modify: `ryoku/hub/quickshell/schema/LauncherPage.js`

**Interfaces:**
- Each Preview consumes: `property var settings`
- Each Preview produces: `signal editRequested(string key, var value)`
- Hub consumes: `catalog.json` variants and capabilities
- Hub produces: atomic `launcher.json.variant` writes through the existing draft/committed adapter

- [ ] **Step 1: Give every variant a preview component**

Each `Preview.qml` is a visual-only `Item` with:

```qml
Item {
    property var settings: ({})
    signal editRequested(string key, var value)
    implicitWidth: 720
    implicitHeight: 250
}
```

Hero Preview moves the existing 720 by 250 inline preview from `LauncherPage.qml`, including image crop dragging. Replace `pg.edit(...)` calls with `editRequested(...)`.

Main Preview renders the separate search row plus the compact RestDashboard card using the same shared hero image settings. OkShell Preview renders its bare search row, eye control, and representative application rows; it does not consume hero settings.

- [ ] **Step 2: Load the catalog once in LauncherPage**

Add a blocking `FileView` whose path follows the established dev/install split:

```qml
readonly property string launcherRoot: {
    var shellDir = String(Quickshell.env("RYOKU_SHELL_DIR") || "");
    return shellDir.length > 0
        ? shellDir + "/quickshell/launcher"
        : String(Qt.resolvedUrl("../../launcher")).replace(/^file:\/\//, "");
}

FileView {
    id: catalogFile
    path: pg.launcherRoot + "/catalog.json"
    blockLoading: true
    printErrors: true
    onLoaded: pg.catalog = JSON.parse(text())
}
```

Expose helpers `variantEntry(id)`, `variantNames()`, `idForVariantName(name)`, `activeCapabilities()`, and `supports(capability)` from this parsed data. Do not duplicate the three IDs in Hub QML.

- [ ] **Step 3: Persist the selection through the existing draft model**

Add `"variant"` to `pg.keys`, add `"variant": "hero"` to `pg.factory`, and add this adapter property:

```qml
property string variant: "hero"
```

`resetDefaults()` must therefore select Hero without special handling.

- [ ] **Step 4: Add the registry-driven selector**

At the start of the settings content, add a `Section` and `Cell` using the existing `Seg` primitive:

```qml
Section {
    title: I18n.tr("LAUNCHER")
    columns: 1

    Cell {
        label: I18n.tr("Style")
        description: pg.variantEntry(pg.draft.variant).description
        source: "launcher.json"

        Seg {
            anchors.right: parent.right
            options: pg.variantNames()
            current: pg.variantEntry(pg.draft.variant).name
            onChose: name => pg.edit("variant", pg.idForVariantName(name))
        }
    }
}
```

- [ ] **Step 5: Replace the inline Hero preview with the selected variant Preview**

Keep the existing `Preview` frame, but replace its hardcoded card body with a `Loader`:

```qml
Loader {
    id: variantPreview
    anchors.fill: parent
    source: "file://" + pg.launcherRoot + "/"
        + pg.variantEntry(pg.draft.variant).preview
    onLoaded: {
        item.settings = Qt.binding(function () { return pg.draft; });
        item.editRequested.connect(function (key, value) { pg.edit(key, value); });
    }
}
```

Scale the loaded item's `implicitWidth` and `implicitHeight` inside the existing preview stage rather than hardcoding Hero's geometry in the Hub page.

- [ ] **Step 6: Gate settings groups by catalog capabilities**

Apply these visibility rules:

```qml
visible: pg.supports("shape")       // radius section/cell
visible: pg.supports("background")  // local frost
visible: pg.supports("results")     // result settle
visible: pg.supports("hero")        // weather, greeting, image, focal controls
```

OkShell then shows the selector and its preview without irrelevant Hero controls. Main and Hero retain the current settings.

- [ ] **Step 7: Add the selector to Hub global search metadata**

Prepend this row to `schema/LauncherPage.js` without copying catalog options:

```javascript
{
  "tab": "",
  "group": "LAUNCHER",
  "key": "variant",
  "label": "Style",
  "desc": "Selects Main, Hero, or OkShell for Super+Space",
  "ctl": "seg",
  "src": "launcher.json"
}
```

- [ ] **Step 8: Smoke-test through the actual Hub save flow**

Run the checkout shell and Hub. For each variant:

1. choose it in App Launcher;
2. confirm the preview changes before Save;
3. confirm the dirty count increases by one;
4. Save;
5. invoke `Super+Space`;
6. confirm the selected variant opens;
7. reopen the Hub and confirm the saved selection is committed.

Also verify Reset to Defaults selects Hero in the draft and Save makes Hero active.

- [ ] **Step 9: Commit the Hub selector and previews**

```bash
git add ryoku/shell/quickshell/launcher/variants/*/Preview.qml ryoku/hub/quickshell/pages/LauncherPage.qml ryoku/hub/quickshell/schema/LauncherPage.js
git commit -m "[ryoku] hub: select the app launcher variant"
```

---

### Task 5: Prove switching, cleanup, and fallback behavior live

**Files:**
- Modify only if smoke testing exposes a defect: `ryoku/shell/quickshell/launcher/shell.qml`
- Modify only if cleanup is incomplete: the affected `variants/*/Main.qml`

**Interfaces:**
- Consumes: all three working variants and Hub selection from Tasks 2 through 4
- Produces: verified close-before-swap behavior and one-shot OkShell fallback

- [ ] **Step 1: Exercise a closed variant switch**

Open and close Hero, save Main in the Hub, and invoke `Super+Space`. Confirm Main opens on the focused monitor and the socket reports:

```json
{
  "variant": "main",
  "requestedVariant": "main",
  "open": true
}
```

- [ ] **Step 2: Exercise an open variant switch**

Keep Main open, then save Hero from the Hub. Observe that Main closes first. Confirm:

- Main's layer surface becomes unmapped;
- compositor blur returns to its pre-launcher value;
- Hyprland `input:follow_mouse` returns to the probed value;
- the command socket remains reachable;
- the state reports `variant == "hero"` only after Main reports hidden;
- the next `Super+Space` opens Hero.

Repeat Hero to OkShell so both animated and immediate-close variants cross the selector boundary.

- [ ] **Step 3: Exercise unknown-ID handling**

Using the QA fixture's temporary launcher config, set `variant` to `does-not-exist`. Restart or reload the launcher config and invoke it. Expected: Hero opens and state reports `variant == "hero"` while `requestedVariant` preserves the invalid configured value for diagnosis.

- [ ] **Step 4: Exercise the one-shot load fallback**

In a disposable worktree edit only, change Main's catalog entrypoint to `variants/main/Missing.qml`, select Main, and invoke the launcher. Expected: the selector logs one Loader error, loads OkShell, reports `variant == "okshell"`, and does not loop. Revert the disposable catalog edit immediately after observing the result.

- [ ] **Step 5: Fix only observed lifecycle defects and repeat the exact failed scenario**

If any cleanup or switching assertion fails, change the source that owns that state. Do not add delays to hide the symptom. Repeat the same scenario until the surface, blur, focus, socket, and active ID all converge.

- [ ] **Step 6: Commit any source-level lifecycle correction**

If no correction was necessary, skip this commit. Otherwise:

```bash
git add ryoku/shell/quickshell/launcher/shell.qml ryoku/shell/quickshell/launcher/variants
git commit -m "[global] launcher: make variant switching converge"
```

---

### Task 6: Add permanent contract coverage and finish delivery cleanup

**Files:**
- Create: `ryoku/shell/quickshell/launcher/shared/lib/catalog.test.mjs`
- Modify: `ryoku/shell/quickshell/launcher/qa/run.sh`
- Modify: `ryoku/shell/quickshell/launcher/qa/scenarios.json`
- Modify: `ryoku/shell/quickshell/launcher/qa/README.md`
- Modify: `docs/launcher.md`
- Modify: `ryoku/shell/CHANGELOG.md`

**Interfaces:**
- Tests: catalog IDs/default/fallback/path safety and unknown-ID resolution
- Tests: live selection of Main, Hero, and OkShell through the stable command socket
- Documents: variant folder contract and add-a-variant procedure

- [ ] **Step 1: Add the catalog unit test now that the live feature works**

Create `catalog.test.mjs` with Node's test runner. It must read the real `catalog.json` and cover observable catalog rules:

```javascript
import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const Catalog = require("./catalog.js");
const raw = JSON.parse(fs.readFileSync(
  new URL("../../catalog.json", import.meta.url), "utf8"));

test("catalog exposes the three launchers with Hero default and OkShell fallback", () => {
  const catalog = Catalog.normalize(raw);
  assert.deepEqual(catalog.variants.map(v => v.id), ["main", "hero", "okshell"]);
  assert.equal(Catalog.defaultEntry(catalog).id, "hero");
  assert.equal(Catalog.fallbackEntry(catalog).id, "okshell");
  assert.equal(Catalog.entry(catalog, "unknown").id, "hero");
});

test("catalog rejects duplicate ids and unsafe entrypoints", () => {
  assert.throws(() => Catalog.normalize({
    version: 1,
    default: "hero",
    fallback: "hero",
    variants: [
      { id: "hero", name: "Hero", entrypoint: "../shell.qml", preview: "variants/hero/Preview.qml" },
      { id: "hero", name: "Again", entrypoint: "variants/hero/Main.qml", preview: "variants/hero/Preview.qml" }
    ]
  }));
});
```

- [ ] **Step 2: Run the shell unit suite**

Run:

```bash
RYOKU_PATH="$PWD" tests/shell-unit-tests.sh
```

Expected: all discovered `.test.mjs` files pass, including `catalog.test.mjs`.

- [ ] **Step 3: Extend the live QA DSL with a reversible `variant <id>` step**

In `qa/run.sh`, add a helper that uses the existing fixture backup and an atomic temporary file to update only `.variant` in `launcher.json`. Add this dispatcher branch:

```bash
"variant "*) set_variant "${step#variant }"; sleep 0.5 ;;
```

`set_variant` must preserve every other launcher key and must create a valid JSON object when the file is absent. Teardown restores the original file through `fixtures.sh`.

- [ ] **Step 4: Add focused live scenarios**

Add scenarios that assert:

- `variant hero`, show, and `.variant == "hero"` with the Hero rest face;
- `variant main`, show, and `.variant == "main"` with a non-empty provider result;
- `variant okshell`, show, and `.variant == "okshell"` with application rows;
- show Main, then `variant hero`, settle, and assert the selector closed Main before activating Hero;
- `variant does-not-exist`, show, and assert `.variant == "hero"`.

Keep the existing Hero scenarios unchanged and run them with Hero explicitly selected by suite setup so a user's saved selection cannot change the QA target.

- [ ] **Step 5: Run live launcher QA**

With the checkout shell running:

```bash
ryoku/shell/quickshell/launcher/qa/run.sh
```

Expected: every state assertion, shell assertion, input step, screenshot step, and teardown passes. Review the evidence screenshots under `/tmp/launcher-qa/run-<timestamp>/` for all three variant faces.

- [ ] **Step 6: Run QML and delivery checks**

Run `qmllint` on:

- `launcher/shell.qml`;
- all `variants/main/*.qml`;
- all `variants/hero/*.qml`;
- all `variants/okshell/*.qml`;
- all moved `shared/*.qml` and `shared/Singletons/*.qml`;
- `hub/quickshell/pages/LauncherPage.qml`.

Then run:

```bash
bin/ryoku-dev-verify-delivery
```

Expected: every launcher catalog, shared file, variant file, and preview is delivered; there are no orphan paths.

- [ ] **Step 7: Update launcher documentation**

Replace the obsolete OkShell-stand-in section in `docs/launcher.md` with:

- Hero is the default;
- Main, Hero, and OkShell behavior summaries;
- the App Launcher selector and persisted `launcher.json.variant` key;
- the `catalog.json`, `shared/`, and `variants/<id>/` structure;
- the standard `Main.qml` and `Preview.qml` contracts;
- the exact add-a-variant flow: folder, entrypoint, preview, catalog row, live smoke, QA.

Update paths elsewhere in the document from root `launcher/Singletons`, `launcher/providers`, `launcher/lib`, and `launcher/art` to their `launcher/shared/...` locations.

- [ ] **Step 8: Update the shell changelog**

Add one concise user-facing entry to `ryoku/shell/CHANGELOG.md`: App Launcher now offers Main, Hero, and OkShell styles in Ryoku Settings, with Hero restored as the default.

- [ ] **Step 9: Commit tests and delivery cleanup**

```bash
git add ryoku/shell/quickshell/launcher/shared/lib/catalog.test.mjs ryoku/shell/quickshell/launcher/qa docs/launcher.md ryoku/shell/CHANGELOG.md
git commit -m "[global] launcher: verify selectable variants"
```

- [ ] **Step 10: Run the final changed-surface audit**

Run:

```bash
prowl-agent changed
prowl-agent doctor
```

Confirm the reported blast radius contains the launcher, Hub App Launcher page, shell delivery, and launcher docs only. Resolve any new dangling reference or orphan path before integration.
