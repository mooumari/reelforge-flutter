#!/usr/bin/env bash
# Runs the headless in-app export on macOS.
#
#     tool/macos_export.sh AudioProbe /tmp/audio.mp4 [scale] [bitrate]
#
# The copy is the point. `flutter build macos` and the CLI's own render step
# write to the same path -- example/build/macos/.../example.app -- so a CLI
# render silently replaces the in-app binary with the render host. Both accept
# `--composition` and both produce an mp4, so the substitution does not fail;
# it just quietly measures ffmpeg twice and calls one of them the in-app path.
set -euo pipefail

COMPOSITION="${1:?usage: macos_export.sh <Composition> <output> [scale] [bitrate]}"
OUT="${2:?usage: macos_export.sh <Composition> <output> [scale] [bitrate]}"
SCALE="${3:-1.0}"
BITRATE="${4:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v flutter > /dev/null; then
  PATH="$(dirname "$(command -v flutter)"):$PATH"
fi

BUILT="$ROOT/example/build/macos/Build/Products/Release/example.app"
COPY="${TMPDIR:-/tmp}/reelforge-inapp.app"

(cd example && flutter build macos --release -t lib/export_main.dart > /dev/null)
rm -rf "$COPY"
cp -R "$BUILT" "$COPY"

ARGS=(--composition "$COMPOSITION" --out "$OUT" --scale "$SCALE")
[ -n "$BITRATE" ] && ARGS+=(--bitrate "$BITRATE")

cd example && "$COPY/Contents/MacOS/example" "${ARGS[@]}"
