# Nacre Main-Parity Implementation Plan

**Goal:** Package main revision `69ca0b25`'s unified frame, island, popup, and
notification behavior inside the configurable Nacre folder style.

**Architecture:** Nacre owns a full-screen overlay and one `Ryoku.Blobs`
group. A `BlobInvertedRect`, three resting `BlobRect` lobes, and every popup
share that group. Nacre widgets publish popup requests to the scene. Existing
unstable services remain the data source, and the default widget arrangement
matches main.

## Constraints

- Modify only `/home/nero/Work/ryoku-arch-unstable`.
- Treat `/home/nero/Work/ryoku-arch` as read-only.
- Keep Nacre production code under `pill/barstyles/nacre/`.
- Preserve Nacre's Bar Studio layout controls.
- Commit locally and do not push.
- Keep production comments limited to non-obvious constraints.

## Tasks

### 1. Reference parity fixtures

- Record main revision `69ca0b25` as the source.
- Add QML probes for shared blob ownership, content-only islands, popup body
  geometry, persistent idle media, and notification toast wiring.
- Confirm the probes fail against the Canvas and standalone-popup
  implementation.

### 2. Unified Nacre runtime

- Replace Nacre's bar-only `PanelWindow` with a reserve window and full-screen
  overlay.
- Port main's `BlobGroup`, `BlobInvertedRect`, resting lobe geometry, rounded
  transitions, mask union, and fullscreen behavior.
- Disable the shell-wide `FrameChrome` while Nacre owns the frame.
- Retain detached-lobe behavior when the outer frame toggle is off.

### 3. Frame-grown popup stack

- Port main's `Popout.qml` curtain, neck, clamping, hover latch, and melt
  animation into `barstyles/nacre/components/`.
- Add Nacre-owned audio, battery, calendar, connectivity, inbox, media,
  resources, weather, and notification toast contents.
- Route widget clicks and media hover through scene-level popup state.
- Disable the standalone notification card window while Nacre is active.

### 4. Configurable main-default bar

- Keep the left, center, and right arrays as the content source.
- Make the default arrangement and dimensions match main.
- Keep media mounted with `No media` when no MPRIS player exists.
- Keep system health icon-led and retain connections, audio, battery, tray,
  weather, recording, and all other registry options.

### 5. Verification and deployment

- Run Nacre model, QML, URL-loading, popup, shell, Hub, delivery, and repository
  checks.
- Deploy through `ryoku/shell/deploy.sh`.
- Verify the active track is `unstable-dev`, Nacre is selected, the shell logs
  are clean, and notification/media behavior is live.
- Commit all implementation and documentation locally without pushing.
