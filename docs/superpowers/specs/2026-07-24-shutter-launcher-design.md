# Ryoku Shutter launcher

Status: visual direction approved 2026-07-24; awaiting written-spec review.
Scope label: `[ryoku]`.

## Outcome

Replace the current full-screen command-palette overlay with a compact,
image-led launcher that feels like a native part of the Hyprland desktop.

The launcher opens as the Hub-selected hero image. Search is a quiet line of
type directly on the image, not a floating search capsule. Typing compresses
the hero and unfolds a dense result drawer below it. The selected result is a
70px full-width Material lead band; the remaining results form a compact
two-column ledger. Additional actions earn additional height only when the
provider supplies real additional actions.

The desktop outside the launcher never dims, blurs, flashes, or intercepts a
click. A thick dark contact shadow makes the small surface read above the
windows beneath it.

## Design invariants

1. **The resting face is the image.** No result list, greeting card, media card,
   Bluetooth bubble, logo, or conventional search box appears below it at rest.
2. **No monitor-sized launcher surface.** The Wayland surface is only the
   launcher plus its shadow envelope. It has no full-screen scrim, grain, blur
   plane, or click-catcher.
3. **No global visual mutation.** Opening the launcher never rewrites
   Hyprland's global blur size, blur enabled state, dim strength, or animation
   settings.
4. **The Hub remains the editor.** The existing App Launcher page remains the
   only place to choose, drag, and tune the hero. The launcher reads the same
   source, focal point, strength, radius, greeting, and weather values.
5. **Space is earned by content.** An app with no secondary action remains
   compact. One secondary action reveals one control. Multiple actions reveal
   exactly those controls. There are no placeholder cells.
6. **The default action stays direct.** Enter always invokes the selected
   result's primary action. Opening the secondary-action shelf never becomes a
   prerequisite for launching.
7. **Provider truth wins.** The launcher does not invent “Private,” “Pin,”
   “New instance,” or workspace actions. It shows those only when an actual
   provider or `.desktop` file supplies them.
8. **Motion explains state.** Opening establishes depth, the hero shutter
   reveals results, and the selected lead expands to reveal actions. Results do
   not perform decorative motion on every keystroke.

## Surface and depth

The launcher instantiates one card-sized `PanelWindow` per screen, but only the
invocation output may map or own focus. Every other output stays unmapped with
an empty input region. At 1080p the base content width is 720px, capped to the
available output width minus 32px. A transparent envelope adds enough room for
the shadow without increasing the input region. The card is horizontally
centered and anchored at a stable upper-middle position; its top does not move
as the drawer grows downward.

The surface must explicitly support alpha. Its input mask covers the visible
card, not the transparent shadow padding. A `HyprlandFocusGrab` owns click-away
dismissal, so no invisible monitor-sized `MouseArea` is needed. Keyboard focus
is requested only while the card is shown and is released when the exit motion
finishes.

The resident shell preloads the chosen hero and shipped fallback while hidden.
Before `visible` becomes true it has already set the final width, rest height,
transparent clear colour, non-opaque surface format, input mask, top-only
layer-shell anchor, and card background. All-edge anchors and output-sized
startup geometry are forbidden.

On show, it maps that prepared card-sized surface at zero visual opacity,
activates the focus grab, and focuses the real `TextInput` immediately. This
transparent Prelude accepts and buffers printable input, but it contributes no
visible pixel and never grows to output size. The first `FrameAnimation` tick
requests a transparent repaint; the second confirms that the Qt render loop
advanced. The visual entrance begins when both that two-tick rule and the
frost-ready/deadline rule below have completed. If input arrived during
Prelude, the entrance targets the resulting Query or scoped-mode geometry
directly instead of flashing through Rest.

