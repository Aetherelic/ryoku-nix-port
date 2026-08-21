#!/bin/bash
# Local cobalt instance lifecycle for the stash download engine toggle.
# cobalt ships only as a Docker image (no Arch package, no public API), so the
# "Cobalt engine" switch in the stash Tools section drives a single container
# named ryoku-cobalt, bound to loopback. Kept between runs so on/off is instant
# after the first pull.
#
# tab-separated, line-buffered status the shell (Stash.qml) parses:
#   status -> "docker\t<missing|denied|ready>" then "cobalt\t<absent|stopped|running>"
#   up     -> "STATUS\t<pulling|starting>" ... then "READY" or "ERROR\t<message>"
#   down   -> "STATUS\tstopping" then "STOPPED" or "ERROR\t<message>"
# usage: stash-cobalt-server.sh status | up | down
set -u

NAME="ryoku-cobalt"
IMAGE="ghcr.io/imputnet/cobalt:11"
PORT="${COBALT_PORT:-9000}"
URL="http://localhost:${PORT}/"

emit() { printf '%s\t%s\n' "$1" "${2:-}"; }

HELPER="${RYOKU_DOCKER_HELPER:-ryoku-docker}"

# Two ways to reach docker. Directly, when this session already has access (the
# user is in the docker group and the daemon is up), or through ryoku-docker,
# which escalates via polkit and therefore does not care about the session's
# groups. The helper is what lets first-time setup work without a re-login.
# Resolved once per run.
ACCESS=""
resolve_access() {
  [ -n "$ACCESS" ] && return
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    ACCESS=direct
  elif command -v "$HELPER" >/dev/null 2>&1; then
    ACCESS=helper
  else
    ACCESS=none
  fi
}

# missing: no docker binary at all, so `ryoku update` is the fix. setup: docker
# is installed but this session cannot reach it AND the privileged helper can,
# so the setup wizard can fix it in place. denied: unreachable with no helper to
# fix it. ready: usable right now.
docker_state() {
  command -v docker >/dev/null 2>&1 || { echo missing; return; }
  resolve_access
  case "$ACCESS" in
    direct) echo ready ;;
    helper) echo setup ;;
    *)      echo denied ;;
  esac
}

# absent: no container by that name. running / stopped otherwise.
container_state() {
  local st
  resolve_access
  if [ "$ACCESS" = helper ]; then
    "$HELPER" container-status 2>/dev/null || echo absent
    return
  fi
  st=$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null) || { echo absent; return; }
  [ "$st" = "true" ] && echo running || echo stopped
}

# poll GET / until the instance answers, bounded so a wedged start still returns.
wait_ready() {
  local _
  for _ in $(seq 1 60); do
    curl -fsS --max-time 2 -H "Accept: application/json" "$URL" >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

# Create or start the container. Both doors emit the same STATUS lines, so the
# UI reads one protocol whichever was used. `starting` is emitted by the caller
# BEFORE this runs and `pulling` from in here, so the long first-pull message is
# the one left on screen for the wait rather than being overwritten by it.
container_up() {
  resolve_access
  if [ "$ACCESS" = helper ]; then
    while IFS= read -r line; do
      case "$line" in
        STEP*pulling*) emit STATUS pulling ;;
      esac
    done < <("$HELPER" container-up "$PORT" 2>/dev/null)
    return 0
  fi
  case "$(container_state)" in
    stopped)
      docker start "$NAME" >/dev/null 2>&1 || return 1 ;;
    absent)
      docker image inspect "$IMAGE" >/dev/null 2>&1 || emit STATUS pulling
      docker run -d --name "$NAME" --restart unless-stopped \
        -p "127.0.0.1:${PORT}:9000" -e API_URL="$URL" "$IMAGE" >/dev/null 2>&1 || return 1 ;;
  esac
  return 0
}

container_down() {
  resolve_access
  if [ "$ACCESS" = helper ]; then
    "$HELPER" container-down >/dev/null 2>&1 || return 1
    return 0
  fi
  docker stop "$NAME" >/dev/null 2>&1 || return 1
}

cmd="${1:-}"
case "$cmd" in
status)
  d=$(docker_state)
  emit docker "$d"
  # `setup` can still answer the container question: the helper reaches docker
  # even when this session cannot, so report the real container state rather
  # than hiding it behind "unknown".
  case "$d" in
    ready|setup) emit cobalt "$(container_state)" ;;
    *)           emit cobalt unknown ;;
  esac
  ;;
up)
  d=$(docker_state)
  case "$d" in
    missing) emit ERROR "docker is not installed"; exit 2 ;;
    denied)  emit ERROR "docker is installed but not reachable, and the ryoku-docker helper is missing"; exit 2 ;;
  esac
  [ "$(container_state)" = running ] && { emit READY; exit 0; }
  emit STATUS starting
  container_up || { emit ERROR "could not start cobalt (is port ${PORT} free?)"; exit 1; }
  if wait_ready; then
    emit READY
    exit 0
  fi
  emit ERROR "cobalt did not become ready"
  exit 1
  ;;
down)
  case "$(docker_state)" in
    ready|setup) ;;
    *) emit STOPPED; exit 0 ;;
  esac
  if [ "$(container_state)" = running ]; then
    emit STATUS stopping
    container_down || { emit ERROR "could not stop the cobalt container"; exit 1; }
  fi
  emit STOPPED
  ;;
*)
  echo "usage: stash-cobalt-server.sh status | up | down" >&2
  exit 2
  ;;
esac
