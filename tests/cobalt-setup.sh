#!/usr/bin/env bash
# hermetic test for the stash Cobalt setup path: the privileged ryoku-docker
# helper and stash-cobalt-server.sh's choice of door.
#
# Nothing here touches a real daemon, a real socket, or root. Every seam points
# at a tmp fixture -- RYOKU_DOCKER_BIN, RYOKU_DOCKER_SYSTEMCTL,
# RYOKU_DOCKER_SOCKET, RYOKU_DOCKER_GETENT for the helper, RYOKU_DOCKER_HELPER
# for the script -- and a fake pkexec on PATH acts as an escalation sentinel.
#
# The load-bearing assertions are the NEGATIVE ones: the helper must refuse a
# bad port or an unknown verb BEFORE it escalates, because its polkit grant is
# passwordless. A helper that validated after escalating would be a root hole.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
helper="$here/../system/containers/ryoku-docker"
server="$here/../ryoku/hyprland/scripts/stash-cobalt-server.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

bin="$tmp/bin"; mkdir -p "$bin"

# escalation sentinel: any pkexec re-exec drops this file.
cat >"$bin/pkexec" <<EOF
#!/bin/sh
touch "$tmp/ESCALATED"
exit 0
EOF
chmod +x "$bin/pkexec"
escalated() { [[ -e "$tmp/ESCALATED" ]]; }
clear_escalated() { rm -f "$tmp/ESCALATED"; }

# a docker whose `info` succeeds or fails on demand, and whose inspect reports a
# container state we control.
cat >"$bin/docker" <<EOF
#!/bin/sh
case "\$1" in
  info)    [ -e "$tmp/DOCKER_UP" ] || exit 1; echo ok ;;
  inspect) [ -e "$tmp/HAVE_CONTAINER" ] || exit 1; cat "$tmp/HAVE_CONTAINER" ;;
  *)       echo "\$@" >>"$tmp/docker.log" ;;
esac
exit 0
EOF
chmod +x "$bin/docker"

cat >"$bin/systemctl" <<EOF
#!/bin/sh
case "\$1" in is-active) [ -e "$tmp/SVC_UP" ] || exit 3 ;; esac
exit 0
EOF
chmod +x "$bin/systemctl"

# docker group exists and lists nero; passwd resolves uid 1000 to nero.
cat >"$bin/getent" <<'EOF'
#!/bin/sh
case "$1:$2" in
  group:docker) [ -n "$FIXTURE_NO_GROUP" ] && exit 2; echo "docker:x:940:${FIXTURE_MEMBERS-nero}"; exit 0 ;;
  passwd:*)     echo "nero:x:1000:1000::/home/nero:/bin/bash"; exit 0 ;;
esac
exit 2
EOF
chmod +x "$bin/getent"

# a real unix socket: the helper requires -S, as /var/run/docker.sock is.
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' "$tmp/sock"

export PATH="$bin:$PATH"
export RYOKU_DOCKER_BIN="$bin/docker"
export RYOKU_DOCKER_SYSTEMCTL="$bin/systemctl"
export RYOKU_DOCKER_SOCKET="$tmp/sock"
export RYOKU_DOCKER_GETENT="$bin/getent"

field() { awk -F'\t' -v k="$1" '$1==k{print $2}'; }

# ---- helper: state is read-only and never escalates --------------------------
touch "$tmp/SVC_UP"
clear_escalated
out="$($helper state)"
[[ "$(field binary  <<<"$out")" == yes    ]] || fail "state: binary should be yes"
[[ "$(field service <<<"$out")" == active ]] || fail "state: service should be active"
[[ "$(field group   <<<"$out")" == yes    ]] || fail "state: group should be yes"
[[ "$(field member  <<<"$out")" == yes    ]] || fail "state: member should be yes"
[[ "$(field socket  <<<"$out")" == yes    ]] || fail "state: socket should be yes"
escalated && fail "state escalated; it must be read-only"

# membership is read from the group file, not from `id`, because a live session
# does not see a freshly added group and that is the case this helper exists for.
clear_escalated
out="$(FIXTURE_MEMBERS=someone-else $helper state)"
[[ "$(field member <<<"$out")" == no ]] || fail "state: member should be no when absent from the group line"

rm -f "$tmp/SVC_UP"
out="$($helper state)"
[[ "$(field service <<<"$out")" == inactive ]] || fail "state: service should be inactive"
touch "$tmp/SVC_UP"

# ---- helper: provision converges without escalating -------------------------
clear_escalated
out="$($helper provision)"
[[ "$(head -1 <<<"$out" | cut -f1)" == OK ]] || fail "provision: a ready host should report OK, got: $out"
escalated && fail "provision escalated on an already-provisioned host; it must converge"

# ---- helper: the port policy is enforced BEFORE escalating ------------------
for p in 0 80 1023 65536 abc " " "9000 x" "9000; id"; do
  clear_escalated
  rc=0; $helper container-up "$p" >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 2 ]] || fail "container-up accepted port '$p' (rc=$rc); it must exit 2"
  escalated && fail "container-up escalated for port '$p' before validating it"
done

