# RyoStore External Catalogue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `ryoku-extras` the complete source of every RyoStore product's code and media, with lazy browsing, safe install/update/remove receipts, and production live updates that never require a shell reload.

**Architecture:** Each category exposes one complete browse registry from `ryoku-extras`; selected product manifests declare verified payload files fetched only for install or update. The main repository supplies generic Go validation, transactions, receipts, providers, and revision notifications, while Quickshell watches the revision and recreates versioned plugin/bar components automatically.

**Tech Stack:** Go 1.26 standard library, Python 3 standard library, Bash, jq, QML/Quickshell 0.2, Node.js helper tests, ImageMagick, grim, ydotool, GitHub raw HTTP/local fixture servers.

## Global Constraints

- Product assets mean both media and implementation: images, QML, JavaScript, configuration, manifests, scripts, fonts, and uninstall metadata.
- Every Store product asset lives in `/home/nero/Work/ryoku-extras`; the main repository contains only generic runtime code, schemas, tests, and non-Store core fallbacks.
- RyoStore never discovers an offered product directly from a third-party repository.
- Browsing fetches category registries only. Product manifests and payload files are fetched lazily for install, update, or selected detail data.
- Install, update, and removal are atomic and receipt-driven; removal never deletes pre-existing, shared, unrelated, untracked, or traversal-reachable files.
- A successful code update becomes visible through production revision watchers and versioned Loader URLs. No developer hot reload, `ryoku reload`, shell restart, or Hyprland restart is allowed.
- Browsing and updating an installed rice never applies it. Settings remains the explicit apply surface.
- Keep provider failures isolated and cached products browseable with exact offline/error state.
- Real screenshots are preferred. Temporary generated showcase media uses real registry metadata and lives only beside its product in `ryoku-extras`.
- Main-repository commits use required area labels. `ryoku-extras` commits follow that repository's existing subjects.

## File Structure

### Main repository (`/home/nero/Work/ryoku-arch-unstable`)

**Create:**

- `ryoku/apps/ryostore/backend/product_manifest.go`: common registry envelope, product manifest, file validation, and exact version comparison.
- `ryoku/apps/ryostore/backend/product_manifest_test.go`: local-server and path/hash/limit contract tests.
- `ryoku/apps/ryostore/backend/receipt.go`: atomic receipt and revision persistence.
- `ryoku/apps/ryostore/backend/receipt_test.go`: rollback, ownership, shared-reference, and revision tests.
- `ryoku/apps/ryostore/backend/product_transaction.go`: generic staged file install/update/remove transaction.
- `ryoku/apps/ryostore/backend/product_transaction_test.go`: end-to-end temporary-XDG transactions.
- `ryoku/shell/quickshell/pill/Singletons/BarProducts.qml`: installed optional-bar index plus Store revision watcher.

**Modify:**

- `ryoku/apps/ryostore/backend/model.go`: normalized manifest/version/update fields.
- `ryoku/apps/ryostore/backend/catalog.go`: add `Remove`, common product source, and no eager payload requirement.
- `ryoku/apps/ryostore/backend/main.go`: public `remove <category> <id>` and generic internal transaction routes.
- `ryoku/apps/ryostore/backend/extras_assets.go`: delegate product trees to the common transaction rather than category-specific publication.
- all six `provider_*.go` files and tests: browse external registries only, join receipt/runtime state, and route install/remove to the transaction or bundle actuator.
- `ryoku/shell/quickshell/widgets/Singletons/Registry.qml`: watch Store revision and expose installed plugin version.
- `ryoku/shell/quickshell/widgets/PluginDesktopSlot.qml`, `widgets/shell.qml`, and `pill/PluginPopouts.qml`: add version query strings to plugin component URLs.
- `ryoku/shell/quickshell/pill/shell.qml`: keep Sumi core, replace the static optional-style registry with `BarProducts`.
- `ryoku/hub/quickshell/pages/AddonsPage.qml`, `AppearancePage.qml`, `LockscreenPage.qml`, `BarStudioPage.qml`, and `FastfetchPage.qml`: call the generic RyoStore remove/apply contracts.
- `system/extras/ryoku-extras-install`: consume inline bundle component metadata and receipt ownership.
- focused backend, shell, Settings, actuator, delivery, and wire probes.

