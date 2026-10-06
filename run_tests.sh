#!/usr/bin/env bash
# Usage: ./run_tests.sh [unit|sim|sim-tiers|all|--quick]. Requires $GODOT (Godot 4.7 binary, see docs/DECISIONS.md D-116).
# sim = res://tests/sim, sim-tiers = res://tests/sim_tier (two CI jobs, D-247). all = unit, sim, sim-tiers (stops at the first failure).
# --quick = unit + night-1 sims (no tick hook), for local loops (D-132). CI always runs the full suites.
# Sim budget (D-247): the deterministic check is a per-test physics-tick budget (tests/sim_ticks.golden.json, +20%),
# enforced by tests/sim/tick_budget_hook.gd. Wall time only warns above SIM_WARN_S (default 60) and fails above
# SIM_FAIL_S (default 150). Update the golden file deliberately: TICK_BUDGET_UPDATE=1 ./run_tests.sh sim|sim-tiers
# (refused in CI). A watchdog kills a sim suite that is still running SIM_FAIL_S + 30 s after it started (a hang).
# Fails on test failures AND on GUT errors (missing scripts, parse errors, nothing run).
# .gutconfig.json is ignored by this runner (-gconfig=); dirs come from the flags below.
set -euo pipefail
cd "$(dirname "$0")"
SELF="$PWD/$(basename "$0")"
: "${GODOT:?Set GODOT to the Godot 4.7 binary path}"
SUITE="${1:-all}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
run_gut() {
  local log rc; log="$(mktemp)"
  trap 'rm -f "$log"' RETURN INT TERM
  local wd=()
  if [ -n "${WATCHDOG_S:-}" ]; then wd=(perl -e 'alarm shift; exec @ARGV or die "exec $ARGV[0]: $!\n"' "$WATCHDOG_S"); fi
  set +e
  ${wd[@]+"${wd[@]}"} "$GODOT" --headless --path . --fixed-fps 60 -s res://addons/gut/gut_cmdln.gd \
    -gconfig= -ginclude_subdirs -gprefix=test_ "$@" -gexit 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  set -e
  if [ -n "${WATCHDOG_S:-}" ] && [ "$rc" -eq 142 ]; then
    echo "SIM SUITE ${WATCHDOG_MODE:-?}: killed by the watchdog after ${WATCHDOG_S}s (hang or runaway sim)"
    trap - RETURN INT TERM; rm -f "$log"; return 1
  fi
  if [ "$rc" -eq 0 ] && sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E '^Errors[[:space:]]+[1-9]|Could not find script|could not be loaded|\[GUT ERROR\]:.*does not exist\.|Nothing was run|SCRIPT ERROR' >/dev/null; then
    echo "GUT reported errors (see above); failing"; rc=1
  fi
  if [ -n "${TICK_CHECK:-}" ]; then
    local clean; clean="$(sed 's/\x1b\[[0-9;]*m//g' "$log")"
    if printf '%s\n' "$clean" | grep -E '^TICK BUDGET: FAIL' >/dev/null; then
      echo "Tick budget failed (see TICK BUDGET lines above); failing"; rc=1
    elif ! printf '%s\n' "$clean" | grep -E '^TICK BUDGET: (OK|UPDATED)' >/dev/null; then
      echo "Tick budget hook did not report (no TICK BUDGET: OK or UPDATED line); failing"; rc=1
    fi
  fi
  trap - RETURN INT TERM
  rm -f "$log"; return "$rc"
}
# Shared by sim and sim-tiers: tick budget (hard) plus wall time (warn > SIM_WARN_S, fail > SIM_FAIL_S).
run_sim_suite() {
  local mode="$1" dir="$2" warn="${SIM_WARN_S:-60}" fail="${SIM_FAIL_S:-150}" start elapsed rc=0 msg hook=res://tests/sim/tick_budget_hook.gd
  if [ "${TICK_BUDGET_UPDATE:-}" = "1" ] && [ "${GITHUB_ACTIONS:-}" = "true" ]; then echo "TICK_BUDGET_UPDATE is not allowed in CI; failing"; return 1; fi
  case "$warn$fail" in *[!0-9]*|'') echo "SIM_WARN_S/SIM_FAIL_S must be integers"; return 2 ;; esac
  if [ -z "$(find "$dir" -name 'test_*.gd' -print -quit 2>/dev/null)" ]; then echo "SIM SUITE $mode: no test_*.gd under $dir; failing (never drop a sim, D-132)"; return 1; fi
  # GUT hangs (never exits) on a missing hook script, so fail fast here instead.
  if [ ! -f "${hook#res://}" ]; then echo "Tick budget hook missing: $hook; failing"; return 1; fi
  start=$SECONDS
  WATCHDOG_S=$((10#$fail + 30)) WATCHDOG_MODE="$mode" TICK_CHECK=1 TICK_BUDGET_DIR="res://$dir" run_gut -gdir="res://$dir" -gpre_run_script="$hook" || rc=$?
  elapsed=$((SECONDS - start))
  echo "SIM SUITE $mode: ${elapsed}s (warn ${warn}s, fail ${fail}s)"
  [ "$rc" -eq 0 ] || return "$rc"
  if [ "$elapsed" -gt "$fail" ]; then echo "SIM SUITE OVER HARD LIMIT (${fail}s)"; return 1; fi
  if [ "$elapsed" -gt "$warn" ]; then
    msg="$mode took ${elapsed}s (soft budget ${warn}s, hard limit ${fail}s). Runner speed varies; check the TICKS lines."
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then echo "::warning title=Sim suite slow::$msg"; else echo "SIM SUITE SLOW: $msg"; fi
  fi
  return 0
}
case "$SUITE" in
  unit) run_gut -gdir=res://tests/unit ;;
  sim) run_sim_suite sim tests/sim ;;
  sim-tiers) run_sim_suite sim-tiers tests/sim_tier ;;
  all) "$SELF" unit && "$SELF" sim && "$SELF" sim-tiers ;;
  --quick)
    run_gut -gdir=res://tests/unit && run_gut -gtest=res://tests/sim/test_night_sims.gd ;;
  *) echo "usage: $0 [unit|sim|sim-tiers|all|--quick]"; exit 2 ;;
esac
