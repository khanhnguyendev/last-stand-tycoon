#!/usr/bin/env bash
# S4 determinism proof (spec 6.3): re-runs the sweep for the 3 baseline seeds and diffs. Never re-record the baseline.
set -euo pipefail
: "${GODOT:?Set GODOT}"
cd "$(dirname "$0")/.."
T=$(mktemp -d); rc=0
for s in 20260930 11 777; do
  rm -f tests/sim/out/sweep.csv
  "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --seed=$s > "$T/$s.log" 2>&1 || rc=1
  ! grep -q 'SCRIPT ERROR' "$T/$s.log" || { echo "SCRIPT ERROR in sweep $s"; rc=1; }
  grep -E '^(SWEEP|RETRIES) ' "$T/$s.log" > "$T/$s.txt" || true
  [ "$(grep -c '^SWEEP ' "$T/$s.txt")" = 1 ] || { echo "no SWEEP line for $s"; rc=1; }
  [ -f tests/sim/out/sweep.csv ] || { echo "no sweep.csv for $s"; rc=1; continue; }
  diff -u tests/sim/baseline/s4_sweep_$s.csv tests/sim/out/sweep.csv || rc=1
  diff -u tests/sim/baseline/s4_sweep_$s.txt "$T/$s.txt" || rc=1
done
[ $rc -eq 0 ] && echo "baseline identical" || echo "BASELINE DIFF (logs: $T)"
exit $rc