**Remove after the replacement passes:**

- `ryoku/apps/ryostore/backend` direct qylock GitHub tree/cache code.
- `ryoku/shell/quickshell/pill/barstyles/registry.js`.
- optional `nacre/` and `obi/` payload directories from main after their external copies validate and load.
- Store-visible bundled lockscreen theme payloads that have external validated copies; retain only an explicitly non-Store core fallback.

### Extras repository (`/home/nero/Work/ryoku-extras`)

**Create:**

- `schema/store-product-v1.json`: canonical product envelope and manifest schema.
- `tests/validate-store.py`: standard-library validation of all six categories, hashes, modes, paths, and declared files.
- `lockscreens/registry.json` plus one folder per redistributable theme.
- `barstyles/registry.json`, `barstyles/nacre/`, and `barstyles/obi/`.
- `fastfetch/registry.json` and two initial style folders.
- `tools/render-showcase.qml` and `tools/render-showcase.sh`: metadata-driven temporary preview generator used only to create committed product media.

**Modify:**

- `rices/registry.json`, `plugins/registry.json`, and `bundles/registry.json`: complete common browse envelopes.
- every offered product manifest: schema/category/version/delivery file list with SHA-256, size, mode, and destination.
- `tests/validate-catalogue.sh`: invoke `validate-store.py` after existing relationship checks.
- category authoring guides: document common envelope, manifests, image requirements, and update/remove ownership.

---

### Task 1: Canonical Extras Product Schema and Validator

**Repository:** `/home/nero/Work/ryoku-extras`

**Files:**
- Create: `schema/store-product-v1.json`
- Create: `tests/validate-store.py`
- Create: `tests/test_validate_store.py`
- Modify: `tests/validate-catalogue.sh`

**Interfaces:**
- Registry entry: `id`, `name`, `version`, `path`, `author`, `summary`, `description`, `tags`, `accent`, `surface`, `preview`, `screenshots`, `manifest`, `manifestSha256`.
- Manifest: `schema: 1`, matching `id/category/version`, `destination`, and `files[]` rows containing `source`, `destination`, `mode`, `size`, `sha256`, and `install`; `mode` is exactly `"0644"` or `"0755"`, and only declared executable scripts use `"0755"`.
- Validator: `python3 tests/validate-store.py --root .`; success prints `store catalogue OK: 6 categories validated`. `--categories rices,plugins` narrows migration checks, and `--require-media` adds ImageMagick dimension/blank-image checks.

- [ ] **Step 1: Add failing validator unit fixtures**

`tests/test_validate_store.py` must create temporary trees and assert exact errors for duplicate ids, missing product path, manifest hash mismatch, `../` paths, absolute paths, symlinks, undeclared code/media, wrong executable mode, and missing preview. Include one valid fixture with an installable QML file and non-installed preview.

```python
self.assertEqual(validate_tree(valid_root), [])
self.assertIn("rices/demo: source escapes product root", validate_tree(traversal_root))
self.assertIn("plugins/demo: undeclared payload content/Widget.qml", validate_tree(undeclared_root))
```

- [ ] **Step 2: Run RED**

```bash
cd /home/nero/Work/ryoku-extras
python3 -m unittest tests.test_validate_store -v
```

Expected: import or missing-function failure because `validate-store.py` does not exist.

- [ ] **Step 3: Implement schema and validator**

Use Python standard library for schema, path, hash, and file validation. `validate_tree(root: Path) -> list[str]` loads the six fixed registry paths, verifies common fields and ids, hashes the manifest before parsing it, validates every file row, rejects symlinks, and compares declared files with all code/media/config files below the product root. Allow documentation and license files outside the delivery list; require every preview and screenshot to be declared with `install: false`. Only `--require-media` may call `magick identify` for decoded dimensions and channel statistics.

