#!/usr/bin/env bash
# Runs the headless in-app export on a booted iOS simulator.
#
#     tool/ios_export.sh VideoProbe /tmp/probe_ios.mp4 [scale] [bitrate]
#
# iOS has no argv for the same reason Android does not: an app is launched,
# not a process invoked, so `--dart-entrypoint-args` arrives empty and the
# working directory is `/`, which is not writable. The app reads its options
# from export_args.txt in its Documents directory instead; the simulator keeps
# that directory on this machine, so writing and reading it is a file copy.
set -euo pipefail

COMPOSITION="${1:?usage: ios_export.sh <Composition> <output> [scale] [bitrate]}"
OUT="${2:?usage: ios_export.sh <Composition> <output> [scale] [bitrate]}"
SCALE="${3:-1.0}"
BITRATE="${4:-}"

BUNDLE=com.fluttermotion.example
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v flutter > /dev/null; then
  PATH="$(dirname "$(command -v flutter)"):$PATH"
fi

(cd example && flutter build ios --simulator --debug -t lib/export_main.dart > /dev/null)
xcrun simctl install booted example/build/ios/iphonesimulator/Runner.app

DATA="$(xcrun simctl get_app_container booted "$BUNDLE" data)"
DOCS="$DATA/Documents"
mkdir -p "$DOCS"
REMOTE_OUT="$DOCS/${COMPOSITION}_inapp.mp4"
rm -f "$REMOTE_OUT"

{
  printf -- '--composition\n%s\n--out\n%s\n--scale\n%s\n' \
    "$COMPOSITION" "$REMOTE_OUT" "$SCALE"
  [ -n "$BITRATE" ] && printf -- '--bitrate\n%s\n' "$BITRATE"
} > "$DOCS/export_args.txt"

xcrun simctl terminate booted "$BUNDLE" > /dev/null 2>&1 || true
START="$(date +%s)"
PID="$(xcrun simctl launch booted "$BUNDLE" | awk -F': ' '{print $2}')"

# Watch the pid rather than a process list: the app calls exit() when the
# export finishes, so "gone" is the completion signal, and a launchd query
# inside the simulator does not reliably name the app at all.
for _ in $(seq 1 3600); do
  kill -0 "$PID" 2> /dev/null || break
  sleep 1
done

xcrun simctl spawn booted log show --start "@$START" \
  --predicate 'process == "Runner"' 2>/dev/null \
  | grep -o 'flutter: .*' | sed 's/^flutter: //' || true

[ -f "$REMOTE_OUT" ] || { echo "No output at $REMOTE_OUT" >&2; exit 1; }
cp "$REMOTE_OUT" "$OUT"
echo "copied $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
