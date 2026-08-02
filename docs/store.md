# The store

Ryoku's extras are delivered through a **store**: a browsable catalogue of
bundles and plugins that install into the running desktop with no setup, and
remove just as cleanly. The catalogue is a separate repo (`ryoku-extras`); the
store UI lives in the Hub; the shell hosts whatever a bundle brings.

## How it works today

- **Catalogue = `ryoku-extras`.** Each kind of thing (bundles, plugins,
  nautilus packs, livewalls, colorschemes) is a folder with a `registry.json`.
  An item is invisible to the shell until it is listed there. The Hub fetches
  the repo at runtime (`RYOKU_EXTRAS_BASE`, default the GitHub `main` raw tree)
  and caches it under `~/.cache/ryoku/extras`, so the catalogue still renders
  offline.
- **Store UI = the Hub.** Ryoku Settings has an **Add-ons -> Store** section
  with **Plugins** and **Bundles** tabs: image-rich cards (hero, install badge,
  source and count chips), a detail view, and one install action. Managing
  what is already installed lives on the Add-ons page.
- **Install = the actuator.** `ryoku-extras-install` routes each bundle item by
  type: `package` through `pacman -Syu` / the AUR helper (one package at a time,
  so one failure never strands the rest), `script` through `installers/<name>.sh`,
  and `plugin` / `nautilus-pack` through the shell's guest paths. It runs in a
  floating terminal for the sudo prompt; a bundle's `requires` (such as
  `multilib`) is ensured first. Removal is symmetric.
- **Guests = host/guest.** The shell is the *host*; a bundle ships *guests*
  (a plugin that renders in a widget or frame-popout host, a nautilus pack that
  drops right-click scripts). A guest declares its host and mounts on install,
  reload, and use with no extra setup; removing the bundle takes the guest and
  its state with it. All the guest's code lives in `ryoku-extras`, not here, so
  the shell stays a host and the catalogue stays independent.

## Decision: build Ryostore

The conditions for a standalone store are now present. The catalogue spans six
distinct product categories, discovery is split across unrelated Settings
pages, and the store is intended to be a visible front door for the Ryoku
ecosystem. Ryostore replaces those browse surfaces rather than duplicating them.

There is one door for discovery and installation:

- **Ryostore discovers and installs.** It owns remote catalogues, cached
  metadata, search, previews, item details, installation, and installed-state
  summaries.
- **Ryoku Settings manages what is present.** It owns activation, configuration,
  updates, removal, placement, and applied-state controls.
- **Install never activates.** Installing a rice, lockscreen, plugin, bar style,
  or future fastfetch style must not change the desktop. Completion offers
  **Open in Settings**.

The first release exposes Lockscreens, Plugins, Bundles, Rices, Bar styles, and
Fastfetch styles. A category without a live remote registry remains visible with
an honest empty plate. It never receives fake specimens.

## Product shape

Ryostore is a standalone Quickshell app in the same family as Ryoport and
ryowalls. Its ideal window is 1180 by 760, clamped to the available screen.
Below the ideal width, poster plates reflow rather than shrinking type or hiding
actions.

The persistent rail is organized by user intent:

```text
FIND
  Today
  Installed

WEAR
  Rices
  Lockscreens
  Bar styles
  Fastfetch

EXTEND
  Plugins
  Bundles
```

**Today** combines an editorial archive with a poster wall. Large category
plates carry useful facts such as `4 INSTALLED`, `1 ACTIVE`, or `2 UPDATES`.
They sit beside a permanent **On this machine** shelf, one curated feature, and
a small set of recent specimens. There is no recommendation engine, account,
rating system, or endless feed.

**Installed** is a first-class cross-category collection, not a filter hidden in
each catalogue. Every item writes its state explicitly:

- `ACTIVE` for the rice, lockscreen, bar, or fastfetch style currently worn;
- `ENABLED` for a running plugin;
- `INSTALLED` for an owned but inactive item;
- `<installed> / <total> INSTALLED` for a partial bundle;
- `UPDATE` when a newer store-managed version is available.

A category page has global search, a small set of meaningful filters, and a
responsive specimen grid. Opening a specimen produces a split dossier: real
preview art and screenshots on one side, then author, source, version,
compatibility, exact local state, description, and actions on the other.

Actual preview art may keep its color because it is the item being evaluated.
The app chrome remains paper and ink. Poster ornaments occupy dead space and
never overlap controls.

## Interaction contract

Navigation follows a peel-back model:

- `/` and `Ctrl+K` focus global search from anywhere;
- `Esc` closes a detail, clears search, then returns to Today, and never quits;
- arrow keys move the current specimen and `Enter` opens it;
- `Ctrl+1` opens Today and `Ctrl+2` opens Installed;
- returning from a detail restores the category, filters, scroll position, and
  focused card;
- quitting during an active installation requires a second quit action.

Search is global and grouped by category. Results retain state, so a query such
as `installed clock` can find installed lockscreen and fastfetch specimens
without navigating to either category.

Installation feedback stays in the detail:

1. The primary action locks immediately and reads `INSTALLING`.
2. A thin ledger reports the real stage: fetching, verifying, installing, or
   complete.
3. The backend is re-probed after completion and whenever the window regains
   focus.
4. Success becomes `INSTALLED` with `OPEN IN SETTINGS`.
5. Failure keeps the detail open, prints the actionable error, and offers
   `RETRY`.

Bundles retain the existing floating terminal because package authorization and
long-running output belong there. The dossier lists every component and current
count before the user starts `INSTALL <n> ITEMS`. Ryostore watches the existing
report file so the app reflects live progress while the terminal owns the
privileged operation.

