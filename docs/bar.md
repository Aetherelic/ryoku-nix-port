# Frame bars

Ryoku renders one frame-bar system: four independent rails that share the
monitor's frame scene. `ryoku/shell/quickshell/pill/Bar.qml` creates a
`FrameRail` for each edge and reads the normalized `frameBars` object from
`~/.config/ryoku/shell.json`.

A rail is a thin interactive strip, not a second panel process. The monitor
overlay owns its input region and the corresponding exclusive-zone reserve, so
tiled windows clear exactly the enabled edge rails.

## Default profile

The shipped profile enables a compact top rail and a continuous left rail:

- **Top**: centred clock.
- **Left**: quick settings and workspaces at the top, dock in the centre, tray,
  network, and clock at the bottom.
- **Bottom and right**: configured but initially disabled.

Every edge has its own `enabled`, `size`, `reveal`, and three axis-appropriate
zones. Horizontal rails use `start`, `center`, and `end`; vertical rails use
`top`, `center`, and `bottom`. A zone holds its group against its own end of
the rail: a start zone hugs the leading edge, a centre zone sits on the rail's
midpoint, an end zone hugs the trailing edge. The runtime accepts only
catalogued widgets that fit the target axis.

## Styles

`frameBars.style` accepts two shared-chrome styles:

- `slate-frame`: subdued dark material, fine light outline, and a compact clock.
- `ryoku-frame`: paper material, grain, Ryoku typography, and brand accents.

Style changes materials and metrics only. It never selects a different rail,
menu, or input-routing tree. Theme colours come from `Theme` and `Palette`;
user configurations do not carry a second palette.

## Bar Studio

Open **Bar Studio** with **Super+Period**. The shortcut records the Bar Studio
section before opening the guarded Ryoku Settings process.

Bar Studio edits the essentials, and keeps them few enough that every control
works. It stages a complete immutable `frameBars` object through the normal Hub
draft and Save flow, and its edits apply to the running desktop as you make
them. It supports:

- the frame chrome the shell draws around the desktop: the draw toggle, the
  widget and window corner radii, the border width, and the window opacity;
- switching `slate-frame` and `ryoku-frame` without changing layout geometry;
- each rail's own switches: enabled, hover reveal, and thickness;
- the widgets in each rail's three zones: add a catalogued widget that fits the
  rail's axis and is not already on it, remove one, or reorder within a zone.

Every change is live on the desktop at once. Save keeps it and rebaselines;
Revert, or closing the window with unsaved edits, walks the desktop back to the
saved state through the same channel. Bar Studio never writes configuration
files directly.

The bounded menus and the `stash` and `system` frame surfaces keep whatever
values are persisted: every Bar Studio edit clones the whole `frameBars` object,
so a subtree it does not touch is never dropped. They are configured through
their defaults and the catalogue, not edited on this page.

## Menus and surfaces

A rail widget reports its owner rectangle to the monitor-local
`FrameMenuManager`. That manager owns one active surface per anchor and monitor,
combines the trigger and body mask regions, and closes a surface on Escape,
backdrop click, focus loss, or fullscreen.

`ryoku-shell bar <id>` opens a bounded catalogue entry on the active monitor.
The catalogued IDs are `quick-settings`, `clock`, `launcher`, `clipboard`,
`screenshot`, `recording`, `theme`, `wallpaper`, `weather`, `media`, `stash`,
and `system`. Unknown IDs are rejected before they reach Quickshell.

Asking for the surface that already owns an anchor closes it, so a rail button
and its command both read as one toggle. A different surface at the same anchor
replaces it safely. Escape and a click outside dismiss whatever is open; the
keyring prompt and the voice surface are daemon-owned and replace rather than
toggle.

A surface clears the rail it grows from, and it draws above the rails, so a
body never hides under rail chrome.

`ryoku-shell power`, `ryoku-shell voice`, and enabled plugin commands retain
their existing entry points and share this same manager scene.

## Extending frame bars

1. Add a catalogued widget or surface with an explicit axis/anchor contract.
2. Add the matching finite IPC route if it needs a command entry point.
3. Keep menu body work gated by its `open` state and release it on close.
4. Preserve owner rectangles, mask regions, monitor locality, and identity-safe
   close behavior.
5. Add the behavior test and Bar Studio label before exposing the new ID.

Do not introduce a parallel renderer, unbounded component loader, or direct
configuration writer.
