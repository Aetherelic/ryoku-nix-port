#!/usr/bin/env bash
# Bake the full target package closure into a [offline] file:// repo so the
# installed system pacstraps with NO network (installation/backend/lib/offline.sh).
#
# Downloads (build host needs network + disk) every package a target can reach:
#   base.packages + every hardware.packages profile (amd/intel/nvidia microcode)
#   + dev.packages + the GPU-driver packages the per-vendor
#   scripts install + the Ryoku desktop set (ryoku-keyring, ryoku-desktop).
# Resolves the whole dependency closure against Arch core/extra/multilib and
# [ryoku], into one repo with a repo-add db. TrustAll download
# over TLS; the installed target re-verifies against real keyrings on first -Syu.
#
# usage: offline-repo.sh <REPO_ROOT> <DEST_REPO_DIR> [RYOKU_REPO_URL]
# env:
#   RYOKU_OFFLINE_CACHE   persistent pkg cache (reused across builds; NOT wiped)
#   RYOKU_ARCH_MIRROR     Arch mirror base (default geo.mirror.pkgbuild.com)
#   RYOKU_OFFLINE_MEASURE 1 = resolve + count the closure, then stop (no download)
set -euo pipefail

REPO_ROOT=$1
DEST=$2
RYOKU_REPO_URL=${3:-https://repo.ryoku.dev/stable/x86_64}

ARCH_MIRROR=${RYOKU_ARCH_MIRROR:-https://geo.mirror.pkgbuild.com}
CACHE=${RYOKU_OFFLINE_CACHE:-$REPO_ROOT/installation/iso/offline-cache}
REPO_NAME=offline
VARIANT=${RYOKU_VARIANT:-plain}
CACHY_MIRROR=${RYOKU_CACHYOS_MIRROR:-https://mirror.cachyos.org/repo}

log() { printf '\033[1;36moffline-repo:\033[0m %s\n' "$*"; }
die() { printf 'offline-repo: error: %s\n' "$*" >&2; exit 1; }

command -v pacman >/dev/null 2>&1 || die "pacman not found"
command -v repo-add >/dev/null 2>&1 || die "repo-add not found (pacman package)"

# read a plain one-per-line list, dropping comments + blanks.
read_list() { [[ -f $1 ]] && grep -vE '^[[:space:]]*(#|$)' "$1" || true; }
# read the packages under [section] in an INI file (matches lib/pacstrap.sh).
read_section() {
  awk -v sec="[$2]" '
    $0 == sec { f = 1; next }
    /^\[/ { f = 0 }
    f && NF && $0 !~ /^[[:space:]]*#/ { print }
  ' "$1"
}

pkgdir="$REPO_ROOT/system/packages"
hw="$pkgdir/hardware.packages"

# the full closure's top-level names (deps are pulled in by pacman -S).
mapfile -t PKGS < <(
  read_list "$pkgdir/base.packages"
  read_list "$pkgdir/dev.packages"
  # cachyos variant: the full CachyOS layer (kernel, settings, schedulers, proton).
  [[ $VARIANT == cachyos ]] && read_list "$pkgdir/cachyos.packages"
  # every hardware profile so any machine installs offline (the ISO carries all).
  read_section "$hw" amd
  read_section "$hw" intel
  read_section "$hw" nvidia
  # GPU-driver packages the per-vendor scripts (system/hardware/drivers/*.sh)
  # install. the mutually-conflicting nvidia MODULE packages are fetched
  # separately below (one -Sw each) so every variant lands in the repo; a single
  # resolve would keep only one. nvidia-utils/libva/lib32 don't conflict, so here.
  printf '%s\n' \
    mesa vulkan-radeon lib32-vulkan-radeon \
    intel-media-driver vpl-gpu-rt vulkan-intel lib32-vulkan-intel sof-firmware \
    nvidia-utils lib32-nvidia-utils libva-nvidia-driver \
    vulkan-icd-loader lib32-vulkan-icd-loader \
    broadcom-wl
  # the Ryoku desktop umbrella pulls every monorepo component + its deps.
  printf '%s\n' ryoku-keyring ryoku-desktop
)
# dedupe, keep order.
mapfile -t PKGS < <(printf '%s\n' "${PKGS[@]}" | awk '!seen[$0]++')
log "closure has ${#PKGS[@]} top-level packages (deps resolved by pacman)"

# throwaway pacman config + db so the host's own pacman state is untouched.
# SigLevel = Never for the download: the DBs/packages come over TLS from official
# infra (verifying here would need every repo's key in a host keyring), and the
# installed target re-verifies everything against real keyrings on its first -Syu.
work=$(mktemp -d)
trap 'rm -rf "$work" 2>/dev/null || sudo rm -rf "$work"' EXIT
conf="$work/pacman.conf"
cat >"$conf" <<EOF
[options]
Architecture = x86_64
SigLevel = Never
LocalFileSigLevel = Never
ParallelDownloads = 10

[core]
Server = $ARCH_MIRROR/core/os/x86_64
[extra]
Server = $ARCH_MIRROR/extra/os/x86_64
[multilib]
Server = $ARCH_MIRROR/multilib/os/x86_64

[ryoku]
Server = $RYOKU_REPO_URL
EOF

# cachyos variant: add the generic [cachyos] repo (x86_64) so the closure can
# resolve linux-cachyos + the whole layer offline. the installed target wires the
# arch-optimized [cachyos-v3] repos itself (lib/cachyos.sh) for future updates.
if [[ $VARIANT == cachyos ]]; then
  cat >>"$conf" <<EOF

[cachyos]
Server = $CACHY_MIRROR/x86_64/cachyos
EOF
fi

# pacman -Sy/-Sw need root even with an isolated dbpath/cachedir. use sudo when
# not already root (the ISO build runs mkarchiso under sudo too); --dbpath and
# --cachedir keep the host's real pacman state untouched.
PAC=(pacman); (( EUID == 0 )) || PAC=(sudo pacman)

mkdir -p "$CACHE" "$work/db"
log "syncing repo databases (throwaway db)"
"${PAC[@]}" -Sy --config "$conf" --dbpath "$work/db" --noconfirm >/dev/null

# validate every name + resolve the whole closure BEFORE downloading a gigabyte.
log "resolving the dependency closure"
if ! resolved=$("${PAC[@]}" -Sp --config "$conf" --dbpath "$work/db" --print-format '%n' "${PKGS[@]}" 2>"$work/err"); then
  cat "$work/err" >&2
  die "closure resolution failed (an unknown package name above); fix system/packages or the driver list in offline-repo.sh"
fi
count=$(printf '%s\n' "$resolved" | grep -c . || true)
log "resolved closure: $count packages (with dependencies)"

if [[ ${RYOKU_OFFLINE_MEASURE:-0} == 1 ]]; then
  log "MEASURE mode: not downloading. resolved package count = $count"
  exit 0
fi

# download the whole closure into the persistent cache (--needed skips what a
# prior build already fetched, so a rebuild is a delta, not a re-download).
log "downloading the closure into $CACHE (this is the long pole; cached for reuse)"
"${PAC[@]}" -Sw --config "$conf" --dbpath "$work/db" --cachedir "$CACHE" --noconfirm --needed "${PKGS[@]}"

# the nvidia kernel-module packages all provide NVIDIA-MODULE and conflict
# pairwise, so a single resolve keeps only one. fetch each in its own pass so
# ALL land in the repo and the installer's nvidia.sh can pick per-GPU offline:
#   nvidia-open-dkms  Turing+ (GSP) custom kernel    nvidia-dkms  pre-Turing
#   nvidia-open/nvidia  prebuilt stock-linux modules.
# best-effort per variant (a name absent from the current repos must not abort).
nv=(nvidia-open-dkms nvidia-dkms nvidia-open nvidia)
[[ $VARIANT == cachyos ]] && nv+=(linux-cachyos-nvidia-open)
for v in "${nv[@]}"; do
  "${PAC[@]}" -Sw --config "$conf" --dbpath "$work/db" --cachedir "$CACHE" --noconfirm --needed "$v" \
    || log "note: could not fetch nvidia variant '$v' (not in the current repos?); continuing"
done

# assemble the [offline] repo: reflink every cached package into DEST (btrfs COW,
# so no extra space), then build the db.
log "assembling the [offline] repo at $DEST"
rm -rf "$DEST"; mkdir -p "$DEST"
shopt -s nullglob
pkgs=("$CACHE"/*.pkg.tar.zst "$CACHE"/*.pkg.tar.xz)
(( ${#pkgs[@]} )) || die "no packages in $CACHE after download"
cp -a --reflink=auto "${pkgs[@]}" "$DEST"/
# repo-add builds offline.db(.tar.zst) + offline.files; lib/offline.sh globs it.
repo-add --quiet "$DEST/$REPO_NAME.db.tar.zst" "$DEST"/*.pkg.tar.* >/dev/null

n=$(find "$DEST" -maxdepth 1 -name '*.pkg.tar.*' | wc -l)
sz=$(du -sh "$DEST" | cut -f1)
log "baked $n packages into the [offline] repo ($sz) at $DEST"
