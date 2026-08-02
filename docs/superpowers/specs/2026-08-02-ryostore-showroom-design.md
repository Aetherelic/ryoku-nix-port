# RyoStore Living Showroom Design

## Context

The first RyoStore implementation followed the recovered July 29 archive/store plan too literally. Its grain layer, print ornaments, permanent navigation rail, rounded cards, and inspector-like detail panel made it look like another Ryoku Settings surface and carried generic dashboard patterns. RyoStore instead needs to be a visual-discovery product: easy to navigate, memorable in motion, and led by the goods it presents.

This design keeps Ryoku's shared theme roles, typography, controls, accessibility behavior, and motion policy. It gives RyoStore a distinct composition and interaction grammar.

## Goals

- Make visual discovery the first-open priority.
- Let product artwork drive selection and navigation without hiding search, categories, Library, status, or actions.
- Give RyoStore a recognizable showroom identity distinct from Ryoku Settings, RyoVM, and Ryowalls.
- Keep install state explicit and trustworthy through backend reprobes.
- Preserve keyboard, pointer, touchpad, reduced-motion, offline, missing-art, and cramped-window behavior.

## Non-goals

- Rewriting the Go catalogue or provider contracts.
- Moving installed-item management out of Ryoku Settings where Settings remains the owner.
- Adding reviews, accounts, payments, recommendations, telemetry, or social features.
- Keeping the previous archive UI as an alternate route or compatibility mode.

## Visual contract

RyoStore is a living showroom, not a card dashboard.

The selected product fills the window as a visual stage. Its artwork is a full-window backdrop with contrast-safe tonal treatment derived from the artwork and Ryoku theme roles. Product identity, summary, compatibility, size, status, and primary action sit directly on that stage. Artwork may carry its own colour; app chrome continues to use shared Ryoku roles.

A filmstrip along the bottom is the catalogue. The selected cover rises slightly and gains the strongest focus treatment. Neighboring covers remain visible so the user understands position and can browse without leaving the stage. The filmstrip is square-edged and image-led, not a row of floating rounded cards.

The fixed header contains only:

- the RyoStore identity;
- Discover and category navigation;
- Search;
- Library and its installed/update count.

The UI must not use:

- `Grain`, registration grids, corner ticks, barcodes, or archive/print ornament;
- a permanent left navigation rail;
- a settings-sheet or boxed inspector composition;
- a bento dashboard;
- rounded containers around every item;
- decorative gradients standing in for real artwork.

## Navigation and interaction

### Discover

Discover opens on a featured product. The stage and filmstrip together form the browse surface. Category navigation changes the collection in place instead of opening a new dashboard page.

The user may move through products with:

- Left and Right arrows;
- mouse wheel or touchpad scroll over the filmstrip;
- drag or swipe on the filmstrip;
- pointer hover to preview only artwork and title, and click for committed selection;
- Home and End for collection boundaries.

Hover previews never retarget the primary action; actions always belong to the committed selection. Wheel, touchpad, drag, and swipe commit the item where the filmstrip settles.

Committed selection updates product copy, state, action, stage artwork, filmstrip focus, and position indicator. Focus remains visible throughout.

### Search

Ctrl+K, `/`, or activating Search expands the fixed header control into a focused search layer. Search results retain the showroom grammar: the first valid result enters the stage and all matches populate the filmstrip. Search does not replace the app with a generic text-result page.

Escape clears search and restores the prior collection, selection, filmstrip position, and focus.

### Library

Library uses the same showroom and filmstrip. It contains installed products and makes `ACTIVE`, `INSTALLED`, `UPDATE`, and partial component state explicit. Empty Library state points back to Discover without introducing a separate dashboard.

### Product detail

Explore Details performs one shared-element transition. The selected artwork expands while screenshots, description, compatibility, contents, author, version, size, install state, primary action, and Settings handoff enter around it.

Escape reverses the transition and restores the exact collection, selection, filmstrip offset, and focused control. A failure or completed install never ejects the user from the detail route.

### Motion

- Stage changes use a short crossfade plus restrained image scale/parallax.
- Filmstrip selection uses position and focus treatment, not ornamental animation.
- Detail entry and exit use one shared-element motion anchored to selected artwork.
- Installation progress is informative motion only.
- Reduced-motion mode removes parallax, scale, and shared-element travel; it uses immediate swaps or short fades without changing hierarchy or navigation.

## State contract

Browsing never changes the desktop. Installation begins only from an explicit primary action.

