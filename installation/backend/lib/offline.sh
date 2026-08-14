#!/usr/bin/env bash
# shellcheck shell=bash
# Fully-offline install. The ISO bakes the entire package closure (base + all
# hardware + dev + CachyOS + the Ryoku desktop set) into a single [offline]
# file:// repo (installation/iso/offline-repo.sh), so pacstrap and the in-chroot
# driver step install from local disk with no network at all. Active only when
# RYOKU_ONLINE != 1 AND RYOKU_OFFLINE_REPO points at a baked repo that has a
# synced db; otherwise the online path in pacstrap.sh / deploy.sh runs unchanged.
#
# The desktop set is folded into the pacstrap transaction (one pass, the way
# omarchy batches its base install) rather than a second chroot `pacman -S`, so
# an offline install is a single dependency resolution over local packages.

: "${RYOKU_OFFLINE_REPO:=}"
RYOKU_OFFLINE_REPO_NAME=offline

# ryoku_offline_active: true when this is an offline install backed by a baked
# repo (the db glob proves the repo is real, not just an empty dir).
ryoku_offline_active() {
  [[ ${RYOKU_ONLINE:-1} != 1 ]] || return 1
  [[ -n $RYOKU_OFFLINE_REPO && -d $RYOKU_OFFLINE_REPO ]] || return 1
  compgen -G "$RYOKU_OFFLINE_REPO/$RYOKU_OFFLINE_REPO_NAME.db*" >/dev/null 2>&1
}

# ryoku_offline_verify: an offline install must have a repo it can actually
# install from. RYOKU_ONLINE=0 with no usable baked repo used to sail through
# preflight and only fail at pacstrap -- after the disk was already wiped --
# because every network step politely skips itself when offline and pacstrap then
# reached for a mirror that is not there. Fail here instead, before the disk is
# touched, and say which half is missing.
ryoku_offline_verify() {
  [[ ${RYOKU_ONLINE:-1} != 1 ]] || return 0
  ryoku_offline_active && return 0
  if [[ -z $RYOKU_OFFLINE_REPO ]]; then
    die "this is an offline install (RYOKU_ONLINE=0) but RYOKU_OFFLINE_REPO is unset, so there is nothing to install from. Boot an ISO that bakes the offline repo, or connect to a network and install online."
  fi
  if [[ ! -d $RYOKU_OFFLINE_REPO ]]; then
    die "offline install: the baked package repo is missing at $RYOKU_OFFLINE_REPO. This image is incomplete; connect to a network to install online, or re-download the ISO."
  fi
  die "offline install: $RYOKU_OFFLINE_REPO has no $RYOKU_OFFLINE_REPO_NAME.db, so pacman cannot resolve anything from it (a bake that stopped before repo-add). This image is incomplete; connect to a network to install online, or re-download the ISO."
}

# ryoku_offline_prepare: write the pacstrap-time pacman.conf pointing [offline]
# at the baked repo and export RYOKU_PACMAN_CONF so lib/pacstrap.sh passes
# `pacstrap -C`. TrustAll: the packages were vetted over TLS at ISO-build time
# and re-verified against real keyrings on the target's first online -Syu.
ryoku_offline_prepare() {
  ryoku_offline_active || return 0
  local conf=${RYOKU_PACMAN_CONF:-/tmp/ryoku-offline-pacman.conf}
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "offline: would write $conf ([offline] -> file://$RYOKU_OFFLINE_REPO, TrustAll) and pacstrap from it"
    export RYOKU_PACMAN_CONF=$conf
    return 0
  fi
  cat >"$conf" <<EOF
[options]
Architecture = x86_64 x86_64_v3
HoldPkg = pacman glibc
ParallelDownloads = 5
SigLevel = Never
LocalFileSigLevel = Never

[$RYOKU_OFFLINE_REPO_NAME]
SigLevel = Never
Server = file://$RYOKU_OFFLINE_REPO
EOF
  export RYOKU_PACMAN_CONF=$conf
  log "offline: pacstrap installs from the baked [offline] repo at $RYOKU_OFFLINE_REPO"
}

# ryoku_offline_pacstrap_extra: packages folded into the offline pacstrap set.
# the desktop umbrella pulls every monorepo component + its deps, all present in
# the baked repo, so the whole system installs in this one transaction. prints
# nothing (a no-op append) on an online install.
ryoku_offline_pacstrap_extra() {
  ryoku_offline_active || return 0
  printf '%s\n' ryoku-keyring ryoku-desktop
}

