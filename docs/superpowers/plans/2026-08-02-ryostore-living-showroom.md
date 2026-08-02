# RyoStore Living Showroom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace RyoStore's grainy Hub-like dashboard with the approved artwork-led living showroom, filmstrip navigation, reversible detail route, and trustworthy install states.

**Architecture:** Keep the existing Go catalogue/providers and `Singletons/Store.qml` process ownership. Replace the QML presentation with a thin `App.qml` coordinator over focused header, stage, filmstrip, search, detail, cover, and status components; keep collection and selection projection pure in `lib/store.js`.

**Tech Stack:** Qt 6 / Quickshell QML, JavaScript ES modules tested with Node, Go 1.26 backend, shell-driven QML probes, `qmllint`, `ydotool`, and `grim`.

## Global Constraints

- The approved design source is `docs/superpowers/specs/2026-08-02-ryostore-showroom-design.md`.
- Preserve the normalized Go catalogue and provider contracts; this plan does not rewrite providers.
- Keep Ryoku theme roles, typography, controls, accessibility behavior, and reduced-motion policy.
- Never use `Grain`, registration grids, corner ticks, barcodes, a permanent navigation rail, a settings-sheet inspector, bento dashboards, or rounded containers around every item.
- Artwork may carry colour; app chrome uses shared `Ryoku.Ui` roles.
- Browsing never installs or activates anything. Success becomes visible only after backend reprobe.
- The ideal window is 1180×760; the required cramped window is 980×640.
- Delete replaced QML files and migrate every caller; leave no alternate legacy route or compatibility alias.

## File Structure

**Create:**

- `ryoku/apps/ryostore/quickshell/ProductCover.qml`: real-art and metadata-derived missing-art cover.
- `ryoku/apps/ryostore/quickshell/StatusReadout.qml`: explicit availability, install, update, offline, progress, and failure labels.
- `ryoku/apps/ryostore/quickshell/StoreHeader.qml`: RyoStore identity, category navigation, Search, and Library.
- `ryoku/apps/ryostore/quickshell/ShowroomStage.qml`: artwork-led selected-product stage and committed actions.
- `ryoku/apps/ryostore/quickshell/Filmstrip.qml`: collection selection, snapping, pointer/wheel/drag, and keyboard boundaries.
- `ryoku/apps/ryostore/quickshell/SearchLayer.qml`: query entry and result-context restoration surface.
- `ryoku/apps/ryostore/quickshell/ProductDetail.qml`: expanded product dossier and install feedback.
- `tests/ui/ryostore-components-probe.qml`: focused component and interaction contracts.
- `tests/ui/ryostore-components-probe.sh`: isolated Quickshell launcher for the component probe.

**Modify:**

- `ryoku/apps/ryostore/quickshell/lib/store.js`: showroom collection and selection helpers.
- `ryoku/apps/ryostore/quickshell/lib/store.test.mjs`: projection, state precedence, and selection tests.
- `ryoku/apps/ryostore/quickshell/Singletons/Store.qml`: retry/error clearing and per-item process state exposed to the new components.
- `ryoku/apps/ryostore/quickshell/App.qml`: thin showroom coordinator and context restoration.
- `ryoku/apps/ryostore/quickshell/shell.qml`: keep the IPC import, expose new route names, and preserve responsive sizing.
- `ryoku/apps/ryostore/backend/routing.go`: replace `today`/`installed` deep links with `discover`/`library`.
- `ryoku/apps/ryostore/backend/routing_test.go`: assert the clean route cutover.
- `tests/ui/ryostore-shell-probe.qml` and `.sh`: real app structure, status, and responsive contracts.
- `tests/ui/ryostore-flow-probe.qml` and `.sh`: search/detail restoration plus success/failure reprobe flow.
- `tests/ui/ryostore-handoff-probe.qml` and `.sh`: new Library/category navigation while retaining Settings handoffs.

**Remove after the replacement app passes its smoke probe:**

