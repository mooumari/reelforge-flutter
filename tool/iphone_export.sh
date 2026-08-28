#!/usr/bin/env bash
# Runs the headless in-app export on a physically connected iPhone.
#
#     tool/iphone_export.sh VideoProbe /tmp/probe_iphone.mp4 [scale] [bitrate]
#
# The simulator runs Apple's software H.264 encoder; a real phone runs the one
# in the SoC. Stride, plane alignment and colour handling are where those two
# differ, so a simulator pass is not evidence about a device.
#
# Options go in and results come out through the app's own data container,
# which devicectl can read and write for a development-signed app. There is no
# argv and no console: a release build launched this way says nothing to
# stdout, so the export writes export_log.txt beside its output and this
# script brings that back too.
set -euo pipefail

COMPOSITION="${1:?usage: iphone_export.sh <Composition> <output> [scale] [bitrate]}"
OUT="${2:?usage: iphone_export.sh <Composition> <output> [scale] [bitrate]}"
SCALE="${3:-1.0}"
BITRATE="${4:-}"

BUNDLE=com.reelforge.example
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v flutter > /dev/null; then
  PATH="$(dirname "$(command -v flutter)"):$PATH"
fi

DEVICE="${IPHONE:-$(xcrun devicectl list devices 2>/dev/null \
  | awk '$0 ~ /connected/ && $0 ~ /iPhone/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-/) print $i; exit}')}"
[ -n "$DEVICE" ] || { echo "No connected iPhone. Set IPHONE=<identifier>." >&2; exit 1; }

container() {
  xcrun devicectl device "$1" files --device "$DEVICE" \
    --domain-type appDataContainer --domain-identifier "$BUNDLE" \
    --username mobile "${@:2}"
}

(cd example && flutter build ios --release -t lib/export_main.dart > /dev/null)
xcrun devicectl device install app --device "$DEVICE" \
  example/build/ios/iphoneos/Runner.app > /dev/null

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
{
  # No --out: the export defaults into its own Documents directory, which is
  # the only device path knowable from this side.
  printf -- '--composition\n%s\n--scale\n%s\n' "$COMPOSITION" "$SCALE"
  [ -n "$BITRATE" ] && printf -- '--bitrate\n%s\n' "$BITRATE"
} > "$WORK/export_args.txt"

xcrun devicectl device copy to --device "$DEVICE" --domain-type appDataContainer \
  --domain-identifier "$BUNDLE" --user mobile \
  --source "$WORK/export_args.txt" --destination Documents/export_args.txt > /dev/null

REMOTE="Documents/${COMPOSITION}_inapp.mp4"
xcrun devicectl device process launch --device "$DEVICE" \
  --terminate-existing "$BUNDLE" > /dev/null

# devicectl cannot watch a process, so watch for the file the run produces.
for _ in $(seq 1 900); do
  if xcrun devicectl device info files --device "$DEVICE" \
      --domain-type appDataContainer --domain-identifier "$BUNDLE" \
      --username mobile 2> /dev/null | grep -q "${COMPOSITION}_inapp.mp4"; then
    break
  fi
  sleep 2
done

# The log first, so a failed run still explains itself.
if xcrun devicectl device copy from --device "$DEVICE" --domain-type appDataContainer \
    --domain-identifier "$BUNDLE" --user mobile \
    --source Documents/export_log.txt --destination "$WORK/log.txt" > /dev/null 2>&1; then
  cat "$WORK/log.txt"
fi

xcrun devicectl device copy from --device "$DEVICE" --domain-type appDataContainer \
  --domain-identifier "$BUNDLE" --user mobile \
  --source "$REMOTE" --destination "$OUT" > /dev/null 2>&1 || {
  echo "No output at $REMOTE" >&2
  exit 1
}
echo "copied $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
