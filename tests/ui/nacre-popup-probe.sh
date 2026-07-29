#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/Ryoku" "$work/pill"
ln -s "$repo/ryoku/ui" "$work/Ryoku/Ui"
ln -s "$repo/ryoku/shell/framebars" "$work/Ryoku/FrameBars"
cp -a "$repo/ryoku/shell/quickshell/pill/." "$work/pill/"
cp "$here/nacre-popup-probe.qml" "$work/pill/probe.qml"

QML2_IMPORT_PATH="$work:${QML2_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
    timeout 20 qs -p "$work/pill/probe.qml" >"$work/log" 2>&1 || true
grep -q NACRE-POPUP-PROBE-PASS "$work/log" || { sed -n '1,100p' "$work/log"; exit 1; }
grep -Eq ' ERROR|TypeError|ReferenceError' "$work/log" && { sed -n '1,100p' "$work/log"; exit 1; }
echo "nacre-popup-probe: shared popup components load"
