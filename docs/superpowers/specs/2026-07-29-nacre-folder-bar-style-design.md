# Nacre Folder Bar Style Design

**Date:** 2026-07-29
**Status:** Approved
**Target:** `unstable-dev`

## Goal

Move Nacre out of the legacy monolithic bar implementation and make it a
first-class folder bar style under `pill/barstyles/`. Port the frame, islands,
popouts, and notification behavior from main revision `69ca0b25` into that
folder without changing the main worktree. Add live customization in Bar
Studio without changing the reference default.

The finished style must be selectable as `nacre`, work on every active monitor,
survive malformed or partial persisted settings, and apply live through the
existing Hub Save/Revert flow.

## User Experience

Nacre renders one full-screen blob field with a rounded desktop frame and three
lobes grown from its top edge:

- Left defaults to brand, media, and active window.
- Center defaults to clock, hollow-ring workspaces, and resource statistics.
- Right defaults to connectivity, audio, battery, and tray.

Weather and utilities begin in the unused widget palette. Every widget can be
reordered inside its island, moved to another island, or hidden by returning it
to the palette. A hidden dynamic widget keeps its configured position. Battery,
weather, and tray collapse while unavailable and return to the same configured
position. Media remains present and reads `No music` while idle.

The layout is shared across monitors. Each monitor owns a Nacre scene and popup
windows anchored to widgets on that monitor.

## Style Registration and Ownership

The style registry gains:

```js
{
    id: "nacre",
    name: "Nacre",
    desc: "Pearl: three frosted islands beneath a hairline edge.",
    scene: "barstyles/nacre/Scene.qml"
}
```

The new style lives at:

```text
ryoku/shell/quickshell/pill/barstyles/nacre/
├── Scene.qml
├── components/
│   ├── Island.qml
│   └── WidgetHost.qml
└── widgets/
    ├── ActiveWindow.qml
    ├── Audio.qml
    ├── Battery.qml
    ├── Brand.qml
    ├── Clock.qml
    ├── Connectivity.qml
    ├── Media.qml
    ├── Resources.qml
    ├── Tray.qml
    ├── Utils.qml
    ├── Weather.qml
    ├── Workspaces.qml
    └── registry.js
```

`Scene.qml` owns the exclusive-zone reserve, full-screen overlay, input mask,
shared blob group, frame, island placement, configured widget loaders, popout
state, and monitor binding. `Island.qml` owns content geometry while the frame
is enabled and a detached capsule when it is disabled. `WidgetHost.qml`
resolves a widget ID to one Nacre widget component and collapses unavailable
widgets without changing configuration.

Nacre widgets own the compact face shown in the bar. They may use existing
singletons and small neutral primitives from the shell, but they do not import
Obi's bar-facing widgets.

## Code Discipline

Production files stay small and literal. Each QML file owns one component, pure
layout operations stay in JavaScript, and existing primitives are reused.
Comments explain only non-obvious constraints or reasons; they do not narrate
the code, repeat the design document, or add filler.

## Nacre Popup Architecture

The main implementation's frame-grown popup machinery is copied into Nacre:

```text
ryoku/shell/quickshell/pill/barstyles/nacre/
├── components/
│   └── Popout.qml
└── popouts/
    ├── AudioPopout.qml
    ├── BatteryPopout.qml
    ├── CalendarPopout.qml
    ├── ConnectivityPopout.qml
    ├── InboxPopout.qml
    ├── MediaPopout.qml
    ├── NotificationToast.qml
    ├── ResourcesPopout.qml
    └── WeatherPopout.qml
```

`components/Popout.qml` is the main branch's `BlobRect` curtain and neck
geometry, adapted only for Nacre's local settings and current shared services.
Every popup joins the same `BlobGroup` as the desktop frame and resting lobes.
Opening grows the frame inward at the triggering widget; closing melts back
into the same lobe.

Nacre owns its popup contents, and Obi reuses those content components with its
own standalone window. Compact Nacre widgets report a popup ID and their
screen-space center to `Scene.qml`; they do not create independent
`PanelWindow` cards.

Tray menus remain provided by Quickshell's tray items and are not converted
into a frame popup. The brand launcher and utilities actions also remain
direct actions rather than popups unless an existing Obi utility already owns
one.

Notification popups use the same mechanism as main. A live notification opens
the toast popup at the bell's lobe, and clicking the bell opens the inbox in the
same place. Cards paint content only; the shared blob is their only surface and
outline.

## Nacre Configuration

`Config.qml` exposes a `nacre` object in the shell JSON adapter. The Hub mirrors
the same default and includes `nacre` in its live keys:

```json
{
  "islands": {
    "left": ["brand", "media", "activeWindow"],
    "center": ["clock", "workspaces", "resources"],
    "right": ["connectivity", "audio", "battery", "tray"]
  },
  "height": 40,
  "opacity": 0.82,
  "padding": 12,
  "spacing": 8,
  "islandGap": 14,
  "frameRoundness": 9,
  "edgeMelt": 8,
  "islandScale": 1,
  "osdScale": 1,
  "frame": true,
  "occupiedWorkspaces": true
}
```

The first release supports these live controls:

- `height`: capsule and exclusive-zone height within safe bounds.
- `opacity`: frosted island surface opacity.
- `padding`: horizontal inset inside each island.
- `spacing`: distance between widgets in an island.
- `islandGap`: minimum gap between the center island and either side island.
- `frameRoundness`: radius shared by the frame and resting lobes.
- `edgeMelt`: blend depth between Nacre blob shapes.
- `islandScale`: size of the islands and their widget faces.
- `osdScale`: size of Nacre popups and the shell OSD.
- `frame`: draw Nacre's outer desktop frame.
- `occupiedWorkspaces`: show only occupied workspaces plus the active one.

