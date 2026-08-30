#!/usr/bin/env bash
set -euo pipefail

ROOT=${RYOKU_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
page="$ROOT/ryoku/hub/quickshell/SchemaPage.qml"

grep -qF 'import Quickshell.Io' "$page"
grep -qF 'Process {' "$page"

echo "SchemaPage Process import: OK"
