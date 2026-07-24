# The bar

Ryoku ships one bar: Atoll, a row of floating islands at the top or bottom
screen edge. `ryoku/shell/quickshell/pill/Bar.qml` is the small host and
`AtollBar.qml` owns the layout. The `pill/` directory name is historical.

The bar shares the shell's full-screen transparent frame overlay. A separate
reserve window claims the chosen edge so tiled windows stop below the islands.
The overlay input mask covers the bar strip and active surfaces only; the rest
of the screen passes through to applications.

## Settings

Ryoku Settings exposes the live bar contract:

- `barEnabled` shows or hides the islands.
- `barPosition` accepts `top` or `bottom`.
- `barHeight` sets the unscaled island strip height.
- `atollVariant` selects `ilyamiro` or `ryoku`.
- `fontScale` participates in the per-monitor scale.

The shell scale is:

    monitor height / 1080 * fontScale

with `fontScale` clamped to 0.7 through 1.6. Atoll has no runtime style
selector. `ryoku doctor` removes legacy `barStyle`, style, island and
sidebar-opener keys from user-owned `shell.json`.

The two Atoll looks share layout and behavior:

- `ilyamiro` uses rounded translucent islands and the faithful mono treatment.
- `ryoku` uses compact square paper-black islands, Space Grotesk and the shell
  grain.

## Layout

The islands reveal in a short startup cascade:

- Left: launcher, Ryoku Settings and power; workspace controls; now-playing
  when a player is present.
- Center: the clock, date and current weather.
- Right: system tray when populated; network, Bluetooth, volume, battery and
  notification status.

`AtollWorkspaces.qml` owns workspace switching. `BarMedia.qml` and
`BarWeather.qml` are display-only readouts. `BarTray.qml` hosts StatusNotifier
items. `AtollStatus.qml` keeps connectivity, volume, battery, notification and
do-not-disturb state visible without opening panels.

The bar strip itself accepts the mouse wheel for volume. Volume and brightness
changes are narrated by the standalone bottom-center OSD rather than a bar
popup.

## Popups

The power/session menu is the only bar-owned popup. Super+Escape opens it
through `ryoku-shell power`; the Atoll power icon requests the same surface at
its island center. `shell.qml` owns the `Popout` and its input mask, while
`PowerPanel.qml` owns the actions.

Calendar, media, mixer, network, Bluetooth, battery, resource, clipboard,
weather, workspace and notification bar popups are gone. Atoll status items
stay visible but inert where their old click would have opened one.

The left stash/sidebar and right system/sidebar bodies remain mounted for a
future UI, but no corner, edge, hover, keybind or IPC route opens them.

## Sizing and motion

`barBandBase` is `barHeight + 18` before monitor scaling. Each island derives
its height from that band and keeps a small edge inset and gap. The startup
reveal changes only translation and opacity; media and tray islands collapse to
zero width when absent.

The center clock remains anchored independently of the left and right groups.
Media width is capped against the center island so a long title elides rather
than crossing the clock.

## Changing the bar

- Keep layout work in `AtollBar.qml`; `Bar.qml` remains a host.
- Put a reusable readout in its own component and size it from `s` and the
  island height.
- Do not add a `barStyle` branch or restore a retired renderer.
- A status item that has no custom surface stays display-only. Do not wire it
  to a generic old popup.
- If a new surface is intentionally introduced, add its command route, popout,
  mask region and focused-monitor behavior together, then document the new
  contract here.
