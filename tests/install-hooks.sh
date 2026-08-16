#!/usr/bin/env bash
# Regression test for the two defects that broke the offline install for users:
#
#   1. The initramfs mask was laid at /mnt/etc/pacman.d/hooks/90-mkinitcpio-install.hook
#      BEFORE pacstrap. limine-mkinitcpio-hook ships that exact path, so pacman
#      aborted the whole transaction with "exists in filesystem" and no packages
#      were installed. The mask must land after pacstrap, and must move a
#      package-owned file aside rather than clobber it, so restore hands it back.
#
#   2. The retry paths ran `pacstrap -K --needed /mnt ...`. pacstrap parses only
#      short options (getopts ':C:cDGiKMNPU'), so a long option before the root
#      died with "pacstrap: invalid option -- '-'" and the real pacman error was
#      never surfaced. pacman flags belong after the root, where pacstrap passes
#      them through as targets.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. ordering: the mask may not be laid before pacstrap runs.
inst="$root/installation/backend/ryoku-install"
mask_line=$(grep -n "ryoku_hooks_defer_mkinitcpio" "$inst" | grep -v '^\s*#' | head -n1 | cut -d: -f1)
strap_line=$(grep -n "^\s*ryoku_pacstrap$" "$inst" | head -n1 | cut -d: -f1)
[[ -n $mask_line && -n $strap_line ]] || fail "could not locate the mask and pacstrap calls in ryoku-install"
(( mask_line > strap_line )) \
  || fail "ryoku_hooks_defer_mkinitcpio (line $mask_line) runs before ryoku_pacstrap (line $strap_line); the mask collides with limine-mkinitcpio-hook's packaged hook"

# 2. no pacstrap invocation may put a long option before the root argument.
while IFS= read -r line; do
  args=${line#*pacstrap }
  for tok in $args; do
    case $tok in
      /mnt|"\"\$newroot\"") break ;;
      --*) fail "pacstrap long option '$tok' precedes the root argument: $line" ;;
    esac
  done
done < <(grep -rhn "run pacstrap" "$root/installation/backend/lib/" || true)

# 3. behaviour: a package-owned hook survives mask + restore intact.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
hooks="$tmp/etc/pacman.d/hooks"
mkdir -p "$hooks"
printf 'packaged limine hook\n' >"$hooks/90-mkinitcpio-install.hook"

# The lib writes to /mnt; source a copy pointed at the temp tree, with `run` and
# `log` stubbed, so the test needs neither root nor a real target.
sed "s#/mnt/etc/pacman.d/hooks#$hooks#g" "$root/installation/backend/lib/chroot.sh" >"$tmp/chroot.sh"
run() { "$@"; }
log() { :; }
die() { fail "$*"; }
# shellcheck source=/dev/null
source "$tmp/chroot.sh"
ryoku_hooks_defer_mkinitcpio
[[ -L $hooks/90-mkinitcpio-install.hook ]] \
  || fail "mask did not replace the hook with a /dev/null symlink"
[[ -f $hooks/90-mkinitcpio-install.hook.ryoku-off ]] \
  || fail "the packaged hook was clobbered instead of moved aside"

ryoku_hooks_restore
[[ -f $hooks/90-mkinitcpio-install.hook && ! -L $hooks/90-mkinitcpio-install.hook ]] \
  || fail "restore did not hand the packaged hook back"
[[ $(cat "$hooks/90-mkinitcpio-install.hook") == "packaged limine hook" ]] \
  || fail "restored hook has the wrong contents"
[[ ! -e $hooks/90-mkinitcpio-install.hook.ryoku-off ]] \
  || fail "restore left the .ryoku-off copy behind"

echo "install-hooks: OK"
