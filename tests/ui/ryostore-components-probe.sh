#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/Ryoku"
ln -s "$repo/ryoku/ui" "$work/Ryoku/Ui"
cp -a "$repo/ryoku/apps/ryostore/quickshell" "$work/ryostore"
cp "$here/ryostore-components-probe.qml" "$work/probe.qml"

QML2_IMPORT_PATH="$work:${QML2_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
    timeout 20 qs -p "$work/probe.qml" >"$work/log" 2>&1 || true
if ! grep -q RYOSTORE-COMPONENTS-PROBE-PASS "$work/log"; then
    sed -n '1,160p' "$work/log"
    exit 1
fi
if grep -Eq '(^|[[:space:]])ERROR|TypeError|ReferenceError' "$work/log"; then
    sed -n '1,160p' "$work/log"
    exit 1
fi
echo "ryostore-components-probe: cover and status states"
