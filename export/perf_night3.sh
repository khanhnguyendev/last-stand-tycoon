#!/usr/bin/env bash
# Night-3 perf on the iOS Simulator (S4 spec 9.5, D-196). Usage: export/perf_night3.sh <web_profile_build_dir> <out_dir>
# Serves the build on localhost:8765, adds seed_save.html + the fixtures, and opens them in Safari:
# 1. f=night3_closeup (resumes into day 3's day; travelers queue) -> day_peak.png after 90 s (its frozen PERF line is the day window).
# Needs load + 2 s warm-up + 60 s window < 100 s for the night line to be frozen before the shot.
# 2. f=night3_start (resumes straight into night 3) -> night3_80s.png after 100 s (the overlay freezes its reading once 60 s of frames are counted, after a 2 s warm-up).
set -euo pipefail
BUILD="$1"; OUT="$2"; PORT=8765
mkdir -p "$OUT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cp "$(dirname "$0")/seed_save.html" "$BUILD/"
mkdir -p "$BUILD/fixtures" && cp "$(dirname "$0")"/fixtures/*.save.json "$BUILD/fixtures/"
grep -q LST_BUILD "$BUILD/index.html" || sed -i '' 's#</head>#<script>window.LST_BUILD="local";</script></head>#' "$BUILD/index.html"
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then echo "port $PORT is busy" >&2; exit 1; fi
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$BUILD" >/dev/null 2>&1 & SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
UDID=$(xcrun simctl list devices available | grep -E 'iPhone [0-9]+ Pro \(' | head -1 | grep -oE '[0-9A-F-]{36}' || true)
[ -n "$UDID" ] || { echo "no available 'iPhone <n> Pro' simulator (xcrun simctl list devices available)" >&2; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl terminate "$UDID" com.apple.mobilesafari 2>/dev/null || true
xcrun simctl openurl "$UDID" "http://localhost:$PORT/seed_save.html?f=night3_closeup&to=/"
sleep 90; xcrun simctl io "$UDID" screenshot "$OUT/day_peak.png" >/dev/null
xcrun simctl terminate "$UDID" com.apple.mobilesafari 2>/dev/null || true   # no hidden tab flushing its DAY save
xcrun simctl openurl "$UDID" "http://localhost:$PORT/seed_save.html?f=night3_start&to=/"
sleep 100; xcrun simctl io "$UDID" screenshot "$OUT/night3_80s.png" >/dev/null
echo "ios: $OUT/night3_80s.png"
