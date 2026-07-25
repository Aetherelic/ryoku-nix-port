#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/qs"
cp "$here/RailGeometry.integration.qml" "$work/qs/shell.qml"
ln -s "$here" "$work/qs/framebars"
ln -s "$here/../Bar.qml" "$work/qs/Bar.qml"
ln -s "$here/../FrameRail.qml" "$work/qs/FrameRail.qml"
ln -s "$here/../RailZone.qml" "$work/qs/RailZone.qml"

QT_QPA_PLATFORM=offscreen \
QML_IMPORT_PATH="${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
  timeout 20 qs -p "$work/qs" >"$work/log" 2>&1 || true

cat "$work/log"
grep -q RAIL-GEOMETRY-PASS "$work/log" || { echo "FAIL: rail geometry integration"; exit 1; }
echo "rail-geometry-integration: chrome, mask, and reserve agree at scale 1.3"
