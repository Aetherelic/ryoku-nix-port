# Launcher QA

This directory exercises the live Shutter launcher. `run.sh` drives the resident
command socket and real keyboard input, saves the launcher's state JSON, takes a
screenshot after every scenario, and evaluates both state and shell side
effects.

Run it from a live Hyprland session after starting the checkout shell:

```sh
ryoku/shell/dev-run.sh
ryoku/shell/quickshell/launcher/qa/run.sh
```

Evidence lands under `/tmp/launcher-qa/run-<timestamp>/` unless `QA_OUT` is set.
Every scenario keeps its definition, command log, final state, and screenshot;
`results.tsv` is the run summary.

## Pass contract

A scenario passes only when:

1. every `asserts[]` jq expression returns exactly `true` for `state.json`;
2. every `shell_asserts[]` command exits zero;
3. every input step succeeds; and
4. teardown restores every fixture it changed.

There is no partial pass. Network scenarios may declare a genuine external
blocker, but launcher defects are never marked blocked.

Each scenario begins hidden and settled. `show` must reach a mapped `open`
surface with two Prelude ticks and a terminal capture state. Hiding must finish
`closed`, unmapped, and without focus. Asynchronous providers settle only when
their provider-owned busy state is false.

## Expanded app options

The suite installs temporary `.desktop` fixtures with zero through eight real
Desktop Actions, then removes them (restoring an unlikely same-name file from a
backup if one existed). The acceptance matrix is exact:

| Extra Desktop Actions | Expected shelf |
|---:|---|
| 0 | `Ctrl+K` does nothing; no marker, shelf, height, or blank space appears. |
| 1 | One full-width 38 px row. |
| 2 | One row of two equal cells. |
| 3 | One row of three equal cells. |
| 4 | Two rows of paired cells. |
| 5 | Two paired rows, then one full-width row. |
| 6 | Three paired rows. |
| 7 | Three visible rows plus scrolling; the odd fourth row is full width. |
| 8+ | Three visible rows plus scrolling; remaining rows stay paired. |

`Launch` is the primary action and never appears again in the shelf. Names and
order must match the `.desktop` declaration. Empty IDs, duplicate IDs,
disabled/unexecutable entries, and malformed primaries are not usable options.

Keyboard coverage is part of the matrix:

- `Tab` / `Shift+Tab` walk declaration order and wrap;
- arrows respect the visual rows and return from an odd full-width row to the
  prior column;
- `Enter` runs the focused option;
- `Esc` closes the shelf before leaving its search mode;
- typing closes the shelf while the actual query field keeps focus;
- a changed action signature closes the shelf instead of running a stale
  action;
- pointer hover focuses and pointer click runs the exact cell.

Apps with no additional actions stay dense: the selected 70 px lead and 40 px
ledger rows are the only result space.

## Visual and motion review

The automated assertions catch lifecycle, geometry, provider, and interaction
state. The screenshots and frame recordings carry a separate visual bar:

- no fullscreen dim/scrim, flash, compositor-wide blur, grain, or click-catcher;
- the mapped surface is the card plus its reserved shadow envelope;
- the hard contact shadow and broad falloff are complete at every animation
  extreme;
- no text, icon, mode key, ledger row, option, range counter, or scrollbar
  overlaps or clips;
- Rest opens as a fully prepared 250 px hero, never a compressed Query remnant;
- typing compresses the hero and opens the drawer without a solid/frost pop;
- the outer window grows before content is revealed and shrinks after visible
  content;
- open (210 ms), close (160 ms), shutter (360 ms), drawer (280 ms), selection
  (90 ms), and shelf (180 ms) are checked frame by frame;
- a close/show reversal keeps the current query and generation without a flash;
- click-away, `Esc`, and monitor transfer release focus only after the transparent
  close frames.

Record at the display refresh rate and extract every frame around Rest→Query,
Query→Rest, close, reversal, and local-frost readiness. A single wrong frame is
a failure even when the final screenshot looks correct.

## Image, palette, and scale matrix

The final live pass uses the Hub editor and the real launcher together:

- shipped fallback, wide, portrait, strongly off-centre, and missing hero paths;
- drag both axes in the Hub, save, and compare the live crop to the preview;
- two visually different wallpapers under both Wallust and Material roles;
- palette hashes before/after, selected-lead contrast of at least 4.5:1, and no
  stale colour from the prior wallpaper;
- default 2 px local frost, zero frost, reduced motion, and low-power fallback;
- representative 1.0, fractional, and high display scales;
- constrained-height output geometry.

The local frost must come from the active output, remain frozen for the
invocation, stay under the animated drawer only, and create no `MultiEffect` at
steady Rest. Capture failure or the 50 ms deadline must use the solid drawer
without changing opening timing.

## Files

- `scenarios.json`: live scenarios: `id`, `name`, `covers`, `steps`,
  `asserts`, optional `shell_asserts`, and `teardown`.
- `run.sh [suite] [only-ids]`: driver and evidence collector.
- `fixtures.sh`: reversible Desktop Action and recent-file fixtures used by
  the scenarios.

The step DSL is `show`, `hide`, `type <text>`, `key <keysym…>`, `ctrl <key>`,
`sleep <seconds>`, `settle [seconds]`, `bounds <label>`, `record-start <label>`,
`record-stop`, and `sh <command>`. A recording is forced to 120 fps with damage
tracking disabled; stopping it extracts every encoded frame beside the clip.
