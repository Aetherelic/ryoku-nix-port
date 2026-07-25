#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/qs"
cp "$here/RailGeometry.integration.qml" "$work/qs/shell.qml"
ln -s "$here" "$work/qs/framebars"
ln -s "$here/../Bar.qml" "$work/qs/Bar.qml"
ln -s "$here/../BarWidgetHost.qml" "$work/qs/BarWidgetHost.qml"
ln -s "$here/../MaterialIcon.qml" "$work/qs/MaterialIcon.qml"
ln -s "$here/../FrameRail.qml" "$work/qs/FrameRail.qml"
ln -s "$here/../RailZone.qml" "$work/qs/RailZone.qml"
ln -s "$here/../Singletons" "$work/qs/Singletons"
ln -s "$here/../lib" "$work/qs/lib"

QT_QPA_PLATFORM=offscreen \
QML_IMPORT_PATH="${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
  timeout 20 qs -p "$work/qs" >"$work/log" 2>&1 || true

cat "$work/log"
grep -q RAIL-GEOMETRY-PASS "$work/log" || { echo "FAIL: rail geometry integration"; exit 1; }
grep -q FRAME-BAR-CONTRACT-PASS "$work/log" || { echo "FAIL: frame-bar contract"; exit 1; }
echo "rail-geometry-integration: chrome, mask, and reserve agree at scale 1.3"