- `ryoku/apps/ryostore/quickshell/Rail.qml`
- `ryoku/apps/ryostore/quickshell/TodayPage.qml`
- `ryoku/apps/ryostore/quickshell/InstalledPage.qml`
- `ryoku/apps/ryostore/quickshell/CategoryPage.qml`
- `ryoku/apps/ryostore/quickshell/DetailView.qml`
- `ryoku/apps/ryostore/quickshell/PosterPlate.qml`
- `ryoku/apps/ryostore/quickshell/StoreCard.qml`
- `ryoku/apps/ryostore/quickshell/StatusPlate.qml`
- `ryoku/apps/ryostore/quickshell/EmptyPlate.qml`
- `ryoku/apps/ryostore/quickshell/InstallLedger.qml`

---

### Task 1: Pure Showroom Collection and Selection Model

**Files:**
- Modify: `ryoku/apps/ryostore/quickshell/lib/store.js`
- Modify: `ryoku/apps/ryostore/quickshell/lib/store.test.mjs`

**Interfaces:**
- Consumes: normalized catalogue items with `category`, `id`, `installed`, `active`, `enabled`, `installedCount`, `totalCount`, `updateAvailable`, `sourceError`, and `art`.
- Produces: `itemKey(item) -> string`, `collection(items, options) -> item[]`, `selectionKey(items, requestedKey, fallbackIndex) -> string`, plus the existing status/action helpers.

- [ ] **Step 1: Write failing showroom projection tests**

Add exact behavior tests to `store.test.mjs`:

```js
const products = [
  { id: "hero", category: "rices", name: "Hero", art: "hero.jpg", installed: false },
  { id: "lock", category: "lockscreens", name: "Lock", art: "lock.jpg", installed: true },
  { id: "partial", category: "bundles", installedCount: 2, totalCount: 4 },
];

eq(Store.itemKey(products[0]), "rices:hero", "stable item key");
eq(Store.collection(products, { view: "discover", categoryID: "lockscreens" }).map(Store.itemKey), ["lockscreens:lock"], "category collection");
eq(Store.collection(products, { view: "library" }).map(Store.itemKey), ["lockscreens:lock", "bundles:partial"], "library collection");
eq(Store.collection(products, { view: "discover", query: "hero" }).map(Store.itemKey), ["rices:hero"], "search collection");
eq(Store.selectionKey(products, "lockscreens:lock", 0), "lockscreens:lock", "preserve valid selection");
eq(Store.selectionKey(products, "missing:item", 1), "lockscreens:lock", "fallback by bounded index");
eq(Store.selectionKey([], "missing:item", 0), "", "empty selection");
```

- [ ] **Step 2: Run the helper test and observe the missing API failure**

Run:

```bash
node ryoku/apps/ryostore/quickshell/lib/store.test.mjs
```

Expected: FAIL because `itemKey`, `collection`, or `selectionKey` is not exported.

- [ ] **Step 3: Implement the minimal pure helpers**

Add these shapes to `store.js`, reusing `filter`, `featured`, and `isInstalled` rather than duplicating search logic:

```js
function itemKey(item) {
    return item ? String(item.category || "") + ":" + String(item.id || "") : "";
}

function collection(items, options) {
    var opts = options || {};
    var filtered = filter(items, {
        category: opts.categoryID || "",
        installedOnly: opts.view === "library",
        query: opts.query || ""
    });
    if (opts.view !== "library" && !opts.categoryID && !opts.query) {
        var lead = featured(filtered);
        return lead ? [lead].concat(filtered.filter(function(item) { return itemKey(item) !== itemKey(lead); })) : filtered;
    }
    return filtered;
}

function selectionKey(items, requestedKey, fallbackIndex) {
    var source = Array.isArray(items) ? items : [];
    for (var i = 0; i < source.length; i++)
        if (itemKey(source[i]) === requestedKey)
            return requestedKey;
    if (source.length === 0)
        return "";
    var index = Math.max(0, Math.min(source.length - 1, Number(fallbackIndex || 0)));
    return itemKey(source[index]);
}
```

Export all three names from `module.exports`.

- [ ] **Step 4: Run the helper test**

Run the Step 2 command.

Expected: `RYOSTORE-STORE-HELPERS-PASS`.

- [ ] **Step 5: Commit the projection contract**

```bash
git add ryoku/apps/ryostore/quickshell/lib/store.js ryoku/apps/ryostore/quickshell/lib/store.test.mjs
git commit -m "[ryoku] ryostore: define showroom projection"
```

---

### Task 2: Product Cover and Explicit Status Readout

