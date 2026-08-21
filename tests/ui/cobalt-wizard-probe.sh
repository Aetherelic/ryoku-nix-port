#!/usr/bin/env bash
# cobalt-wizard-probe: the stash Cobalt setup modal renders Stash's setup state.
# Drives the state machine through idle, in-flight, failure, reset and done, and
# asserts what the view actually shows: a row per step, the failing step's own
# message, and no way to abandon a privileged step mid-run. Loads the real shell
# components against a faithful mirror of shell/ used as the config folder, the
# way center-popout-probe.sh does, so their deep relative imports resolve.
# Hermetic: no docker, no pkexec, no processes. Commit nothing.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
src="$repo/ryoku/shell/quickshell/shell"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/Ryoku" "$work/shell/modules" "$work/cfg/ryoku"
ln -s "$repo/ryoku/ui" "$work/Ryoku/Ui"
ln -s "$repo/ryoku/shell/framebars" "$work/Ryoku/FrameBars"
for child in "$src"/*; do
    name="$(basename "$child")"
    [[ "$name" == modules ]] && continue
    ln -s "$child" "$work/shell/$name"
done
for child in "$src/modules"/*; do
    ln -s "$child" "$work/shell/modules/$(basename "$child")"
done

cp "$here/cobalt-wizard-probe.qml" "$work/shell/probe.qml"

# A helper path that cannot exist, so nothing in this run can reach a real
# daemon even if a code path tried.
XDG_CONFIG_HOME="$work/cfg" \
    RYOKU_DOCKER_HELPER="$work/no-such-helper" \
    QML2_IMPORT_PATH="$work:${QML2_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
    timeout 40 qs -p "$work/shell/probe.qml" >"$work/probe.log" 2>&1 || true

if ! grep -q COBALT-WIZARD-PROBE-PASS "$work/probe.log"; then
    echo "cobalt-wizard-probe: FAILED" >&2
    sed -n '1,120p' "$work/probe.log" >&2
    exit 1
fi
echo "cobalt-wizard-probe: the modal renders every step state, keeps the failure's own message, and cannot be abandoned mid-run"
