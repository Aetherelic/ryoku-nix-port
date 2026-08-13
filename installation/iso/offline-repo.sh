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
# every variant lands in the repo and the installer's nvidia.sh can pick per-GPU
# offline. nvidia-open (prebuilt, stock linux) and nvidia-open-dkms (custom
# kernels) are what every supported card installs (Turing+, the only GPUs the
# open module and the current repos cover), so they are REQUIRED: a missing one
# is the driverless NVIDIA desktop from issue #30 and must fail the build, not
# slip through a warning. the rest are genuinely optional per kernel/variant.
nv_required=(nvidia-open nvidia-open-dkms)
nv_optional=(nvidia-open-lts)
[[ $VARIANT == cachyos ]] && nv_optional+=(linux-cachyos-nvidia-open)
for v in "${nv_required[@]}"; do
  "${PAC[@]}" -Sw --config "$conf" --dbpath "$work/db" --cachedir "$CACHE" --noconfirm --needed "$v" \
    || die "required NVIDIA driver '$v' could not be fetched; an NVIDIA target would install to a driverless desktop. check the [extra] mirror and that the package still exists."
done
for v in "${nv_optional[@]}"; do
  "${PAC[@]}" -Sw --config "$conf" --dbpath "$work/db" --cachedir "$CACHE" --noconfirm --needed "$v" \
    || log "note: optional nvidia variant '$v' not fetched (absent from the current repos?); continuing"
done

