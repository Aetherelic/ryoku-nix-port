#!/usr/bin/env bash
# Regression test for ryoku-hw-backlight: pick the backlight on the CONNECTED
# internal panel, not the first name-sorted device. Multi-backlight laptops
# expose several devices (several amdgpu_bl* for connected + disconnected
# connectors, or nvidia_0 beside amdgpu_bl*), and a fixed name list grabbed the
# wrong one -> dead brightness keys. Select by ground truth: the connected
# eDP/LVDS/DSI connector. Fall back to the name list only with no DRM mapping.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
helper="$here/system/hardware/display/ryoku-hw-backlight"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

run() { RYOKU_BACKLIGHT_PATH="$tmp/bl" RYOKU_DRM_PATH="$tmp/drm" "$helper"; }
reset() { rm -rf "$tmp/bl" "$tmp/drm" "$tmp/pci"; mkdir -p "$tmp/bl" "$tmp/drm" "$tmp/pci"; }

# 1. Two amdgpu_bl*: the panel is on the connected connector (bl2/eDP-2), bl0's
#    connector is disconnected. Must pick bl2, not the name-first bl0.
reset
mkdir -p "$tmp/drm/card2-eDP-0" "$tmp/drm/card2-eDP-2" "$tmp/bl/amdgpu_bl0" "$tmp/bl/amdgpu_bl2"
printf 'disconnected\n' >"$tmp/drm/card2-eDP-0/status"
printf 'connected\n'    >"$tmp/drm/card2-eDP-2/status"
ln -s "$tmp/drm/card2-eDP-0" "$tmp/bl/amdgpu_bl0/device"
ln -s "$tmp/drm/card2-eDP-2" "$tmp/bl/amdgpu_bl2/device"
got="$(run)"
[[ $got == amdgpu_bl2 ]] || { echo "FAIL: multi amdgpu_bl picked '$got', want amdgpu_bl2" >&2; exit 1; }

# 2. nvidia_0 whose `device` is the GPU's PCI node, and the connected panel is on
#    that card -> resolve through the PCI node and pick nvidia_0.
reset
mkdir -p "$tmp/pci/gpu" "$tmp/drm/card0" "$tmp/drm/card0-eDP-1" "$tmp/bl/nvidia_0"
ln -s "$tmp/pci/gpu" "$tmp/drm/card0/device"
ln -s "$tmp/pci/gpu" "$tmp/bl/nvidia_0/device"
printf 'connected\n' >"$tmp/drm/card0-eDP-1/status"
got="$(run)"
[[ $got == nvidia_0 ]] || { echo "FAIL: nvidia-driven panel picked '$got', want nvidia_0" >&2; exit 1; }

# 3. A backlight whose only panel connector is disconnected is NOT chosen over
#    the name-list fallback: no connected panel anywhere -> name list (amdgpu).
reset
mkdir -p "$tmp/drm/card0-eDP-0" "$tmp/bl/amdgpu_bl0" "$tmp/bl/nvidia_wmi_ec_backlight"
printf 'disconnected\n' >"$tmp/drm/card0-eDP-0/status"
ln -s "$tmp/drm/card0-eDP-0" "$tmp/bl/amdgpu_bl0/device"
got="$(run)"
[[ $got == amdgpu_bl0 ]] || { echo "FAIL: fallback picked '$got', want amdgpu_bl0" >&2; exit 1; }

# 4. No DRM tree at all -> name-priority list still works (amdgpu over the EC path).
reset
mkdir -p "$tmp/bl/nvidia_wmi_ec_backlight" "$tmp/bl/amdgpu_bl0"
got="$(run)"
[[ $got == amdgpu_bl0 ]] || { echo "FAIL: no-DRM fallback picked '$got', want amdgpu_bl0" >&2; exit 1; }

echo "backlight-pick: ok"
