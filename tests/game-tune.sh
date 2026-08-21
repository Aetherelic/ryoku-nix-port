#!/usr/bin/env bash
# fixture test for ryoku-game-tune: Game Mode's privileged system tuning.
# /proc/sys, the cpuidle tree and the saved-state file all point at a tmp dir, so
# no real knob is touched and no root is needed. covers:
#   - every tunable present is moved to its play value
#   - a tunable the running kernel does not expose is skipped, not an error
#     (this is what lets one toggle serve both the Arch and CachyOS kernels)
#   - deep idle states are chosen by exit cost, so a cheap state is left enabled
#   - restore puts back the exact prior values, not defaults
#   - apply is idempotent: a second apply must not record the tuned values as the
#     originals, which would make restore re-apply the tune instead of undoing it
#   - status reflects whether a tune is currently applied
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tune="$here/../system/hardware/power/ryoku-game-tune"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

proc="$tmp/proc"; cpu="$tmp/cpu"
mkdir -p "$proc/kernel" "$proc/vm"

export RYOKU_PROC_SYS="$proc"
export RYOKU_CPU_DIR="$cpu"
export RYOKU_GAME_TUNE_STATE="$tmp/state/saved"

fail() { echo "FAIL: $1" >&2; exit 1; }
val() { cat "$1" 2>/dev/null || echo MISSING; }
want() { [[ "$(val "$1")" == "$2" ]] || fail "$3 (want '$2', got '$(val "$1")')"; }

# Prior values, deliberately non-default so a restore that writes a default
# instead of the original is visible.
echo 1 >"$proc/kernel/nmi_watchdog"
echo 1 >"$proc/kernel/split_lock_mitigate"
echo 17 >"$proc/vm/compaction_proactiveness"
echo 7 >"$proc/vm/page_lock_unfairness"
echo 55 >"$proc/vm/swappiness"
# kernel/sched_energy_aware deliberately absent: only some kernels build it.

# Two idle states: one cheap to leave, one expensive.
mkdir -p "$cpu/cpu0/cpuidle/state1" "$cpu/cpu0/cpuidle/state3" "$cpu/cpu1/cpuidle/state3"
echo 18 >"$cpu/cpu0/cpuidle/state1/latency";  echo 0 >"$cpu/cpu0/cpuidle/state1/disable"
echo 350 >"$cpu/cpu0/cpuidle/state3/latency"; echo 0 >"$cpu/cpu0/cpuidle/state3/disable"
echo 350 >"$cpu/cpu1/cpuidle/state3/latency"; echo 0 >"$cpu/cpu1/cpuidle/state3/disable"

"$tune" status && fail "status reported applied before any apply"

# --- apply ------------------------------------------------------------------
"$tune" apply
want "$proc/kernel/nmi_watchdog" 0 "NMI watchdog left on"
want "$proc/kernel/split_lock_mitigate" 0 "split/bus-lock mitigation left on"
want "$proc/vm/compaction_proactiveness" 0 "proactive compaction left on"
want "$proc/vm/page_lock_unfairness" 1 "page-lock unfairness untouched"
want "$proc/vm/swappiness" 10 "swappiness untouched"
want "$cpu/cpu0/cpuidle/state3/disable" 1 "expensive idle state left enabled"
want "$cpu/cpu1/cpuidle/state3/disable" 1 "expensive idle state left enabled on cpu1"
want "$cpu/cpu0/cpuidle/state1/disable" 0 "disabled a cheap idle state it should have kept"
[[ -f "$proc/kernel/sched_energy_aware" ]] &&
  fail "invented a knob this kernel does not expose"
"$tune" status || fail "status reported not applied after apply"

# --- apply again: must not re-record the tuned values as the originals -------
"$tune" apply
"$tune" restore
want "$proc/kernel/nmi_watchdog" 1 "restore after a double apply did not put back the original"
want "$proc/vm/swappiness" 55 "restore after a double apply did not put back the original"
want "$cpu/cpu0/cpuidle/state3/disable" 0 "restore after a double apply left an idle state off"
"$tune" status && fail "status reported applied after restore"

# --- restore is exact, not a set of defaults --------------------------------
"$tune" apply
"$tune" restore
want "$proc/kernel/split_lock_mitigate" 1 "split-lock prior value not restored"
want "$proc/vm/compaction_proactiveness" 17 "compaction prior value not restored"
want "$proc/vm/page_lock_unfairness" 7 "page-lock prior value not restored"
want "$proc/vm/swappiness" 55 "swappiness prior value not restored"

# --- restore with nothing applied is a clean no-op --------------------------
"$tune" restore
want "$proc/vm/swappiness" 55 "a no-op restore changed a value"

# --- a kernel exposing the extra knob gets it tuned too ---------------------
# (the CachyOS side of "one toggle, more levers where they exist")
echo 1 >"$proc/kernel/sched_energy_aware"
"$tune" apply
want "$proc/kernel/sched_energy_aware" 0 "did not tune a knob the kernel does expose"
"$tune" restore
want "$proc/kernel/sched_energy_aware" 1 "did not restore the extra knob"

# --- an unreadable-but-present knob is skipped rather than half-applied -----
: >"$proc/vm/empty_knob"
"$tune" apply
"$tune" restore

# --- a seamed run must never escalate onto the real machine -----------------
# pkexec strips the environment, so escalating from a seamed run would drop the
# redirection and apply the tune to the real /proc and /sys. A caller who
# redirected our view is never asking for privilege on the real box, so an
# unwritable seamed path has to fail rather than widen scope. Regression: an
# early version escalated here and tuned the live machine during a test run.
real_nmi="$(cat /proc/sys/kernel/nmi_watchdog 2>/dev/null || echo unknown)"
RYOKU_GAME_TUNE_STATE=/proc/definitely-not-writable/saved \
  "$tune" apply >/dev/null 2>&1 &&
  fail "a seamed run with an unwritable state path reported success"
[[ "$(cat /proc/sys/kernel/nmi_watchdog 2>/dev/null || echo unknown)" == "$real_nmi" ]] ||
  fail "a seamed run escalated and changed the real machine"

echo "game-tune: all checks passed"
