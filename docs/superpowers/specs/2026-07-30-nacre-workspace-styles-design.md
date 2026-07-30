# Nacre Workspace Styles and Drag Feedback

## Goal

Let Nacre users choose how workspaces read at a glance instead of forcing the
default ring face. Make Bar Studio's island editor show where a dragged widget
will land.

## Workspace Styles

Nacre gains one `workspaceStyle` setting with three accepted values:

- `dots`: the current hollow-ring face.
- `numbers`: Arabic workspace numbers.
- `kanji`: Obi's Japanese numerals `一` through `十`.

`dots` remains the default so existing installations keep their current look.
Malformed or unknown values normalize to `dots`. Workspaces above ten use their
Arabic identifier in `kanji` mode.

All styles use the existing workspace list, occupied-only option, click target,
wheel navigation, and active/occupied state. Dots retain their compact ring
geometry. Numbers and kanji use equal circular cells, with the active workspace
filled in the accent colour, occupied workspaces using a subtle surface, and
empty workspaces remaining transparent. Kanji uses the Japanese UI font.

The implementation stays in Nacre's existing workspace component. It does not
add duplicate workspace widgets to the registry.

## Configuration and Bar Studio

`NacreConfig` owns validation, defaulting, and staging for `workspaceStyle`.
The setting therefore follows the same live preview, Save, and Revert path as
the other Nacre appearance values.

Bar Studio adds a `DOTS / NUMBERS / KANJI` segmented control beside the occupied
workspace toggle. Changing it updates the running Nacre bar immediately.

## Drag-and-Drop Feedback

Every Nacre island lane and the unused palette retains a wrapping `Flow` with a
fixed slot for each chip. Dragging continues to move only the chip's visual
child, so layout geometry cannot collapse or overlap.

While a widget is over an island:

- The lane calculates and exposes the current insertion index.
- A narrow accent marker appears before the target chip or after the last chip.
- An empty lane shows a centred `DROP WIDGET` target instead of an uninformative
  blank box.
- The lane border and background use the existing active-drop colours.

The unused palette highlights as a removal target and changes its empty hint to
`ALL WIDGETS PLACED`. Chips keep their bounded width and elided labels.

Dropping still calls the existing pure `NacreConfig.move` or
`NacreConfig.remove` operations. No second layout model is introduced.

## Testing

Model tests cover the default, accepted values, invalid fallback, and staged
workspace style. A QML workspace probe verifies dot, number, kanji, and
above-ten labels without requiring a live Hyprland workspace change.

The editor probe verifies:

- an empty lane has a visible drop affordance,
- drag entry updates the insertion index,
- the insertion marker remains inside the wrapping lane,
- the palette exposes its removal state,
- long chips remain bounded and the Flow-owned slot stays fixed.

The existing Nacre editor, popup, frame, keyboard, barcode, wire, and delivery
checks remain green.

## Constraints

- Modify only `/home/nero/Work/ryoku-arch-unstable`.
- Use main only as a read-only visual and behavioral reference.
- Keep production QML concise and avoid narrative comments.
- Commit locally and do not push.
- Deploy through `ryoku dev switch unstable-dev`.