**Files:**
- Create: `ryoku/apps/ryostore/quickshell/ProductCover.qml`
- Create: `ryoku/apps/ryostore/quickshell/StatusReadout.qml`
- Create: `tests/ui/ryostore-components-probe.qml`
- Create: `tests/ui/ryostore-components-probe.sh`

**Interfaces:**
- Consumes: one normalized item, Store process fields, shared `Tokens`, and `lib/store.js`.
- Produces: `ProductCover.item`, `ProductCover.stage`, `ProductCover.selected`; `StatusReadout.item`, `busyKey`, `installStage`, `installError`, and a readable `labels` array.

- [ ] **Step 1: Write a failing isolated component probe**

Create a probe that renders one real-art cover, one missing-art cover, and state readouts for active, partial, progress, offline, and exact failure:

```qml
Ryo.ProductCover {
    id: missingCover
    objectName: "missing-cover"
    width: 320; height: 180
    item: ({ id: "plain", category: "rices", name: "Plain", art: "", accent: "#d75f5f", surface: "#101010" })
}
Ryo.StatusReadout {
    id: partial
    objectName: "partial-readout"
    item: ({ category: "bundles", id: "pack", installedCount: 2, totalCount: 4 })
}
```

In the probe timer, require:

```qml
require(missingCover.hasArtwork === false, "metadata cover path");
require(missingCover.coverTitle === "Plain", "missing art retains identity");
require(missingCover.Accessible.name.indexOf("Plain") !== -1, "cover has accessible identity");
require(partial.labels.indexOf("2 / 4 INSTALLED") !== -1, "partial state explicit");
require(failed.labels.indexOf("fixture install failed") !== -1, "exact failure preserved");
```

The `.sh` launcher must copy the RyoStore QML tree into a temporary import root, link `Ryoku/Ui`, run `qs -p`, reject `ERROR|TypeError|ReferenceError`, and print `ryostore-components-probe: cover and status states` only after `RYOSTORE-COMPONENTS-PROBE-PASS`.

- [ ] **Step 2: Run the component probe and observe missing types**

Run:

```bash
bash tests/ui/ryostore-components-probe.sh
```

Expected: FAIL because `ProductCover` and `StatusReadout` do not exist.

- [ ] **Step 3: Implement `ProductCover` and `StatusReadout`**

Use a single `Image` only when `item.art` is non-empty. The missing-art branch must be a solid metadata-driven composition, for example:

```qml
readonly property bool hasArtwork: String(item.art || "") !== ""
readonly property string coverTitle: String(item.name || item.id || "Untitled")
readonly property color coverSurface: item.surface || Tokens.paperLift
readonly property color coverAccent: item.accent || Tokens.inkDim

Rectangle {
    anchors.fill: parent
    visible: !cover.hasArtwork
    color: cover.coverSurface
    Rectangle { width: 5; anchors { top: parent.top; bottom: parent.bottom; left: parent.left }; color: cover.coverAccent }
    Text { text: cover.coverTitle; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: cover.stage ? Tokens.fHero : Tokens.fRow }
}
```

`StatusReadout.labels` must derive from `StoreLogic.statusLabels(item)`, append the current busy stage only for the matching `busyKey`, append `OFFLINE` when requested, and append the exact install error only for the matching item.

- [ ] **Step 4: Run the isolated component probe and helper test**

```bash
bash tests/ui/ryostore-components-probe.sh
node ryoku/apps/ryostore/quickshell/lib/store.test.mjs
```

Expected: both PASS; the QML log contains no hard runtime error.

- [ ] **Step 5: Commit cover and state primitives**

```bash
git add ryoku/apps/ryostore/quickshell/ProductCover.qml ryoku/apps/ryostore/quickshell/StatusReadout.qml tests/ui/ryostore-components-probe.qml tests/ui/ryostore-components-probe.sh
git commit -m "[ryoku] ryostore: add showroom cover states"
```

---

### Task 3: Snapping Filmstrip Navigation

**Files:**
- Create: `ryoku/apps/ryostore/quickshell/Filmstrip.qml`
- Modify: `tests/ui/ryostore-components-probe.qml`

**Interfaces:**
- Consumes: `items: var`, `selectedKey: string`, and `reducedMotion: bool`.
- Produces: `previewRequested(var item)`, `selectionRequested(var item)`, `pendingKey`, `move(int delta)`, `moveBoundary(bool last)`, `previewAt(int index)`, `commitPending()`, `positionFor(string key) -> int`, and `contentOffset: real`.

