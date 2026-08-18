#!/usr/bin/env bash
# offline-repo.sh must verify every cached package is a complete, readable archive
# before baking it into the [offline] repo. `pacman -Sw --needed` never re-fetches
# a file that already exists by name, and the cache is persistent, so a download
# truncated by one network hiccup sat corrupt in the cache and shipped in every
# ISO -- the offline pacstrap then died with a "truncated <pkg>" error (reported
# on ryomotion, the large Electron package ryoku-desktop depends on). See the
# integrity loop in installation/iso/offline-repo.sh.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
repo="$root/installation/iso/offline-repo.sh"
fail() { echo "FAIL: $1" >&2; exit 1; }

[[ -f $repo ]] || fail "offline-repo.sh not found"

# 1. the bake verifies package integrity with bsdtar, and does it BEFORE it builds
#    the db -- otherwise a truncated package would already be indexed and shipped.
grep -qE 'bsdtar -tf' "$repo" || fail "offline-repo.sh no longer verifies package integrity with bsdtar -tf"
vline=$(grep -nE 'bsdtar -tf' "$repo" | head -n1 | cut -d: -f1)
rline=$(grep -nE '^[[:space:]]*repo-add --quiet' "$repo" | head -n1 | cut -d: -f1)
[[ -n $vline && -n $rline ]] || fail "could not locate the integrity check and repo-add"
(( vline < rline )) || fail "integrity check (line $vline) runs after repo-add (line $rline); a truncated package would already be indexed"
# 2. a still-truncated package fails the build, it is never silently shipped.
grep -qE 'die "cache integrity' "$repo" || fail "offline-repo.sh must fail the build on a still-truncated package"

# 3. bsdtar -tf actually detects a truncated zstd package on this host (proves the
#    detection primitive the fix relies on). Skipped if bsdtar lacks zstd support.
command -v bsdtar >/dev/null 2>&1 || { echo "offline-repo-integrity: bsdtar absent; static checks OK"; exit 0; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
printf 'hello\n' >"$tmp/file"
if ! bsdtar -caf "$tmp/good.tar.zst" -C "$tmp" file 2>/dev/null; then
  echo "offline-repo-integrity: bsdtar has no zstd support here; static checks OK"
  exit 0
fi
bsdtar -tf "$tmp/good.tar.zst" >/dev/null 2>&1 || fail "a valid package failed the integrity check"
head -c 10 "$tmp/good.tar.zst" >"$tmp/trunc.tar.zst"
if bsdtar -tf "$tmp/trunc.tar.zst" >/dev/null 2>&1; then
  fail "a truncated package passed the integrity check"
fi

echo "offline-repo-integrity: OK"
