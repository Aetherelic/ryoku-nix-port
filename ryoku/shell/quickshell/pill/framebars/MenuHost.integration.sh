#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
pill="$here/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/qs"

# The menu components pull in most of the pill dir (icons, fader, singletons),
# so mirror the whole tree by symlink and swap in the harness as the entry.
for f in "$pill"/*; do
  ln -s "$f" "$work/qs/$(basename "$f")"
done
rm -f "$work/qs/shell.qml"
cp "$here/MenuHost.integration.qml" "$work/qs/shell.qml"

QT_QPA_PLATFORM=offscreen \
QML_IMPORT_PATH="${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
  timeout 30 qs -p "$work/qs" >"$work/log" 2>&1 || true

cat "$work/log"

fail=0
grep -q MENU-HOST-RESOLVE-PASS "$work/log" || { echo "FAIL: menu host resolution"; fail=1; }
grep -q MENU-OPEN-GATE-PASS "$work/log" || { echo "FAIL: menu open-state gating"; fail=1; }

# Every implemented id must resolve without the developer-error default firing.
for id in clock notifications network bluetooth audio-input audio-output power-profile quick-settings quick-actions layout-switcher container divider spacer launcher clipboard screenshot recording theme wallpaper weather media; do
  if grep -q "no host component for $id\$" "$work/log"; then
    echo "FAIL: implemented id '$id' hit the dev-error default"; fail=1
  fi
done

if (( fail )); then exit 1; fi
echo "menu-host-integration: every catalogued id resolves and open-state gates release"