- [ ] **Step 1: Extend the probe with failing filmstrip behavior**

Render four fixture products, start on the second, then assert:

```qml
strip.move(-10);
require(strip.pendingKey === "rices:a", "left boundary clamps");
strip.moveBoundary(true);
require(strip.pendingKey === "rices:d", "End reaches final item");
strip.move(1);
require(strip.pendingKey === "rices:d", "right boundary clamps");
strip.commitPending();
require(lastSelected === "rices:d", "settled item commits");
require(strip.contentOffset >= 0, "filmstrip offset exposed");
```

Also call `previewAt(1)` and require that it emits `previewRequested` without emitting `selectionRequested`.

- [ ] **Step 2: Run the component probe and observe the missing Filmstrip type**

Run `bash tests/ui/ryostore-components-probe.sh`.

Expected: FAIL because `Filmstrip` does not exist.

- [ ] **Step 3: Implement one snapping horizontal filmstrip**

The component must use one horizontal `Flickable`, a `Row`/`Repeater` of `ProductCover`, and explicit key functions. Keep the public behavior deterministic:

```qml
function move(delta) {
    const current = Math.max(0, positionFor(pendingKey || selectedKey));
    setPending(Math.max(0, Math.min(items.length - 1, current + delta)));
}
function moveBoundary(last) {
    if (items.length > 0) setPending(last ? items.length - 1 : 0);
}
function commitPending() {
    const index = positionFor(pendingKey);
    if (index >= 0) selectionRequested(items[index]);
}
```

Wheel, drag, and swipe must snap to a product then call `commitPending`. Hover calls only `previewRequested`; click commits. The selected cover carries the strongest border/scale treatment. In reduced-motion mode, disable scale animation and snap immediately.

- [ ] **Step 4: Run the component probe**

Run the Step 2 command.

Expected: PASS for boundary, preview, commit, and offset assertions.

- [ ] **Step 5: Commit the filmstrip**

```bash
git add ryoku/apps/ryostore/quickshell/Filmstrip.qml tests/ui/ryostore-components-probe.qml
git commit -m "[ryoku] ryostore: add snapping filmstrip"
```

---

### Task 4: Artwork-led Showroom Stage

**Files:**
- Create: `ryoku/apps/ryostore/quickshell/ShowroomStage.qml`
- Modify: `tests/ui/ryostore-components-probe.qml`

**Interfaces:**
- Consumes: `item` (committed product), `previewItem` (art/title only), Store process state, `offline`, and `reducedMotion`.
- Produces: `installRequested(var item)`, `detailsRequested(var item)`, `settingsRequested(var item)`, `displayItem`, and `motionDuration` for probe visibility.

- [ ] **Step 1: Add failing committed-versus-preview assertions**

Render the stage with committed item `a` and preview item `b`. Require:

```qml
require(stage.displayItem.id === "b", "preview owns stage artwork");
require(stage.actionItem.id === "a", "preview cannot retarget action");
stage.triggerInstall();
require(installedKey === "rices:a", "install targets committed selection");
stage.previewItem = null;
require(stage.displayItem.id === "a", "preview clears to committed selection");
stage.reducedMotion = true;
require(stage.motionDuration === 0, "reduced motion disables stage travel");
```

At 980×640, render the stage above the existing `Filmstrip` in one probe container and require named title, state, and primary-action objects to remain inside the stage area without intersecting the filmstrip.

- [ ] **Step 2: Run the component probe and observe the missing stage**

Run `bash tests/ui/ryostore-components-probe.sh`.

Expected: FAIL because `ShowroomStage` does not exist.

- [ ] **Step 3: Implement the stage hierarchy**

Build the stage around one full-bleed `ProductCover { stage: true }`, a contrast scrim, story copy, `StatusReadout`, primary action, Details, and a position indicator. Preserve action safety:

```qml
readonly property var displayItem: previewItem || item || ({})
readonly property var actionItem: item || ({})
readonly property int motionDuration: reducedMotion ? 0 : Tokens.swap
function triggerInstall() {
    if (actionItem && StoreLogic.primaryAction(actionItem) !== "INSTALLED" && busyKey === "")
        installRequested(actionItem);
}
```