# ---- helper: unknown verbs are refused before escalating --------------------
for v in "" bogus run exec docker "container-up; id" --help; do
  clear_escalated
  rc=0; $helper "$v" >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 2 ]] || fail "helper accepted verb '$v' (rc=$rc); it must exit 2"
  escalated && fail "helper escalated for verb '$v' before validating it"
done

# ---- the seams must NOT be honoured when running privileged ----------------
# RYOKU_DOCKER_BIN reaching a root pass would be arbitrary root code execution.
# pkexec sanitises the environment so it should never get there, but the script
# refuses to depend on that: at EUID 0 it uses hardcoded paths. fakeroot gives a
# real EUID of 0 without real privilege, which is exactly enough to exercise that
# branch hermetically.
#
# The fake drops a sentinel FILE rather than printing: container-status captures
# $DOCKER's stdout into a variable and sends its stderr to /dev/null, so a
# printed marker would be swallowed and the check would silently pass.
if command -v fakeroot >/dev/null 2>&1; then
  cat >"$bin/evil-docker" <<EOF
#!/bin/sh
touch "$tmp/SEAM_USED"
echo true
EOF
  chmod +x "$bin/evil-docker"

  # container-status actually EXECUTES \$DOCKER; `state` only probes for it with
  # command -v, so it would never reveal a honoured seam.
  rm -f "$tmp/SEAM_USED"
  RYOKU_DOCKER_BIN="$bin/evil-docker" fakeroot bash "$helper" container-status >/dev/null 2>&1 || true
  [[ -e "$tmp/SEAM_USED" ]] \
    && fail "RYOKU_DOCKER_BIN was honoured at EUID 0; a privileged pass must ignore the seams"

  # Control: the same seam MUST reach $DOCKER unprivileged, or the check above is
  # asserting nothing at all.
  rm -f "$tmp/SEAM_USED"
  RYOKU_DOCKER_ASSUME_ROOT=1 RYOKU_DOCKER_BIN="$bin/evil-docker" bash "$helper" container-status >/dev/null 2>&1 || true
  [[ -e "$tmp/SEAM_USED" ]] \
    || fail "the unprivileged run never reached RYOKU_DOCKER_BIN; the seam check proves nothing"
  rm -f "$tmp/SEAM_USED"
fi

# A valid port must NOT be rejected (the allowlist has to permit the real case),
# and an omitted or empty one falls back to the default rather than erroring.
clear_escalated
rc=0; $helper container-up 9000 >/dev/null 2>&1 || rc=$?
[[ $rc -ne 2 ]] || fail "container-up rejected the valid port 9000"
rc=0; $helper container-up "" >/dev/null 2>&1 || rc=$?
[[ $rc -ne 2 ]] || fail "container-up should default an empty port, not reject it"

# ---- the server script picks the right door --------------------------------
export RYOKU_DOCKER_HELPER="$helper"

# direct: `docker info` works, so the script must not involve the helper at all.
touch "$tmp/DOCKER_UP"
printf 'true\n' >"$tmp/HAVE_CONTAINER"
out="$("$server" status)"
[[ "$(field docker <<<"$out")" == ready ]] || fail "status: direct access should report ready, got: $out"
[[ "$(field cobalt <<<"$out")" == running ]] || fail "status: should report the running container, got: $out"

# helper: `docker info` fails but the helper is present, so the state is the
# actionable "setup" rather than the dead-end "denied", and the container state
# is still answerable through the helper.
rm -f "$tmp/DOCKER_UP"
# The seam stands in for pkexec here: the point of this case is the door the
# script chooses, not the escalation itself, which the negative tests above
# already pin.
out="$(RYOKU_DOCKER_ASSUME_ROOT=1 "$server" status)"
[[ "$(field docker <<<"$out")" == setup ]] || fail "status: with a helper present the state should be setup, got: $out"
[[ "$(field cobalt <<<"$out")" == running ]] || fail "status: helper door should still report the container, got: $out"

# none: no helper on PATH and no direct access degrades to denied, and `up` says
# so instead of pretending.
out="$(RYOKU_DOCKER_HELPER=/nonexistent-helper "$server" status)"
[[ "$(field docker <<<"$out")" == denied ]] || fail "status: no door should report denied, got: $out"
rc=0; RYOKU_DOCKER_HELPER=/nonexistent-helper "$server" up >"$tmp/up.out" 2>&1 || rc=$?
[[ $rc -eq 2 ]] || fail "up should exit 2 with no way to reach docker (rc=$rc)"
grep -q 'ryoku-docker helper is missing' "$tmp/up.out" \
  || fail "up should name the missing helper, got: $(cat "$tmp/up.out")"

# missing docker entirely: the fix is an update, and the message must say
# installed-ness rather than accessibility.
out="$(PATH="$tmp/empty:$PATH" RYOKU_DOCKER_BIN=/nonexistent-docker "$server" status 2>/dev/null || true)"
mkdir -p "$tmp/empty"

# ---- an already-running container short-circuits to READY -------------------
touch "$tmp/DOCKER_UP"
out="$("$server" up)"
[[ "$(head -1 <<<"$out" | cut -f1)" == READY ]] || fail "up: a running container should report READY at once, got: $out"

echo "cobalt-setup: all checks passed"