`tests/validate-catalogue.sh` runs the new validator only when all six registries exist, so Tasks 2, 5, and 6 can migrate categories incrementally without making the old catalogue unusable.

- [ ] **Step 4: Run GREEN**

Run the unittest command. Also run `bash tests/validate-catalogue.sh`; the existing catalogue check must remain green before the six-category gate activates.

- [ ] **Step 5: Commit**

```bash
git add schema tests/validate-store.py tests/test_validate_store.py tests/validate-catalogue.sh
git commit -m "catalogue: define store product schema"
```

---

### Task 2: Common Main-Repository Manifest Contract

**Repository:** `/home/nero/Work/ryoku-arch-unstable`

**Files:**
- Create: `ryoku/apps/ryostore/backend/product_manifest.go`
- Create: `ryoku/apps/ryostore/backend/product_manifest_test.go`
- Modify: `ryoku/apps/ryostore/backend/model.go`

**Interfaces:**

```go
type ProductEntry struct {
    ID, Name, Version, Path, Author, Summary, Description string
    Tags, Screenshots []string
    Accent, Surface, Preview, Manifest, ManifestSHA256 string
}
type ProductFile struct {
    Source, Destination, SHA256 string
    Mode string
    Size int64
    Install bool
}
type ProductManifest struct {
    Schema int
    ID, Category, Version, Destination string
    Files []ProductFile
}
func loadProductManifest(ctx context.Context, cache *Cache, category string, entry ProductEntry) (ProductManifest, error)
func validateProductManifest(category string, entry ProductEntry, manifest ProductManifest) error
```

`Item` gains `Manifest`, `ManifestSHA256`, and `InstalledVersion`; `UpdateAvailable` is true only when an installed receipt version differs from registry `Version`.

- [ ] **Step 1: Write failing Go tests**

Use an `httptest.Server` to serve a valid registry/manifest/file set. Assert valid decode, manifest SHA mismatch, id/category/version mismatch, duplicate destination, forbidden absolute/parent path, invalid mode, negative or over-limit size, and exact version inequality.

- [ ] **Step 2: Run RED**

```bash
cd ryoku/apps/ryostore/backend
go test ./... -run 'Test(ProductManifest|ProductVersion)' -count=1
```

Expected: compile failure for undefined contract types/functions.

- [ ] **Step 3: Implement the contract**

Use existing `Cache.Fetch` and limits. Validate before returning any manifest. Do not fetch payload files here. Keep provider-specific metadata in existing provider structs and normalize only common fields.

- [ ] **Step 4: Run GREEN and full backend suite**

```bash
cd ryoku/apps/ryostore/backend
go test ./... -run 'Test(ProductManifest|ProductVersion)' -count=1
go test ./...
```

- [ ] **Step 5: Commit**

```bash
git add ryoku/apps/ryostore/backend/product_manifest.go ryoku/apps/ryostore/backend/product_manifest_test.go ryoku/apps/ryostore/backend/model.go
git commit -m "[ryoku] ryostore: define product manifest contract"
```

---

### Task 3: Atomic Product Transactions, Receipts, and Revision

**Repository:** `/home/nero/Work/ryoku-arch-unstable`

**Files:**
- Create: `ryoku/apps/ryostore/backend/receipt.go`
- Create: `ryoku/apps/ryostore/backend/receipt_test.go`
- Create: `ryoku/apps/ryostore/backend/product_transaction.go`
- Create: `ryoku/apps/ryostore/backend/product_transaction_test.go`
- Modify: `ryoku/apps/ryostore/backend/catalog.go`
- Modify: `ryoku/apps/ryostore/backend/main.go`

**Interfaces:**

```go
type Receipt struct {
    Category, ID, Version, Destination string
    Files []ReceiptFile
    Components []ReceiptComponent
}
type StoreRevision struct {
    Revision uint64
    Category, ID, Version, Operation string
}
func installProduct(ctx context.Context, cache *Cache, category string, entry ProductEntry) error
func removeProduct(ctx context.Context, category, id string) error
func readReceipt(category, id string) (Receipt, error)
func writeStoreRevision(change StoreRevision) error
```