Use `Behavior` only when `!reducedMotion`; the stage must not import or instantiate `Grain`, `Reg`, `Ticks`, `Barcode`, or `Motif`.

- [ ] **Step 4: Run the component probe at ideal and cramped sizes**

Run the Step 2 command.

Expected: PASS with committed action safety and no clipped required controls.

- [ ] **Step 5: Commit the stage**

```bash
git add ryoku/apps/ryostore/quickshell/ShowroomStage.qml tests/ui/ryostore-components-probe.qml
git commit -m "[ryoku] ryostore: build artwork-led stage"
```

---

### Task 5: Header, Categories, Search, and Library Entry

**Files:**
- Create: `ryoku/apps/ryostore/quickshell/StoreHeader.qml`
- Create: `ryoku/apps/ryostore/quickshell/SearchLayer.qml`
- Modify: `tests/ui/ryostore-components-probe.qml`

**Interfaces:**
- `StoreHeader` consumes `view`, `categoryID`, `categories`, `query`, `libraryCount`, `updateCount`, and `offline`; emits `routeRequested(string view, string categoryID)` and `searchRequested()`.
- `SearchLayer` consumes `open`, `query`, and `resultCount`; emits `queryEdited(string value)` and `closeRequested()`; exposes `focusField()`.

- [ ] **Step 1: Add failing route and search tests**

Assert category activation emits `discover/rices`, Library emits `library/""`, search focus accepts text, and Escape emits close without mutating the query itself:

```qml
header.activateCategory("rices");
require(routeView === "discover" && routeCategory === "rices", "category route");
header.activateLibrary();
require(routeView === "library" && routeCategory === "", "library route");
search.open = true;
search.focusField();
require(search.fieldActive, "search takes focus");
search.requestClose();
require(searchClosed, "search delegates restoration");
```

- [ ] **Step 2: Run the component probe and observe missing types**

Run `bash tests/ui/ryostore-components-probe.sh`.

Expected: FAIL because `StoreHeader` and `SearchLayer` do not exist.

- [ ] **Step 3: Implement fixed, unboxed navigation**

The header must use text navigation and one underline/focus treatment, not a row of rounded pills. Keep Discover, categories, Search, and Library in fixed semantic order. At 980px, category labels scroll horizontally while Search and Library remain visible.

`SearchLayer` expands from the header search region, not from a centered modal card. It owns only editing/focus and delegates all projection and context restoration to `App`.

- [ ] **Step 4: Run the component probe**

Run the Step 2 command.

Expected: PASS for route emission, search focus, and close delegation.

- [ ] **Step 5: Commit header and search**

```bash
git add ryoku/apps/ryostore/quickshell/StoreHeader.qml ryoku/apps/ryostore/quickshell/SearchLayer.qml tests/ui/ryostore-components-probe.qml
git commit -m "[ryoku] ryostore: add showroom navigation"
```

---

### Task 6: Reversible Product Detail and Install Feedback

**Files:**
- Create: `ryoku/apps/ryostore/quickshell/ProductDetail.qml`
- Modify: `ryoku/apps/ryostore/quickshell/Singletons/Store.qml`
- Modify: `tests/ui/ryostore-components-probe.qml`
- Modify: `tests/ui/ryostore-components-probe.sh`

**Interfaces:**
- Consumes: `item`, `open`, `originRect`, `busyKey`, `installStage`, matching `installError`, and `reducedMotion`.
- Produces: `closeRequested()`, `installRequested(var item)`, `retryRequested(var item)`, `settingsRequested(var item)`, and `transitionMode: "shared"|"immediate"` for probe visibility.
- Adds to Store: `clearInstallError(item)` and `retryInstall(item)` without changing command syntax.

- [ ] **Step 1: Add failing detail and Store retry assertions**

The component probe must require the open detail to expose screenshots/metadata/actions, preserve exact failure text, keep `open === true` after failure, and emit close without clearing item state. Extend the component fixture command capture so Retry invokes the same `ryostore install <category> <id>` command after clearing the matching error.

Use assertions shaped like:

