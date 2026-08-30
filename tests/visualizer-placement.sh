#!/usr/bin/env bash
set -euo pipefail

root=${RYOKU_PATH:-$(cd "$(dirname "$0")/.." && pwd)}
viz="$root/ryoku/shell/quickshell/shell/modules/visualizer/Visualizer.qml"
config="$root/ryoku/shell/quickshell/shell/modules/visualizer/Singletons/Config.qml"

fail() { printf 'visualizer placement: %s\n' "$*" >&2; exit 1; }

grep -Fq 'function dataAt(index)' "$config" || fail 'missing stable per-instance accessor'
grep -Fq 'model: Config.count' "$viz" || fail 'render repeater rebuilds on every config object update'
grep -Fq 'active: root.placeable && root.activeView !== null' "$viz" || fail 'placer can map without an active visualizer view'
! grep -Fq 'Qt.rect(0, 0, win.width, win.height)' "$viz" || fail 'placer falls back to a full-screen box'

echo 'visualizer placement: PASS'
