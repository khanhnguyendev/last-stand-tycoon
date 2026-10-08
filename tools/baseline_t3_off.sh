#!/usr/bin/env bash
# Tier-3 off-state identity (E6, D-286): with Balance.data.tiers.retune_enabled false, a real 32-day tier-bot run must
# equal the run recorded from main at the start of the slice (tests/sim/baseline/tier3_off.csv). About 4 minutes.
# Prints `tier-3 off identical <commit>` or the first differing row. Usage: tools/baseline_t3_off.sh [--record]
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?set GODOT (see CLAUDE.md)}"
BASE=tests/sim/baseline/tier3_off.csv
OUT=tests/sim/out/tier3_off_check.csv
mkdir -p tests/sim/out
"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --bot=tier --days=32 --seed=20260930 --policy=threat --cols=extra --out=tier3_off_check.csv >/dev/null 2>&1
[ -s "$OUT" ] || { echo "tier-3 off: the sweep wrote no rows" >&2; exit 1; }
if [ "${1:-}" = "--record" ]; then cp "$OUT" "$BASE"; echo "tier-3 off recorded $(git rev-parse --short HEAD) ($(wc -l < "$BASE" | tr -d ' ') lines)"; exit 0; fi
if cmp -s "$OUT" "$BASE"; then echo "tier-3 off identical $(git rev-parse --short HEAD)"; else echo "tier-3 off DIFFERS:"; diff "$BASE" "$OUT" | head -6; exit 1; fi
