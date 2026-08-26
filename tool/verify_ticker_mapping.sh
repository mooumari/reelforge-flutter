#!/usr/bin/env bash
#
# Proves that a widget animating on its own Ticker -- the way a widget lifted
# out of a real app does -- lands on the same animation state no matter how
# many processes the render was split across.
#
# The TickerProbe composition owns an AnimationController on a
# SingleTickerProviderStateMixin, repeating every 1000ms, and paints its value
# as a grey. Reading one pixel out of an exported frame therefore says exactly
# where the animation was. A Ticker treats its *first* tick as elapsed zero,
# so a shard entering at frame 45 would otherwise restart the animation --
# and video that is one animation out still looks like video.
#
# Usage: tool/verify_ticker_mapping.sh [shard counts...]   (default: 1 2 4 8)
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

for n in "${SHARDS[@]}"; do
  echo "rendering with $n shard(s)..."
  (cd packages/fluttermotion_cli && dart run bin/fluttermotion.dart render \
      --project ../../example --composition TickerProbe \
      --shards "$n" --out "$WORK/ticker_s$n.mp4" \
      --codec libx264 --bitrate 20M) > /dev/null
  "$FFMPEG" -v error -i "$WORK/ticker_s$n.mp4" -f rawvideo -pix_fmt rgba - \
    > "$WORK/out_s$n.raw"
done

python3 - "$WORK" "${SHARDS[@]}" <<'PY'
import sys
work, shards = sys.argv[1], [int(s) for s in sys.argv[2:]]
W, H = 320, 240
n = W * H * 4
centre = (H // 2 * W + W // 2) * 4

def read(k):
    d = open(f'{work}/out_s{k}.raw', 'rb').read()
    return [d[i * n + centre] for i in range(len(d) // n)]

# A 1000ms repeat at 60fps: frame f sits (f % 60) / 60 through the cycle.
def expected(f):
    return round((f % 60) / 60 * 255)

sets = {k: read(k) for k in shards}
ok = True
base = sets[shards[0]]

for k, frames in sets.items():
    bad = [(f, frames[f], expected(f))
           for f in range(len(frames)) if abs(frames[f] - expected(f)) > 2]
    print(f'  {k:>2} shard(s): {len(frames)} frames, '
          f'{"OK" if not bad else f"{len(bad)} WRONG {bad[:5]}"}')
    ok &= not bad
    if k != shards[0]:
        diff = [f for f in range(min(len(base), len(frames)))
                if abs(base[f] - frames[f]) > 2]
        if diff:
            print(f'      differs from {shards[0]}-shard at {diff[:5]}')
            ok = False

print('PASS' if ok else 'FAIL')
sys.exit(0 if ok else 1)
PY
