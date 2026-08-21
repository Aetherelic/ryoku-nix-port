#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
helper="$here/system/hardware/input/ryoku-hw-asus-aura"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/class/dmi/id" "$tmp/bus/platform/drivers/asus-nb-wmi" "$tmp/devices"

printf '%s\n' 'ASUSTeK COMPUTER INC.' >"$tmp/class/dmi/id/sys_vendor"
printf '%s\n' 'ROG Zephyrus G14' >"$tmp/class/dmi/id/product_family"
RYOKU_ASUS_SYSFS="$tmp" "$helper"

printf '%s\n' 'Dell Inc.' >"$tmp/class/dmi/id/sys_vendor"
if RYOKU_ASUS_SYSFS="$tmp" "$helper"; then
  echo 'non-ASUS hardware matched Aura support' >&2
  exit 1
fi

printf '%s\n' 'ASUS' >"$tmp/class/dmi/id/sys_vendor"
printf '%s\n' 'Other' >"$tmp/class/dmi/id/product_family"
if RYOKU_ASUS_SYSFS="$tmp" "$helper"; then
  echo 'unsupported ASUS family matched without a driver' >&2
  exit 1
fi
ln -s "$tmp/devices" "$tmp/bus/platform/drivers/asus-nb-wmi/ASUS0001:00"
RYOKU_ASUS_SYSFS="$tmp" "$helper"