During installation:

- the primary action becomes a progress/readout state;
- artwork, description, filmstrip navigation, and Escape remain usable;
- repeated install activation is disabled;
- bundle terminal work remains visible through the existing terminal flow.

Success appears only after the backend reprobes installed state. The product then shows its real installed/active/component state and the appropriate management handoff, such as Open in Settings.

Failure:

- remains attached to the selected product;
- preserves artwork, metadata, route, filmstrip position, and installed state;
- shows the exact backend error;
- offers Retry when retry is meaningful;
- never reports installation or closes detail optimistically.

Provider failures remain isolated. Cached products stay browseable under a clear offline indicator. One failed source cannot empty successful sources.

If artwork is absent, RyoStore builds an intentional cover from product name, category, and supplied accent/surface metadata. It must not use grain, a broken-image glyph, a decorative generic gradient, or an empty rounded placeholder.

## Responsive contract

The ideal window remains 1180 by 760.

At 980 by 640:

- the stage remains the primary surface;
- title size, copy measure, and filmstrip height contract;
- low-priority metadata collapses before actions or status;
- category labels may horizontally scroll;
- Search, Library, primary action, state, and Escape navigation remain visible;
- no control or status clips beneath the filmstrip.

The layout may support larger windows by widening artwork and filmstrip spacing, not by adding dashboard columns.

## Component boundaries

`App.qml` is a thin coordinator. The intended QML units are:

- `StoreHeader.qml`: identity, category navigation, Search entry, and Library entry;
- `ShowroomStage.qml`: selected artwork, copy, state, primary action, and position indicator;
- `Filmstrip.qml`: collection projection, selection, scrolling, drag/wheel, and keyboard boundaries;
- `SearchLayer.qml`: query entry, match projection, and restoration of pre-search context;
- `ProductDetail.qml`: expanded dossier, screenshots, metadata, actions, progress, and failure;
- `ProductCover.qml`: real-art and missing-art cover rendering shared by stage transitions and filmstrip;
- `StatusReadout.qml`: explicit availability, installed, active, update, partial, progress, offline, and failure labels.

The existing `Singletons/Store.qml` continues to own catalogue loading, selected data, install commands, backend reprobes, and Settings handoffs. Pure projection and search helpers remain in `lib/store.js`.

The previous `Rail`, Today dashboard, Installed dashboard, category-card pages, poster plates, store cards, grain layer, and inspector-style detail composition are removed when their replacement is live. No alternate legacy route remains.

## Data flow

1. `Store.qml` loads normalized provider output from the Go backend.
2. Discover, category, Library, and Search produce a collection through pure projection helpers.
3. `Filmstrip` owns the visible collection index and reports committed selection to `App`.
4. `ShowroomStage` and `ProductDetail` render the same selected product and source-of-truth state.
5. An install request returns to `Store.qml`, which invokes the backend and exposes progress/error state.
6. Completion triggers a backend reprobe. Only reprobed state updates installed, active, update, or partial labels.
7. Settings handoffs use the existing per-category routing contract.

## Accessibility and input

- Every product cover exposes product name, category, and state to accessibility APIs.
- Focus order follows header, stage actions, filmstrip, and any open detail controls.
- Selection is not conveyed by image treatment alone; focus and status text remain explicit.
- All pointer interactions have keyboard equivalents.
- Text and actions use contrast-safe shared theme roles over a computed artwork scrim.
- Motion honors the desktop reduced-motion setting.
- Escape peels one layer at a time: detail, search, then a non-featured category back to Discover; at Discover it does nothing.

## Verification

Permanent automated checks cover:

- catalogue and category projection;
- Library projection and explicit state precedence;
- selection and filmstrip boundary behavior;
- search entry, result projection, and exact context restoration;
- detail entry/return state;
- install progress and backend-reprobe success;
- failure preservation and retry;
- provider isolation and offline cache;
- missing-art cover data;
- Settings handoff routes.

Live proof covers:

- ideal Discover and every category;
- keyboard, wheel, drag, and pointer filmstrip navigation;
- Search and restoration;
- Library state;
- detail shared-element entry and Escape return;
- safe install-only success and failure;
- bundle progress and Settings handoff;
- offline cached browsing;
- missing artwork;
- reduced motion;
- 1180×760 and 980×640 layouts.

Visual acceptance rejects grain, archive ornament, a permanent sidebar, rounded-card dashboards, inspector panels, hidden navigation, clipped state/actions, and any screenshot taken before the final source edit.