This is an implementable render-cycle rule, not a claim that Qt exposes a
Wayland presentation acknowledgement. The surface never exposes an opaque Qt
default background or an undecoded image. On close, content and clear colour
become transparent, the same two-tick render-cycle rule runs, and the surface
then unmaps and releases focus. A bounded 50ms fallback prevents a stalled
render loop from hanging the surface. Frame-by-frame live QA remains the
acceptance check for both edges of the lifecycle. A cold image that is not
ready uses the already-decoded fallback for that opening and may replace it
only after a completed decode, never with a blank intermediate frame.

Window height tracks the current transition's required card height plus shadow
padding. It is never a fixed maximum-height or output-height envelope. Before
every grow transition, the outer surface synchronously resizes to the target
height plus shadow padding while the added area is transparent. One Qt render
tick later, the visible card and its input mask animate into that space. For a
shrink, the card and mask animate first inside the existing outer surface; one
render tick after they reach the smaller bounds, the outer surface shrinks.
This ordering applies to drawer and action-shelf growth so content and the
falloff shadow cannot clip.

The silhouette uses one long and one short corner in alternation. The long
corners read `LauncherConfig.radius`; the short corners are
`max(2px, radius * 0.18)`. This keeps the approved asymmetric shape while
honouring the existing Hub control.

Depth comes from:

- a 1px high-contrast frame;
- a hard black contact step around 8px down and right;
- a broad black falloff around 28-44px below the card;
- a nearly opaque dark drawer surface;
- at most a very small card-local frost.

There is no glow, per-result shadow, or grain layer.

### Card-local frost

`bgBlur` remains the stored compatibility key, but the Hub presents it as
**Local frost** rather than a global desktop blur radius. `0` is fully sharp.
The value remains an approximate pixel radius: `2` requests an approximately
2px local kernel. The target default and this machine's target are `2`, a
barely visible effect.

The effect is a frozen opening snapshot, captured during the fully transparent
Prelude before any hero, shadow, or drawer pixel is visible:

1. Invocation maps only the zero-alpha, card-sized Prelude, acquires keyboard
   focus, and requests one cursor-free frame from the active output.
2. The visual entrance waits for `hasContent` or a strict 50ms deadline. On
   timeout, it starts immediately with a solid drawer and ignores any late
   frame for that session.
3. Retain only the crop behind the drawer's maximum possible bounds.
4. Feed that single texture through one `MultiEffect`.
5. Clip it to the currently visible drawer and cover it with the near-black
   surface.
6. Retain it until the surface fully unmaps, then discard it.

Because the mapped Prelude composites as zero alpha, the frame contains only
the desktop behind the future card; it cannot self-capture launcher content.
The maximum visual-open delay is 50ms, while keyboard input is owned from the
start of Prelude. Every request carries an invocation generation ID, so
timeout, completed close, monitor change, and a new Closed-to-Prelude
invocation invalidate older frames. An open-close-open reversal that occurs
before unmap stays in the same invocation and reuses its existing snapshot or
solid fallback; it does not capture a mapped hero. Once Closed is reached, a
later open starts a fresh capture. The capture is never written to disk and is
not live, avoiding recursive capture and continuous GPU work. Low-power mode,
reduced motion, `bgBlur: 0`, or an unavailable screencopy protocol skips the
request and starts the visual entrance as soon as the two-tick Prelude rule
completes.

## Visual language

The launcher bridges Ryoku's printed/TUI language and Material colour rather
than choosing one:

- **Space Grotesk** carries application names and readable interface copy.
- **Space Mono** carries the query, provider labels, key hints, paths, counts,
  and indices.
- One-pixel rules, rank numbers, and narrow provider rails provide the blocky
  instrument structure.
- Application icons keep their native colour.
- The selected lead band uses the current Appearance palette. With Material
  You or wallpaper matching enabled, it uses the generated Material container
  role. With the default Ryoku palette, selection uses the shared bone/ink and
  restrained signature colour. There is no launcher-only theme toggle.
- Provider rail colours come from shared palette roles and are used only as
  small routing marks, not as arbitrary rainbow cards.

Implementation uses `Ryoku.Ui` tokens. It does not create another hardcoded
launcher palette. There is no Ryoku logo or copied Narsell branding.