```qml
require(detail.open && detail.item.id === "broken", "failure keeps dossier open");
require(detail.errorText.indexOf("fixture install failed") !== -1, "exact failure shown");
detail.triggerRetry();
require(retryKey === "lockscreens:broken", "retry targets selected item");
detail.reducedMotion = true;
require(detail.transitionMode === "immediate", "reduced motion removes shared-element travel");
detail.triggerClose();
require(closeCount === 1, "detail delegates reversible close");
```

- [ ] **Step 2: Run the component probe and observe failure**

```bash
bash tests/ui/ryostore-components-probe.sh
```

Expected: FAIL because `ProductDetail`, retry, and error clearing do not exist.

- [ ] **Step 3: Implement detail and retry behavior**

`ProductDetail` must reuse `ProductCover` and `StatusReadout`, render real screenshots when present, and lay out description, compatibility, contents, author, version, size, and actions without a boxed inspector panel.

When `open && !reducedMotion`, animate the cover from `originRect` into the detail artwork bounds and reverse those properties on close. When `reducedMotion`, set `transitionMode` to `"immediate"`, skip translation/scale travel, and change visibility without spatial animation.

Add Store functions:

```qml
function clearInstallError(item) {
    if (installErrorKey !== itemKey(item)) return;
    installError = "";
    installErrorKey = "";
    installStage = "";
}
function retryInstall(item) {
    clearInstallError(item);
    install(item);
}
```

Success must continue through the existing `VERIFYING` refresh before `busyKey` clears.

- [ ] **Step 4: Run the component probe**

Run the Step 2 command.

Expected: PASS; failure remains attached and Retry records the same item command. The end-to-end success reprobe remains covered by Task 7's flow probe.

- [ ] **Step 5: Commit detail and retry flow**

```bash
git add ryoku/apps/ryostore/quickshell/ProductDetail.qml ryoku/apps/ryostore/quickshell/Singletons/Store.qml tests/ui/ryostore-components-probe.qml tests/ui/ryostore-components-probe.sh
git commit -m "[ryoku] ryostore: add reversible product detail"
```

---

### Task 7: Integrate the Living Showroom and Cut Over Deep Links

**Files:**
- Modify: `ryoku/apps/ryostore/quickshell/App.qml`
- Modify: `ryoku/apps/ryostore/quickshell/shell.qml`
- Modify: `ryoku/apps/ryostore/backend/routing.go`
- Modify: `ryoku/apps/ryostore/backend/routing_test.go`
- Modify: `tests/ui/ryostore-shell-probe.qml`
- Modify: `tests/ui/ryostore-shell-probe.sh`
- Modify: `tests/ui/ryostore-flow-probe.qml`
- Modify: `tests/ui/ryostore-handoff-probe.qml`

**Interfaces:**
- App state: `view: "discover"|"library"`, `categoryID`, `query`, `searchOpen`, `selectedKey`, `previewItem`, `detailItem`, `filmstripOffset`, and separate `searchContext`/`detailContext` snapshots so nested detail can return to search before search returns to browse.
- Public deep link: `openRoute("discover"|"library"|<category>)`.
- Backend accepted routes: `discover`, `library`, and the six catalogue category IDs.

- [ ] **Step 1: Rewrite app-level probes for the new contract**

The shell probe must wait for `objectName` values `ryostore-header`, `ryostore-stage`, and `ryostore-filmstrip`; require there is no `ryostore-rail`; verify Discover, Library, active/update/partial states, and required controls at both 1180×760 and 980×640.

The flow probe must call:

```qml
app.openRoute("lockscreens");
app.selectKey("lockscreens:clock");
app.openSelectedDetail();
// install fixture, wait for reprobe
app.closeDetail();
require(app.selectedKey === "lockscreens:clock", "detail restored selection");
app.openSearch();
app.setQuery("installed clock");
require(app.collection.length === 1, "showroom search projection");
app.openSelectedDetail();
app.escapeLayer();
require(app.searchOpen && app.query === "installed clock", "detail returns to search layer");
app.escapeLayer();
require(app.categoryID === "lockscreens" && app.selectedKey === "lockscreens:clock", "search restored exact context");
```

Change `routing_test.go` to accept `discover` and `library`, reject `today` and `installed`, and continue accepting all six category IDs.

- [ ] **Step 2: Run app, backend, flow, and handoff probes to observe the old API failures**

