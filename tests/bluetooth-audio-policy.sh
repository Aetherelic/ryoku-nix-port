#!/usr/bin/env bash
# Verify the shipped WirePlumber fragment changes the effective session policy,
# rather than merely being syntactically present in the repository.
#
# This asserted `autoswitch-to-headset-profile: false` from the day it was
# written, and kept asserting it after the shipped policy deliberately became
# `true` (a Bluetooth mic did not work at all with it off). So it failed for
# weeks while describing an intent Ryoku had abandoned, which is worse than no
# test: a red suite everyone learns to ignore. It now pins the policy that
# actually ships, and the codec order along with it, so changing either is a
# deliberate act with a test to update.
set -euo pipefail

ROOT=${RYOKU_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
if ! command -v pw-config >/dev/null 2>&1; then
  printf 'SKIP: pw-config is unavailable\n'
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/wireplumber/wireplumber.conf.d"
cp /usr/share/wireplumber/wireplumber.conf "$work/wireplumber/"
cp "$ROOT/ryoku/apps/wireplumber/wireplumber.conf.d/51-ryoku-bluetooth.conf" \
  "$work/wireplumber/wireplumber.conf.d/"

fail() { printf 'FAIL: %s\n%s\n' "$1" "${2:-}" >&2; exit 1; }

# 1. The mic profile switch stays ON. A device that cannot offer a microphone to
#    any app is the louder bug; the per-device A2DP pin is the escape hatch for
#    anyone who would rather keep pristine playback.
settings=$(PIPEWIRE_CONFIG_DIR="$work/wireplumber" pw-config -N -n wireplumber.conf merge wireplumber.settings)
[[ $settings == *'"bluetooth.autoswitch-to-headset-profile": true'* ]] \
  || fail "the shipped policy no longer engages the headset profile for a mic" "$settings"

# 2. sbc_xq must outrank aac. This is the whole fix for "Bluetooth sounds
#    terrible on Samsung": those buds offer neither LDAC nor aptX, so they land
#    on whichever of these two comes first, and on Linux AAC is the weaker
#    encoder. Asserted by position, not presence, because presence was never the
#    problem.
props=$(PIPEWIRE_CONFIG_DIR="$work/wireplumber" pw-config -N -n wireplumber.conf merge monitor.bluez.properties)
# pw-config prints the array as bare, space-separated tokens:
#   "bluez5.codecs": [ ldac aptx_hd aptx sbc_xq aac sbc ]
codecs=$(printf '%s' "$props" | tr '\n' ' ' | sed -n 's/.*"bluez5\.codecs"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p')
[[ -n $codecs ]] || fail "no bluez5.codecs list reached the effective config" "$props"

xq=-1 aac=-1 i=0
read -r -a list <<<"$codecs"
for c in "${list[@]}"; do
  c=${c//\"/}
  [[ $c == sbc_xq ]] && xq=$i
  [[ $c == aac ]] && aac=$i
  i=$((i + 1))
done
(( xq >= 0 )) || fail "sbc_xq is not an enabled codec" "$codecs"
(( aac >= 0 )) || fail "aac is not an enabled codec" "$codecs"
(( xq < aac )) || fail "aac outranks sbc_xq, so LDAC-less devices (Samsung Buds) get the weaker encoder" "$codecs"

# 3. The high-quality codecs still win outright when a device offers them.
#    Preferring sbc_xq over aac must not have demoted them.
for better in ldac aptx_hd aptx; do
  pos=-1 i=0
  for c in "${list[@]}"; do
    c=${c//\"/}
    [[ $c == "$better" ]] && pos=$i
    i=$((i + 1))
  done
  (( pos >= 0 )) || fail "$better is not an enabled codec" "$codecs"
  (( pos < xq )) || fail "$better no longer outranks sbc_xq" "$codecs"
done

printf 'PASS: mic profile switches on demand, and sbc_xq outranks aac while LDAC/aptX still win\n'
