#!/usr/bin/env bash
# E5 (D-237): the tier-1 identity. Re-runs the planner sweep for the 3 baseline seeds and diffs only the first N data
# rows (default 7) of each CSV against tests/sim/baseline/. Rows past N are allowed to differ (the tier-1 cap).
set -euo pipefail
: "${GODOT:?Set GODOT}"
N="${1:-7}"
cd "$(dirname "$0")/.."
T=$(mktemp -d); rc=0
for s in 20260930 11 777; do
  rm -f tests/sim/out/sweep.csv
  "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --seed=$s > "$T/$s.log" 2>&1 || rc=1
  ! grep -q 'SCRIPT ERROR' "$T/$s.log" || { echo "SCRIPT ERROR in sweep $s"; rc=1; }
  [ -f tests/sim/out/sweep.csv ] || { echo "no sweep.csv for $s"; rc=1; continue; }
  head -n $((N + 1)) tests/sim/baseline/s4_sweep_$s.csv > "$T/base_$s.csv"
  head -n $((N + 1)) tests/sim/out/sweep.csv > "$T/now_$s.csv"
  diff -u "$T/base_$s.csv" "$T/now_$s.csv" || rc=1
  grep -E '^(SWEEP|RETRIES) ' "$T/$s.log" | sed "s/^/seed $s: /"
done
[ $rc -eq 0 ] && echo "rows 1-$N identical" || echo "ROWS 1-$N DIFFER (logs: $T)"
exit $rc
