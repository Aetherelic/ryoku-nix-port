#!/usr/bin/env bash
# fixture test for ryoku-cmd-game-mode (the one-click competitive toggle). stubs
# hyprctl, pkexec, powerprofilesctl and both privileged helpers, points state +
# sysfs scan at a tmp dir, so the real compositor, the real wifi radio and the
# real power profile are never touched. verifies:
#   - toggle lifecycle
#   - compositor goes through `hyprctl eval` (not the keyword path the Lua
#     parser rejects), with tearing + the immediate rule, reverts via reload
#   - the power profile flips to performance and the PRIOR one comes back, not a
#     guessed default
#   - the privileged system tune is applied on start and restored on stop
#   - wifi power-save delegated to the privileged ryoku-wifi-powersave via
#     pkexec (off on start, on on stop)
#   - refuses on battery, before touching anything
#   - clean no-op when there's no wifi device or a helper is missing
#
# helpers are addressed through their env seams (RYOKU_*_BIN) rather than by
# removing a stub from PATH. a bare PATH removal cannot express "absent": on a
# deployed machine `command -v` still finds the real helper in /usr/bin, so the
# absent-helper case silently tested nothing and failed for weeks.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
gm="$here/../ryoku/hyprland/scripts/ryoku-cmd-game-mode"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"; mkdir -p "$bin"
calls="$tmp/calls.log"

logger() {  # name -> stub that records its argv and exits 0
  cat >"$bin/$1" <<EOF
#!/usr/bin/env bash
echo "$1 \$*" >>"$calls"
exit 0
EOF
}
logger hyprctl
logger pkexec
logger ryoku-wifi-powersave
logger ryoku-game-tune

printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/notify-send"

# powerprofilesctl stub with a real backing value, so a restore that writes back
# the wrong profile is visible rather than merely unlogged.
profile="$tmp/profile"; echo balanced >"$profile"
cat >"$bin/powerprofilesctl" <<EOF
#!/usr/bin/env bash
echo "powerprofilesctl \$*" >>"$calls"
case "\${1:-}" in
  get) cat "$profile" ;;
  set) printf '%s\n' "\${2:-}" >"$profile" ;;
esac
exit 0
EOF

