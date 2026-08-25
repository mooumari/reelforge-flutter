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

Pre-alpha. The rendering approach is validated (see `benchmarks/`); the public
API is not yet written.

## Layout

| Path | What |
|---|---|
| `packages/fluttermotion` | The composition framework |
| `packages/fluttermotion_cli` | `fluttermotion render` |
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

Reproduce:

```bash
cd benchmarks/spike
flutter build macos --release
./build/macos/Build/Products/Release/spike.app/Contents/MacOS/spike
```

## Roadmap

1. Sharded deterministic renderer + golden test suite + `fluttermotion render`
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
