#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"
[ -f "$src" ] || { echo "no $src to probe against"; exit 77; }

mkdir -p "$work/cfg" "$work/qs"
cp "$src" "$work/cfg/shell.json"
cp "$here/wire-probe.qml" "$work/qs/shell.qml"

RYOKU_TEST_CFG="$work/cfg" \
QML_IMPORT_PATH="${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
  timeout 20 qs -p "$work/qs" >"$work/log" 2>&1 || true

grep -q FLUSHED "$work/log" || { echo "FAIL: never flushed"; sed -n '1,20p' "$work/log"; exit 1; }

python3 - "$work/cfg/shell.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
want = {"frameBorder": 88, "barStyle": "delos",
        "islandModules": ["workspaces", "clock", "tray"]}
bad = [k for k, v in want.items() if d.get(k) != v]
for k, v in want.items():
    print("  %-14s %-34s %s" % (k, json.dumps(d.get(k)), "ok" if d.get(k) == v else "MISMATCH, wanted " + json.dumps(v)))
sys.exit(1 if bad else 0)
PY
echo "wire-probe: the adapter writes what the UI set"
