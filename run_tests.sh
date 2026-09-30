#!/usr/bin/env bash
# Usage: ./run_tests.sh [unit|sim|all|--quick]. Requires $GODOT (Godot 4.7 binary, see docs/DECISIONS.md D-116).
# --quick = unit + night-1 sims, for local loops (D-132). CI always runs the full unit and sim suites.
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
  set +e
  "$GODOT" --headless --path . --fixed-fps 60 -s res://addons/gut/gut_cmdln.gd \
    -gconfig= -ginclude_subdirs -gprefix=test_ "$@" -gexit 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -eq 0 ] && sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E '^Errors[[:space:]]+[1-9]|Could not find script|could not be loaded|\[GUT ERROR\]:.*does not exist\.|Nothing was run|SCRIPT ERROR' >/dev/null; then
    echo "GUT reported errors (see above); failing"; rc=1
  fi
  trap - RETURN INT TERM
  rm -f "$log"; return "$rc"
}
case "$SUITE" in
  unit) run_gut -gdir=res://tests/unit ;;
  sim)
    if [ -z "$(find tests/sim -name 'test_*.gd' -print -quit 2>/dev/null)" ]; then echo "SIM SUITE: no sim tests yet"; exit 0; fi
    start=$SECONDS
    rc=0; run_gut -gdir=res://tests/sim || rc=$?
    elapsed=$((SECONDS - start))
    echo "SIM SUITE: ${elapsed}s (budget 60s)"
    [ "$rc" -eq 0 ] || exit "$rc"
    if [ "$elapsed" -gt 60 ]; then echo "SIM SUITE OVER BUDGET"; exit 1; fi ;;
  all) "$SELF" unit && "$SELF" sim ;;
  --quick)
    run_gut -gdir=res://tests/unit && run_gut -gtest=res://tests/sim/test_night_sims.gd ;;
  *) echo "usage: $0 [unit|sim|all|--quick]"; exit 2 ;;
esac