# ryoku_offline_chroot_on: make the baked repo resolvable INSIDE the target
# chroot so the per-hardware GPU driver step (system/hardware/drivers/*) can
# `pacman -S` its packages offline. bind the repo into /mnt at the same path (so
# file:// resolves) and append an [offline] stanza to the target pacman.conf.
# only [offline] has a synced db in the fresh target, so pacman resolves drivers
# from it with no network regardless of stanza order. best-effort: a bind failure
# must not abort an install whose drivers are already present (e.g. a VM).
ryoku_offline_chroot_on() {
  ryoku_offline_active || return 0
  local conf=/mnt/etc/pacman.conf
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "offline: would bind $RYOKU_OFFLINE_REPO into the chroot and add [offline] to $conf for the driver step"
    return 0
  fi
  run mkdir -p "/mnt$RYOKU_OFFLINE_REPO"
  if ! mountpoint -q "/mnt$RYOKU_OFFLINE_REPO" 2>/dev/null; then
    mount --bind "$RYOKU_OFFLINE_REPO" "/mnt$RYOKU_OFFLINE_REPO" \
      || log "offline: warning, could not bind the offline repo into the chroot (driver installs will be skipped)"
  fi
  grep -q '^\[offline\]' "$conf" 2>/dev/null && return 0
  append_file "$conf" <<EOF

[offline]
SigLevel = Never
Server = file://$RYOKU_OFFLINE_REPO
EOF
}

# ryoku_offline_chroot_off: undo ryoku_offline_chroot_on before the install ends,
# so the installed system's pacman.conf carries only the real (http) repos and
# no dangling file:// [offline] that a later `pacman -Syu` would choke on. drop
# the synced offline db too. idempotent; safe from the failure trap.
ryoku_offline_chroot_off() {
  ryoku_offline_active || return 0
  [[ -n ${RYOKU_DRYRUN:-} ]] && { log "offline: would strip [offline] from the target pacman.conf and unmount the bound repo"; return 0; }
  local conf=/mnt/etc/pacman.conf
  if [[ -f $conf ]]; then
    # delete the [offline] stanza: the header line and its two directive lines.
    sed -i '/^\[offline\]$/,/^Server = file:\/\//d' "$conf" 2>/dev/null || true
    # tidy a stray blank line the delete can leave at EOF.
    sed -i -e :a -e '/^\n*$/{$d;N;ba}' "$conf" 2>/dev/null || true
  fi
  rm -f /mnt/var/lib/pacman/sync/"$RYOKU_OFFLINE_REPO_NAME".db* 2>/dev/null || true
  if mountpoint -q "/mnt$RYOKU_OFFLINE_REPO" 2>/dev/null; then
    umount "/mnt$RYOKU_OFFLINE_REPO" 2>/dev/null || umount -l "/mnt$RYOKU_OFFLINE_REPO" 2>/dev/null || true
  fi
  rmdir "/mnt$RYOKU_OFFLINE_REPO" 2>/dev/null || true
}

# ryoku_offline_aur: install the AUR toolset bundled into the baked [offline] repo
# (offline-repo.sh bake_aur_set). every ISO install is offline, so this is the only
# place the AUR set an online install builds actually lands. runs inside the
# [offline] window (repo bound + db synced by pacstrap), best-effort: a tool that
# did not bake is filtered out (one unknown name would abort the whole -S batch),
# and a failed install (e.g. a DKMS module) warns instead of aborting the install.
ryoku_offline_aur() {
  ryoku_offline_active || return 0
  local aur_file="$RYOKU_REPO/system/packages/aur.packages"
  [[ -f $aur_file ]] || return 0
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "DRYRUN: install the bundled AUR toolset from the baked [offline] repo (best-effort)"
    return 0
  fi
  local -a want=() have=()
  mapfile -t want < <(grep -vE '^[[:space:]]*(#|$)' "$aur_file")
  (( ${#want[@]} )) || return 0
  local p
  for p in "${want[@]}"; do
    arch-chroot /mnt pacman -Sp "$p" >/dev/null 2>&1 && have+=("$p")
  done
  (( ${#have[@]} )) || { log "AUR: no bundled tools found in the offline repo (built best-effort at ISO time); skipping"; return 0; }
  log "AUR: installing ${#have[@]} bundled tool(s) from the baked [offline] repo"
  arch-chroot /mnt pacman -S --noconfirm --needed "${have[@]}" \
    || log "AUR: warning, some bundled tools did not install (e.g. a DKMS module); continuing"
  return 0
}
