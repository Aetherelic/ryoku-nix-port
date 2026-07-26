#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../../../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/qs" "$work/config/ryoku"
while IFS= read -r line; do
    case "$line" in
        'import "__RYOWALLS_DIR__" as Ryowalls') printf 'import "file:%s" as Ryowalls\n' "$repo/ryoku/apps/ryowalls/quickshell" ;;
        *) printf '%s\n' "$line" ;;
    esac
done <"$here/FrameBarsCutover.integration.qml" >"$work/qs/shell.qml"

declare -A geometry
declare -A material

run_case() {
    local style="$1"
    local layout="$2"
    local key="$style/$layout"
    local top=false left=false bottom=false right=false
    if [[ "$layout" == "top-left" ]]; then
        top=true
        left=true
    else
        bottom=true
        right=true
    fi

    cat >"$work/config/ryoku/shell.json" <<EOF
{"frameBars":{"style":"$style","rails":{"top":{"enabled":$top,"size":32,"start":[],"center":[],"end":[]},"left":{"enabled":$left,"size":48,"top":[],"center":[],"bottom":[]},"bottom":{"enabled":$bottom,"size":32,"start":[],"center":[],"end":[]},"right":{"enabled":$right,"size":48,"top":[],"center":[],"bottom":[]}}}}
EOF

    local log="$work/$style-$layout.log"
    CUTOVER_STYLE="$style" CUTOVER_LAYOUT="$layout" XDG_CONFIG_HOME="$work/config" \
        QT_QPA_PLATFORM=offscreen QML_IMPORT_PATH="${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
        timeout 20 qs -p "$work/qs" >"$log" 2>&1 || true
    cat "$log"

    local line=""
    while IFS= read -r line; do
        case "$line" in
            *FRAME-BARS-CUTOVER-GEOMETRY*) geometry["$key"]="${line#*FRAME-BARS-CUTOVER-GEOMETRY $layout }" ;;
            *FRAME-BARS-CUTOVER-MATERIAL*) material["$key"]="${line#*FRAME-BARS-CUTOVER-MATERIAL $style }" ;;
        esac
    done <"$log"
    [[ -n "${geometry[$key]:-}" ]] || { echo "FAIL: missing $key preview geometry"; exit 1; }
    [[ -n "${material[$key]:-}" ]] || { echo "FAIL: missing $key preview material"; exit 1; }
    case "$(cat "$log")" in
        *FRAME-BARS-CUTOVER-PASS*) ;;
        *) echo "FAIL: Ryowalls frame preview did not pass for $style/$layout"; exit 1 ;;
    esac
}

run_case slate-frame top-left
run_case ryoku-frame top-left
run_case slate-frame bottom-right
run_case ryoku-frame bottom-right

[[ "${geometry[slate-frame/top-left]}" == "${geometry[ryoku-frame/top-left]}" ]] || { echo "FAIL: top-left geometry changed with style"; exit 1; }
[[ "${geometry[slate-frame/bottom-right]}" == "${geometry[ryoku-frame/bottom-right]}" ]] || { echo "FAIL: bottom-right geometry changed with style"; exit 1; }
[[ "${material[slate-frame/top-left]}" != "${material[ryoku-frame/top-left]}" ]] || { echo "FAIL: styles did not change preview material"; exit 1; }
echo "frame-bars-cutover-integration: shared geometry and Ryowalls preview verified"