```bash
(cd ryoku/apps/ryostore/backend && go test ./...)
bash tests/ui/ryostore-shell-probe.sh
bash tests/ui/ryostore-flow-probe.sh
bash tests/ui/ryostore-handoff-probe.sh
```

Expected: FAIL on the clean route names and missing showroom object/API contract.

- [ ] **Step 3: Replace `App.qml` with the thin coordinator**

Use pure projection and stable selection:

```qml
property string view: "discover"
property string categoryID: ""
property string query: ""
property bool searchOpen: false
property string selectedKey: ""
property var previewItem: null
property var detailItem: null
property real filmstripOffset: 0
property var searchContext: null
property var detailContext: null

readonly property var collection: StoreLogic.collection(searchableItems, {
    view: view,
    categoryID: categoryID,
    query: query
})

function reconcileSelection(fallbackIndex) {
    selectedKey = StoreLogic.selectionKey(collection, selectedKey, fallbackIndex || 0);
}
```

Compose `StoreHeader`, `ShowroomStage`, `Filmstrip`, `SearchLayer`, and `ProductDetail` directly. Snapshot `{ view, categoryID, query, selectedKey, filmstripOffset, focusObject }` into `searchContext` when Search opens and into `detailContext` when Detail opens. Escape restores Detail first, then Search, then a non-featured category to Discover. Hover assigns only `previewItem`; committed selection owns every action.

Keep Ctrl+K, `/`, Left/Right, Home/End, Enter, Escape, Ctrl+Q, and reduced-motion behavior. The app must not instantiate a `Loader` for page dashboards or any grain/ornament component.

- [ ] **Step 4: Cut over IPC/backend routes and pass integration checks**

Change backend route names:

```go
var storeSections = map[string]struct{}{
    "discover": {}, "library": {}, "rices": {}, "lockscreens": {},
    "barstyles": {}, "fastfetch": {}, "plugins": {}, "bundles": {},
}
```

Make `shell.qml` call `app.openRoute(section)` from IPC and retain `import Quickshell.Io` so `IpcHandler` loads in production.

Run the Step 2 commands plus:

```bash
node ryoku/apps/ryostore/quickshell/lib/store.test.mjs
bash tests/ui/ryostore-components-probe.sh
```

Expected: every command PASS and no QML hard error.

- [ ] **Step 5: Commit the integrated showroom**

```bash
git add ryoku/apps/ryostore/quickshell/App.qml ryoku/apps/ryostore/quickshell/shell.qml ryoku/apps/ryostore/backend/routing.go ryoku/apps/ryostore/backend/routing_test.go tests/ui/ryostore-shell-probe.qml tests/ui/ryostore-shell-probe.sh tests/ui/ryostore-flow-probe.qml tests/ui/ryostore-handoff-probe.qml
git commit -m "[ryoku] ryostore: integrate living showroom"
```

---

### Task 8: Remove the Legacy Dashboard Composition

**Files:**
- Remove: the ten legacy QML files listed in File Structure.
- Modify: `tests/ui/ryostore-handoff-probe.sh` if its copied import set names removed files.
- Modify: `release/CHANGELOG.md` with one user-facing RyoStore showroom entry.

**Interfaces:**
- Consumes: the fully passing integrated showroom from Task 7.
- Produces: one clean presentation path with no dead page or ornament references.

- [ ] **Step 1: Prove the replacement app works before deletion**

Run:

```bash
bash tests/ui/ryostore-shell-probe.sh
bash tests/ui/ryostore-flow-probe.sh
bash tests/ui/ryostore-handoff-probe.sh
```

Expected: PASS on the live replacement files.

- [ ] **Step 2: Search for callers of every legacy component**

Use Prowl/file relations and exact reference searches for `Rail`, `TodayPage`, `InstalledPage`, `CategoryPage`, `DetailView`, `PosterPlate`, `StoreCard`, `StatusPlate`, `EmptyPlate`, and `InstallLedger`.

Expected: only the legacy files themselves remain. If any caller remains, migrate it to the Task 7 interfaces before deletion.

- [ ] **Step 3: Delete the legacy files and add the release note**

Remove exactly the listed files. Add under the current release section:

```markdown
- RyoStore now opens as an artwork-led living showroom with filmstrip browsing, reversible product details, Library state, and accessible reduced-motion navigation.
```

Do not retain aliases, commented code, or an alternate legacy route.

