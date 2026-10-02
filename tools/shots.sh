#!/usr/bin/env bash
# Standard S4 shot list (spec 9.4, 9.6). Usage: tools/shots.sh <out_dir> [extra capture.gd args...]
# Renders with the real renderer (no --headless) at 720x1280 and writes a 40% copy (288x512) of each shot.
# A shot fails on a non-zero exit, a SCRIPT ERROR in its log, a hang (120 s) or a missing PNG. Logs: $OUT/.<name>.log,
# deleted on success.
set -euo pipefail
: "${GODOT:?Set GODOT}"
mkdir -p "$1"; OUT="$(cd "$1" && pwd)"; shift
cd "$(dirname "$0")/.."
cap() {
  local n="$1"; shift
  local log="$OUT/.$n.log"
  rm -f "$OUT/$n.png"
  perl -e 'alarm 120; exec @ARGV' "$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --out="$OUT/$n.png" "$@" > "$log" 2>&1 \
    || { echo "capture $n failed (see $log)"; exit 1; }
  if grep -q 'SCRIPT ERROR' "$log"; then echo "capture $n: SCRIPT ERROR (see $log)"; exit 1; fi
  [ -f "$OUT/$n.png" ] || { echo "capture $n: no PNG (see $log)"; exit 1; }
}
cap day --phase=day "$@"
cap night --phase=night "$@"
cap build --phase=build "$@"
cap fail --phase=fail "$@"
cap retry --phase=retry "$@"
cap cardpick --scene=cardpick --seconds=3 "$@"
for l in west north east; do cap "lane_$l" --lane=$l --seconds=2 "$@"; done
cap hud --phase=day --crop-top=360 "$@"
for f in "$OUT"/*.png; do case "$f" in *_40.png|*/hud.png|*/icons_sheet.png|*/moons.png) continue;; esac; sips -z 512 288 "$f" --out "${f%.png}_40.png" >/dev/null; done
rm -f "$OUT"/.*.log
ls "$OUT"
