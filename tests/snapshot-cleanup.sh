#!/usr/bin/env bash
# REAL snapper + btrfs test for the snapshot-retention fix (ryoku/cli/internal/
# updater/update.go snapperPost, ryoku/cli/internal/doctor/reconcile_snapshots.go).
# It reproduces the runaway growth (snapshots pile up when cleanup never runs),
# then proves the fix: `snapper cleanup number` bounds the numbered pile to
# NUMBER_LIMIT, and the doctor drain removes the Cleanup=timeline snapshots that
# number cleanup skips (the leak behind the 400 GB reports). Isolated to a
# loop-device btrfs via `snapper --no-dbus --root`, so nothing touches the live
# root or /etc/snapper.
#
# needs root + snapper + btrfs + loop devices; skips (exit 0) otherwise so a
# non-root CI job stays green. run: sudo bash "$0".
set -euo pipefail

fail() { echo "FAIL: $1" >&2; exit 1; }
skip() { echo "snapshot-cleanup: SKIP ($1)"; exit 0; }

[[ $EUID -eq 0 ]] || skip "not root; needs losetup/mkfs.btrfs/snapper (run: sudo bash $0)"
for t in losetup mkfs.btrfs btrfs snapper truncate awk mountpoint unshare; do
  command -v "$t" >/dev/null 2>&1 || skip "missing $t"
done

# snapper runs client plugins from /usr/lib/snapper/plugins on every operation;
# on a Ryoku box the limine-snapper-sync plugin fails against this throwaway
# root and aborts snapper. Re-exec in a private mount namespace so the host
# plugin dir can be hidden without touching the real system.
if [[ -z ${RYOKU_SNAPTEST_NS:-} ]]; then
  export RYOKU_SNAPTEST_NS=1
  exec unshare -m --propagation private -- bash "$0" "$@"
fi

# loop devices must actually work (a locked-down runner may have the tools but
# no usable loop device): probe once and skip if attaching fails.
probe_img="$(mktemp --suffix=.ryoku-snapprobe.img)"
truncate -s 8M "$probe_img" 2>/dev/null || { rm -f "$probe_img"; skip "cannot create a sparse file"; }
probe_loop="$(losetup -f --show "$probe_img" 2>/dev/null || true)"
[[ -n $probe_loop ]] || { rm -f "$probe_img"; skip "loop devices unavailable"; }
losetup -d "$probe_loop" 2>/dev/null || true
rm -f "$probe_img"

LOOP=""; IMG=""; MNT=""; _empty=""
cleanup() {
  [[ -n $MNT ]] && mountpoint -q "$MNT" 2>/dev/null && umount -R "$MNT" 2>/dev/null || true
  [[ -n $LOOP ]] && losetup -d "$LOOP" 2>/dev/null || true
  [[ -n $IMG ]] && rm -f "$IMG" 2>/dev/null || true
  [[ -n $MNT ]] && rm -rf "$MNT" 2>/dev/null || true
  [[ -n $_empty ]] && { umount /usr/lib/snapper/plugins 2>/dev/null; rmdir "$_empty" 2>/dev/null; } || true
}
trap cleanup EXIT

# hide the host snapper plugins in this namespace so none run against the test
# root (the limine-snapper-sync plugin would fail and abort snapper).
if [[ -d /usr/lib/snapper/plugins ]]; then
  _empty="$(mktemp -d)"
  mount --bind "$_empty" /usr/lib/snapper/plugins 2>/dev/null || skip "cannot isolate snapper plugins"
fi

IMG="$(mktemp --suffix=.ryoku-snap.img)"
truncate -s 2G "$IMG"
LOOP="$(losetup -f --show "$IMG")"
mkfs.btrfs -f -L ryokutest "$LOOP" >/dev/null 2>&1 || fail "mkfs.btrfs failed on the loop device"
MNT="$(mktemp -d)"
mount "$LOOP" "$MNT" || fail "could not mount the loop device"

# snapper's create-config needs snapperd (absent under --no-dbus) and system
# templates, so write the config by hand exactly as Ryoku's installer does:
# 5 numbered kept, pruned immediately, no timeline (Ryoku's number-only policy).
btrfs subvolume create "$MNT/.snapshots" >/dev/null || fail "could not create .snapshots subvolume"
chmod 750 "$MNT/.snapshots"
mkdir -p "$MNT/etc/snapper/configs" "$MNT/etc/conf.d"
cat > "$MNT/etc/snapper/configs/root" <<'EOF'
SUBVOLUME="/"
FSTYPE="btrfs"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="0"
NUMBER_LIMIT="5"
NUMBER_LIMIT_IMPORTANT="5"
TIMELINE_CREATE="no"
EOF
printf 'SNAPPER_CONFIGS="root"\n' > "$MNT/etc/conf.d/snapper"

SN=(snapper --no-dbus --root "$MNT" -c root)
"${SN[@]}" list >/dev/null 2>&1 || skip "snapper cannot use a hand-written config here"

# count snapshots with a given cleanup value (base 0 and the header excluded).
count() {
  "${SN[@]}" --csvout list --columns number,cleanup 2>/dev/null |
    awk -F, -v c="$1" 'NR>1 && $1 ~ /^[0-9]+$/ && $1 != "0" && $2 == c' | wc -l
}

# reproduce: without cleanup, numbered snapshots pile up past the limit.
for i in $(seq 1 8); do
  "${SN[@]}" create -c number -d "txn $i" >/dev/null || fail "snapper create failed"
done
n=$(count number)
[[ $n -eq 8 ]] || fail "expected 8 numbered snapshots before cleanup, got $n"
echo "  reproduced: 8 numbered snapshots accumulated, limit is 5 [ok]"

# fix: the prune ryoku update runs inline and the reconciler runs on drift.
"${SN[@]}" cleanup number >/dev/null || fail "snapper cleanup number failed"
n=$(count number)
[[ $n -eq 5 ]] || fail "expected 5 numbered snapshots after cleanup, got $n"
echo "  cleanup number bounded the pile to NUMBER_LIMIT=5 [ok]"

# leak: number cleanup never removes a Cleanup=timeline snapshot (the root cause).
"${SN[@]}" create -c timeline -d "leaked timeline" >/dev/null || fail "snapper create (timeline) failed"
"${SN[@]}" cleanup number >/dev/null || fail "snapper cleanup number failed"
[[ $(count timeline) -eq 1 ]] || fail "number cleanup should leave the timeline snapshot in place"
echo "  confirmed leak: number cleanup leaves Cleanup=timeline snapshots [ok]"

# drain: the reconciler's exact query + delete removes the leaked timeline ones.
leaked="$("${SN[@]}" --csvout list --columns number,cleanup 2>/dev/null |
  awk -F, 'NR>1 && $1 ~ /^[0-9]+$/ && $1 != "0" && $2 == "timeline" { print $1 }')"
[[ -n $leaked ]] || fail "no leaked timeline snapshot to drain"
# shellcheck disable=SC2086  # deliberate word-split: delete takes many numbers
"${SN[@]}" delete $leaked >/dev/null || fail "snapper delete (drain) failed"
[[ $(count timeline) -eq 0 ]] || fail "drain did not remove the leaked timeline snapshot"
[[ $(count number) -eq 5 ]] || fail "drain must not touch numbered snapshots"
echo "  drained leaked timeline snapshots; numbered pile untouched at 5 [ok]"

echo "snapshot-cleanup: all checks passed"