`Provider` adds `Remove(ctx context.Context, id string) error`. Public dispatch accepts `remove <category> <id>` beside install.

- [ ] **Step 1: Write failing transaction tests**

Temporary-XDG tests must prove successful install, identical-version replacement, version update, hash failure rollback, interrupted staging cleanup, untracked destination refusal, symlink refusal, receipt atomicity, removal of only receipt-owned files, preservation of unrelated files, monotonically increasing revision, and exact revision operation values `install`, `update`, `remove`.

- [ ] **Step 2: Run RED**

```bash
cd ryoku/apps/ryostore/backend
go test ./... -run 'Test(ProductTransaction|Receipt|StoreRevision|RemoveDispatch)' -count=1
```

- [ ] **Step 3: Implement transaction and CLI**

Fetch each declared install file through the bounded cache, verify size/hash before staging, write modes explicitly, and rename the complete staged directory. Hold one per-product flock across fetch publication, receipt, and revision. Keep the old destination until the new stage verifies; rollback before returning any error. Removal requires a receipt whose destination matches the category allowlist.

- [ ] **Step 4: Run GREEN and backend suite**

Run focused tests, `go test ./...`, and `go vet ./...` from the backend directory.

- [ ] **Step 5: Commit**

```bash
git add ryoku/apps/ryostore/backend/{receipt.go,receipt_test.go,product_transaction.go,product_transaction_test.go,catalog.go,main.go}
git commit -m "[ryoku] ryostore: add atomic product transactions"
```

---

### Task 4: Migrate Existing Rice, Plugin, and Bundle Products

**Repository:** `/home/nero/Work/ryoku-extras`

**Files:**
- Modify: `rices/registry.json`, `plugins/registry.json`, `bundles/registry.json`
- Modify: every non-template product manifest below those three categories
- Move: bundle-specific scripts from `installers/` into their owning bundle when not shared
- Modify: `tests/validate-catalogue.sh` to activate common validation for migrated categories individually

**Interfaces:**
- Every migrated entry satisfies Task 1's common envelope.
- Every product manifest satisfies `ProductManifest` and declares all product code/media.
- Bundle registry rows inline `components` used for installed/partial state, including `type`, `name`, `detect`, `tier`, `interactive`, and `summary`.

- [ ] **Step 1: Add migration assertions**

Extend validator tests to load the real three registries and assert every non-template entry has a matching manifest hash, at least one declared payload, and every declared preview/screenshot exists.

- [ ] **Step 2: Run RED**

```bash
python3 -m unittest tests.test_validate_store -v
python3 tests/validate-store.py --root . --categories rices,plugins,bundles
```

Expected: missing common envelope and delivery declarations.

- [ ] **Step 3: Migrate metadata and delivery lists**

Keep existing product ids and runtime manifests. Extend those manifests in place with `schema`, `category`, `version`, `destination`, and `files`; do not create duplicate metadata files. Compute exact sizes and SHA-256 after final file content is stable, then place the manifest hash in the registry. Templates remain authoring examples and are excluded from offered ids.

- [ ] **Step 4: Run GREEN**

Run both Step 2 commands plus `bash tests/validate-catalogue.sh`.

- [ ] **Step 5: Commit**

```bash
git add rices plugins bundles installers tests
git commit -m "catalogue: migrate existing store products"
```

---

### Task 5: External Lockscreen Catalogue and Provider Cutover

**Repositories:** both

**Extras files:**
- Create: `lockscreens/registry.json`
- Create: `lockscreens/<id>/` for every redistributable offered theme, including QML, config, fonts, media, license, preview, and product delivery fields

**Main files:**
- Replace: `ryoku/apps/ryostore/backend/provider_locks.go`
- Modify: `provider_locks_test.go`, `catalog.go`, `ryoku/lockscreen/install-qylock`, delivery tests
- Remove after proof: direct GitHub API/tree/cache/preview worker code and duplicated Store-visible theme payloads