## Hero and Hub contract

The resting hero is 250px high at the 1080p base scale. Its image uses the
existing `heroImage`, `heroPosX`, `heroPosY`, and `heroStrength` values. Empty
`heroImage` continues to use the shipped fallback art.

The launcher and the Hub preview share one read-only cover/focal renderer. The
Hub keeps its existing selector, contact sheet, folder picker, drag gesture,
and save flow; its drag wrapper writes the focal values. The launcher uses the
same renderer without editing gestures. This prevents the saved preview and
the launched crop from drifting apart.

The current solar-horizon animation survives as a subtle bottom layer on the
hero. Its wave drift and sun/moon position run only while the launcher is
visible. `showGreeting` controls a small tracked greeting in the lower-left
metadata line. `showWeather` controls the compact weather readout on the right.
Neither creates another card.

At the image centre:

- a quiet search glyph;
- `TYPE TO SEARCH` or the typed query;
- one hairline directly under the type;
- four independent dark mode keys: `ALL`, `IMG`, `FILE`, `REC`.

There is no background rectangle, blur capsule, or opaque bar behind this
search line. A restrained image vignette and text shadow provide contrast
without hiding the art.

## Launcher states

| State | Hero | Drawer | Selection |
|---|---:|---:|---|
| Closed | Unmapped | Unmapped | Reset |
| Prelude | Transparent | Hidden | Buffered from input |
| Rest | 250px | Hidden | None |
| Query | 126px | Results | First valid result |
| Browse all | 126px | Alphabetical apps | First app |
| Images/files | 126px | Scoped results or prompt | First valid result |
| Recent | 126px | Recent files | First valid result |
| Actions | 126px | Results plus earned action shelf | Pinned by result key |
| Help/special provider | 126px | Provider-specific body | Provider-defined |

Printable input is accepted immediately at rest even though the input has no
box. The real `TextInput` remains accessible to input methods and assistive
technology.

### Mode keys

- At image-only rest, printable input starts the default federated search.
- `ALL` is the dedicated all-apps control. Activating it with an empty query
  unfolds the full alphabetical app browser. Typing while this browser is open
  searches apps only; clearing the query returns to the alphabetical browser.
  Escape leaves Browse All and returns to image-only rest, where typing is
  federated again.
- `IMG` enters image mode and returns focus to the query.
- `FILE` enters file mode and returns focus to the query.
- `REC` opens standard recent files immediately; typing filters that set.

`ALL`, `IMG`, `FILE`, and `REC` remain visibly active until Escape returns to
rest or another mode is chosen. The rest state itself has no active provider
button, even though all four controls remain visible.

Clicking `IMG` or `FILE` changes internal mode state; it does not inject
`/image` or `/file` text into the visible query. The existing typed prefixes
remain valid and resolve to the same scoped state, but text a user explicitly
types remains visible. Clearing a default federated query returns to Rest.
Clearing an ALL filter returns to the alphabetical app browser. Clearing an
IMG or FILE query keeps the compressed hero and shows that mode's prompt.
Clearing a REC filter restores the unfiltered recent rows.

Mode and prefix precedence is explicit:

- Activating a mode key always wins at that moment. It removes a recognized
  leading provider-prefix token, preserves the payload text after that token,
  and reparses the payload as the new mode's filter. Without a prefix, it
  preserves the visible query unchanged.
- Activating the already-active key only refocuses the query; it does not clear
  or toggle the mode.
- Normal text in ALL, IMG, FILE, or REC remains scoped to that mode. Typing a
  complete recognized provider prefix intentionally exits the button mode,
  leaves the explicitly typed prefix visible, and opens that provider's body.
  No mode key remains active.
- Switching from one mode key to another follows the same payload-preserving
  rule. Escape is the operation that clears the filter and returns to Rest.

