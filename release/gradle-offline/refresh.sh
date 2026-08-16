#!/usr/bin/env bash
# Regenerate repo/, the vendored maven repo both limine PKGBUILDs build against
# (limine-mkinitcpio-hook and limine-snapper-sync pin the same plugin version).
# Run this (with network) only when upstream bumps the graalvm buildtools plugin;
# the package builds themselves never reach the network.
#
#   ./refresh.sh            # version taken from limine-mkinitcpio-hook's PKGBUILD
#   ./refresh.sh 1.2.0      # pin a different plugin version
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"

ver=${1:-$(grep -oE 'buildtools\.native.{0,60}' ../packages/limine-mkinitcpio-hook/PKGBUILD \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)}
[[ -n $ver ]] || { echo "could not determine the plugin version; pass it as \$1" >&2; exit 1; }
command -v gradle >/dev/null || { echo "gradle is not on PATH" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/proj"
printf 'rootProject.name = "resolve"\n' >"$tmp/proj/settings.gradle.kts"
printf 'plugins { id("org.graalvm.buildtools.native") version "%s" }\n' "$ver" >"$tmp/proj/build.gradle.kts"

echo "resolving org.graalvm.buildtools.native:$ver"
( cd "$tmp/proj" && gradle -g "$tmp/gh" --no-daemon tasks --all >/dev/null )

# Gradle caches artifacts under <group>/<artifact>/<version>/<sha1>/<file>;
# flatten that into the plain maven layout a file:// repo needs.
rm -rf repo
python3 - "$tmp/gh/caches/modules-2/files-2.1" repo <<'PY'
import sys, pathlib, shutil
src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
n = 0
for f in src.rglob("*"):
    if not f.is_file():
        continue
    rel = f.relative_to(src).parts
    if len(rel) < 5:
        continue
    group, artifact, version = rel[0], rel[1], rel[2]
    out = dst.joinpath(*group.split("."), artifact, version, f.name)
    out.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(f, out)
    n += 1
print(f"vendored {n} artifacts")
PY

echo "repo/ is $(du -sh repo | cut -f1) in $(find repo -type f | wc -l) files"
echo "verify with: gradle --offline -I offline.init.gradle -Dryoku.offline.repo=file://$here/repo help"
