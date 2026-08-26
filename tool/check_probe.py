#!/usr/bin/env python3
"""Reads a rendered probe back and says which source frame landed where.

    check_probe.py <raw-rgba-file> <start> <length> <step> [label]

`start`, `length` and `step` describe how the composition mounted the clip:
the first composition frame it appears on, how many composition frames it
lasts, and how many source frames pass per composition frame. Composition
frame `f` inside that window must show source frame `step * (f - start)`, and
every frame outside it must show no clip at all.

The reading is exact, not approximate. See tool/make_probe.py for why the
frame index is carried in black-and-white blocks rather than in the grey.
Exit status is 0 only if every frame is exactly right.
"""
import sys

WIDTH, HEIGHT, BITS = 320, 240, 8
BLOCK = WIDTH // BITS


def read(path, width=WIDTH, height=HEIGHT):
    """The source frame each exported frame shows, or None where the clip is
    absent."""
    data = open(path, "rb").read()
    stride = width * height * 4
    out = []
    for i in range(len(data) // stride):
        base = i * stride
        value = 0
        for b in range(BITS):
            x, y = b * BLOCK + BLOCK // 2, 16
            if data[base + (y * width + x) * 4] > 128:
                value |= 1 << b
        # Zero is reserved for "no clip", so the stored value is one more than
        # the source frame index.
        out.append(None if value == 0 else value - 1)
    return out


def grey(path, width=WIDTH, height=HEIGHT):
    """The background grey of each exported frame, for a fidelity number."""
    data = open(path, "rb").read()
    stride = width * height * 4
    centre = (height // 2 * width + width // 2) * 4
    return [data[i * stride + centre] for i in range(len(data) // stride)]


def main():
    path, start, length, step = sys.argv[1], *map(int, sys.argv[2:5])
    label = sys.argv[5] if len(sys.argv) > 5 else path

    shown = read(path)
    greys = grey(path)

    def expected(f):
        return step * (f - start) if start <= f < start + length else None

    wrong = [(f, shown[f], expected(f))
             for f in range(len(shown)) if shown[f] != expected(f)]

    # Informational only: how far the grey drifted where the frame is right.
    # This is the encoder's fidelity, not the decoder's correctness, and
    # conflating the two is what the block pattern exists to stop.
    drift = max((abs(greys[f] - (2 * shown[f] if shown[f] is not None else 0))
                 for f in range(len(shown)) if shown[f] == expected(f)),
                default=0)

    print(f'{label}: {len(shown)} frames, grey drift {drift} levels, '
          + ('every frame exact'
             if not wrong else f'{len(wrong)} WRONG {wrong[:6]}'))
    return 0 if not wrong else 1


if __name__ == "__main__":
    sys.exit(main())
