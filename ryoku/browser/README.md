# Ryoku Theme browser extension

Live-recolors Firefox and Chromium/Chrome/Brave from the Ryoku desktop palette.
Plain JavaScript, no bundler, no npm: it ships and loads as-is.

## What it does

- Connects to the native-messaging host `ryoku_theme` (built and installed
  separately) and receives `{ mode, colors }` on connect and on every palette
  change.
- Firefox: applies the palette to browser chrome live via `browser.theme.update`
  (frame, toolbar, tabs, popup, sidebar, ...). Chromium has no runtime theme API,
  so its manifest ships a fixed placeholder frame.
- Every engine: persists the last palette to `storage.local`, exposes each M3
  role to web pages as a `:root` CSS variable (`--ryoku-primary`,
  `--ryoku-surface`, `--ryoku-on-surface`, ... snake role to kebab var), and can
  optionally recolor page content when the popup toggle is on.

## Protocol

Native messaging host name: `ryoku_theme`. Standard WebExtension framing
(4-byte little-endian length + UTF-8 JSON), handled by the browser. Messages
the host pushes:

```json
{ "mode": "dark", "colors": { "primary": "#rrggbb", "surface": "#rrggbb", "...": "..." } }
```

`colors` carries the Material 3 roles (snake_case) plus `color0`..`color15`.
The extension sends `{ "type": "hello" }` on connect; the host ignores it.

## Loading

Build the two unpacked dirs, then load them:

```sh
./build.sh   # writes dist/chromium and dist/firefox, each with a plain manifest.json
```

- Chromium/Chrome/Brave: `chrome://extensions` -> Developer mode -> Load unpacked
  -> `dist/chromium`.
- Firefox: `about:debugging` -> This Firefox -> Load Temporary Add-on ->
  `dist/firefox/manifest.json` (or package it for a signed install).

The native host manifest (`~/.mozilla/native-messaging-hosts/ryoku_theme.json`
for Firefox, `~/.config/<browser>/NativeMessagingHosts/ryoku_theme.json` for
Chromium) is installed by the Ryoku doctor, not by this extension.

## Files

- `src/background.js`: native-host bridge, theme apply (Firefox), persist, broadcast.
- `src/content.js`: `:root` CSS vars always, optional guarded page recolor.
- `src/popup.html` / `src/popup.js`: the "Recolor web content" toggle.
- `manifest.chromium.json` (MV3) / `manifest.firefox.json` (MV2): per-engine manifests.
- `build.sh`: copies `src/` + the matching manifest into `dist/<engine>/`.
