#!/usr/bin/env bash
# The installer runs with no one at the keyboard: the TUI streams its output and
# answers nothing. So NOTHING it invokes may wait for input. Two shipped installs
# proved what happens when something does:
#
#   1. pacstrap ran without --noconfirm, so pacman asked ":: There are 5 providers
#      available for vulkan-driver" (the baked repo carries every NVIDIA branch
#      plus vulkan-intel and vulkan-radeon) and took its default: nvidia-470xx-utils,
#      a Kepler-era driver, which then collided with the real driver in the
#      configure stage and failed the install.
#   2. `mkinitcpio -P` in the chroot resolved to /usr/local/bin/mkinitcpio, the
#      wrapper limine-mkinitcpio-hook ships, which builds and then PROMPTS
#      ("Would you like to run 'limine-mkinitcpio' now?"). With a terminal on stdin
#      that hangs the install; without one it flips a coin.
#
# The fixes are structural, so this pins them structurally: commands run with stdin
# closed, pacstrap never confirms, the real mkinitcpio is called by path, and every
# hardware profile names a concrete vulkan-driver provider so the menu cannot
# appear at all.
#
# The grep patterns below are literal shell source, so single quotes are the point.
# shellcheck disable=SC2016
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. run() and run_sh() close stdin.
common="$root/installation/backend/lib/common.sh"
grep -qE '^\s*"\$@" </dev/null$' "$common" \
  || fail "common.sh run() no longer closes stdin; a packaged prompt can block the install"
grep -qE '^\s*bash -c "\$1" </dev/null$' "$common" \
  || fail "common.sh run_sh() no longer closes stdin"

# 2. every pacstrap invocation is non-interactive, and the flag sits after the
#    root (pacstrap parses only short options; a long one before /mnt aborts it).
found=0
while IFS= read -r line; do
  found=$((found + 1))
  [[ $line == *--noconfirm* ]] || fail "pacstrap invocation without --noconfirm: $line"
  args=${line#*pacstrap }
  for tok in $args; do
    case $tok in
      /mnt) break ;;
      --*) fail "pacstrap long option '$tok' precedes the root argument: $line" ;;
    esac
  done
done < <(grep -hE '^[^#]*run pacstrap' "$root/installation/backend/lib/pacstrap.sh")
(( found >= 1 )) || fail "found no pacstrap invocation to check"

# 3. the initramfs build calls the real binary by path, never the wrapper.
while IFS= read -r line; do
  fail "chroot mkinitcpio call resolves through /usr/local/bin (the prompting wrapper): $line"
done < <(grep -hnE '^[^#]*arch-chroot /mnt mkinitcpio' "$root/installation/backend/lib/"*.sh || true)
grep -qE 'arch-chroot /mnt /usr/bin/mkinitcpio -P' "$root/installation/backend/lib/bootloader.sh" \
  || fail "bootloader.sh no longer builds the initramfs via /usr/bin/mkinitcpio"

# 4. every in-chroot pacman transaction is non-interactive.
while IFS= read -r line; do
  [[ $line == *"log \""* || $line == *"DRYRUN"* ]] && continue
  [[ $line == *-S* ]] || continue
  [[ $line == *--noconfirm* || $line == *-Sy* || $line == *-Sp* || $line == *-Si* ]] \
    || fail "in-chroot pacman transaction without --noconfirm: $line"
done < <(grep -rhE '^[^#]*(arch-chroot /mnt pacman|ryoku_offline_pacman) ' \
  "$root/installation/backend/lib/" || true)

# 5. every hardware profile pins a concrete vulkan-driver provider, so pacman has
#    no provider menu to ask about. amd-nvidia is [amd]+[intel]+[nvidia], so each
#    section on its own has to carry one.
hw="$root/system/packages/hardware.packages"
providers='vulkan-radeon|vulkan-intel|vulkan-swrast|vulkan-nouveau|nvidia-utils|nvidia-[0-9]+xx-utils'
section=""
declare -A pin64=() pin32=()
while IFS= read -r line; do
  if [[ $line =~ ^\[([a-z0-9_-]+)\]$ ]]; then
    section=${BASH_REMATCH[1]}
    pin64[$section]=0
    pin32[$section]=0
    continue
  fi
  [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
  [[ -n $section ]] || continue
  [[ $line =~ ^lib32-($providers)$ ]] && pin32[$section]=1
  [[ $line =~ ^($providers)$ ]] && pin64[$section]=1
done <"$hw"
(( ${#pin64[@]} >= 4 )) || fail "hardware.packages lost a profile section (found ${#pin64[@]})"
# both virtuals get their own menu, so both need a named provider.
for s in "${!pin64[@]}"; do
  (( pin64[$s] == 1 )) \
    || fail "hardware.packages [$s] names no vulkan-driver provider; pacstrap will stop on a provider menu"
  (( pin32[$s] == 1 )) \
    || fail "hardware.packages [$s] names no lib32-vulkan-driver provider; pacstrap will stop on a provider menu"
done

echo "install-noninteractive: OK"