The existing explicit provider prefixes remain available: actions, calculator,
packages, web/instant answers, radio, Rashin, folders, video, snippets,
quicklinks, scripts, windows, and media. Their special bodies occupy the same
drawer and inherit the new frame and motion. `F1` opens the keyboard/provider
reference because the resting face has no dedicated help button.

Recent files come from the standard
`~/.local/share/recently-used.xbel` store. The provider sorts by modification
time, excludes missing local paths, decodes file URLs, and returns at most 40
rows. A row's primary action opens it; its one secondary action reveals its
containing folder. A missing, malformed, or empty store produces a compact
`NO RECENT FILES` state rather than an error surface.

## Result density

The selected result is always one 70px lead band across the full drawer. It
contains:

- a 36-40px native icon when present;
- title and subtitle;
- a compact type/provider or path readout;
- the primary verb and Enter hint;
- a `+N MORE · CTRL+K` hint only when secondary actions exist.

The band has no fixed empty metadata cells. Missing icon, subtitle, metadata,
or secondary actions collapse their own slots.

The next results form a two-column ledger of approximately 40px rows. Each row
uses a small icon, title, short type/path label, rank, and a 2px provider rail.
Rows have hairline separation rather than individual rounded cards. The
viewport normally shows the lead plus six ledger matches; additional matches
scroll.

Result rank remains the data model. Changing selection crossfades the lead
content while the ledger retains rank order. The currently selected result is
omitted from its ledger slot, and its former selection returns to its ranked
slot. Keyboard navigation is defined over the stable ranked model, not over
the temporarily promoted visual positions.

Async provider updates preserve the selected result by its composite result
key whenever it still exists. They never silently replace an open action shelf
with another result's actions.

## Primary and expanded actions

### Provider contract

The dispatcher formalizes and normalizes the existing result shape:

```text
{
  id, providerId, title, subtitle, icon, type, score,
  actions: [{ id, name, icon, execute, enabled?, closeOnExecute? }]
}
```

The provider-local `id` is required and stable for the life of the underlying
result. `providerId` is attached by the dispatcher. The dispatcher forms a
collision-safe composite `resultKey` from both values; selection, pinning, and
exported QA state always use that key, never a provider-local ID alone. Apps,
actions, calculator, find, MPRIS, packages, radio, scripts,
snippets/quicklinks, web, and windows must all pass stable-ID contract tests.
Missing `actions` normalizes to an empty array. Primary validation always
examines raw slot zero before any filtering: a missing ID, non-callable
`execute`, `enabled: false`, or malformed primary makes the whole row
informational and disabled. Its secondaries are unavailable, and a later valid
secondary is never promoted to primary. Only `actions.slice(1)` is then
normalized and filtered for the shelf.

Every action also has a stable provider-supplied `id` unique within its result.
The app adapter uses `launch` for the primary action and the
`DesktopAction.id` for each declared action; other providers use stable
semantic IDs such as `open`, `reveal`, `copy`, `next`, or `previous`. Display
names are never used as identity.

`actions[0]` is the primary action. Enter invokes it. Displayable secondary
actions are:

```text
actions.slice(1).filter(action =>
    action && action.id is nonempty &&
    action.execute is callable && action.enabled !== false)
```

`enabled` defaults to true. Disabled and unsupported actions are not rendered,
counted in `+N`, or focusable. Providers must mark unavailable MPRIS transport
actions disabled instead of advertising a no-op. If filtering leaves no
secondary action, the result follows the zero-action case.

`closeOnExecute` defaults to true, preserving current behaviour for launch,
open, copy, focus, package, system, and script actions. A provider that needs an
in-launcher follow-up may explicitly set it false. A synchronous execution
exception keeps the launcher open and replaces the footer hint with a compact
error; successful asynchronous completion is not inferred.

The secondary shelf never repeats `actions[0]`. It renders names first and an
icon only when the provider supplies one, so a missing icon does not reserve a
blank square.

### Progressive geometry

