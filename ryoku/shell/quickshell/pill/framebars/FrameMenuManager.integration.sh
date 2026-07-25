#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
pill="$here/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/qs"
for f in "$pill"/*; do
  ln -s "$f" "$work/qs/$(basename "$f")"
done
rm -f "$work/qs/shell.qml"
cp "$here/FrameMenuManager.integration.qml" "$work/qs/shell.qml"

QT_QPA_PLATFORM=offscreen \
QML_IMPORT_PATH="${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
  timeout 30 qs -p "$work/qs" >"$work/log" 2>&1 || true
cat "$work/log"
grep -q FRAME-MENU-MANAGER-PASS "$work/log" || {
  echo "FAIL: frame menu manager integration" >&2
  exit 1
}
