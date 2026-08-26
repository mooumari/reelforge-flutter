# FlutterMotion

**Build videos with Flutter.** Use any Flutter widget as motion graphics,
preview them instantly, and render them anywhere.

```dart
class ProductPromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final frame = Video.frame(context);
    return Stack(children: [
      ProductCard(product: product),               // your app's own widget
      Positioned(
        bottom: interpolate(frame, [0, 30], [0, 100]),
        child: Text(product.name),
      ),
    ]);
  }
}
```

```bash
fluttermotion render lib/video.dart --out promo.mp4 --fps 60 --size 1080x1920
```

This is **not** a screen recorder. A composition is a deterministic function of
frame number: `data -> widgets -> frames -> MP4`.

## Status

Pre-alpha, but it renders. `fluttermotion render` produces an MP4 from a
composition today. Audio, video clips, and the preview scrubber are not built
yet.

## Try it

```bash
# lib/render_main.dart in your own Flutter project:
#   void main(List<String> args) => renderMain(args, [myComposition]);

cd packages/fluttermotion_cli
dart run bin/fluttermotion.dart list   --project ../../example
dart run bin/fluttermotion.dart render --project ../../example \
  --composition WeeklyDeals --out deals.mp4
```

The CLI builds your project with that entry point, asks the resulting binary
what compositions it defines, then spawns it once per shard to render
contiguous frame ranges in parallel and stream-copies the segments together.

## Layout

| Path | What |
|---|---|
| `packages/fluttermotion` | The composition framework |
| `packages/fluttermotion_cli` | `fluttermotion render` |
| `example` | A working project with two compositions |
| `benchmarks/spike` | Throughput + determinism harness |

## Validated so far

Measured on an M3 Max, Flutter 3.35 release mode, at 1080x1920 with a complex
composition (40 shadowed cards, gradients, `CustomPaint`, `BackdropFilter`):

- **Determinism is byte-exact.** Identical output across isolated renders and
  across forward and backward scrubbing to the same frame.
- **Rasterisation is the entire cost.** build+layout+paint is 0.5 ms/frame;
  `toImage()` is ~17 ms; GPU readback is 0.2 ms.
- **~0.75x realtime end-to-end** to MP4, single process. A 60 s vertical video
  exports in roughly 80 s.
- **Overlapping frames does not reliably help.** Across runs, serial ranged
  53-61 fps and pipelined 53-63 fps -- the difference is inside run-to-run
  variance, and depth 4 and 8 were measurably *worse*. The raster path is a
  saturated serial ceiling per process, so the renderer shards frame ranges
  across processes rather than pipelining deeper. Overlap is verified byte-safe
  (24/24 frames identical to serial) if it is ever needed.

### Sharding does scale

The spike could not answer whether separate processes would contend on the one
GPU. Measured end to end on `WeeklyDeals` (1080x1920, 300 frames):

| shards | wall time | vs realtime | speedup | output size |
|---|---|---|---|---|
| 1 | 8.04 s | 0.62x | 1.00x | 7.4 MB |
| 2 | 5.64 s | 0.89x | 1.43x | 8.0 MB |
| 4 | 4.14 s | 1.21x | **1.94x** | 8.7 MB |
| 8 | 4.37 s | 1.15x | 1.84x | 10.7 MB |

Four processes is the knee, which is why `--shards auto` picks 4. Past that,
GPU contention cancels the gain and the file keeps growing: each segment opens
with a keyframe, so 8 shards costs 45% more bytes for no speed. **Sharding
trades bitrate for wall time** -- worth knowing before raising the default.

Correctness of the sharded path was checked against the single-process render
with per-frame SSIM: 300/300 frames compared, minimum 0.9906, none below 0.95.
A misordered or duplicated frame would score 0.3-0.7. The ~0.6% delta is h264
quantisation noise from differing GOP boundaries, not content drift.

Reproduce:

```bash
cd benchmarks/spike
flutter build macos --release
./build/macos/Build/Products/Release/spike.app/Contents/MacOS/spike
```

## Tests

```bash
cd packages/fluttermotion && flutter test
```

25 tests. The ones that matter assert that a frame is byte-identical when
rendered from a fresh renderer, when reached by playing forward, and when
reached by scrubbing backward from later in the timeline.

## Roadmap

1. ~~Sharded deterministic renderer + test suite + `fluttermotion render`~~ done
2. Scrubber preview (`flutter run`, hot reload)
3. Declaration pass — asset preloading, video decode windows, audio scheduling
4. Audio
5. Video clips
6. On-device export (the moat)

Explicitly deferred: Studio app, timeline UI, cloud rendering, effects library.

## Licence

Source-available under `FSL-1.1-ALv2` — free for everything except building a
competing product, and Apache 2.0 after two years. See `LICENSE.md`,
`NOTICE.md`, and `CLA.md`.
