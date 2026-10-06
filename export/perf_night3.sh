#!/usr/bin/env bash
# Night-3 perf on the iOS Simulator (S4 spec 9.5, D-196). Usage: export/perf_night3.sh <web_profile_build_dir> <out_dir>
# Serves the build on localhost:8765, adds seed_save.html + the fixtures, and opens them in Safari:
# 1. f=night3_closeup (resumes into day 3's day; travelers queue) -> day_peak.png after 90 s (its frozen PERF line is the day window).
# Needs load + 2 s warm-up + 60 s window < 100 s for the night line to be frozen before the shot.
# QUERY (optional, e.g. QUERY="warmup=0&perfwarm=4") is appended to both game URLs as a query string (to=/%3F<query>, "&" encoded).
# DAY_FIXTURE (optional, default night3_closeup) picks the day fixture, e.g. DAY_FIXTURE=day3_counter5 (E1).
# NIGHT_ONLY=1 (optional) skips step 1 (the day half), so a run takes about 2 minutes.
# A mid-run idle sample (cpu_idle_mid=, one per phase) is printed from a background subshell about halfway through each wait.
# 2. f=night3_start (resumes straight into night 3) -> night3_80s.png after 100 s (the overlay freezes its reading once 60 s of frames are counted, after a 2 s warm-up).
set -euo pipefail
BUILD="$1"; OUT="$2"; PORT=8765
TO="/"; [ -z "${QUERY:-}" ] || TO="/%3F${QUERY//&/%26}"
DAY_FIXTURE="${DAY_FIXTURE:-night3_closeup}"
[ -f "$(dirname "$0")/fixtures/$DAY_FIXTURE.save.json" ] || { echo "no fixture $DAY_FIXTURE" >&2; exit 1; }
echo "day_fixture=$DAY_FIXTURE"
# The reading depends on what else the Mac is doing (S4: 59.5 fps idle vs 51.9 with an editor at 53% CPU), so wait
# for an idle machine (PERF_MIN_IDLE, default 75%) and print the idle figure next to the reading (D-209).
cpu_idle() { top -l 2 -n 0 | awk '/CPU usage/ {v=$7} END {gsub("%","",v); print int(v)}'; }
MIN_IDLE="${PERF_MIN_IDLE:-75}"
# A previous run leaves Safari playing the game; stop it before measuring idle.
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" xcrun simctl terminate booted com.apple.mobilesafari 2>/dev/null && sleep 15 || true
for _ in $(seq 1 40); do IDLE=$(cpu_idle); [ "$IDLE" -ge "$MIN_IDLE" ] && break; echo "cpu idle ${IDLE}% < ${MIN_IDLE}%, waiting"; sleep 15; done
echo "cpu_idle_before=${IDLE}%"
mkdir -p "$OUT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cp "$(dirname "$0")/seed_save.html" "$BUILD/"
mkdir -p "$BUILD/fixtures" && cp "$(dirname "$0")"/fixtures/*.save.json "$BUILD/fixtures/"
grep -q LST_BUILD "$BUILD/index.html" || sed -i '' 's#</head>#<script>window.LST_BUILD="local";</script></head>#' "$BUILD/index.html"
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then echo "port $PORT is busy" >&2; exit 1; fi
python3 "$(dirname "$0")/serve_nocache.py" "$PORT" "$BUILD" >/dev/null 2>&1 & SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
UDID=$(xcrun simctl list devices available | grep -E 'iPhone [0-9]+ Pro \(' | head -1 | grep -oE '[0-9A-F-]{36}' || true)
[ -n "$UDID" ] || { echo "no available 'iPhone <n> Pro' simulator (xcrun simctl list devices available)" >&2; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl terminate "$UDID" com.apple.mobilesafari 2>/dev/null || true
if [ -z "${NIGHT_ONLY:-}" ]; then
xcrun simctl openurl "$UDID" "http://localhost:$PORT/seed_save.html?f=$DAY_FIXTURE&to=$TO"
( sleep 45; echo "cpu_idle_mid=$(cpu_idle)% phase=day" ) & MID=$!   # sampled in the background: timings unchanged
sleep 90; xcrun simctl io "$UDID" screenshot "$OUT/day_peak.png" >/dev/null; wait $MID
xcrun simctl terminate "$UDID" com.apple.mobilesafari 2>/dev/null || true   # no hidden tab flushing its DAY save
fi
xcrun simctl openurl "$UDID" "http://localhost:$PORT/seed_save.html?f=night3_start&to=$TO"
( sleep 50; echo "cpu_idle_mid=$(cpu_idle)% phase=night" ) & MID=$!
sleep 100; xcrun simctl io "$UDID" screenshot "$OUT/night3_80s.png" >/dev/null; wait $MID
echo "ios: $OUT/night3_80s.png"
echo "cpu_idle_after=$(cpu_idle)%"