**Interfaces:**
- Browse source: `lockscreens/registry.json` from shared `Cache`.
- Destination allowlist: `${XDG_CONFIG_HOME}/qylock/themes/<id>`.
- Install/remove: common Task 3 transaction.
- Core fallback: explicitly absent from registry and not removable.

- [ ] **Step 1: Add failing extras and provider tests**

Extras validation requires the full lockscreen registry and every theme payload. Go tests use a local HTTP server and assert registry-only browsing, absolute preview URLs rooted in extras, installed receipt/state join, generic install/remove, source isolation, and no request to GitHub API/tree endpoints.

- [ ] **Step 2: Run RED in both repositories**

```bash
cd /home/nero/Work/ryoku-extras
python3 tests/validate-store.py --root . --categories lockscreens
cd /home/nero/Work/ryoku-arch-unstable/ryoku/apps/ryostore/backend
go test ./... -run 'TestLock' -count=1
```

- [ ] **Step 3: Vendor licensed themes and replace provider**

Preserve upstream license and author data beside each mirrored theme. Do not list any theme whose code, fonts, or media lack redistribution permission. Normalize the external registry through the common entry helper and route install/remove through the transaction. The installed theme must include everything required offline.

- [ ] **Step 4: Verify install/remove in temporary XDG**

Run extras validation, all lock provider tests, and an end-to-end local-base install/remove that compares installed files against manifest hashes and leaves the core fallback untouched.

- [ ] **Step 5: Commit each repository**

```bash
# extras
git add lockscreens tests
git commit -m "catalogue: own lockscreen products"
# main
git add ryoku/apps/ryostore/backend ryoku/lockscreen tests
git commit -m "[ryoku] ryostore: externalize lockscreen products"
```

---

### Task 6: External Bar Styles and Version-Aware Live Loader

**Repositories:** both

**Extras files:**
- Create: `barstyles/registry.json`, `barstyles/nacre/`, `barstyles/obi/`
- Copy then validate all optional style QML/JS/manifests/assets from main

**Main files:**
- Create: `ryoku/shell/quickshell/pill/Singletons/BarProducts.qml`
- Modify: its `qmldir`, `pill/shell.qml`, `backend/provider_bars.go`, `provider_bars_test.go`, shell probes
- Remove after proof: `pill/barstyles/registry.js`, `pill/barstyles/nacre/`, `pill/barstyles/obi/`

**Interfaces:**
- Destination: `${XDG_DATA_HOME}/ryoku/barstyles/<id>`.
- Index: `${XDG_STATE_HOME}/ryoku/store/barstyles.json` with `{id, version, scene}` rows.
- `BarProducts.sceneUrl(id)` returns `file://<scene>?v=<version>` or `""` for Sumi.
- `BarProducts` watches `store/revision.json`; a barstyle change reloads only the active Loader component.

- [ ] **Step 1: Add failing schema, provider, and QML live-update probes**

The live probe launches a shell fixture with Sumi core plus optional `obi` v1, records the shell process id and marker exposed by the scene, atomically installs v2 and writes a revision, then requires the marker to change while the pid remains identical. Removal of the active optional style must fall back to Sumi without a shell restart.

- [ ] **Step 2: Run RED**

Run extras barstyle validation, `go test ./... -run TestBar`, and the new live QML probe. Expected failures: missing registry, local provider semantics, missing `BarProducts`.

- [ ] **Step 3: Externalize styles and implement loader**

Keep only Sumi as built-in. The external provider joins receipt and active `Config.barStyle` state. `BarProducts` parses the installed index and revision with `FileView { watchChanges: true; atomicWrites: true }`. `pill/shell.qml` uses the versioned URL and preserves monitor model injection.

- [ ] **Step 4: Run GREEN and deploy smoke test**

Run extras validation, bar provider tests, shell probes, deploy, select/update/remove an optional style, and assert unchanged shell pid.

- [ ] **Step 5: Commit both repositories**

Use `catalogue: externalize bar styles` in extras and `[ryoku] shell: load store bar styles live` in main.

---

### Task 7: Fastfetch Product Catalogue

**Repositories:** both

