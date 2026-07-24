# The frame

The frame is the rounded border around each display and the shared material for
surfaces that deliberately grow from a screen edge. It lives in the shell
overlay at `ryoku/shell/quickshell/pill/shell.qml`.

Atoll is drawn above that material as independent floating islands. The frame
does not swell into an old bar band, and retired bar popups no longer allocate
blob bodies. The power/session menu is the only bar-owned popup.

## Blob field

The merge is real geometry, not stacked translucent rectangles. The
`Ryoku.Blobs` QML plugin is a packaged C++ scene-graph item and signed-distance
field shader:

- `BlobGroup` owns one field, fill, outline, smoothing and shadow.
- `BlobShape` is the positioned base shape and exposes its deformation matrix
  for content that needs to move with a springing body.
- `BlobInvertedRect` cuts the desktop-sized hole whose remainder is the frame.
  Each edge has an independent border thickness.
- `BlobRect` adds a rounded body with per-corner radii, sibling exclusions and a
  velocity spring.
- `BlobMaterial` combines up to 16 shapes with a smooth minimum so overlapping
  shapes become one silhouette.

The plugin ships in `ryoku-blobs`; installed systems do not build it. The shell
launcher supplies the QML import path used by supervised Quickshell processes.

## Per-monitor scene

Each monitor overlay contains:

- one `BlobGroup` using the wallpaper-derived surface or
  `Config.surfaceColor`;
- one oversized `BlobInvertedRect`; its outer edge clips off-screen and its
  inner edge forms the visible frame;
- the Atoll bar, drawn above the field;
- active service, plugin and power surfaces that intentionally use the field;
- the recording HUD and full-screen grain layer.

The frame retracts while a workspace is fullscreen. Turning
`Config.frameEnabled` off collapses the oversized border thickness so the ring
and its shadow disappear, while Atoll continues to float at its configured
edge. The saved frame border remains available when the frame is enabled again.

## Popout machinery

`quickshell/pill/popouts/Popout.qml` wraps a `BlobRect`, content slot and reveal
clip. `edge` selects the frame side. `alongCenter` places the body at its owner,
and negative values fall back to the configured alignment. `openW` and `openH`
follow the content's implicit size.

The corners touching the frame become square and a short neck reaches into the
border field. The open animation reveals fixed-size content from the edge rather
than reflowing it. A closed body shrinks back into the border and stops any live
work gated by the content's `open` flag.

The current scene has these intentional surfaces:

- `PowerPanel` is the only bar-owned popup. Super+Escape and the Atoll power
  button select the same `power` state.
- Voice and keyring prompts are service-driven overlays, not bar module
  popups. They open only through their dedicated daemon path.
- `PluginPopouts` hosts enabled third-party plugins whose manifest chooses the
  frame popout placement.
- The left and right sidebar bodies stay mounted with `active: false` so their
  content and state remain available for the later UI rebuild.

Calendar, media, mixer, network, Bluetooth, battery, resources, clipboard,
weather, workspaces and notifications no longer have bar popout wrappers.

## Input and focus

The full-screen overlay normally exposes only a region containing the Atoll
strip, active surface masks and the recording HUD. Everything else clicks
through to applications.

Power and plugin surfaces use `HyprlandFocusGrab` for click-away dismissal.
Keyboard service surfaces temporarily make the overlay modal, request exclusive
keyboard focus and restore application focus after they close. Voice remains
focus-passive so dictated text reaches the already focused application.

The popup state records the owning monitor before the surface name. This avoids
moving an already-open body to a new monitor before it closes. Fullscreen on the
owning monitor clears the popup.

## Preserved sidebars

`SidebarFeatures.qml` still contains the left Stash board and its pane state.
`SidebarSystem.qml` still contains notifications, calendar, media, weather and
recording panes plus their shared control logic. Both are instantiated in
`shell.qml`, but their `Popout` hosts are inactive.

There are no corner hit regions, hover timers, edge gestures, keybinds, daemon
commands or pill IPC functions that can open either sidebar. The Hub exposes
only the pane ordering and width needed to preserve that content. It does not
show the removed enable, hover or corner controls.

## Extending the frame

A new frame surface is a behavior change, not a styling shortcut. Keep the
following contract together in one change:

1. Add one transparent content component with explicit implicit dimensions.
2. Add one `Popout` in the monitor's shared `BlobGroup`.
3. Add the body's mask regions so it receives input only while visible.
4. Add a deliberate command or control route and focused-monitor behavior.
5. Gate scanners, polling and other live work on the surface's open state.
6. Document why the surface belongs on the frame rather than in a normal
   application window.

Do not restore one of the deleted generic bar popups or create a second blob
scene for a surface that must visually fuse with the frame.
