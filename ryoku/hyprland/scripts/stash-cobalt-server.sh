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

# missing: no docker binary. denied: binary present but the daemon is
# unreachable (not running, or the user isn't in the docker group). ready: usable.
docker_state() {
  command -v docker >/dev/null 2>&1 || { echo missing; return; }
  docker info >/dev/null 2>&1 || { echo denied; return; }
  echo ready
}

# absent: no container by that name. running / stopped otherwise.
container_state() {
  local st
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

cmd="${1:-}"
case "$cmd" in
status)
  d=$(docker_state)
  emit docker "$d"
  if [ "$d" = "ready" ]; then
    emit cobalt "$(container_state)"
  else
    emit cobalt unknown
  fi
  ;;
up)
  d=$(docker_state)
  case "$d" in
    missing) emit ERROR "docker is not installed"; exit 2 ;;
    denied)  emit ERROR "docker is installed but not accessible (start docker.service or add yourself to the docker group)"; exit 2 ;;
  esac
  case "$(container_state)" in
    running)
      emit READY; exit 0 ;;
    stopped)
      emit STATUS starting
      docker start "$NAME" >/dev/null 2>&1 || { emit ERROR "could not start the cobalt container"; exit 1; } ;;
    absent)
      # first run: pull (implicit on run) then create + start. surface the pull
      # so the UI can explain the wait.
      docker image inspect "$IMAGE" >/dev/null 2>&1 || emit STATUS pulling
      emit STATUS starting
      if ! docker run -d --name "$NAME" --restart unless-stopped \
          -p "127.0.0.1:${PORT}:9000" -e API_URL="$URL" "$IMAGE" >/dev/null 2>&1; then
        emit ERROR "could not start cobalt (is port ${PORT} free?)"
        exit 1
      fi ;;
  esac
  if wait_ready; then
    emit READY
    exit 0
  fi
  emit ERROR "cobalt did not become ready"
  exit 1
  ;;
down)
  [ "$(docker_state)" = "ready" ] || { emit STOPPED; exit 0; }
  case "$(container_state)" in
    running)
      emit STATUS stopping
      docker stop "$NAME" >/dev/null 2>&1 || { emit ERROR "could not stop the cobalt container"; exit 1; }
      emit STOPPED ;;
    *) emit STOPPED ;;
  esac
  ;;
*)
  echo "usage: stash-cobalt-server.sh status | up | down" >&2
  exit 2
  ;;
esac
