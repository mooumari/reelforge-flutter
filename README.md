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

Pre-alpha, but it works end to end: preview a composition with hot reload,
then render it to MP4 with assets decoded first and the declared audio mixed
in. Video clips are not built yet.

## Preview

```dart
// lib/main.dart
void main() => previewMain(<Composition>[helloFlutter, weeklyDeals]);
```

```bash
cd example && flutter run -d macos
```

Scrub the timeline, then edit a widget and save -- hot reload applies to
compositions like any other Flutter code, and the frame you are parked on
redraws immediately.

The preview builds the **same widget tree the exporter rasterises**, wrapped in
the same `VideoFrame` and laid out at the composition's true size before being
scaled to fit. A 1080-wide composition is laid out at 1080 even in a 600px
window, so what you scrub to is what renders.

Wall-clock time is used in exactly one place: deciding which frame the playhead
is on. The composition never sees it.

| Key | |
|---|---|
| `space` | play / pause |
| `←` `→` | step one frame (`shift` for ten) |
| `home` `end` | jump to first / last frame |
| `L` | toggle loop |

## Assets and audio

A composition must be a pure function of its frame number, which rules out
resolving anything asynchronously mid-render -- frame 12 showing a placeholder
on one run and a photo on the next is exactly the bug that makes a renderer
untrustworthy.

So before a single frame is rasterised, a **declaration pass** builds every
frame of the timeline and collects what the composition asked for:

```dart
Stack(children: [
  const Audio(src: 'assets/music.mp3', volume: 0.4),
  const Sequence(
    from: 40,
    durationInFrames: 25,
    child: Audio(src: 'assets/chime.mp3'),
  ),
  MotionImage(image: badge, width: 160, height: 160),
])
```

`Audio` draws nothing; its position and length come from where it is mounted,
so a [Sequence] schedules it with no extra API. `MotionImage` replaces `Image`
inside compositions -- it declares itself to the pass and paints from an
already-decoded bitmap, and throws a named error rather than silently drawing
nothing if it was somehow missed.

```bash
dart run bin/fluttermotion.dart inspect --project ../../example
```

```text
WeeklyDeals  1080x1920  60fps  300 frames  (5.00s)
  swept 300 frames in 34ms
  audio:
    assets/music.mp3  frames 0-299 (300)  vol 0.4
    assets/chime.mp3  frames 40-64 (25)  vol 1.0
    assets/chime.mp3  frames 180-204 (25)  vol 1.0
  images:
    assets/badge.png
```

**Every frame is visited, not sampled.** That is affordable only because of
the benchmark above: building a frame costs ~0.5 ms against ~17 ms to
rasterise it, so sweeping a 300-frame timeline takes **34 ms** -- roughly 150x
cheaper than rendering it. Sampling would be marginally faster and would
silently miss a sound that plays for two frames inside a `Sequence`, which is
the whole bug class the pass exists to prevent.

The preview runs the same pass before it draws, so it cannot show something
the render would not.

The manifest is what `render` mixes from, so `inspect` is the ground truth for
what you will hear.

### How audio is mixed

Each declared clip becomes one ffmpeg input, trimmed to its window, rebased,
resampled to 48 kHz, scaled by its volume, and delayed to its start frame; the
results are combined with `amix=normalize=0` and muxed against the video with
`-c:v copy`, so mixing never re-encodes a single frame.

Three details are deliberate:

- **Mixed once, against the concatenated video** -- never per shard. A clip can
  straddle a shard boundary, and a shard knows nothing about frames outside its
  own range.
- **`normalize=0`** -- ffmpeg's default divides by the input count, so adding a
  one-second sound effect would duck the music bed under it for that second.
- **`src` is a filesystem path relative to the project, not a Flutter asset
  key.** ffmpeg reads these files directly and knows nothing about the asset
  bundle. For anything under `assets/` the two strings coincide, which is
  convenient but not a guarantee; a clip that resolves to nothing is reported
  by name rather than silently dropped.

Pass `--no-audio` to skip mixing, `--audio-codec` / `--audio-bitrate` to change
the encode (default `aac` at `192k`).

## Render

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

47 tests. The ones that matter assert that a frame is byte-identical when
rendered from a fresh renderer, when reached by playing forward, and when
reached by scrubbing backward from later in the timeline.

## Roadmap

1. ~~Sharded deterministic renderer + test suite + `fluttermotion render`~~ done
2. ~~Scrubber preview (`flutter run`, hot reload)~~ done
3. ~~Declaration pass — asset preloading and audio scheduling~~ done
   (video decode windows still to come)
4. ~~Audio mixing~~ done
5. Video clips
6. On-device export (the moat)

Explicitly deferred: Studio app, timeline UI, cloud rendering, effects library.

## Licence

Source-available under `FSL-1.1-ALv2` — free for everything except building a
competing product, and Apache 2.0 after two years. See `LICENSE.md`,
`NOTICE.md`, and `CLA.md`.
