# spike

The throughput and determinism harness. It is not a package anyone installs --
it is the thing that produces the numbers quoted in `docs/guide.md`, and the
reason those numbers can be checked rather than believed.

It renders the same compositions the framework does, but through a bare
`WidgetsFlutterBinding` with no CLI and no ffmpeg in the way, so the cost it
reports is the cost of Flutter itself: build, layout, paint, `toImage()` and
GPU readback, timed separately.

## Running it

Release mode, on real hardware, with nothing else on the machine -- these are
wall-clock numbers and they notice a busy CPU.

```bash
cd benchmarks/spike
flutter run -d macos --release \
  --dart-define=reportPath="$PWD/bench_result.json"
```

The app renders, writes `bench_result.json` and exits on its own. The
`reportPath` define is not optional in practice: a macOS app's working
directory is `/`, so the path has to be absolute, and hard-coding one belongs
to whoever's machine it was.

## What it measures

- Per-frame cost at 1080x1920, simple and complex compositions, with and
  without GPU readback -- the split is what shows that rasterisation, not the
  widget work, is the whole bill.
- Determinism: the same frame rendered twice, from a fresh renderer and after
  scrubbing, compared byte for byte.
- Pipeline correctness, and one end-to-end encode.

`bench_result.json` is committed. It records the Flutter version and the
machine along with the numbers, because neither means anything without the
other -- when the SDK moves, this is re-run and the file replaced.
