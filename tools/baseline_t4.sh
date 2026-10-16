#!/usr/bin/env bash
# Tier-4 identity (E8 phase 2, B16): the shipped game, a real 45-day tier-bot run (seed 20260930, threat policy, the bot NOT capped), must equal the run recorded in tests/sim/baseline/tier4.csv.
# The CSV is recorded AFTER Task 11's tuning, never before. Without it this prints "no baseline yet; record with --record". Usage: tools/baseline_t4.sh [--record]
# Prints `tier-4 identical <commit>` or the first differing row. The tier-3 twin is tools/baseline_t3.sh (capped at tier 3).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?set GODOT (the pinned binary, see the project guide)}"
BASE=tests/sim/baseline/tier4.csv
OUT=tests/sim/out/tier4_check.csv
mkdir -p tests/sim/out
if [ "${1:-}" != "--record" ] && [ ! -f "$BASE" ]; then echo "tier-4: no baseline yet; record with --record (after Task 11's tuning)"; exit 1; fi  # nothing to compare with: do not spend the run
"$GODOT" --headless --path . --import >/dev/null 2>&1 || { echo "import failed" >&2; exit 1; }  # a fresh worktree has no import cache: without this the sweep spins for 30+ minutes
LOG=tests/sim/out/tier4_check.log
rm -f "$OUT"  # a stale CSV must never pass or be recorded
rc=0
"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --bot=tier --days=45 --seed=20260930 --policy=threat --cols=extra --out=tier4_check.csv >"$LOG" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { echo "tier-4: sweep exit $rc, log $LOG" >&2; exit 1; }
grep -q -F 'OVERRIDES none' "$LOG" || { echo "tier-4: the sweep ran with overrides (no 'OVERRIDES none' line), log $LOG" >&2; exit 1; }
[ -s "$OUT" ] || { echo "tier-4: the sweep wrote no rows" >&2; exit 1; }
grep -q '^T4RUN ' "$LOG" || { echo "tier-4: the run played no tier-4 night or boss night (no T4RUN line), log $LOG" >&2; exit 1; }
if [ "${1:-}" = "--record" ]; then cp "$OUT" "$BASE"; echo "tier-4 recorded $(git rev-parse --short HEAD) ($(wc -l < "$BASE" | tr -d ' ') lines)"; exit 0; fi
if cmp -s "$OUT" "$BASE"; then echo "tier-4 identical $(git rev-parse --short HEAD)"; else echo "tier-4 DIFFERS:"; diff "$BASE" "$OUT" | head -6; echo "sweep log (stdout and stderr): $LOG"; echo "Godot processes now:"; pgrep -fl Godot || echo "(none)"; exit 1; fi
