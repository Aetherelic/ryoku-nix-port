#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export XDG_RUNTIME_DIR="$tmp/runtime"
mkdir -p "$XDG_RUNTIME_DIR"

cover="$root/ryoku/shell/scripts/ryoku-reload-cover"
token=$(RYOKU_RELOAD_COVER_TEST=1 "$cover" begin)
test -n "$token"
test "$(stat -c %a "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")" = 600
test "$(jq -r .token "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")" = "$token"

test "$(jq -r .pid "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")" -gt 0
RYOKU_RELOAD_COVER_TEST=1 "$cover" finish wrong-token
test "$(jq -r .token "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")" = "$token"

RYOKU_RELOAD_COVER_TEST=1 "$cover" finish "$token"
test ! -e "$XDG_RUNTIME_DIR/ryoku-reload-cover.json"


for out in "$tmp/a" "$tmp/b"; do
    (RYOKU_RELOAD_COVER_TEST=1 "$cover" begin >"$out" 2>/dev/null) &
done
wait || true
test "$(awk 'NF { n++ } END { print n + 0 }' "$tmp/a" "$tmp/b")" = 1
token=$(jq -r .token "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")
RYOKU_RELOAD_COVER_TEST=1 "$cover" finish "$token"

echo "reload cover launcher: PASS"