**Extras files:**
- Create: `fastfetch/registry.json`
- Create: `fastfetch/ryoku-dossier/` and `fastfetch/minimal-grid/` with complete configs, product manifests, preview metadata, and licenses

**Main files:**
- Modify: `backend/provider_fastfetch.go`, `provider_fastfetch_test.go`, `hub/quickshell/pages/FastfetchPage.qml`, focused probes

**Interfaces:**
- Destination: `${XDG_DATA_HOME}/ryoku/fastfetch/<id>`.
- Settings selection copies or renders the selected external style into its existing editable `~/.config/fastfetch/config.jsonc` source after explicit user action.
- Store install/update never overwrites that editable source automatically.

- [ ] **Step 1: Add failing catalogue/provider tests**

Assert two real external products, correct previews, receipt/update state, safe install/remove, and explicit Settings apply. Removing an applied style removes the library copy but leaves the user's current editable config intact.

- [ ] **Step 2: Run RED**

Run extras fastfetch validation and backend Fastfetch tests.

- [ ] **Step 3: Implement products and provider**

Use valid Fastfetch JSONC modules with no machine-specific paths. Replace the temporary 404-as-empty path with normal external registry behavior and common transactions.

- [ ] **Step 4: Run GREEN and live terminal smoke**

Apply each style through Settings, run `fastfetch --config ~/.config/fastfetch/config.jsonc`, install an update, and confirm a new terminal invocation sees it without any shell reload.

- [ ] **Step 5: Commit both repositories**

Use `catalogue: add fastfetch styles` and `[ryoku] ryostore: open fastfetch catalogue`.

---

### Task 8: Plugin Revision Watch and Versioned Component URLs

**Repository:** `/home/nero/Work/ryoku-arch-unstable`

**Files:**
- Modify: `widgets/Singletons/Registry.qml`
- Modify: `widgets/PluginDesktopSlot.qml`, `widgets/shell.qml`, `pill/PluginPopouts.qml`
- Modify: `backend/provider_plugins.go`, `provider_plugins_test.go`, `extras_assets.go`
- Create or modify: focused plugin live-update probe

**Interfaces:**
- Registry item adds `version` from installed manifest/receipt.
- Every plugin service/content URL appends `?v=<encoded version>`.
- Registry watches both `plugins.json` and `~/.local/state/ryoku/store/revision.json`.

- [ ] **Step 1: Add failing live update probe**

Install and enable fixture plugin v1, start the shell fixture, capture visible marker and pid, update to v2 through `ryostore install plugins fixture`, and require v2 marker with identical pid. Remove must unload the plugin automatically and preserve unrelated placements.

- [ ] **Step 2: Run RED**

Run provider tests and the focused live-update probe. Expected: installed files change but the running component remains v1 or does not reprobe.

- [ ] **Step 3: Implement revision watch and cache-busting URLs**

Atomic product publication writes the receipt and revision after manifest publication. The Registry's revision handler reruns discovery. Every `createComponent` or Loader source uses a file URL with the exact installed version query. Keep service/content replacement scoped to the changed registry model.

- [ ] **Step 4: Run GREEN and deploy smoke**

Run provider, shell, plugin placement, and live-update probes. Deploy and repeat with one real plugin while recording unchanged shell pid.

- [ ] **Step 5: Commit**

```bash
git add ryoku/apps/ryostore/backend ryoku/shell/quickshell/widgets ryoku/shell/quickshell/pill tests
git commit -m "[ryoku] shell: apply plugin updates live"
```

---

### Task 9: Lazy Bundle State and Ownership-Safe Removal

**Repositories:** both

**Extras files:**
- Finalize inline `components` in `bundles/registry.json`
- Keep product-specific installers inside owning product folders

**Main files:**
- Modify: `backend/provider_bundles.go`, `provider_bundles_test.go`, `system/extras/ryoku-extras-install`, `tests/extras-install.sh`

**Interfaces:**
- Browsing fetches `bundles/registry.json` only; it must not fetch every `bundle.json` or installer.
- Bundle receipt components record `preExisting`, `installedByRyoku`, and references from other installed bundle receipts.
- Removal deletes only `installedByRyoku && references == 0` components.

