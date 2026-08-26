#!/usr/bin/env bash
#
# Proves that a video clip lands on the same source frame no matter how many
# processes the render was split across.
#
# `example/assets/probe.mp4` encodes each frame's own index as its grey value
# (frame i is rgb(2i, 2i, 2i)), so reading one pixel out of an exported frame
# says exactly which source frame ended up there. The VideoProbe composition
# mounts it from frame 40 for 120 frames, which puts shard boundaries in the
# middle of the clip -- the case that actually breaks.
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
    (cd packages/fluttermotion_cli && dart run bin/fluttermotion.dart render \
        --project ../../example --composition "$name" \
        --shards "$n" --out "$WORK/${name}_s$n.mp4" \
        --codec libx264 --bitrate 20M) > /dev/null
    "$FFMPEG" -v error -i "$WORK/${name}_s$n.mp4" -f rawvideo -pix_fmt rgba - \
      > "$WORK/${name}_s$n.raw"
  done
done

python3 - "$WORK" "${PROBES[*]}" "${SHARDS[@]}" <<'PY'
import sys
work = sys.argv[1]
probes = sys.argv[2].split()
shards = [int(s) for s in sys.argv[3:]]
W, H, = 320, 240
n = W * H * 4
centre = (H // 2 * W + W // 2) * 4

def read(name, k):
    d = open(f'{work}/{name}_s{k}.raw', 'rb').read()
    return [d[i * n + centre] for i in range(len(d) // n)]

ok = True
for probe in probes:
    name, start, length, step = probe.split(':')
    start, length, step = int(start), int(length), int(step)
    print(name)

    # Grey is twice the source frame index, and the source advances `step`
    # frames for every frame of the composition.
    def expected(f, start=start, length=length, step=step):
        inside = start <= f < start + length
        return 2 * step * (f - start) if inside else 0

    sets = {k: read(name, k) for k in shards}
    base = sets[shards[0]]

    for k, frames in sets.items():
        bad = [(f, frames[f], expected(f))
               for f in range(len(frames)) if abs(frames[f] - expected(f)) > 1]
        print(f'  {k:>2} shard(s): {len(frames)} frames, '
              f'{"OK" if not bad else f"{len(bad)} WRONG {bad[:5]}"}')
        ok &= not bad
        if k != shards[0]:
            diff = [f for f in range(min(len(base), len(frames)))
                    if abs(base[f] - frames[f]) > 1]
            if diff:
                print(f'      differs from {shards[0]}-shard at {diff[:5]}')
                ok = False

print('PASS' if ok else 'FAIL')
sys.exit(0 if ok else 1)
PY
