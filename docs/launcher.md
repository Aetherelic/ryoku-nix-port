# The launcher

The launcher is Ryoku's app picker and command palette, opened with
`Super + Space`. Its resting face is the hero image itself: time, weather, a
fine search line, and four small scope keys sit directly over the art. There is
no floating search capsule and no empty result panel waiting below it.

Typing works like opening a camera shutter. The 250 px hero compresses to
126 px while a dark result drawer grows from its lower edge. The selected
result takes one dense 82 px lead row; more matches continue as 44 px ledger
rows. Clearing the query or pressing `Esc` closes the drawer and gives the image
its room back. The drawer reserves that same compact deck as soon as typing
starts, so late provider replies fill cells instead of resizing the card.

The launcher runs from `ryoku/shell/quickshell/launcher/` as a warm Quickshell
component supervised by `ryoku-shell`. `ryoku-shell launcher` toggles it on the
focused output.

## Rest, search, and scopes

At rest:

- start typing for a federated search;
- press or click `ALL` to browse applications;
- use `IMG` or `FILE` for a focused filesystem search;
- use `REC` for freedesktop recent files;
- press `Ctrl+A` as the keyboard route to `ALL`;
- press `F1` for the built-in reference.

The scope is sticky while typing. `ALL` never leaks file or window results into
an app browse; `IMG` and `FILE` keep the visible query clean instead of adding a
synthetic prefix. Pressing the active scope again only returns focus to the
query. `Esc` walks back one stage at a time: input-method preedit, expanded
options, the current search/scope, then the launcher.

Prefixes remain available for commands that do not need a permanent hero key:

| Input | Scope |
|---|---|
| `/` | system actions, with categories across the drawer |
| `/file`, `/folder`, `/image`, `/video` | a specific filesystem kind |
| `>install`, `>remove`, `>search` | packages |
| `=` or a numeric expression | calculator |
| `?` | web search and instant answer |
| `@` | radio search and playback |
| `\` | one terse Rashin answer |

Unprefixed text searches the default providers together. The selected result
stays attached to its stable provider/result identity when an asynchronous
provider inserts, removes, or reorders rows.

Each edited query begins at result `01`. Arrow keys move the visible two-column
ledger (`Left`/`Right` across a row, `Up`/`Down` by a row); the selected cell
keeps a raised material plate, bright outline, and thicker provider rail in
place. The lead mirrors that exact cell without pulling it out of the ledger,
so keyboard movement never causes the remaining rows to reshuffle.

## Primary actions and expanded app options

`Enter` always runs the selected result's primary action. For an application,
that primary action is **Launch**.

Some `.desktop` files also advertise named Desktop Actions: for example,
**New Window**, **New Incognito Window**, **Compose**, or **Open Profile**.
Those real actions become the app's expanded options. Ryoku preserves their
declared names and order; it does not invent options, repeat **Launch**, or
promote a malformed action. An action with no usable ID, a duplicate ID, or a
disabled/unexecutable entry is not counted.

Press `Ctrl+K` on the selected result to open its options. The drawer only
spends space that the selected app has earned:

| Usable extra options | Layout |
|---:|---|
| 0 | Nothing opens. There is no marker, blank shelf, or reserved gap; `Ctrl+K` is a no-op. |
| 1 | One full-width 38 px row. |
| 2–3 | One 38 px row, split into equal cells. |
| 4–6 | Two cells per row; an odd final option spans the full row. |
| 7+ | The shelf shows at most three rows (114 px) and scrolls, with a visible range counter. |

This means apps without Desktop Actions remain the compact 82 px lead plus the
following ledger, never a large icon floating in empty space. Apps with actions
expand immediately below that same lead row, so the options still read as part
of the selected app.

While the shelf is open:

- `Tab` and `Shift+Tab` walk options in declaration order;
- the arrow keys move through the packed rows;
- `Enter` runs the focused option;
- `Esc` closes only the shelf;
- typing edits the query and closes the now-stale shelf;
- hovering an option is visual only; clicking runs that exact option.

The real query field keeps keyboard focus throughout. If the desktop-entry
model changes while the shelf is open, an app update adds, removes, or reorders
its actions, the action signature changes and the shelf closes instead of
executing a stale target.

### Open-window rail

When the selected result is an app with matching Hyprland windows, a separate
bottom layer-surface appears below the launcher. It is intentionally detached
by a deep gap and local shadow; each window is its own static card with an app
icon, title, and workspace cue. There is no screencopy or periodic preview
refresh: Hyprland's toplevel events update the set directly. The rail is an
earned surface: it does not exist for apps with no open windows and never
covers the hero image.

`Enter` always keeps its default meaning: it launches a new instance of the
selected application. Press `Tab` or `Shift+Tab` to explicitly enter the window
rail; its header and the lead row then change to **WINDOW FOCUS**. `Left` and
`Right` move the bright focus frame between window cards, and `Enter` switches
to the framed window. Press `Tab` again to return to the result deck without
leaving the query field. The selected address is kept stable while results
refresh, so typing does not make the keyboard cursor jump to a different open
window. While the launcher is active,
Ryoku temporarily freezes pointer-driven Hyprland focus and restores the
user’s exact setting after close; moving the pointer outside the card can never
take typing away. The rail caps at six cards; when more windows match, the
horizontal strip scrolls without changing the result selection.

When an application match owns an open-window rail, its matching `Window`
provider rows are deliberately omitted from the app deck. Existing windows
therefore have one home, the detached rail, while a query that finds only a window
still presents that direct **Focus** result normally.

The same result contract serves every provider:

```text
result:
  stable provider-local id
  title, subtitle, icon, type, score
  actions[0]                 primary
  actions[1...]              optional secondary actions