- [ ] **Step 1: Add failing request-count and ownership tests**

Tests must assert one registry HTTP request for browse, lazy selected-manifest fetch for install, preservation of pre-existing packages, preservation of a component shared by two installed bundles, removal after the final owner is removed, and exact failure reporting per component.

- [ ] **Step 2: Run RED**

```bash
cd ryoku/apps/ryostore/backend && go test ./... -run TestBundle -count=1
cd /home/nero/Work/ryoku-arch-unstable && bash tests/extras-install.sh
```

- [ ] **Step 3: Implement lazy and receipt-driven behavior**

Remove browse-time installer warming. Status reads inline components. Before installation, snapshot component presence into the receipt. Before removal, read every installed bundle receipt once and compute remaining references. Keep the existing terminal UI and package helpers.

- [ ] **Step 4: Run GREEN plus extras validation**

Run Step 2 plus full backend tests and `bash /home/nero/Work/ryoku-extras/tests/validate-catalogue.sh`.

- [ ] **Step 5: Commit both repositories**

Use `catalogue: inline bundle delivery state` and `[ryoku] extras: preserve shared bundle ownership`.

---

### Task 10: Generic Settings Removal and Clean Provider Cutover

**Repository:** `/home/nero/Work/ryoku-arch-unstable`

**Files:**
- Modify: all six providers and tests
- Modify: `hub/quickshell/pages/{AddonsPage,AppearancePage,LockscreenPage,BarStudioPage,FastfetchPage}.qml`
- Modify: RyoStore handoff, wire, and Settings probes
- Modify: delivery docs only where current command ownership is described

**Interfaces:**
- Settings calls `ryostore remove <category> <id>` for every product library removal.
- Bundle item-level removal remains `ryoku-extras-install remove item <bundle> <name>`.
- Plugin removal deletes the product first and runs `ryoku-plugins-place <id> forget` only after success; a failed removal preserves placement and settings.
- Providers have no direct third-party source, local optional-product scan, or category-specific deletion path.

- [ ] **Step 1: Rewrite probes for generic removal**

Require exact category/id calls for rice, lockscreen, barstyle, Fastfetch, plugin, and whole-bundle removal. Search logs must reject `internal remove-guest`, direct `rm`, direct qylock GitHub URLs, and local optional bar scans.

- [ ] **Step 2: Run RED**

Run backend tests, Settings handoff/wire probes, and extras actuator tests.

- [ ] **Step 3: Migrate callers and delete obsolete paths**

Update every caller in one clean cutover. Preserve explicit apply/enable/active controls in Settings. For plugins, wait for successful generic removal before forgetting placement/settings. Delete old provider code and product payload copies only after their external equivalents pass validation and install proof.

- [ ] **Step 4: Run complete nonvisual verification**

```bash
cd ryoku/apps/ryostore/backend && go test ./... && go vet ./...
cd /home/nero/Work/ryoku-arch-unstable
node ryoku/apps/ryostore/quickshell/lib/store.test.mjs
bash tests/extras-install.sh
bash tests/ui/ryostore-handoff-probe.sh
bash tests/ui/wire-probe.sh
bash /home/nero/Work/ryoku-extras/tests/validate-catalogue.sh
```

- [ ] **Step 5: Commit**

```bash
git add ryoku/apps/ryostore ryoku/hub system/extras tests docs
git commit -m "[ryoku] ryostore: unify product removal"
```

---

### Task 11: Complete Product Media in `ryoku-extras`

**Repository:** `/home/nero/Work/ryoku-extras`

**Files:**
- Create: `tools/render-showcase.qml`, `tools/render-showcase.sh`
- Create or replace: missing `assets/preview.webp` and detail screenshots beside products
- Modify: all registry image references and manifests/hashes