| Real secondary actions | Ctrl+K and geometry | Example |
|---:|---|---|
| 0 | No expansion affordance; Ctrl+K is a true no-op | Kitty, calculator, package, web search |
| 1 | Attach one 38px full-width action row | Nautilus/Zed desktop action, file `Reveal` |
| 2-3 | Use one 38px row with two or three equal-width actions | Chromium, Thunar, MPRIS transport |
| 4+ | Pack two actions per 38px row; an odd final action spans the full row | Future provider or unusually rich desktop entry |

The action shelf is part of drawer layout. It pushes or reduces the visible
ledger viewport and never overlays another row. Its height is computed from
the actual action delegates. The shelf shows at most three action rows
(114px plus hairlines). Seven or more actions scroll inside that explicit
viewport and show `1-6 / N`; the result ledger is a sibling viewport, not a
parent Flickable, so wheel and keyboard input have one unambiguous owner. One,
three, five, and every other odd action count leave no blank cell.
The overflow readout follows the visible action range as the shelf scrolls,
such as `3-7 / 7` when its final three rows are visible.

Applications append Quickshell's real `DesktopEntry.actions` after the primary
`Launch` action, preserving declaration order. A `.desktop` action invokes
`DesktopAction.execute()`. Its raw `Exec` string is never executed manually.
Any app action also bumps the app's frecency. The adapter rebuilds its action
closures when `DesktopEntries.applicationsChanged` fires and does not retain
desktop-action objects across an application-model revision.

Examples from this live machine establish the required cases:

- Kitty has no declared desktop actions and remains a 70px lead.
- Zed, Nautilus, and Inkscape each expose one additional action.
- Chromium exposes `New Window` and `New Incognito Window`.
- Thunar exposes `Home`, `Computer`, and `Trash`.

These names are examples of provider data, not strings hardcoded into the
launcher.

The same contract applies outside apps:

- files/images/folders/videos: `Open` is primary; `Reveal` is secondary;
- MPRIS: `Play/Pause` is primary; supported `Next` and `Previous` are
  secondary;
- providers with only `Run`, `Copy`, `Search`, `Focus`, `Install`, `Select`,
  or `Tune in` stay compact;
- a result with no executable primary action is informational, appears
  disabled, and does not close on Enter.

### Action input

- `Ctrl+K` opens or closes secondary actions only when one exists.
- With no displayable secondary action, `Ctrl+K` performs no state change,
  focus change, animation, sound, pulse, or hint.
- Opening the shelf focuses the first displayable secondary action. The
  primary lead action is not part of shelf focus.
- `Tab` and `Shift+Tab` move linearly through displayable secondary actions and
  wrap between the first and last.
- Left and Right move within the current visual row without wrapping. Up and
  Down move to the nearest column in the adjacent row and stop at the first or
  last row. A full-width odd final cell is the destination from either column;
  moving back up returns to the source column.
- For seven or more actions, changing action focus scrolls the shelf just
  enough to keep the focused control fully visible. Wheel input scrolls the
  shelf only while the pointer is over it; otherwise it scrolls the ledger.
- Enter invokes the focused secondary action, then closes only when its
  `closeOnExecute` policy requests it.
- Escape or closing `Ctrl+K` collapses the shelf, returns focus to the query,
  and preserves query and selected result.
- Typing collapses the shelf and resumes query input.
- Pointer selection of another result collapses the shelf before changing the
  pinned result.

The active result is pinned by `resultKey`, not index, and action focus is
pinned by action ID. If the ordered displayable action-ID list changes while a
shelf is open, the shelf collapses before the updated list can receive input.
If only callbacks or labels refresh while IDs and order remain unchanged, focus
stays on the same action ID and Enter invokes the newest callback. All-apps
browse and ranked search each resolve Ctrl+K against their own active
selection, never a hidden list.

### Escape ladder

An active input-method preedit consumes Escape first and cancels only the
preedit. Otherwise Escape is deterministic:

1. Actions collapses to its parent state and returns focus to the query.
2. Query clears the federated query and returns to image-only Rest.
3. Browse All, IMG, FILE, and REC clear their filter, exit their mode, and
   return to image-only Rest.
