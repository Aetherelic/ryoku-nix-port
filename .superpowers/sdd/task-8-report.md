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

## Review-fix evidence

- Red: `(cd ryoku/shell/ipc && go test . -run TestDispatchBarMenu -count=1 -v)` failed for all eight allowed ids with `err unknown command: bar`. Green: the same focused test passed after dispatch retained the normalized `bar <id>` input through route and pill IPC construction. It uses a Unix pill socket and verifies each call is `bar DP-1 <id>`; missing, unknown, and extra arguments are rejected.
- Red: `(cd ryoku/shell/quickshell/pill/framebars && node FrameBars.test.mjs)` failed because every Task-8 default menu record was absent. Green: it passed after all eight finite records were added to the default configuration and catalogue.
- `(cd ryoku/cli && go test ./internal/doctor -run FrameBars -count=1)` passed.
- `RYOKU_PATH=/home/nero/Work/ryoku-arch/.worktrees/frame-bars tests/shell-unit-tests.sh` passed all 32 Node test files, including the updated frame-bar defaults test.
- `/usr/lib/qt6/bin/qmllint quickshell/pill/framebars/menus/MenuClipboard.qml quickshell/pill/framebars/menus/MenuLauncher.qml quickshell/pill/framebars/menus/MenuCapture.qml quickshell/pill/framebars/menus/MenuMedia.qml quickshell/pill/framebars/menus/MenuWeather.qml quickshell/pill/framebars/menus/MenuTheme.qml quickshell/pill/framebars/menus/MenuWallpaper.qml quickshell/pill/shell.qml quickshell/pill/Singletons/Config.qml` completed. The external Quickshell/Ryoku module diagnostics and existing dynamic-loader warnings remain; the new clipboard missing Theme properties were corrected. The focused clipboard lint now has only declaration-scope unqualified-access warnings. No live daemon was started, stopped, restarted, or taken over.
- Removed the inert launcher owner `hostMode`. `/usr/lib/qt6/bin/qmllint launcher/shell.qml pill/framebars/menus/MenuLauncher.qml` completed with only existing unresolved external Ryoku/Quickshell module and declaration-scope diagnostics. `(cd ryoku/shell/quickshell && ./pill/framebars/MenuHost.integration.sh)` passed `MENU-HOST-RESOLVE-PASS` and `MENU-OPEN-GATE-PASS`.