# ryoku-idle owns the AC/battery question; exit 1 = on AC (permissive default).
ac="$tmp/on_ac"; : >"$ac"
cat >"$bin/ryoku-idle" <<EOF
#!/usr/bin/env bash
echo "ryoku-idle \$*" >>"$calls"
[[ -f "$ac" ]] && exit 1
exit 0
EOF
chmod +x "$bin"/*

# fake sysfs with one wifi device (overridable per-test).
net="$tmp/net"; mkdir -p "$net/wlan0/wireless" "$net/eth0"
nonet="$tmp/nonet"; mkdir -p "$nonet/eth0"

export PATH="$bin:$PATH"
export RYOKU_STATE_PATH="$tmp/state"
export RYOKU_GAMEMODE_STATE_FILE="$tmp/state/game-mode.enabled"
export RYOKU_GAMEMODE_PROFILE_FILE="$tmp/state/game-mode.profile"
export RYOKU_NET_SYSFS="$net"
export RYOKU_WIFI_POWERSAVE_BIN="$bin/ryoku-wifi-powersave"
export RYOKU_GAME_TUNE_BIN="$bin/ryoku-game-tune"
export RYOKU_IDLE_BIN="$bin/ryoku-idle"
state="$RYOKU_GAMEMODE_STATE_FILE"

fail() { echo "FAIL: $1" >&2; exit 1; }
on() { [[ -f $state ]]; }

"$gm" status && fail "status reported on before any start"

# --- start: compositor via eval + profile + tune + wifi off ----------------
: >"$calls"
"$gm" start
on || fail "start did not persist the request"
grep -qF 'hyprctl eval' "$calls" || fail "compositor did not go through hyprctl eval"
grep -qF 'keyword' "$calls" && fail "used the keyword path the Lua parser rejects"
grep -qF 'allow_tearing = true' "$calls" || fail "eval lua did not enable tearing"
grep -qF 'immediate = true' "$calls" || fail "eval lua did not add the immediate rule"
grep -qF 'powerprofilesctl set performance' "$calls" || fail "did not ask for the performance profile"
grep -qF 'ryoku-game-tune apply' "$calls" || fail "system tune not applied"
grep -qE 'pkexec .*ryoku-wifi-powersave off' "$calls" || fail "WiFi helper not asked to disable power-save"
[[ "$(cat "$profile")" == performance ]] || fail "profile did not actually reach performance"
"$gm" status || fail "status reported off while on"

# --- stop: reload + tune restored + the PRIOR profile back -----------------
: >"$calls"
"$gm" stop
on && fail "stop did not clear the request"
grep -qF 'hyprctl reload' "$calls" || fail "stop did not reload to revert the compositor"
grep -qF 'ryoku-game-tune restore' "$calls" || fail "system tune not restored"
grep -qE 'pkexec .*ryoku-wifi-powersave on' "$calls" || fail "WiFi helper not asked to restore power-save"
[[ "$(cat "$profile")" == balanced ]] ||
  fail "restored the wrong profile (want the prior 'balanced', got '$(cat "$profile")')"
"$gm" status && fail "status reported on after stop"

# --- the prior profile is whatever was there, not a hardcoded default ------
echo power-saver >"$profile"
"$gm" start
[[ "$(cat "$profile")" == performance ]] || fail "second start did not reach performance"
"$gm" stop
[[ "$(cat "$profile")" == power-saver ]] ||
  fail "did not restore a non-default prior profile (got '$(cat "$profile")')"

# --- toggle flips both ways ------------------------------------------------
"$gm" toggle; on || fail "toggle did not turn on"
"$gm" toggle; on && fail "toggle did not turn off"

# --- on battery: refuses, and touches nothing ------------------------------
rm -f "$ac"                      # ryoku-idle now reports discharging
echo balanced >"$profile"
: >"$calls"
"$gm" start && fail "start succeeded on battery"
on && fail "a refused start still persisted the request"
grep -qF 'hyprctl eval' "$calls" && fail "stripped the compositor on battery"
grep -qF 'ryoku-game-tune' "$calls" && fail "applied the privileged tune on battery"
[[ "$(cat "$profile")" == balanced ]] || fail "changed the power profile on battery"
: >"$ac"                         # back on AC

# --- no ryoku-idle at all: treated as AC, matching the house default -------
: >"$calls"
RYOKU_IDLE_BIN="$tmp/nope" "$gm" start
on || fail "refused to start when the AC/battery helper is absent"
RYOKU_IDLE_BIN="$tmp/nope" "$gm" stop

# --- no wifi device: compositor still applies, wifi is a clean no-op -------
: >"$calls"
RYOKU_NET_SYSFS="$nonet" "$gm" start
on || fail "start failed on a no-WiFi host"
grep -qF 'hyprctl eval' "$calls" || fail "compositor did not apply on a no-WiFi host"
grep -qF 'ryoku-wifi-powersave' "$calls" && fail "touched WiFi on a host with no WiFi device"
RYOKU_NET_SYSFS="$nonet" "$gm" stop

# --- helpers absent: the rest still applies --------------------------------
: >"$calls"
RYOKU_WIFI_POWERSAVE_BIN="$tmp/nope" RYOKU_GAME_TUNE_BIN="$tmp/nope" "$gm" start
grep -qF 'hyprctl eval' "$calls" || fail "compositor did not apply when helpers absent"
grep -qF 'ryoku-wifi-powersave' "$calls" && fail "tried to call an absent WiFi helper"
grep -qF 'ryoku-game-tune' "$calls" && fail "tried to call an absent tune helper"
RYOKU_WIFI_POWERSAVE_BIN="$tmp/nope" RYOKU_GAME_TUNE_BIN="$tmp/nope" "$gm" stop

echo "game-mode: all checks passed"