Motion uses the shared tokens: short hover and press feedback, a standard page
cross-fade, and a spatial detail transition. Hidden and idle surfaces do no
work. Focus is always visible, all text uses the contrast-solved ink tiers, and
every mouse action has a keyboard equivalent.

## Unified subsystem

Store ownership lives in one folder:

```text
ryoku/apps/ryostore/
  backend/
    go.mod
    main.go
    model.go
    cache.go
    provider_locks.go
    provider_plugins.go
    provider_bundles.go
    provider_rices.go
    provider_bars.go
    provider_fastfetch.go
  quickshell/
    shell.qml
    App.qml
    StoreHeader.qml
    ShowroomStage.qml
    Filmstrip.qml
    SearchLayer.qml
    ProductDetail.qml
    ProductCover.qml
    StatusReadout.qml
    lib/
      store.js
    Singletons/
      Store.qml
      qmldir
    logo.svg
  ryostore.desktop
```

Each QML file owns one surface. More focused files may be added when a real
surface requires them; unrelated views are not merged to keep the file count
small.

The Go backend builds to `/usr/bin/ryostore` through the existing first-party app
packaging loop. It normalizes all providers into one JSON contract:

```text
Category
  id, name, group, description, count, installedCount

Item
  id, category, name, summary, description
  art, screenshots, author, version, compatibility
  installed, active, enabled, installedCount, totalCount
  updateAvailable, metadata
```

The public command surface is deliberately small:

```text
ryostore catalog [--refresh]
ryostore install <category> <id>
ryostore settings <category> [id]
```

QML invokes this contract instead of maintaining six bespoke process and state
models. Adding a specimen changes only its upstream registry or owning local
manifest. Adding a category adds one provider and one category registration;
the generic rail, search, Installed page, grid, and detail view need no new QML
page.

Runtime implementations remain with their owning subsystem. A bar style still
lives under `pill/barstyles/<id>/`, a qylock theme under the qylock theme tree,
and a plugin in the plugin data directory. Ryostore owns their catalogue adapter
and installation, not a second runtime copy.

## Provider behavior

- **Lockscreens:** fetch the qylock catalogue, preview cache, and install-only
  theme downloader. Installed and active state come from the local qylock theme
  tree and current theme. Settings retains preview and activation.
- **Plugins:** fetch and install the `ryoku-extras` plugin registry. Installed
  version, enabled state, and update state come from the plugin directory and
  `plugins.json`. Settings retains enable, placement, update, configuration, and
  removal.
- **Bundles:** fetch the `ryoku-extras` bundle registry and join it with
  `ryoku-extras-install status`. Partial counts are first-class. Settings owns
  installed bundle status and removal.
- **Rices:** fetch and install the `ryoku-extras` rice registry. Installed and
  active state come from the local rices tree and active marker. Appearance
  retains apply, capture, fork, export, delete, and local rice management.
- **Bar styles:** expose the shipped runtime style manifests and the active
  `shell.json` value. The current development styles are all visible and report
  installed state. Settings retains selection and configuration.
- **Fastfetch styles:** expose the category and active local state. Until a
  style registry exists, the category renders its honest upcoming plate.
  Fastfetch editing remains in Settings.

Each provider can fail independently. Cached catalogue data and all local state
still render offline under an `OFFLINE · ARCHIVE FROM <date>` running head. A
failed lockscreen source cannot blank plugins, bundles, or the Installed view.

## Migration

Store-specific code moves out of the Hub instead of being copied:

- qylock catalogue, cache, and install-only download move to Ryostore; the Hub
  keeps installed list, preview, selection, and greeter application;
- plugin and bundle catalogue, cache, and install paths move to Ryostore;
- rice catalogue and installation move to Ryostore;
- the Hub Store page and remote browse modes are removed;
- Add-ons keeps plugin management and gains installed bundle status and removal;
- Lockscreen, Appearance, Add-ons, Bar Studio, and Fastfetch gain one
  `BROWSE RYOSTORE` route where appropriate;
- existing callers of moved commands migrate to `/usr/bin/ryostore`, with no
  compatibility shim or duplicated command left in `ryoku-hub`;
- `ryostore settings` starts or focuses Ryoku Settings and uses the Hub's
  existing `nav` IPC target to open the correct management section.

This is a clean cutover. Ryostore is the only browse surface after the migration.

## Verification

Backend tests use local fixtures for every provider. They cover normalization,
installed and active precedence, update state, partial bundles, stale cache
fallback, malformed registries, missing assets, and install-only behavior.
Existing store tests move with their implementations.

A backend smoke scenario uses temporary XDG directories:

1. run `ryostore catalog` against the full fixture;
2. install one fixture specimen;
3. run the catalogue again;
4. observe `installed: true` and `active: false`.

Pure JavaScript tests cover grouping, filtering, search ranking, status
precedence, and restored browse state. `qmllint` checks all new and touched QML.

The live app is deployed from the checkout and exercised with `ydotool` and
`grim`:

- Today, each category, a detail, and the return path;
- global search and Installed;
- keyboard-only navigation;
- successful fixture install and retryable fixture failure;
- Open in Settings deep links;
- offline cached rendering;
- ideal and cramped window compositions.

The captured frames are inspected for spacing, clipping, focus, status
legibility, loading and error plates, and detail motion. A visible window alone
is not acceptance.

Delivery is complete when the Hub contains no duplicate remote store, all moved
callers use Ryostore, the existing app packaging loop ships the Quickshell tree,
binary, desktop entry, and icon, focused checks pass, and the relevant app,
Hub, structure, and delivery documentation reflects the cutover.