4. Help or any special-provider body clears its prefix/query and returns to
   image-only Rest.
5. Rest starts the close animation. Prelude cancels its capture and unmaps
   through the transparent two-tick close rule without playing a visible exit.
   Closed ignores Escape.

Pointer click-away and a second launcher-toggle request close directly from
any open state rather than walking this ladder.

Quickshell 0.3 currently ignores `Terminal=true` and some desktop field codes
when executing entries and actions. The launcher uses the supported
`execute()` API and does not promise context-dependent file/URL action
substitution that Quickshell itself does not provide.

## Motion

Motion uses purpose-specific states and transitions:

- **Open:** 210ms, opacity 0 to 1, translate up 13px, scale 0.965 to 1.
- **Close:** 160ms, opacity 1 to 0, translate down 8px, scale 1 to 0.985; unmap
  after the two-tick Qt render-cycle rule or its 50ms availability fallback.
- **First query:** hero 250px to 126px over 360ms while the drawer reveals from
  its top edge over 280ms.
- **Clear default query:** an empty default-federated query reverses to Rest;
  the drawer finishes clipping before the hero fully settles. Clearing an ALL,
  IMG, FILE, or REC filter retains its scoped drawer geometry as described
  under Mode keys.
- **Lead selection:** 80-100ms content/colour handoff with no spring overshoot.
- **Action shelf:** 180ms height and opacity reveal.

Query evaluation and result replacement do not wait for these animations.
Rows update immediately; only the containing geometry settles. Rapid
open-close-open requests reverse the active transition rather than spawning
timers that can race.

Reduced-motion or low-power mode sets transition durations to zero, stops the
solar drift, skips the frost capture, and retains the same final geometry.

## Preserve and deliberately relocate

All existing search providers, calculator, package operations, system actions,
web answers, radio, Rashin, snippets, scripts, window switching, app frecency,
async loading, error/empty states, and command-socket QA state remain.

The current rest dashboard is deliberately decomposed:

- hero image, crop, solar horizon, time, greeting, and weather move into the
  hero shutter;
- MPRIS remains searchable but contributes nothing to the image-only resting
  face and has no separate rest card;
- detached Bluetooth bubbles are removed from the launcher silhouette; device
  state remains available in the shell's system surfaces;
- help moves to `F1`;
- all-apps moves to the `ALL` mode key.

This is required for the approved image-only resting face.

## Component boundaries

- `shell.qml`: IPC, per-screen card surface, focus grab, map/unmap lifecycle.
- `Launcher.qml`: query and mode state coordinator; no drawing details.
- `HeroShutter.qml`: hero composition, implicit input, modes, weather/solar
  metadata, rest-to-query geometry.
- shared `HeroCrop.qml`: cover crop and focal-point rendering used by Hub and
  launcher.
- `ResultDrawer.qml`: drawer clipping, body choice, and height budget.
- `LeadResult.qml`: promoted selected result.
- `ResultLedger.qml`: virtualized two-column result viewport.
- `ActionShelf.qml`: progressive secondary-action layout and navigation.
- `providers/recent/Recent.qml`: XBEL loading and recent-row production.
- app-provider adapter: default launch plus real desktop actions.

Each component owns one concern. Provider data remains independent of visual
layout, and the Hub remains independent of launcher runtime state.

## Failure and edge behaviour

- Hero load failure uses the shipped fallback without changing geometry.
- Frost capture failure uses the solid drawer.
- Missing recent-file tools/store shows the empty recent state.
- Async providers show one compact progress line in the drawer; stale results
  are not replaced by a full blank frame.
- No matches preserves the compressed hero and shows a native empty plate.
- If an expanded result disappears, collapse the shelf and select the nearest
  surviving rank.
- If an action becomes disabled or disappears while focused, the normalized
  displayable action-ID list changes and the shelf collapses.
- Surface height is capped to output work area. The ledger/action body scrolls;
  the hero and query remain fixed.