# Bundle the AUR toolset into the offline repo. Every ISO install is offline, so
# the AUR set an online install builds (voxtype, brand fonts, extra cursors, game
# controllers, localsend, ...) never lands otherwise: system/packages/aur.packages
# is skipped on an offline install. Build each with makepkg on the networked build
# host (the target has no toolchain), pull its runtime deps into the closure so it
# resolves offline, and cache the result in $CACHE so a rebuild is a delta. Best
# effort per package: a flaky AUR source or heavy build warns and is skipped
# rather than failing the release, and lib/offline.sh installs the set best-effort
# too. This is how omarchy bakes its packages into its offline mirror.
bake_aur_set() {
  local aur_file="$REPO_ROOT/system/packages/aur.packages"
  [[ -f $aur_file ]] || return 0
  if ! { command -v makepkg && command -v git && command -v curl; } >/dev/null 2>&1; then
    log "AUR bake: makepkg/git/curl missing; skipping (base-devel not installed on the build host)"
    return 0
  fi

  local -a names=()
  mapfile -t names < <(read_list "$aur_file")
  # bundle the AUR-legacy NVIDIA drivers alongside the toolset: pre-Turing cards
  # (Maxwell/Pascal/Volta -> 580xx, Kepler -> 470xx) are not covered by nvidia-open
  # and Arch dropped the closed driver, so without these an offline install of a
  # GTX 9xx/10xx box comes up with no driver and no desktop. building a -dkms
  # pkgbase also produces its -utils; lib32 is its own base.
  names+=(nvidia-580xx-dkms lib32-nvidia-580xx-utils nvidia-470xx-dkms)
  (( ${#names[@]} )) || return 0

  # makepkg refuses to run as root: build as an unprivileged user with passwordless
  # pacman so -s can sync build deps. a non-root build host builds as itself.
  local builder="" 
  local -a as=()
  if (( EUID == 0 )); then
    builder=ryoku-aurbuild
    id "$builder" &>/dev/null || useradd -m -s /bin/bash "$builder"
    printf '%s ALL=(ALL) NOPASSWD: /usr/bin/pacman\n' "$builder" >/etc/sudoers.d/99-ryoku-aurbuild
    chmod 0440 /etc/sudoers.d/99-ryoku-aurbuild
    as=(runuser -u "$builder" --)
  fi

  local bdir out n base src f dep
  bdir=$(mktemp -d); out="$bdir/out"; mkdir -p "$out"; chmod -R 0777 "$bdir"
  local -a built=() failed=() deps=()
  log "AUR bake: building ${#names[@]} package(s) into the offline repo"
  for n in "${names[@]}"; do
    # cache hit from a prior build (clear $CACHE to force a fresh build).
    if compgen -G "$CACHE/$n-*.pkg.tar.*" >/dev/null 2>&1; then built+=("$n(cached)"); continue; fi
    # split packages: the AUR git is keyed by PackageBase, not the pkgname.
    base=$(curl -fsSL "https://aur.archlinux.org/rpc/v5/info?arg[]=$n" 2>/dev/null \
      | grep -oE '"PackageBase":[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/')
    [[ -n $base ]] || base=$n
    src="$bdir/$base"; rm -rf "$src"
    if ! git clone -q --depth 1 "https://aur.archlinux.org/$base.git" "$src" 2>/dev/null || [[ ! -f $src/PKGBUILD ]]; then
      log "AUR bake: skip $n (could not fetch '$base' from the AUR)"; failed+=("$n"); continue
    fi
    (( EUID == 0 )) && chown -R "$builder:$builder" "$src"
    local -a envv=(env "PKGDEST=$out")
    [[ -n $builder ]] && envv=(env "HOME=/home/$builder" "PKGDEST=$out")
    if ( cd "$src" && "${as[@]}" "${envv[@]}" makepkg -s --noconfirm --skippgpcheck --needed >/dev/null 2>&1 ); then
      built+=("$n")
    else
      log "AUR bake: skip $n (build failed)"; failed+=("$n")
    fi
  done

  # move built packages into the cache and pull each one's runtime deps into the
  # closure, so it installs conflict-free from the baked repo on the target.
  shopt -s nullglob
  for f in "$out"/*.pkg.tar.*; do
    [[ $f == *.sig ]] && continue
    while IFS= read -r dep; do [[ -n $dep ]] && deps+=("$dep"); done \
      < <(bsdtar -xOf "$f" .PKGINFO 2>/dev/null | sed -n 's/^depend = //p' | sed 's/[<>=:].*//')
    cp -a "$f" "$CACHE"/
  done
  if (( ${#deps[@]} )); then
    mapfile -t deps < <(printf '%s\n' "${deps[@]}" | awk 'NF && !seen[$0]++')
    "${PAC[@]}" -Sw --config "$conf" --dbpath "$work/db" --cachedir "$CACHE" --noconfirm --needed "${deps[@]}" \
      || log "AUR bake: note, some runtime deps did not fetch; those tools may not install offline"
  fi

  (( EUID == 0 )) && rm -f /etc/sudoers.d/99-ryoku-aurbuild
  rm -rf "$bdir"
  log "AUR bake: bundled ${#built[@]} (${built[*]:-none}); skipped ${#failed[@]} (${failed[*]:-none})"
}
# best-effort: the AUR bake must never fail the release build. calling it in a
# `||` context also disables `set -e` inside it, so any unhandled error there
# degrades to a pacman-closure-only offline repo instead of bricking the ISO.
bake_aur_set || log "AUR bake: unexpected error; continuing with the pacman closure only"

# assemble the [offline] repo: reflink every cached package into DEST (btrfs COW,
# so no extra space), then build the db.
log "assembling the [offline] repo at $DEST"
rm -rf "$DEST"; mkdir -p "$DEST"
shopt -s nullglob
pkgs=("$CACHE"/*.pkg.tar.zst "$CACHE"/*.pkg.tar.xz)
(( ${#pkgs[@]} )) || die "no packages in $CACHE after download"
cp -a --reflink=auto "${pkgs[@]}" "$DEST"/

# repo_has_pkg / pkgfile_for NAME: is package NAME baked into the repo, and which
# file is it? a package filename is NAME-VER-REL-ARCH.pkg.tar.*; VER and REL never
# contain '-', so stripping the three trailing '-' fields recovers NAME exactly.
# matching by that stem (not a "NAME-<digit>" glob) is correct for a version that
# starts with a letter (libyuv-r2426+..., a git r<rev> build) and still keeps a
# name that is a prefix of another apart (nvidia-open vs nvidia-open-dkms).
pkgfile_for() {
  local want=$1 f base stem
  for f in "$DEST/$want"-*.pkg.tar.*; do
    [[ -e $f ]] || continue
    base=${f##*/}; base=${base%.pkg.tar.*}            # NAME-VER-REL-ARCH
    stem=${base%-*}; stem=${stem%-*}; stem=${stem%-*} # drop ARCH, REL, VER
    [[ $stem == "$want" ]] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}
repo_has_pkg() { pkgfile_for "$1" >/dev/null; }
missing=()
for req in nvidia-open nvidia-open-dkms nvidia-utils libva-nvidia-driver \
           mesa vulkan-radeon vulkan-intel vulkan-icd-loader \
           ryoku-keyring ryoku-desktop; do
  repo_has_pkg "$req" || missing+=("$req")
done
(( ${#missing[@]} == 0 )) || die "offline repo is missing required packages: ${missing[*]}. the install would leave a driverless or incomplete desktop."
# pre-Turing NVIDIA (Maxwell/Pascal/Volta) needs the AUR-legacy 580xx driver,
# built best-effort above. warn loudly if it did not land: those cards then
# install offline with no driver and no desktop. not fatal -- Turing+ and
# non-NVIDIA targets are unaffected, so a transient AUR outage must not block
# an otherwise-complete release.
repo_has_pkg nvidia-580xx-dkms || log "WARNING: nvidia-580xx-dkms did not bake into the offline repo; pre-Turing NVIDIA targets (GTX 9xx/10xx) will install with no driver. Check the AUR bake log above."
# repo-add builds offline.db(.tar.zst) + offline.files; lib/offline.sh globs it.
repo-add --quiet "$DEST/$REPO_NAME.db.tar.zst" "$DEST"/*.pkg.tar.* >/dev/null

# verify the exact pacstrap transaction resolves and installs conflict-free from
# ONLY the baked repo. the installer folds the whole desktop set into one offline
# pacstrap (lib/offline.sh), so any two packages shipping the same path -- an
# upstream churn window like default-cursors taking over an icon file another
# package still owns -- makes pacman abort "conflicting files ... exists in
# filesystem", and offline there is no network to recover with: the ISO is a
# brick. catch it HERE, on the networked build host where a rebuild is cheap,
# not at install time. doubles as a closure-completeness check: every resolved
# dependency must be in the repo (a missing dep is the same dead end offline).
verify_offline_closure() {
  local vconf="$work/verify.conf" vdb="$work/verify-db"
  mkdir -p "$vdb"
  cat >"$vconf" <<EOF
[options]
Architecture = x86_64 x86_64_v3
SigLevel = Never
[$REPO_NAME]
SigLevel = Never
Server = file://$DEST
EOF
  "${PAC[@]}" -Sy --config "$vconf" --dbpath "$vdb" --noconfirm >/dev/null 2>&1 \
    || die "offline verify: cannot read the baked [$REPO_NAME] db at $DEST"

  # the installer's pacstrap set (lib/pacstrap.sh ryoku_pacstrap): base + dev +
  # [cachy] + BOTH microcodes (they never conflict) + the desktop set folded in
  # by ryoku_offline_pacstrap_extra. GPU drivers are the in-chroot driver step,
  # NOT pacstrap, and the nvidia module variants conflict pairwise, so they are
  # excluded here (repo_has_pkg above already proved them present in the repo).
  local -a pset=()
  mapfile -t pset < <( {
    read_list "$pkgdir/base.packages"
    read_list "$pkgdir/dev.packages"
    [[ $VARIANT == cachyos ]] && read_list "$pkgdir/cachyos.packages"
    printf '%s\n' amd-ucode intel-ucode ryoku-keyring ryoku-desktop
  } | awk '!seen[$0]++' )

  local resolved
  if ! resolved=$("${PAC[@]}" -Sp --print-format '%n' --config "$vconf" --dbpath "$vdb" "${pset[@]}" 2>"$work/verify.err"); then
    log "offline verify: the pacstrap set does not yet resolve from the baked repo (a dependency is missing from the closure):
$(sed 's/^/  /' "$work/verify.err")"
    return 1
  fi

  # map each resolved name to its .pkg in the repo, then list every package's
  # files in ONE pass (pacman -Qlp = "pkgname /path", metadata excluded). a path
  # owned by more than one package is the pacstrap file conflict.
  local name f
  local -a pkgfiles=() vmissing=()
  while IFS= read -r name; do
    [[ -n $name ]] || continue
    if f=$(pkgfile_for "$name"); then
      pkgfiles+=("$f")
    else
      vmissing+=("$name")
    fi
  done <<<"$resolved"
  if (( ${#vmissing[@]} )); then
    log "offline verify: ${#vmissing[@]} resolved package(s) not yet in the baked repo: ${vmissing[*]}"
    return 1
  fi

  local conflicts
  conflicts=$(pacman -Qlp "${pkgfiles[@]}" 2>/dev/null | awk '$2 !~ /\/$/ {print $2" "$1}' | sort | awk '
    { p=$1; k=$2
      if (p!=q){ if(c>1) print q"  <=  "o; q=p; o=k; c=1; s=" "k" " }
      else if (index(s," "k" ")==0){ o=o", "k; c++; s=s k" " } }
    END{ if(c>1) print q"  <=  "o }')
  [[ -z $conflicts ]] || die "offline verify: the baked closure has file conflicts -- pacstrap would abort on the target, offline, with no way to recover:
$(printf '%s\n' "$conflicts" | sed 's/^/  /')
This is usually a transient upstream churn window (one package taking over a file another still ships). Re-run the bake once the mirrors settle, or pin/patch the offending package."

  log "offline verify: pacstrap set resolves ($(grep -c . <<<"$resolved") packages) with no file conflicts"
}
# A resolved dependency can be missing from the freshly baked repo when a mirror
# is mid-sync: its db lists a package before that package's file has propagated,
# so the closure reads as incomplete through no fault of ours. Retry with a db
# refresh and a re-download a few times, so a transient mirror window self-heals
# instead of bricking the release build; a genuinely absent package still fails.
for _vattempt in 1 2 3; do
  verify_offline_closure && break
  (( _vattempt == 3 )) && die "offline verify: the baked closure is still incomplete after $_vattempt attempts; a mirror is likely mid-sync (a dependency's db entry is ahead of its package file). Re-run the bake once the mirrors settle."
  log "offline verify: closure incomplete (attempt $_vattempt); re-syncing the db and re-downloading before retrying"
  "${PAC[@]}" -Sy --config "$conf" --dbpath "$work/db" --noconfirm >/dev/null
  "${PAC[@]}" -Sw --config "$conf" --dbpath "$work/db" --cachedir "$CACHE" --noconfirm --needed "${PKGS[@]}"
  rpkgs=("$CACHE"/*.pkg.tar.zst "$CACHE"/*.pkg.tar.xz)
  (( ${#rpkgs[@]} )) && cp -a --reflink=auto "${rpkgs[@]}" "$DEST"/
  repo-add --quiet "$DEST/$REPO_NAME.db.tar.zst" "$DEST"/*.pkg.tar.* >/dev/null
  sleep 20
done

n=$(find "$DEST" -maxdepth 1 -name '*.pkg.tar.*' | wc -l)
sz=$(du -sh "$DEST" | cut -f1)
log "baked $n packages into the [offline] repo ($sz) at $DEST"