```

The dispatcher validates the primary action first. A result whose primary is
missing, disabled, or not executable remains informational and cannot smuggle a
later secondary action into the primary slot.

## Surface and motion

The launcher is a card-sized layer surface, not a transparent fullscreen
window. Its Wayland input region follows the transformed card itself; the thick
shadow is visual only. Windows and pointer input outside the card remain
untouched.

Opening runs through five lifecycle states:

1. `Closed`: no mapped launcher surface.
2. `Prelude`: map a transparent card-sized buffer, acquire focus, wait two
   render ticks, and attempt the local desktop capture for at most 50 ms.
3. `Opening`: present the card over 210 ms.
4. `Open`: grow the outer surface before revealing a larger drawer; on shrink,
   clip and animate the visible card before contracting the surface.
5. `Closing`: fade and translate for 160 ms, present two transparent ticks (or
   take the 50 ms fallback), then release focus and unmap.

A show during `Closing` reverses the same generation instead of unmapping and
remapping. Moving invocation to another monitor closes the first output before
mapping the next, so two launchers never overlap.

The card carries two shadows inside a reserved transparent envelope: a hard
down-right contact step and a broad dark falloff. The envelope is excluded from
the input mask and sized for the full motion path, preventing either shadow from
being clipped.

## Local frost

`bgBlur` now controls only a frozen crop behind the result drawer. During
Prelude the launcher takes one cursor-free screenshot of the active output,
freezes the future drawer region plus kernel bleed, and applies one local
`MultiEffect`. The near-black drawer covers that texture at 94%, so the default
2 px value reads as a slight material tooth rather than frosted glass.

There is no compositor-wide blur mutation, fullscreen scrim, or grain layer.
The resting hero creates no blur effect at all. Disabled blur, reduced motion,
low-power policy, capture failure, or the 50 ms deadline all choose the same
solid drawer instead of delaying or flashing the launcher.

`ryoku doctor` performs a one-time migration for existing configs: an untouched
old `bgBlur: 12` default becomes the new local `2`; every other value is
preserved. A marker then makes any later deliberate value, including 12, final.

## Providers

Providers live under `providers/<name>/` and register with the shared
`Dispatcher`. Only one provider tree exists for every output surface, so model
ownership and in-flight requests do not split when focus moves between
monitors.

| Provider | How it appears | What it does |
|---|---|---|
| apps | federated, `ALL` | launch desktop apps, fuzzy and frequency ranked; expose real Desktop Actions |
| windows | federated | focus an existing Hyprland window |
| snippets | federated | expand snippets and quicklinks |
| calc | numeric fallback, `=` | qalc math, units, and currency |
| actions | `/` | lock, wallpaper, screenshot, night light, media, settings |
| find | `IMG`, `FILE`, `/file` and kind prefixes | asynchronous `fd` search, open or reveal |
| recent | `REC` | parse `recently-used.xbel`, discard missing paths, open or reveal |
| packages | `>` commands | search/install/remove through GPK |
| web | `?` | web search, bangs, and an inline DuckDuckGo answer |
| mpris | matching search text | searchable tracks and player controls, never a rest-screen media card |
| radio | `@` | find, play, or stop a stream |
| script | script keyword | rofi-script/fuzzel-compatible custom commands |
| rashin | `\` | ask the local agent and act on detected paths, links, commands, or colours |

`REC` reads the standard XBEL history only. It validates paths asynchronously,
does not crawl the home directory, and displays nothing for missing or malformed
history.

Each shell-backed provider owns a generation token and busy state across both
its debounce and process lifetime. Late output from an old query cannot replace
the current results, and an empty drawer waits for the active provider to settle
before saying there are no matches.

Web fallback rows use a dedicated question-mark search tile rather than an app
icon, making **Search** visibly different from **Launch** or **Open**. Image
finder rows carry a local file preview into both the lead and ledger; ordinary
files keep the compact icon treatment, so preview loading never changes row
geometry.

## Hero image and colour

The launcher and Ryoku Hub share `Ryoku.Ui.HeroCrop`. The Hub's App Launcher
page is the only editor: choose an image, drag its focal point in the preview,
set its strength, and save. The live hero uses the same cover-crop math, so wide,
portrait, and off-centre images land exactly where the preview put them. A
missing or unreadable path falls back to the shipped art.

With **Match wallpaper** enabled, the drawer, lead, frame, provider rails, and
selection roles resolve from the live Wallust/Material palette. The selected
lead computes a readable foreground with a 4.5:1 minimum contrast instead of
assuming that every wallpaper produces a dark accent. The sun/moon marker stays
semantic rather than changing identity with the accent.

## Extending it

- **Scripts:** add `{ keyword, name, exec }` entries to
  `~/.config/ryoku/launcher-scripts.json`.
- **Snippets and quicklinks:** use
  `~/.config/ryoku/launcher-snippets.json` and
  `~/.config/ryoku/launcher-quicklinks.json`.
- **A native provider:** add one component under `providers/<name>/`, implement
  the `Provider` result/action contract, and instantiate it once in
  `providers/Providers.qml`.

Result normalization, identity, action packing, selection reconciliation,
request lifecycles, contrast, recent-file parsing, and surface transitions have
Node/Go unit coverage. Live interaction scenarios live in
`ryoku/shell/quickshell/launcher/qa/`; run the complete shell suite with:

```sh
tests/shell-unit-tests.sh
```
