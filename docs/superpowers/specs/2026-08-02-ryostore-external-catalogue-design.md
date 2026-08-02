# RyoStore External Catalogue and Live Delivery Design

## Context

RyoStore already reads some catalogues from `ryoku-extras`, but ownership is split. Rices, plugins, and bundles are external; lockscreen discovery still scrapes qylock directly; bar styles are discovered from code shipped in the main repository; Fastfetch has no usable catalogue. That split makes the main repository carry product payloads, creates category-specific install behavior, and makes live product updates unreliable.

For this design, a Store product asset means both media and implementation: images, QML, JavaScript, configuration, manifests, scripts, fonts, and uninstall metadata. Every such asset belongs in `~/Work/ryoku-extras`. The main Ryoku repository owns only the generic Store client, catalogue schemas, cache, transaction engine, runtime loaders, core fallbacks, and tests.

The existing living-showroom visual design remains authoritative. This document adds the catalogue ownership and delivery contract it consumes.

## Goals

- Make `ryoku-extras` the complete source of every product RyoStore offers.
- Keep the main repository free of Store-specific product code and showcase media.
- Browse from small category registries without downloading every product payload.
- Install, update, and remove every product through one safe transaction contract.
- Make an installed update visible automatically. No developer hot reload, `ryoku reload`, or shell process restart may be required.
- Preserve provider isolation, offline browsing, exact errors, and the rule that browsing never mutates the desktop.
- Store curated screenshots and generated fallback showcase images beside their products in `ryoku-extras`.

## Non-goals

- Core shell code and the built-in Sumi fallback are not Store products and remain in the main repository.
- Installing or updating a rice does not silently apply it. Applying a desktop look remains an explicit Settings action.
- Removing a bundle does not remove packages that predated the bundle or are still owned by another installed bundle.
- RyoStore does not become a general package manager or a Git client.

## Approaches considered

### Inline browse registries with lazy product payloads (selected)

Each category has one complete browse registry in `ryoku-extras`. The registry contains identity, description, version, state-detection metadata, preview paths, screenshot paths, and a product manifest path. RyoStore fetches only the small registries for browsing. It fetches and validates the selected product manifest and its declared files only during install or update.

This removes the current N+1 catalogue fetches, keeps provider failures isolated, supports local test servers, and avoids downloading code the user never installs.

### Whole-repository archive snapshots

RyoStore could download one tarball for every refresh and serve all metadata and assets from it. This gives a coherent snapshot but makes a catalogue refresh scale with every image and product payload. It is wasteful on metered connections and makes quick browsing dependent on a large archive.

### Continue category-specific remote discovery

The current mix of raw GitHub registries, direct qylock tree scraping, and local bar-style scanning minimizes immediate migration work. It does not satisfy single-repository ownership, generic removal, or live update behavior, and it keeps the slowest provider paths.

## Repository ownership

### Main Ryoku repository

The main repository owns:

- the RyoStore Go executable, cache, normalized item model, and category adapters;
- common registry and product-manifest validation;
- generic install, update, remove, receipt, and revision notification machinery;
- generic shell loaders for installed plugin and bar-style products;
- the core Sumi bar fallback and other non-Store runtime essentials;
- Settings surfaces that apply or manage installed products;
- fixture-only test data and probes.

It must not contain a Store product's QML, JavaScript, config payload, font, preview, screenshot, installer, or uninstall recipe.

### `ryoku-extras` repository

`ryoku-extras` owns one folder and one registry entry for every offered product in these categories:

- `rices/`
- `lockscreens/`
- `barstyles/`
- `fastfetch/`
- `plugins/`
- `bundles/`

A product folder owns all files needed to preview, install, update, and remove that product. External upstream projects may be credited and mirrored only when their license permits redistribution. RyoStore never discovers an offered product directly from a third-party repository.

## Registry and manifest contract

Every category registry entry provides a common browse envelope:

```json
{
  "id": "stable-id",
  "name": "Readable name",
  "version": "1.2.3",
  "path": "category/stable-id",
  "author": "Author",
  "summary": "One-line value",
  "description": "Full product copy",
  "tags": ["searchable"],
  "accent": "#d75f5f",
  "surface": "#101010",
  "preview": "assets/preview.webp",
  "screenshots": ["assets/detail-1.webp"],
  "manifest": "product.json",
  "manifestSha256": "64 lowercase hex characters"
}
```

Category-specific state metadata may be inline, such as bundle components, plugin hosts, rice compatibility, or a Fastfetch style id. Browse metadata is never recovered by fetching every product manifest.

`path` is the product root. `preview`, every screenshot, and `manifest` are relative to it. `manifestSha256` authenticates the manifest before RyoStore trusts its file list. Installed version comparison is exact string equality: a receipt version different from the current registry version produces `UPDATE`.

Each product manifest declares:

- schema version, product id, category, and product version;
- destination kind and relative install root;
- every payload file with relative source, relative destination, mode, size, and SHA-256;
- activation metadata used by Settings or a generic runtime loader;
- a removal policy limited to files owned by the receipt;
- compatibility and optional migration metadata.

All paths are relative, normalized, traversal-free, and symlink-safe. Unknown schema versions fail before any destination changes.

## Transaction and receipt model

Install and update share one transaction:

1. Fetch the selected manifest and declared files into a bounded cache.
2. Verify identity, category, version, sizes, hashes, paths, and category policy.
3. Stage the complete destination on the same filesystem as the final target.
4. Preserve the prior version until validation succeeds.
5. Atomically replace the installed product directory or index entry.
6. Write a receipt under `~/.local/state/ryoku/store/<category>/<id>.json`.
7. Atomically increment the Store revision file.
8. Reprobe authoritative installed state before reporting success.

A receipt records source version, owned paths, the previous product receipt needed for rollback, and category-specific ownership. Installation refuses to overwrite an untracked destination. A failed transaction leaves the prior installation intact and returns the exact error.

Removal reads the receipt and deletes only owned paths. It refuses unsafe or untracked paths. Bundle receipts additionally record whether each package or tool was already present and which installed bundles still reference it. Removal keeps pre-existing and shared items.

The public CLI is a clean generic contract:

```text
ryostore install <category> <id>
ryostore remove <category> <id>
ryostore catalog [--refresh]
```

Installing an already-owned older version performs an update. There is no separate product-specific updater in the main repository.

## Category delivery behavior

### Rices

Rice manifests, palettes, wallpapers, hero art, and cursor metadata live in `ryoku-extras`. Installation updates the local rice library but never applies the look. Settings owns explicit preview, apply, fork, and removal. An update to the currently applied rice does not mutate the desktop until the user applies it again.

### Lockscreens

Redistributable theme QML, media, fonts, metadata, and previews live under `lockscreens/<id>/`. The existing direct qylock GitHub tree provider is removed. Installation publishes a complete theme atomically; Settings owns active lock and greeter selection. A non-Store core fallback may remain packaged, but it is not shown as a product.

### Bar styles

Store bar styles live under `barstyles/<id>/` and install into the user data tree. Sumi remains the core fallback and is not listed in RyoStore. The shell reads an installed-style index and loads the selected scene dynamically. The Loader URL includes the installed version so a production update invalidates the QML component cache.

### Fastfetch styles

Every offered Fastfetch config and preview lives under `fastfetch/<id>/`. Installation writes the versioned style into the Store data tree. Settings selects a style through the existing editable Fastfetch source; new terminal invocations see the selected update without a shell reload.

### Plugins

Plugin manifests, QML, JavaScript, assets, and settings schemas remain wholly in `ryoku-extras`. Installation or update atomically replaces the product directory, updates its receipt, and increments the Store revision. The shell plugin registry watches that revision as well as `plugins.json`; enabled plugin Loader URLs include the manifest version so updated code is recreated automatically without restarting the shell.

### Bundles

Bundle browse registries contain the component metadata needed for installed and partial counts. RyoStore no longer warms every script or bundle definition while browsing. Selected bundle payloads are fetched lazily. Bundle installation and removal use receipts to preserve pre-existing packages and components shared with another bundle.

