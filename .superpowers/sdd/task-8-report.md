# Task 8 report

## Red to green

- `(cd ryoku/shell/ipc && go test . -run TestRoute)` first failed as expected: `route("bar launcher") not ok`. After adding the bounded `bar <menu-id>` catalogue and pill route, the same command passed.
- `(cd ryoku/cli && go test ./internal/doctor -run TestMigrateShellConfig)` first failed as expected: sidebar width remained `340`, right-pane order remained the default, and all three retired sidebar keys survived. After migration, it passed. The test asserts left/right anchors, width `360`, left pane list, right-pane order, and removal of `sidebarLeftPanes`, `sidebarRightPanes`, and `sidebarWidth`.
- The offscreen menu-host test first failed because each Task-8 widget used the finite-host developer-error fallback. After adding all catalogue cases, `./MenuHost.integration.sh` passed with `MENU-HOST-RESOLVE-PASS` and `MENU-OPEN-GATE-PASS` for launcher, clipboard, screenshot, recording, theme, wallpaper, weather, and media.

## Verification

- `(cd ryoku/shell/ipc && go test . -run TestRoute)` passed. It exercises launcher, clipboard, screenshot, recording, wallpaper, and media `bar` routes and rejects missing, unknown, and over-argument routes.
- `(cd ryoku/cli && go test ./internal/doctor -run TestMigrateShellConfig)` passed.
- `(cd ryoku/shell/quickshell/pill/framebars && ./MenuHost.integration.sh)` passed. It resolves every catalogue component and confirms lifecycle gates release.
- `tests/shell-unit-tests.sh` passed all 32 Node test files.
- `/usr/lib/qt6/bin/qmllint` ran over modified QML successfully (exit 0). It reports existing project import/type-resolution warnings for Quickshell/Ryoku.Ui and pre-existing dynamic loader/`scale` diagnostics; no QML syntax failure occurred.

## Live-daemon limitation

No installed `qs -c pill` daemon was started, stopped, restarted, or taken over. Interactive desktop actions were not invoked because screenshot and recording require exclusive screen input. The equivalent programmatic/offscreen verification checked menu resolution and open-state gates only.
