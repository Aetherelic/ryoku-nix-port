#!/usr/bin/env bash
# Regression test for #54: ryoku-hw-backlight-fix must not apply the AMD-only
# acpi_backlight=native quirk on Intel+NVIDIA laptops, where the NVIDIA WMI EC
# backlight (nvidia_wmi_ec_backlight) also registers even though no AMD GPU
# exists. The gate must require a real AMD GPU (PCI vendor 0x1002) first.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
helper="$here/system/hardware/display/ryoku-hw-backlight-fix"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# fake sysfs: two DRM cards (card0 is the iGPU, card1 the NVIDIA dGPU) plus a
# backlight dir. $1 = amd|intel picks card0's PCI vendor.
setup() {
  local kind="$1" vendor="0x8086"
  [[ $kind == amd ]] && vendor="0x1002"
  rm -rf "$tmp/drm" "$tmp/bl"
  mkdir -p "$tmp/drm/card0/device" "$tmp/drm/card1/device" "$tmp/bl"
  printf '%s\n' "$vendor" >"$tmp/drm/card0/device/vendor"
  printf '%s\n' "0x10de" >"$tmp/drm/card1/device/vendor"
}

run_fix() {
  RYOKU_DRYRUN=1 RYOKU_DRM_PATH="$tmp/drm" RYOKU_BACKLIGHT_PATH="$tmp/bl" \
    RYOKU_DROPIN="$tmp/dropin.conf" "$helper" 2>&1
}

# 1. Intel+NVIDIA, nvidia_wmi_ec_backlight present, no amdgpu_bl: must NOT fire.
setup intel
mkdir -p "$tmp/bl/nvidia_wmi_ec_backlight"
out="$(run_fix)"
case "$out" in
  *"no AMD GPU"*) ;;
  *) echo "FAIL: fired on Intel+NVIDIA (#54): $out" >&2; exit 1 ;;
esac
case "$out" in
  *write*) echo "FAIL: wrote a drop-in on Intel+NVIDIA (#54): $out" >&2; exit 1 ;;
esac

# 2. ASUS AMD+NVIDIA, nvidia_wmi_ec present, no amdgpu_bl: must apply the fix.
setup amd
mkdir -p "$tmp/bl/nvidia_wmi_ec_backlight"
out="$(run_fix)"
case "$out" in
  *"write $tmp/dropin.conf"*) ;;
  *) echo "FAIL: did not apply the fix on AMD+NVIDIA: $out" >&2; exit 1 ;;
esac

# 3. AMD present but amdgpu_bl* already works: no-op.
setup amd
mkdir -p "$tmp/bl/nvidia_wmi_ec_backlight" "$tmp/bl/amdgpu_bl0"
out="$(run_fix)"
case "$out" in
  *"already present"*) ;;
  *) echo "FAIL: did not no-op when amdgpu_bl* exists: $out" >&2; exit 1 ;;
esac

echo "backlight-fix-gate: ok"