## Verification and acceptance

### Automated

- Unit-test recent XBEL parsing, URL decoding, sort order, missing-path
  filtering, and malformed input.
- Unit-test action normalization for no primary, primary only, one secondary,
  several secondary, disabled actions, missing icons, and 5+ overflow. Include
  a malformed slot-zero fixture followed by a valid secondary and assert that
  the secondary is never promoted.
- Assert exact packing for 1, 2, 3, 4, 5, 6, and 7 actions, including a
  full-width odd final cell and the three-row scroll threshold.
- Unit-test composite result-key selection across cross-provider collisions,
  async insert, reorder, and removal.
- Unit-test stable action identity across callback/label refresh and require a
  shelf collapse when the ordered displayable action-ID list changes.
- Extend launcher QA scenarios for rest, typed query, all four mode keys,
  special providers, empty/loading/error bodies, reduced motion, and action
  keyboard flow.
- Assert that Browse All typing is apps-only, clearing returns to Browse All,
  and Escape restores federated rest search.
- Add deterministic app-action fixtures rather than depending only on locally
  installed desktop files.
- Assert the exported state includes active mode, selected result key,
  secondary-action count, action focus, surface size, and transition state.

### Live machine

Use the checkout workflow in `docs/development.md`:

1. Run `ryoku/shell/dev-run.sh`.
2. Enable the session binding with `ryoku/shell/dev-binds.sh on`.
3. Exercise slow and rapid open/close cycles over bright and dark windows.
4. Poll `hyprctl layers` through startup, hot reload, opening, drawer growth,
   action growth, and closing. The active output may expose only card/shadow
   geometry; every other output must remain unmapped. No sampled frame may use
   all-edge anchors or output-sized geometry.
5. Record and inspect opening/closing frame by frame for a white/black flash,
   unblurred first frame, shadow clipping, or keyboard-focus gap.
6. Type during Prelude and verify the first character reaches the launcher,
   then test pointer click-away, Escape stages, IME input, provider prefixes,
   all action-count cases, long app names, missing icons, and 5+ actions.
7. Run `ryoku/shell/quickshell/launcher/qa/run.sh` and inspect every screenshot
   for clipping, overlap, spacing, and contrast.
8. Test at least two scale/output sizes and the reduced-motion/low-power paths.
9. Open the Hub App Launcher page, drag the hero focal point, save, and verify
   the next launcher open uses the identical crop.
10. Stop with `ryoku/shell/dev-stop.sh` and restore the normal binding.

Acceptance requires:

- no changed pixels outside the launcher/shadow area attributable to opening;
- no monitor-sized input interception;
- no mapped launcher surface on a non-invocation output;
- no overlap at any result/action count;
- no empty expanded action slots;
- direct Enter launch for every executable result;
- smooth reversible open, close, shutter, and action transitions;
- a visually identical Hub preview and launcher hero crop;
- all existing provider QA assertions still passing.

## Delivery

No launcher config key is removed. Existing hero choices and focal positions
survive. The Hub description/default for `bgBlur` is updated to the local-frost
semantics, and launcher documentation and changelog are updated with the new
mode/action behaviour.

The QML and config changes ship through the existing `ryoku-desktop` package.
Any Hyprland namespace/rule adjustment is authored in the existing Lua module.
No live file becomes a source of truth.

## Primary references

- Quickshell 0.3 `DesktopEntry` and its `actions` list:
  https://quickshell.org/docs/v0.3.0/types/Quickshell/DesktopEntry/
- Quickshell 0.3 `DesktopAction` and `execute()`:
  https://quickshell.org/docs/v0.3.0/types/Quickshell/DesktopAction/
- Quickshell 0.3 `ScreencopyView`:
  https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/ScreencopyView/
- Quickshell transparency and shadow guidance:
  https://quickshell.org/docs/v0.3.0/guide/faq/
- Hyprland 0.55 layer rules:
  https://wiki.hypr.land/0.55.0/Configuring/Basics/Window-Rules/
