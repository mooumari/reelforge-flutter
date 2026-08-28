#!/usr/bin/env bash
#
# Installs FlutterMotion the way the README says to, into a Flutter app that
# did not exist a minute ago, and renders an MP4 from it.
#
# Everything else in this repo is checked against `example/`, which was built
# alongside the framework and already has the right entitlements, assets,
# fonts and dependencies. That is the one project where adoption cannot fail,
# so it is the one project that proves nothing about adoption. This script
# starts from `flutter create`.
#
# It asserts three things the README claims and nothing previously ran:
#
#   * `init` scaffolds a project that compiles, in both the Dart and the JSON
#     flavours
#   * the sandbox gate refuses the render *before* the build, rather than
#     after the minutes are spent
#   * the MP4 that comes out has frames with something on them
#
#     tool/cold_start.sh          # temp dir, cleaned up
#     KEEP=1 tool/cold_start.sh   # leave the projects behind to poke at
#
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cli="$repo/packages/fluttermotion_cli/bin/fluttermotion.dart"

# `dart run` rather than the `dart pub global activate` the README documents:
# activation is global state belonging to whoever runs this, and a test script
# should not reach into it. Everything past the activation is the same code.
fm() { dart run "$cli" "$@"; }

command -v flutter >/dev/null || { echo "flutter is not on PATH"; exit 1; }
command -v ffmpeg  >/dev/null || { echo "ffmpeg is not on PATH";  exit 1; }

work="$(mktemp -d)"
cleanup() { [ -n "${KEEP:-}" ] && echo "left in $work" || rm -rf "$work"; }
trap cleanup EXIT

fail() { echo "COLD START FAILED: $*" >&2; exit 1; }

# A rendered file with frames on which something is drawn.
#
# The frame check is a floor, not a proof: it catches a video that came out
# blank, which is what a broken install produces. A video that is merely
# *missing* half its content -- bindings with no data behind them -- looks
# fine here, and is what `validate --data` is for.
#
# Several frames rather than one, because a flat frame is not by itself wrong:
# a reel starts on one and every scene boundary passes through one. What would
# be wrong is all of them.
expect_video() {
  local file="$1" frames="$2"
  [ -f "$file" ] || fail "no $file"
  local got
  got="$(ffprobe -v error -select_streams v:0 -count_frames \
    -show_entries stream=nb_read_frames -of csv=p=0 "$file")"
  [ "$got" = "$frames" ] || fail "$file has $got frames, expected $frames"

  local drawn=0 checked=0 n range lo hi
  for fraction in 15 30 45 60 75 90; do
    n=$((frames * fraction / 100))
    # `csv=p=0` puts a trailing comma on each row, so take the fields by
    # position rather than by splitting on the last separator.
    range="$(ffprobe -v error -f lavfi \
      -i "movie=$file,select=eq(n\,$n),signalstats" \
      -show_entries frame_tags=lavfi.signalstats.YMIN,lavfi.signalstats.YMAX \
      -of csv=p=0 | head -1 | awk -F, '{print $1, $2}')"
    lo="${range%% *}"; hi="${range##* }"
    checked=$((checked + 1))
    [ -n "$lo" ] && [ -n "$hi" ] && [ $((hi - lo)) -gt 8 ] &&
      drawn=$((drawn + 1))
  done
  [ "$drawn" -gt $((checked / 2)) ] ||
    fail "$file: only $drawn of $checked sampled frames have anything on them"
  echo "  ok: $file, $frames frames, $drawn/$checked sampled frames drawn"
}

echo "== the Dart composition path =="
cd "$work"
flutter create --platforms=macos dart_app >/dev/null
cd dart_app
fm init >/dev/null
[ -f lib/video/compositions.dart ] || fail "init wrote no composition"
[ -f lib/render_main.dart ] || fail "init wrote no render entry point"

# `flutter create` scaffolds a sandboxed macOS target, so this is every new
# project, and the whole point of checking before the build is that the build
# is minutes long.
if fm render --composition Intro --out intro.mp4 >/dev/null 2>&1; then
  fail "a sandboxed project rendered instead of being refused"
fi
fm init --fix-entitlements >/dev/null
fm render --composition Intro --out intro.mp4 >/dev/null
expect_video intro.mp4 90

echo "== the JSON document path =="
cd "$work"
flutter create --platforms=macos json_app >/dev/null
cd json_app
fm init --json --fix-entitlements >/dev/null
[ -f video/reel.json ] || fail "init --json wrote no document"
fm validate video/reel.json --data video/reel_data.json >/dev/null \
  || fail "the document init just wrote does not validate against its own data"
fm render video/reel.json --data video/reel_data.json --out reel.mp4 >/dev/null
expect_video reel.mp4 420

echo "cold start OK"
