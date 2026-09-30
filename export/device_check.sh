#!/usr/bin/env bash
# From S3 on, a plain URL resumes a saved run from localStorage. Add ?reset=1 to debug URLs for a fresh start.
# Release URLs can't be reset; use a fresh browser profile.
# Usage: export/device_check.sh <url> <out_dir>   (D-138)
# Opens <url> in the iOS Simulator (Safari, a notch iPhone) and, when installed, the Android Emulator
# (Chrome), waits WAIT_S seconds (default 45) and saves screenshots. It never installs anything: when a
# runtime or device is missing it prints the one-time step for the author. The emulator is shut down
# at the end; the iOS Simulator is left booted.
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: $0 <url> <out_dir>"; exit 2; }
URL="$1"; OUT="$2"; WAIT="${WAIT_S:-45}"
mkdir -p "$OUT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

RUNTIMES=$(xcrun simctl list runtimes 2>/dev/null || true)
if printf '%s\n' "$RUNTIMES" | grep -E '^iOS .*SimRuntime' | grep -v unavailable >/dev/null; then
  UDID=$(xcrun simctl list devices available | grep -E 'iPhone [0-9]+ Pro \(' | head -1 | grep -oE '[0-9A-F-]{36}' || true)
  if [ -z "$UDID" ]; then
    echo "MISSING iPhone Pro simulator. One-time step (author): Xcode > Window > Devices and Simulators > + > iPhone 17 Pro"
  else
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b >/dev/null
    xcrun simctl openurl "$UDID" "$URL"
    sleep "$WAIT"
    xcrun simctl io "$UDID" screenshot "$OUT/ios.png" >/dev/null 2>&1
    echo "ios: $OUT/ios.png"
  fi
else
  echo "MISSING iOS Simulator runtime. One-time step (author): xcodebuild -downloadPlatform iOS"
fi

SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
AVD=""
if [ -x "$SDK/emulator/emulator" ]; then
  AVD=$("$SDK/emulator/emulator" -list-avds 2>/dev/null | awk '!/^INFO/ && NF {print; exit}' || true)
fi
if [ -z "$AVD" ]; then
  # D-141: no emulator -> Playwright Chromium, Pixel 7 profile. Labelled "emulated", not device.
  PW="${LST_PW_DIR:-$HOME/.cache/lst-playwright}"
  [ -d "$PW/node_modules/playwright" ] || npm i --prefix "$PW" --no-audit --no-fund playwright@1.63.0 >/dev/null
  LST_PW_DIR="$PW" node "$(dirname "$0")/pw_check.mjs" "$URL" "$OUT/android_emulated.png" android
  exit $?
fi
ADB="$SDK/platform-tools/adb"
SERIAL=emulator-5554
"$SDK/emulator/emulator" -avd "$AVD" -port 5554 -no-window -no-snapshot-save -no-audio >/dev/null 2>&1 &
booted=""
for _ in $(seq 1 150); do
  if [ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then booted=1; break; fi
  sleep 2
done
[ -n "$booted" ] || { echo "ERROR: Android emulator $AVD did not boot within 300 s"; "$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || true; exit 1; }
case "$URL" in
  http://localhost:*|http://127.0.0.1:*)
    PORT=${URL#*//*:}; PORT=${PORT%%/*}
    "$ADB" -s "$SERIAL" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null ;;  # localhost stays a secure context
esac
# Skip Chrome's first-run screens.
"$ADB" -s "$SERIAL" shell 'echo "_ --disable-fre --no-default-browser-check --no-first-run" > /data/local/tmp/chrome-command-line'
"$ADB" -s "$SERIAL" shell am set-debug-app --persistent com.android.chrome >/dev/null
"$ADB" -s "$SERIAL" shell am start -a android.intent.action.VIEW -d "$URL" com.android.chrome >/dev/null
sleep "$WAIT"
"$ADB" -s "$SERIAL" exec-out screencap -p > "$OUT/android.png"
echo "android: $OUT/android.png"
"$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || true
