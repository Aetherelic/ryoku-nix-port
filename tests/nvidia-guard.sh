#!/usr/bin/env bash
# Regression test for ryoku-nvidia-guard, the heal that breaks the SDDM login
# loop. The trap: nouveau blacklisted with no nvidia module for any installed
# kernel (a DKMS build that failed on a kernel update). No driver then binds the
# card, so the greeter draws on simpledrm but Hyprland cannot, and SDDM bounces
# the login forever. The guard runs from the pacman hook and must restore nouveau
# in that case, rebuild the initramfs when the baked module could be stale, and
# stay a no-op on a healthy box, a non-NVIDIA box, or mid-install.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
guard="$root/system/hardware/drivers/ryoku-nvidia-guard"
fail() { echo "FAIL: $1" >&2; exit 1; }

[[ -x $guard ]] || fail "guard is not executable: $guard"

# Per-case fixture: the two drop-ins, a kernel modules dir, a hooks dir, and stub
# pacman/modinfo/limine-mkinitcpio on PATH. The stubs read env so each case picks
# "which packages" and "is the module present"; the rebuild stub drops a marker so
# a rebuild is observable.
setup() {
  work=$(mktemp -d)
  mkdir -p "$work/bin" "$work/modprobe.d" "$work/mkinitcpio.d" "$work/hooks" "$work/modules/6.16.0-test"
  cat >"$work/bin/pacman" <<'SH'
#!/usr/bin/env bash
[[ ${1:-} == -Qq ]] && { printf '%s\n' ${RYOKU_TEST_PKGS:-}; exit 0; }
exit 0
SH
  cat >"$work/bin/modinfo" <<'SH'
#!/usr/bin/env bash
[[ ${RYOKU_TEST_MODULE:-0} == 1 ]] && exit 0
exit 1
SH
  cat >"$work/bin/limine-mkinitcpio" <<SH
#!/usr/bin/env bash
touch "$work/rebuilt"
SH
  chmod +x "$work/bin/"*
}
teardown() { rm -rf "$work"; }

# lay the blacklist + early-KMS drop-ins system/hardware/drivers/nvidia.sh writes.
blacklist() {
  cat >"$work/modprobe.d/nvidia.conf" <<'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
blacklist nouveau
options nouveau modeset=0
EOF
  printf 'MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)\n' >"$work/mkinitcpio.d/nvidia.conf"
}

# run the guard with the fixture wired in; $1 = stdin (NeedsTargets lines). The
# caller exports RYOKU_TEST_PKGS / RYOKU_TEST_MODULE for the stubs.
run_guard() {
  PATH="$work/bin:$PATH" \
    RYOKU_MODPROBE_CONF="$work/modprobe.d/nvidia.conf" \
    RYOKU_MKINITCPIO_CONF="$work/mkinitcpio.d/nvidia.conf" \
    RYOKU_HOOKS_DIR="$work/hooks" \
    RYOKU_MODULES_DIR="$work/modules" \
    bash "$guard" <<<"$1"
}
blacklisted() { [[ -f $work/modprobe.d/nvidia.conf ]]; }
rebuilt() { [[ -e $work/rebuilt ]]; }

# 1. the login loop: dkms box, kernel update, module failed to build -> restore
#    nouveau (remove both drop-ins) and rebuild.
setup
export RYOKU_TEST_PKGS="nvidia-open-dkms nvidia-utils" RYOKU_TEST_MODULE=0
blacklist
run_guard "usr/lib/modules/6.16.0-test/vmlinuz" || fail "1: guard exited non-zero"
blacklisted && fail "1: stale nouveau blacklist was not removed (login loop persists)"
[[ -f $work/mkinitcpio.d/nvidia.conf ]] && fail "1: stale early-KMS drop-in was not removed"
rebuilt || fail "1: initramfs was not rebuilt after the heal"
teardown

# 2. healthy prebuilt box, kernel-only bump: module present, not dkms -> keep the
#    blacklist and DO NOT rebuild (the kernel's own mkinitcpio hook already did).
setup
export RYOKU_TEST_PKGS="nvidia-open nvidia-utils" RYOKU_TEST_MODULE=1
blacklist
run_guard "usr/lib/modules/6.16.0-test/vmlinuz" || fail "2: guard exited non-zero"
blacklisted || fail "2: healthy box lost its nouveau blacklist"
rebuilt && fail "2: prebuilt kernel bump triggered a redundant rebuild"
teardown

# 3. driver-only update on a healthy box: the baked .ko is now stale -> rebuild,
#    blacklist kept.
setup
export RYOKU_TEST_PKGS="nvidia-open nvidia-utils" RYOKU_TEST_MODULE=1
blacklist
run_guard "nvidia-utils" || fail "3: guard exited non-zero"
blacklisted || fail "3: driver update dropped the blacklist"
rebuilt || fail "3: driver update did not rebuild the initramfs"
teardown

# 4. non-NVIDIA box: no nvidia package, no blacklist -> pure no-op.
setup
export RYOKU_TEST_PKGS="mesa vulkan-radeon" RYOKU_TEST_MODULE=0
run_guard "usr/lib/modules/6.16.0-test/vmlinuz" || fail "4: guard exited non-zero"
rebuilt && fail "4: non-NVIDIA box rebuilt the initramfs"
teardown

# 5. mid-install: the backend has parked the kernel hook (*.ryoku-off), so the
#    initramfs is deferred to the bootloader step. Even with the trap present the
#    guard must do nothing: no heal, no rebuild.
setup
export RYOKU_TEST_PKGS="nvidia-open-dkms nvidia-utils" RYOKU_TEST_MODULE=0
blacklist
touch "$work/hooks/90-mkinitcpio-install.hook.ryoku-off"
run_guard "usr/lib/modules/6.16.0-test/vmlinuz" || fail "5: guard exited non-zero"
blacklisted || fail "5: guard healed during an install instead of deferring"
rebuilt && fail "5: guard rebuilt the initramfs during a deferred install"
teardown

echo "nvidia-guard: OK"
