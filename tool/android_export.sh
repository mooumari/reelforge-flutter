#!/usr/bin/env bash
# Runs the headless in-app export on an Android device and brings the file back.
#
# Android has no argv: `flutter run --dart-entrypoint-args` arrives empty
# because an activity is started rather than a process invoked. The app reads
# the same tokens from export_args.txt in its own external files directory, so
# this script pushes that file, starts the activity, waits for the app to exit,
# and pulls the result. One `flutter build apk` covers every composition.
#
#     tool/android_export.sh VideoProbe /tmp/probe_android.mp4 [scale]
set -euo pipefail

COMPOSITION="${1:?usage: android_export.sh <Composition> <local-output> [scale] [bitrate]}"
LOCAL_OUT="${2:?usage: android_export.sh <Composition> <local-output> [scale] [bitrate]}"
SCALE="${3:-1.0}"
BITRATE="${4:-}"

PKG=com.reelforge.example
ACTIVITY="$PKG/.MainActivity"
REMOTE_DIR="/sdcard/Android/data/$PKG/files"
REMOTE_OUT="$REMOTE_DIR/${COMPOSITION}_inapp.mp4"

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="$ROOT/example/build/app/outputs/flutter-apk/app-release.apk"

[ -f "$APK" ] || {
  echo "No APK. Build it first:" >&2
  echo "  (cd example && flutter build apk --release -t lib/export_main.dart)" >&2
  exit 1
}

# Reinstalling every time is cheap next to a wrong-build debugging session.
"$ADB" install -r "$APK" >/dev/null

"$ADB" shell mkdir -p "$REMOTE_DIR"
"$ADB" shell rm -f "$REMOTE_OUT"

ARGS="$(mktemp)"
printf -- '--composition\n%s\n--out\n%s\n--scale\n%s\n' \
  "$COMPOSITION" "$REMOTE_OUT" "$SCALE" > "$ARGS"
[ -n "$BITRATE" ] && printf -- '--bitrate\n%s\n' "$BITRATE" >> "$ARGS"
"$ADB" push "$ARGS" "$REMOTE_DIR/export_args.txt" >/dev/null
rm -f "$ARGS"

"$ADB" logcat -c
"$ADB" shell am force-stop "$PKG"
"$ADB" shell am start -n "$ACTIVITY" >/dev/null

# The export calls exit() when it is done, so "no process" is the signal. A
# poll rather than a timeout: exports run from seconds to minutes depending on
# the composition, and guessing wrong either truncates or wastes minutes.
#
# Three consecutive misses, and on `pidof`'s *output* rather than its exit
# status. A single `adb shell` under a loaded emulator can come back empty or
# non-zero while the app is very much alive, and one such blink ends the wait,
# pulls a half-written file and reports it as the result -- which is worse
# than either failure mode this loop was written to avoid, because the file
# looks like an answer. A 1800-frame reel was truncated at frame 1020 that
# way, and only the missing moov atom gave it away.
started=0
missed=0
for _ in $(seq 1 3600); do
  if [ -n "$("$ADB" shell pidof "$PKG" 2>/dev/null | tr -d '\r')" ]; then
    started=1
    missed=0
  elif [ "$started" = 1 ]; then
    missed=$((missed + 1))
    [ "$missed" -ge 3 ] && break
  fi
  sleep 1
done

"$ADB" logcat -d | grep "I flutter" | sed 's/.*I flutter : //'

# The export writes its own account of itself next to the video. logcat is a
# ring buffer -- a 1800-frame reel can push its own first half out of it -- so
# the file, not the console, is what says whether the run finished.
"$ADB" shell cat "$REMOTE_DIR/export_log.txt" 2>/dev/null \
  | grep -q '^exported ' || {
  echo "The export did not report success; $REMOTE_OUT is not a result." >&2
  exit 1
}

"$ADB" pull "$REMOTE_OUT" "$LOCAL_OUT" >/dev/null 2>&1 || {
  echo "No output at $REMOTE_OUT" >&2
  exit 1
}
echo "pulled $LOCAL_OUT ($(wc -c < "$LOCAL_OUT" | tr -d ' ') bytes)"