**Interfaces:**
- Real capture command: `grim -g '<x>,<y> <w>x<h>' <product>/assets/<name>.png` after deterministic state setup.
- Generated fallback command: `tools/render-showcase.sh <category> <id> <output.webp>`; it reads only registry metadata and renders the same solid accent/surface/title/category grammar as RyoStore `ProductCover`.
- Capture ledger: `reports/store-media.json` records product, source `real|generated`, dimensions, capture date, and command.

- [ ] **Step 1: Add failing media completeness validation**

Every offered product must have one readable preview at least 1280x720 or a lossless/vector equivalent, no broken dimensions, no alpha-only/blank image, and every screenshot reference must resolve. The validator reports exact category/id.

- [ ] **Step 2: Run RED**

```bash
python3 tests/validate-store.py --root . --require-media
```

Expected: missing media for current rices, most bundles, bar styles, lockscreens, or Fastfetch products.

- [ ] **Step 3: Capture real product frames**

Use the deployed Ryoku checkout as source of truth. Record active state, use `ydotool` only for deterministic interaction, capture with `grim`, crop without upscaling, and restore prior state after each product. Prefer real rice, lockscreen, bar-style, Fastfetch, and plugin frames.

- [ ] **Step 4: Generate temporary eye-candy only for remaining gaps**

The temporary QML renderer imports the shared Ryoku theme from the deployed checkout but emits only image files into `ryoku-extras`. It contains no product-specific copy. Update registry paths, file sizes, SHA-256, and the media ledger.

- [ ] **Step 5: Run GREEN and commit**

```bash
python3 tests/validate-store.py --root . --require-media
bash tests/validate-catalogue.sh
git add rices lockscreens barstyles fastfetch plugins bundles tools reports tests
git commit -m "catalogue: complete store showcase media"
```

---

### Task 12: Exhaustive Install, Update, Remove, Live, and Visual Proof

**Repositories:** both

**Files:**
- Modify only source or tests when the proof exposes a real defect
- Update release changelog in main after all proof passes

- [ ] **Step 1: Run every-product dry-run matrix**

Enumerate ids from all six registries. For every id, run local-base catalog, install dry-run, update dry-run, and remove dry-run. Fail on unknown routes, undeclared files, missing receipts, unsafe destinations, or noisy output.

- [ ] **Step 2: Run one real isolated cycle per category**

Use temporary XDG roots and fixture executables. Install v1, verify file hashes/receipt; install v2, verify rollback safety and `UPDATE` clears after reprobe; remove, verify owned cleanup and unrelated preservation.

- [ ] **Step 3: Prove production live updates**

Deploy the main checkout. Record the running shell pid. Update one enabled plugin and one active optional bar style from v1 to v2. Require visible v2 markers, unchanged shell pid, no `ryoku reload`, and no manual restart. Remove both and verify automatic unload/fallback.

- [ ] **Step 4: Run full automated gates once**

```bash
cd /home/nero/Work/ryoku-extras && python3 -m unittest tests.test_validate_store -v && bash tests/validate-catalogue.sh
cd /home/nero/Work/ryoku-arch-unstable/ryoku/apps/ryostore/backend && go test ./... && go vet ./...
cd /home/nero/Work/ryoku-arch-unstable
node ryoku/apps/ryostore/quickshell/lib/store.test.mjs
bash tests/extras-install.sh
bash tests/ui/ryostore-components-probe.sh
bash tests/ui/ryostore-shell-probe.sh
bash tests/ui/ryostore-flow-probe.sh
bash tests/ui/ryostore-handoff-probe.sh
bash tests/ui/wire-probe.sh
ryoku-dev-verify-delivery
```

- [ ] **Step 5: Perform the complete live visual pass**

Capture and inspect Discover, every category, Library, Search, detail, offline, progress, success, exact failure, missing-art, and 980x640 cramped states. Exercise keyboard, wheel, drag, hover preview, committed action safety, detail return, install/update, and Settings removal. Reject broken URLs, clipped controls, unreadable text, generic dashboard/card composition, grain, or stale state.

- [ ] **Step 6: Commit only evidence-driven fixes and changelog**

Use focused area-labeled commits in main and catalogue-focused commits in extras. Do not create empty commits. Both repositories must end with no uncommitted task changes.
