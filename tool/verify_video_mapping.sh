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
# Usage: tool/verify_video_mapping.sh [shard counts...]   (default: 1 2 4 8)
set -euo pipefail

cd "$(dirname "$0")/.."
FFMPEG="${FFMPEG:-/opt/homebrew/bin/ffmpeg}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SHARDS=("${@:-1 2 4 8}")
read -r -a SHARDS <<< "${SHARDS[*]}"

for n in "${SHARDS[@]}"; do
  echo "rendering with $n shard(s)..."
  (cd packages/fluttermotion_cli && dart run bin/fluttermotion.dart render \
      --project ../../example --composition VideoProbe \
      --shards "$n" --out "$WORK/probe_s$n.mp4" \
      --codec libx264 --bitrate 20M) > /dev/null
  "$FFMPEG" -v error -i "$WORK/probe_s$n.mp4" -f rawvideo -pix_fmt rgba - \
    > "$WORK/out_s$n.raw"
done

python3 - "$WORK" "${SHARDS[@]}" <<'PY'
import sys
work, shards = sys.argv[1], [int(s) for s in sys.argv[2:]]
W, H, = 320, 240
n = W * H * 4
centre = (H // 2 * W + W // 2) * 4

def read(k):
    d = open(f'{work}/out_s{k}.raw', 'rb').read()
    return [d[i * n + centre] for i in range(len(d) // n)]

# The clip is mounted from frame 40 for 120 frames, untrimmed.
def expected(f):
    return 0 if (f < 40 or f > 159) else 2 * (f - 40)

sets = {k: read(k) for k in shards}
ok = True
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
