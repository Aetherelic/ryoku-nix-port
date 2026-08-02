#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
work="$(mktemp -d)"
pid=""
cleanup() {
    if [[ -n $pid ]]; then kill "$pid" 2>/dev/null || true; fi
    rm -rf "$work"
}
trap cleanup EXIT

state="$work/state/ryoku/store"
data="$work/data/ryoku/barstyles/obi"
mkdir -p "$state" "$data"
cp "$here/barstyles-live-probe.qml" "$work/probe.qml"

write_scene() {
    local marker="$1"
    printf 'import QtQuick\nItem { property string marker: "%s" }\n' "$marker" >"$data/.Scene.qml.tmp"
    mv "$data/.Scene.qml.tmp" "$data/Scene.qml"
}
write_index() {
    local body="$1"
    printf '%s\n' "$body" >"$state/.barstyles.json.tmp"
    mv "$state/.barstyles.json.tmp" "$state/barstyles.json"
}
write_revision() {
    local revision="$1"
    printf '{"revision":%s,"category":"barstyles","id":"obi","version":"1.0.%s","operation":"update"}\n' \
        "$revision" "$revision" >"$state/.revision.json.tmp"
    mv "$state/.revision.json.tmp" "$state/revision.json"
}
wait_for() {
    local marker="$1"
    for _ in $(seq 1 200); do
        grep -q "$marker" "$work/log" 2>/dev/null && return 0
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.05
    done
    cat "$work/log" 2>/dev/null || true
    return 1
}

write_scene v1
write_index '[{"id":"obi","version":"1.0.1","scene":"Scene.qml"}]'
write_revision 1
XDG_STATE_HOME="$work/state" XDG_DATA_HOME="$work/data" \
QML_IMPORT_PATH="$repo/ryoku/shell/quickshell:${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
QT_QPA_PLATFORM=offscreen qs -p "$work/probe.qml" >"$work/log" 2>&1 &
pid=$!

wait_for 'BARSTYLE-MARKER:v1'
original_pid=$pid
write_scene v2
write_index '[{"id":"obi","version":"1.0.2","scene":"Scene.qml"}]'
write_revision 2
wait_for 'BARSTYLE-MARKER:v2'
[[ $pid == "$original_pid" ]] && kill -0 "$pid"

write_index '[]'
write_revision 3
wait_for 'BARSTYLE-SUMI'
[[ $pid == "$original_pid" ]] && kill -0 "$pid"

if grep -Eq '(^|[[:space:]])(ERROR|TypeError|ReferenceError)|Failed to load' "$work/log"; then
    cat "$work/log"
    exit 1
fi

echo "barstyles-live-probe: v1 -> v2 -> Sumi in pid $pid"