## Live update contract

`~/.local/state/ryoku/store/revision.json` is written atomically after a successful install, update, or removal. It contains a monotonically increasing revision plus the changed category, id, version, and operation.

The running shell watches this file through Quickshell `FileView`. Plugin and bar-style registries reprobe on change. Their Loader source URLs include the installed product version, forcing a new component instance when code changes. State restoration is product-defined and limited to declared settings; stale QML objects are destroyed after the replacement is ready.

This is production runtime behavior, not developer hot reload. No call to `ryoku reload`, no manual shell restart, and no restart of Hyprland is part of the update path.

Rices, lockscreens, and Fastfetch styles are data managed by Settings and do not require a shell reload. Bundle package state is reprobed by RyoStore.

## Catalogue validation

`ryoku-extras/tests/validate-catalogue.sh` expands to validate all six Store categories. It checks:

- every registry and manifest parses and uses a supported schema;
- every entry resolves to exactly one product folder and matching id/category;
- every declared code and media file exists, remains inside the product folder, and matches its size/hash;
- every preview and screenshot resolves;
- every executable script has a shebang and executable mode;
- every install destination and removal policy is allowed for its category;
- every Store product has install and remove metadata;
- duplicate ids, dangling bundle components, forbidden symlinks, and undeclared payload files fail validation.

The main repository has mirrored schema fixtures and local-server provider tests, but no copied production payloads.

## Visual asset policy

Real screenshots are preferred. Existing plugin previews remain authoritative. Rice, lockscreen, and bar-style previews are captured from the running desktop with `grim`; `ydotool` may drive deterministic navigation or state setup. Before and after each capture, the script records and restores the user's active state.

When a real product cannot yet produce a useful frame, a temporary eye-candy preview is rendered from its actual registry metadata using the same RyoStore `ProductCover` composition and captured to a WebP or PNG. Generated previews are clearly named, stored beside the product in `ryoku-extras`, declared in the registry, and replaced when a real capture is available. The main repository stores no generated product media.

## Verification

### Automated

- Run main-repository Go provider, cache, transaction, route, and receipt tests against a local `RYOKU_EXTRAS_BASE` fixture server.
- Run `ryoku-extras/tests/validate-catalogue.sh` and category-specific schema checks.
- Run a dry-run install, update, and remove matrix for every registry entry.
- Run real temporary-XDG install, update, and remove cycles for one product per category, verifying hashes, receipts, cleanup, and preservation of unrelated files.
- Test bundle ownership with pre-existing and shared components.
- Test an enabled plugin and active optional bar style through two versions; the visible component must change after the revision write while the shell process id remains unchanged.
- Run all RyoStore UI probes and backend tests after the external catalogue cutover.

### Visual

- Capture Discover, every category, Library, Search, detail, offline, progress, success, failure, missing-art, and 980x640 cramped states from the deployed RyoStore.
- Inspect every referenced preview and screenshot for readable composition, correct cropping, and absence of broken URLs.
- Exercise keyboard, wheel, drag, pointer preview, detail return, install/update, and Settings removal on the live app.
- Confirm the running shell process id is unchanged across live plugin and bar-style updates.

## Migration and cutover

1. Add common registry and product-manifest validation without changing current providers.
2. Extend `ryoku-extras` validation and add the six category registries.
3. Move optional bar-style and lockscreen product payloads to `ryoku-extras`; keep only non-Store core fallbacks in main.
4. Make all providers browse only their external registry and lazily fetch selected payloads.
5. Add generic receipts, remove, update, and Store revision notifications.
6. Make plugin and bar-style runtime loaders version-aware and revision-watched.
7. Migrate Settings removal calls to the generic RyoStore contract.
8. Generate or capture missing previews into `ryoku-extras`.
9. Prove the complete install, update, remove, offline, live-update, and visual contracts.
10. Remove the old direct qylock discovery, local optional bar registry, eager payload warming, and any duplicate product media or code from main.

The cutover is clean. No compatibility shim or alternate product source remains.
