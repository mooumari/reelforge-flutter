#!/usr/bin/env bash
#
# Proves that a video clip lands on the same source frame no matter how many
# processes the render was split across.
#
# `example/assets/probe.mp4` states each frame's own index in black-and-white
# blocks along the top (see tool/make_probe.py), so reading an exported frame
# says exactly which source frame ended up there -- exactly, with no tolerance
# that could hide an off-by-one. The VideoProbe composition mounts it from
# frame 40 for 120 frames, which puts shard boundaries in the middle of the
# clip -- the case that actually breaks.
#
# VideoProbeHalf is the same clip in a 30fps composition. probe.mp4 runs at
# 60fps, so it asks for every second source frame, and a decoder that takes the
# next frame rather than the frame due at an instant gets it wrong by a growing
# margin. VideoProbe alone cannot see that: at 60fps into 60fps the two are the
# same thing.
#
# Usage: tool/verify_video_mapping.sh [shard counts...]   (default: 1 2 4 8)
set -euo pipefail

cd "$(dirname "$0")/.."

# A Homebrew `dart` on PATH is usually older than the Flutter SDK's and will
# refuse to run these packages outright. The SDK ships its own next to
# `flutter`, so prefer that one.
if command -v flutter > /dev/null; then
  PATH="$(dirname "$(command -v flutter)"):$PATH"
fi
FFMPEG="${FFMPEG:-/opt/homebrew/bin/ffmpeg}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SHARDS=("${@:-1 2 4 8}")
read -r -a SHARDS <<< "${SHARDS[*]}"

# name : first composition frame of the clip : length : source frames per
# composition frame.
PROBES=("VideoProbe:40:120:1" "VideoProbeHalf:20:60:2")

for probe in "${PROBES[@]}"; do
  name="${probe%%:*}"
  echo "$name"
  for n in "${SHARDS[@]}"; do
    echo "  rendering with $n shard(s)..."
    (cd packages/reelforge_cli && dart run bin/reelforge.dart render \
        --project ../../example --composition "$name" \
        --shards "$n" --out "$WORK/${name}_s$n.mp4" \
        --codec libx264 --bitrate 20M) > /dev/null
    "$FFMPEG" -v error -i "$WORK/${name}_s$n.mp4" -f rawvideo -pix_fmt rgba - \
      > "$WORK/${name}_s$n.raw"
  done
done

fail=0
for probe in "${PROBES[@]}"; do
  IFS=: read -r name start length step <<< "$probe"
  for n in "${SHARDS[@]}"; do
    tool/check_probe.py "$WORK/${name}_s$n.raw" "$start" "$length" "$step" \
      "  $name, $n shard(s)" || fail=1
  done

  # Determinism across shard counts: every split must land on the same source
  # frame as a single-process render, not merely on a plausible one.
  python3 - "$WORK" "$name" "${SHARDS[@]}" <<'SAME' || fail=1
import sys
sys.path.insert(0, 'tool')
from check_probe import read

work, name, shards = sys.argv[1], sys.argv[2], [int(s) for s in sys.argv[3:]]
base = read(f'{work}/{name}_s{shards[0]}.raw')
ok = True
for k in shards[1:]:
    other = read(f'{work}/{name}_s{k}.raw')
    diff = [f for f in range(min(len(base), len(other))) if base[f] != other[f]]
    if diff:
        print(f'  {name}, {k} shard(s) differs from {shards[0]} at {diff[:5]}')
        ok = False
sys.exit(0 if ok else 1)
SAME
done

if [ "$fail" = 0 ]; then echo PASS; else echo FAIL; fi
exit "$fail"