- [ ] **Step 4: Re-run focused checks after deletion**

```bash
node ryoku/apps/ryostore/quickshell/lib/store.test.mjs
(cd ryoku/apps/ryostore/backend && go test ./...)
bash tests/ui/ryostore-components-probe.sh
bash tests/ui/ryostore-shell-probe.sh
bash tests/ui/ryostore-flow-probe.sh
bash tests/ui/ryostore-handoff-probe.sh
bash tests/extras-install.sh
/usr/lib/qt6/bin/qmllint ryoku/apps/ryostore/quickshell/*.qml ryoku/apps/ryostore/quickshell/Singletons/*.qml
```

Expected: all tests PASS; `qmllint` exits zero with no hard errors. Unresolved external-import warnings are acceptable only when the command lacks the deployed Ryoku/Quickshell import path.

- [ ] **Step 5: Commit the clean cutover**

```bash
git add ryoku/apps/ryostore/quickshell tests/ui release/CHANGELOG.md
git commit -m "[ryoku] ryostore: remove legacy storefront"
```

---

### Task 9: Deploy and Prove the Complete Experience

**Files:**
- Modify only showroom QML or tests when direct live evidence proves a defect.
- Do not commit screenshots or temporary fixture directories.

**Interfaces:**
- Consumes: the clean showroom implementation and existing provider fixtures.
- Produces: direct evidence for navigation, motion, states, responsiveness, delivery, and visual rejection criteria.

- [ ] **Step 1: Build and deploy from the checkout**

```bash
RYOKU_REPO="$PWD" ryoku deploy
```

Expected: `installed app ryostore`, `~/.local/bin/ryostore` exists, `~/.config/quickshell/ryostore/shell.qml` contains the deployed showroom, and the production config loads without `IpcHandler is not a type`.

- [ ] **Step 2: Capture ideal Discover and category navigation**

Launch the desktop entry, wait for title `Ryostore`, read its exact Hyprland geometry, and capture only the 1180×760 window with `grim`.

Exercise every category with pointer and keyboard. Verify artwork owns the stage, the filmstrip remains visible, focus is explicit, and Search/Library/primary action/state remain findable. Reject any grain, print ornament, permanent sidebar, rounded-card dashboard, or inspector panel.

- [ ] **Step 3: Prove filmstrip, search, Library, and detail restoration**

Use `ydotool` to exercise Left/Right, Home/End, wheel/drag where supported, Ctrl+K, a multiword query, Enter into detail, Escape back, and Library. Capture stage changes, search, Library, detail, and restored collection frames.

Expected: hover never retargets actions; settled navigation commits the selected product; detail and search restore exact selection, offset, and focus.

- [ ] **Step 4: Prove install success, failure, offline, and missing art**

Run the app with temporary XDG config/data directories and local fixture HTTP endpoints. Install one safe fixture, wait for backend reprobe, and verify installed state plus Settings handoff while active remains false. Point a second asset at 404, verify exact error and Retry without route loss, then relaunch against a closed registry port with cache populated. Include one item without art.

Expected: state changes only after reprobe; provider failure is isolated; offline cache remains browseable; missing art renders a deliberate metadata cover.

- [ ] **Step 5: Prove reduced motion and 980×640 behavior**

Enable the desktop reduced-motion path for the fixture run and resize to 980×640. Capture Discover and Detail.

Expected: no parallax/scale/shared-element travel in reduced motion; title, Search, Library, state, primary action, filmstrip, and Escape path remain visible without clipping.

- [ ] **Step 6: Apply evidence-driven fixes and repeat affected proof**

Only change source for defects visible in Steps 2–5. After every source edit, redeploy and repeat every affected capture; never accept evidence from before the final edit.

- [ ] **Step 7: Run repository and delivery gates**

```bash
bin/ryoku-dev-verify-delivery
prowl-agent changed
prowl-agent doctor
git status --short
```

Expected: no orphaned RyoStore binary/config path, no dangling legacy component, no new architecture violation, and only intended implementation changes remain.

- [ ] **Step 8: Commit final live polish only when source changed**

```bash
git add ryoku/apps/ryostore tests/ui release/CHANGELOG.md
git commit -m "[ryoku] ryostore: polish living showroom"
```

If live proof required no source change, do not create an empty commit.
