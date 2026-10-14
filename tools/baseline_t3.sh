#!/usr/bin/env bash
# Tier-3 identity (E6, D-307 cleanup): the shipped (flag-on) game, a real 32-day tier-bot run, must equal the run recorded before the cleanup (tests/sim/baseline/tier3.csv). About 4 minutes.
# Prints `tier-3 identical <commit>` or the first differing row. Usage: tools/baseline_t3.sh [--record]
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?set GODOT (see CLAUDE.md)}"
BASE=tests/sim/baseline/tier3.csv
OUT=tests/sim/out/tier3_check.csv
mkdir -p tests/sim/out
"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --bot=tier --days=32 --seed=20260930 --policy=threat --cols=extra --out=tier3_check.csv >/dev/null 2>&1
[ -s "$OUT" ] || { echo "tier-3: the sweep wrote no rows" >&2; exit 1; }
if [ "${1:-}" = "--record" ]; then cp "$OUT" "$BASE"; echo "tier-3 recorded $(git rev-parse --short HEAD) ($(wc -l < "$BASE" | tr -d ' ') lines)"; exit 0; fi
if cmp -s "$OUT" "$BASE"; then echo "tier-3 identical $(git rev-parse --short HEAD)"; else echo "tier-3 DIFFERS:"; diff "$BASE" "$OUT" | head -6; exit 1; fi