The widget registry defines the complete set of valid IDs. Normalization:

1. Restores a missing `nacre` object or missing subkeys from defaults.
2. Accepts only `left`, `center`, and `right` arrays.
3. Removes unknown widget IDs.
4. Keeps the first occurrence of a duplicated widget and removes later copies.
5. Clamps numeric settings to their supported ranges.
6. Preserves valid user ordering and hidden widgets.

Normalization is used both where the shell reads the configuration and where
Bar Studio edits it. A malformed stored value therefore cannot prevent the bar
from loading, and the next staged edit heals the persisted object.

## Layout and Overflow

The center island remains screen-centered. Left and right islands anchor to
their respective screen edges. Their maximum widths stop before the center
island plus `islandGap`.

When `frame` is enabled, Nacre's `Ryoku.Blobs` group owns one
`BlobInvertedRect`, three resting `BlobRect` lobes, and every open popup. The
islands paint content only. The frame toggle removes only the outer desktop
ring; the three top lobes remain because they are the bar surface. When
disabled, each lobe still hugs its content at the screen edge without a second
painted capsule. An island with no visible widgets contributes no lobe, border,
surface, or input-mask region.

When a side island would exceed its available width:

1. Active-window text elides first.
2. Media text elides next while controls and artwork remain.
3. Other widgets keep their compact intrinsic widths.
4. The island clips only as a final guard against an invalid or extremely
   narrow monitor configuration.

The scene input mask includes the three islands and every open popup body, so
the desktop and gaps remain click-through.

## Bar Studio Editor

Bar Studio's style catalog gains Nacre. When Nacre is selected, the Sumi and
Obi editors stand down and a Nacre-specific section appears.

The editor contains:

- Full-width Left, Center, and Right lanes stacked vertically.
- A draggable card for every placed widget.
- Insertion targets before, between, and after existing cards.
- An unused-widget palette below the islands.
- Live controls for height, opacity, padding, spacing, island gap, frame
  roundness, edge melt, island size, OSD size, and occupied-only workspaces.

Each lane and the unused palette grows with its wrapping content. Widget chips
use compact typography and a capped width; labels that exceed the cap elide.
Each chip keeps a fixed Flow-owned slot and moves a visual child during a drag.
The drop cannot modify the slot's `x` or `y`, so chips cannot overlap after the
gesture completes.

The Nacre resources face uses CPU, memory, and temperature icons beside compact
numeric readings. The expanded resources popup retains its labels and controls.

A configured media widget remains visible when no MPRIS player is available.
Its compact face shows the music icon and `No music`; transport stays inactive
until a player appears. The user hides it only by moving it to the unused
palette.

A drag carries `{widgetId, sourceIsland, sourceIndex}`. Dropping into an island
removes the source occurrence and inserts the ID at the resolved target index
in one cloned configuration update. Dropping onto the palette removes the
widget from its island. Dragging from the palette inserts the unused widget.
Dropping outside a valid target performs no edit.

Bar Studio stages the entire normalized `nacre` object through
`hub.stageLive("nacre", next)`. The running shell repaints immediately. Hub Save
commits the draft; Revert restores the committed layout and appearance.

The drag model is implemented as pure JavaScript operations with tests for:

- Reordering within one island.
- Moving across islands.
- Adding from the palette.
- Removing to the palette.
- Correct insertion indices after source removal.
- Duplicate prevention.
- Invalid source, target, and widget no-ops.
- Configuration normalization and range clamping.

## Legacy Migration

No live configuration is copied from the main worktree. Nacre receives the
default layout when `shell.json` has no `nacre` key. Existing Sumi `frameBars`
and Obi settings remain untouched.

The main worktree at revision `69ca0b25` is the canonical visual and behavioral
reference. Source copied from it is placed below `barstyles/nacre/` and adapted
to the unstable branch's configuration and service interfaces. Nacre must not
depend on main at runtime or modify that worktree.

If the legacy Nacre branch is still present in this target after the folder
style works, it is removed in the same change so there is one Nacre
implementation. Removal is guarded by impact checks and shell smoke tests.

## Failure Handling

- An unknown configured widget is ignored and omitted on the next normalized
  edit.
- A widget component that fails to load logs its ID while the remaining island
  continues rendering.
- Missing service data collapses only the affected dynamic widget.
- Missing or invalid appearance values use clamped defaults.
- Popup targets that disappear close their popup and do not leave an input
  surface behind.
- Switching bar styles destroys the outgoing style's scene and popups before
  the incoming style takes ownership of the top exclusive zone.

## Verification

Implementation is complete only after:

1. JavaScript model and normalization tests pass.
2. Existing Bar Studio model tests still pass.
3. QML probing/smoke checks load Nacre, Obi, and Bar Studio without component
   errors.
4. Obi popup behavior remains unchanged.
5. Registry, Config, and Hub defaults agree.
6. Project doctor, changed-impact, and relevant delivery checks pass.
7. The `unstable-dev` worktree deploys through the repository's documented
   deploy path.
8. The live shell reports no QML or Hyprland configuration errors.
9. A live style switch to Nacre shows the same frame, lobe shapes, popup melt,
   notification toast, and default module placement as main.
10. Drag edits apply immediately, Save/Revert behave correctly, music remains
    visible while idle, and media, resources, audio, connectivity, calendar,
    notification inbox, and notification toast surfaces open on the correct
    monitor.

## Deployment

After repository verification, deploy from
`/home/nero/Work/ryoku-arch-unstable` using the normal Ryoku development deploy
command. Do not copy files from the checkout into live configuration by hand.
The current machine is already on `unstable-dev`, so deployment updates that
active system track in place. Reload or restart only the shell components
required by the documented deploy workflow, then inspect logs and active
configuration before declaring success.
