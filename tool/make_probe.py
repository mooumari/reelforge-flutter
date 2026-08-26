#!/usr/bin/env python3
"""Regenerates example/assets/probe.mp4, the video-decoder test pattern.

Each frame states its own index twice, in two different currencies:

  * a flat grey background of `2 * index`, which is easy to eyeball and is
    what makes the file useful as a visual scrub, and
  * eight black-or-white blocks along the top, the binary digits of
    `index + 1`.

The `+ 1` matters: a composition paints black outside the clip's window, and
an all-black header would otherwise read as source frame 0. Reserving zero for
"no clip here" makes "the clip is absent" and "the clip is at its first frame"
two different readings rather than one.

The blocks are the part the tests actually read. Grey is a poor carrier for an
exact claim: an exported frame has been through two limited-range colour round
trips and an H.264 quantiser, and the couple of levels that costs is the same
size as the difference between one source frame and the next. Black against
white survives all of it, so "which source frame is this?" gets an exact
answer instead of an answer with a tolerance -- and a tolerance wide enough to
absorb the encoder is wide enough to hide an off-by-one decoder, which is the
entire bug class this file exists to catch.

    tool/make_probe.py            # rewrites example/assets/probe.mp4
"""
import os
import subprocess
import sys

WIDTH, HEIGHT, FPS, FRAMES = 320, 240, 60, 120
BITS = 8
BLOCK = WIDTH // BITS
BLOCK_HEIGHT = 32

FFMPEG = os.environ.get("FFMPEG", "/opt/homebrew/bin/ffmpeg")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "example", "assets", "probe.mp4")


def frame(index):
    grey = (2 * index) & 0xFF
    row = bytearray()
    for x in range(WIDTH):
        row += bytes((grey, grey, grey, 255))
    body = bytes(row) * (HEIGHT - BLOCK_HEIGHT)

    header = bytearray()
    for x in range(WIDTH):
        bit = ((index + 1) >> (x // BLOCK)) & 1
        v = 255 if bit else 0
        header += bytes((v, v, v, 255))
    return bytes(header) * BLOCK_HEIGHT + body


def main():
    proc = subprocess.Popen(
        [FFMPEG, "-y", "-v", "error",
         "-f", "rawvideo", "-pix_fmt", "rgba",
         "-s", f"{WIDTH}x{HEIGHT}", "-r", str(FPS), "-i", "-",
         # High quality, but deliberately not lossless. `-crf 0` makes x264
         # emit a High 4:4:4 Predictive stream even from yuv420p input, and
         # iOS's VideoToolbox refuses to decode that -- "Cannot Decode", with
         # nothing to say it was the profile. macOS accepts it, so the asset
         # can look fine everywhere it is made and fail on the device that
         # matters. Pinning the profile is the point; the crf is just high
         # enough that the pattern is exact and the grey barely moves.
         "-c:v", "libx264", "-preset", "veryslow", "-crf", "12",
         "-profile:v", "high", "-pix_fmt", "yuv420p",
         # Say which matrix these pixels were written with. An untagged file is
         # not neutral, it is ambiguous: ffmpeg, VideoToolbox and MediaCodec
         # each guess, mostly from the height, and they need not agree. 240p is
         # BT.601, which is what ffmpeg used on the way in.
         "-colorspace", "smpte170m", "-color_primaries", "smpte170m",
         "-color_trc", "smpte170m", "-color_range", "tv",
         OUT],
        stdin=subprocess.PIPE,
    )
    for i in range(FRAMES):
        proc.stdin.write(frame(i))
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg failed")
    print(f"wrote {OUT}: {FRAMES} frames, {WIDTH}x{HEIGHT} @{FPS}fps")


if __name__ == "__main__":
    main()
