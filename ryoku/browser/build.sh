#!/usr/bin/env sh
# Assemble unpacked extension dirs for both engines. No external tools.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"

rm -rf dist
for engine in chromium firefox; do
  out="dist/$engine"
  mkdir -p "$out/src"
  cp src/*.js src/*.html "$out/src/"
  cp "manifest.$engine.json" "$out/manifest.json"
  echo "built $out"
done
