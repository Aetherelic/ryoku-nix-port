#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
extras="${RYOKU_EXTRAS_ROOT:-$repo/../ryoku-extras-catalogue}"
[[ -f "$extras/barstyles/nacre/manifest.json" && -f "$extras/barstyles/obi/manifest.json" ]] \
    || { echo "nacre-popup-probe: missing external barstyle products at $extras" >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/Ryoku" "$work/pill/barstyles"
ln -s "$repo/ryoku/ui" "$work/Ryoku/Ui"
ln -s "$repo/ryoku/shell/framebars" "$work/Ryoku/FrameBars"
cp -a "$repo/ryoku/shell/quickshell/pill/." "$work/pill/"
cp -a "$extras/barstyles/nacre" "$extras/barstyles/obi" "$work/pill/barstyles/"
cp "$here/nacre-popup-probe.qml" "$work/pill/probe.qml"

QML2_IMPORT_PATH="$work:${QML2_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
    timeout 20 qs -p "$work/pill/probe.qml" >"$work/log" 2>&1 || true
grep -q NACRE-POPUP-PROBE-PASS "$work/log" || { sed -n '1,100p' "$work/log"; exit 1; }
grep -Eq ' ERROR|TypeError|ReferenceError|Nacre widget failed|is not a type|Type .* unavailable' "$work/log" \
    && { sed -n '1,100p' "$work/log"; exit 1; }
echo "nacre-popup-probe: Nacre popup components load"
