# Desktop Calendar Widget Design

## Goal

Add a first-party desktop calendar widget that looks native to Ryoku, follows the wallpaper palette, and remains useful at a glance. It ships with two user-selectable appearances, restrained motion, configurable week density, location-aware holidays, and indicators for Ryoku's existing personal events.

## Product decisions

- The calendar is a first-party desktop widget beside the existing clock, not a plugin.
- It is enabled by default and starts at the bottom-right so it does not overlap the clock's top-left default.
- Users choose between `glass` and `paper` styles.
- Users choose 4 through 8 visible weeks. The default is 6.
- The header shows the current ISO week number.
- Holidays follow the system locale by default. A setting accepts an ISO 3166-1 country code with an optional subdivision code, such as `US` or `US-CA`.
- Personal events appear as day indicators. Hovering a marked day reveals holiday and event titles. Event editing remains in the existing calendar surface.
- The calendar can be moved, scaled, locked, hidden, and adjusted through the same desktop widget mechanisms as the clock.

## Visual design

### Wallpaper Glass

Wallpaper Glass is a translucent, hairline-bordered plate. Its tint, foreground, muted text, and current-day emphasis come from the live Ryoku palette, so a wallpaper change retunes it without a reload. The surface uses the existing background effect rather than a hardcoded blur or color. It has no logo, red sun, poster ornament, or decorative illustration.

On hover, the plate gains a small amount of opacity and local contrast while the focused day rises by two logical pixels. The current week receives a low-contrast band. Holiday markers use the wallpaper accent only when it clears the design system's contrast rules.

### Ryoku Paper

Ryoku Paper is an opaque paper-and-ink plate using the shared Ryoku tokens. It has a one-pixel hairline, near-square corners, bone text, and no shadow. Hover emphasis uses inversion: a day flips to bone with dark ink. Holidays use a small underline and personal events use a dot, preserving the distinction without introducing extra colors.

### Shared layout

The header contains the localized month and year, the visible range's current ISO week number, and previous, today, and next controls. The body has a weekday header, optional ISO week-number column, and 4 through 8 week rows. Adjacent-month dates remain visible but muted.

The detail strip is collapsed at rest. Hovering or keyboard-focusing a marked day reveals its localized full date, holiday names, and personal event titles. The strip reserves its final height during the reveal so the desktop widget does not jump under the pointer.

## Motion

Motion uses Ryoku's shared `Motion` durations and curves.

- Initial appearance fades and rises once when the widget becomes visible.
- Hovering the plate increases surface contrast over the fast duration.
- Focusing a day moves the selection plate with the emphasized curve instead of rebuilding it per cell.
- Month navigation slides the old grid out and the new grid in over the standard duration.
- Once per minute, a short highlight travels across the current-week band. It rests between runs, avoiding a continuous repaint.
- Motion is disabled or shortened through the existing animation policy. Hidden or covered desktop widgets do not animate.

## Architecture

### Calendar model

Extract date-grid calculations from the existing calendar surface into a pure shared JavaScript module under `shell/services/lib/`. The module owns:

- ISO week-number calculation
- localized week starts
- month shifting
- 4 through 8 week range generation
- adjacent-month day generation
- stable `YYYY-MM-DD` keys

Both the existing shell calendar and the new desktop widget consume this module so Ryoku has one calendar implementation.

### Holiday service

Add a `calendar` topic to `ryoku-shell`, following the existing weather topic pattern. The daemon:

1. resolves an empty override from the process locale;
2. validates explicit country and subdivision codes;
3. fetches the years intersecting the visible range from Nager.Holidays API v4;
4. filters subdivision-specific holidays when an override contains a subdivision;
5. writes successful responses under `$XDG_CACHE_HOME/ryoku/holidays/` by country and year;
6. publishes normalized date, localized name, type, and subdivision fields to QML.

Only country, subdivision, and year are sent. The daemon refreshes a cached year no more than once per day. A failed request keeps and publishes the last successful cache. With no cache, the widget still renders dates and personal events and exposes a quiet unavailable state in its right-click menu and Settings preview.

### QML components

Create a focused `desktop/calendar/` component family:

- `CalendarWidget.qml`: shared state, navigation, holiday subscription, and layout composition
- `CalendarGrid.qml`: weekday and week-row layout
- `CalendarDay.qml`: one interactive day cell
- `CalendarGlass.qml`: Wallpaper Glass surface
- `CalendarPaper.qml`: Ryoku Paper surface
- `CalendarDetails.qml`: holiday and event reveal strip

`Desktop.qml` hosts the widget in a second `WidgetSlot`. The widget reads palette and geometry from the shared design system and animation values from `Motion`. No colors, font names, radii, or durations are hardcoded.

### Configuration and Settings

Extend `widgets.json` through the desktop `Config.qml` adapter with additive defaults:

- `calendarEnabled: true`
- `calendarStyle: "glass"`
- `calendarWeeks: 6`
- `calendarWeekNumbers: true`
- `calendarHolidayRegion: ""`
- `calendarScale: 1.0`
- `calendarAnchor: "bottom-right"`
- `calendarX`, `calendarY`
- `calendarLocked: false`
- `calendarOpacity: 1.0`

An empty holiday region means automatic system-locale detection. Ryoku Settings adds a Calendar tab with a live preview, style choice, visible-week stepper, week-number toggle, holiday-region override, opacity, placement, scale, and lock controls. The desktop right-click menu provides show/hide, lock, and a shortcut to Calendar settings.

These are additive keys, so existing user files inherit defaults without a doctor reconciler.

## Data flow

1. `Config.qml` reads `widgets.json` and supplies placement and display preferences.
2. `CalendarWidget.qml` asks the daemon calendar topic for the visible years and configured region.
3. The daemon immediately publishes cached holidays, then refreshes stale data in the background.
4. The shared calendar module creates day entries for the selected 4 through 8 week range.
5. QML joins holiday frames and the existing `Events` singleton by date key.
6. Either skin renders the same joined model.
7. Settings or desktop menu changes write `widgets.json`; its existing file watcher updates the running widget.

## Error handling

- Invalid week counts clamp to 4 through 8.
- Invalid style values fall back to `glass`.
- Invalid holiday overrides preserve the user's text, report the validation error in Settings, and fall back to the automatic locale for rendering.
- Unsupported locales render without holidays and show a non-blocking explanation in Settings.
- Network and JSON failures never remove a valid cache.
- Missing holiday data never prevents date or personal-event rendering.
- Month navigation handles year boundaries and returns to the real current month through the Today control.

## Verification

### Model and daemon tests

- week ranges contain the requested number of complete localized weeks;
- ISO week 1 and year-boundary cases are correct;
- month navigation handles December and January;
- locale and explicit region resolution choose the expected country/subdivision;
- holiday responses normalize, filter subdivisions, and cache correctly;
- stale-cache refresh, offline fallback, invalid JSON, and unsupported-country paths preserve calendar output.

### QML checks

Run `qmllint` on every changed component. Exercise both styles, 4 and 8 week extremes, current-week display, holiday and event indicators, region override, month navigation, Today, hover details, drag, scale, lock, opacity, and wallpaper retheming.

### Live visual confirmation

Run the checkout through `ryoku/shell/dev-run.sh` on the live machine. Confirm Wallpaper Glass and Ryoku Paper against at least one dark and one light or colorful wallpaper. Inspect the widget at its default bottom-right placement, at minimum and maximum scale, and while windows cover and uncover it. Confirm no overlap with the default clock, readable contrast, smooth hover and passive motion, and zero animation work while hidden.
