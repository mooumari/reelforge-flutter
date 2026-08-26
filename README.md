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
then render it to MP4 with assets decoded first, video clips composited into
the widget tree, and the declared audio mixed in. The same composition also
exports from inside a running app, on device, with no ffmpeg and no server --
and widgets lifted straight out of an existing app render correctly, including
the ones that animate on their own clock.

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
is on. The composition never sees it -- with one exception, which is that a
widget animating on its own `Ticker` still animates on the wall clock *in the
preview*. See [What still is not true](#what-still-is-not-true).

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
  swept 300 frames in 32ms
  audio:
    assets/music.mp3  frames 0-299 (300)  vol 0.4
    assets/chime.mp3  frames 40-64 (25)  vol 1.0
    assets/chime.mp3  frames 180-204 (25)  vol 1.0
  images:
    assets/badge.png

VideoShowcase  1280x720  60fps  120 frames  (2.00s)
  swept 120 frames in 2ms
  video:
    assets/clip.mp4  frames 0-119 (120)  decode 960x540
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

## Video clips

```dart
Sequence(
  from: 60,
  durationInFrames: 120,
  child: VideoClip(src: 'assets/clip.mp4', decodeWidth: 960),
)
```

A `VideoClip` is a real part of the widget tree. It can be rounded, tilted,
masked, blurred, or drawn under Flutter text -- the example does all of those
at once.

That is the whole reason this exists rather than wrapping `video_player`. A
platform view renders in its own layer, outside Flutter's scene graph, so
`RenderRepaintBoundary.toImage()` cannot see it: a `video_player` inside a
composition exports as a **black hole** in every frame. `VideoClip` decodes
with ffmpeg and paints the pixels through `RawImage`, so what you see is what
gets encoded. It also makes playback a function of frame number rather than of
the wall clock, which is what keeps the render deterministic.

### Frame accuracy across shards

Frames are rendered by several processes over different ranges, so a clip must
land on the *same* source frame whether decoding entered at the clip's start
or half way through it. Getting this wrong is nearly invisible -- video that is
one frame out still looks like video.

Naive `-ss` cannot promise it: input seeking rebases timestamps to zero, so the
`fps` filter's sampling grid ends up anchored wherever the seek landed, and a
seek that falls between two source frames shifts everything after it. Anchoring
the grid at absolute zero instead is worse -- the filter *pads* from its anchor,
so entering a clip an hour in emits an hour of duplicated first frames. That
bug is what the probe below caught: entry frames were exact and every frame
after them was frozen.

What works is `-copyts` (keep the source's absolute timestamps) with the grid
anchored at the seek point, which is itself an exact multiple of `1 / fps` and
therefore a suffix of the same absolute grid a full decode would use.

`tool/verify_video_mapping.sh` proves it rather than asserting it.
`example/assets/probe.mp4` encodes each frame's own index as its grey value
(frame *i* is `rgb(2i, 2i, 2i)`), so reading one pixel out of an exported frame
says exactly which source frame landed there:

```text
   1 shard(s): 200 frames, OK
   2 shard(s): 200 frames, OK
   4 shard(s): 200 frames, OK
   8 shard(s): 200 frames, OK
PASS
```

All 200 frames, every shard count, identical to the single-process render.

### Decoding, not buffering

Images are decoded once up front; video cannot be, because a minute of raw
1080p frames is about 15 GB. Instead each clip owns one ffmpeg process and the
renderer pulls one frame per composition frame, awaiting the decode *before* the
frame is built so the tree still paints synchronously. Reads are backpressured,
so ffmpeg never runs more than a few frames ahead.

Scrubbing backwards restarts the decoder; that is the only expensive path, and
the preview coalesces scrub requests so a fast drag costs one restart rather
than one per frame crossed.

`decodeWidth` / `decodeHeight` are the biggest lever on cost. A 4K source drawn
into a 1080p composition decodes four times the pixels it will ever paint, on
every frame, and nothing downstream recovers that.

A clip whose source runs out mid-window holds its last frame and says so by
name, rather than freezing silently:

```text
Warning: assets/clip.mp4 is mounted for frames 0-179 and needs 180 source
frames at 60fps, but the file only has 120 (2.00s). The last frame will be
held for the remaining 60.
```

## Widgets from your app

The point of building this on Flutter is that you already have the widgets. A
`ProductCard` that renders a row in your app should render a frame of a promo
video. Two things quietly stop that from being true, and both fail without
raising anything.

**Ambient state.** A composition renders in a detached tree, so `Theme.of` finds
no `Theme` and returns a fallback. Your card renders in stock Material purple
and nothing says a word. `wrapper` is the seam:

```dart
Composition(
  // ...
  wrapper: (BuildContext context, Widget child) =>
      Theme(data: myAppTheme, child: child),
  builder: (BuildContext context) => const ProductCard(),
)
```

It takes anything inherited -- a `Provider`, `Localizations`, a
`DefaultTextStyle`. The renderer and the preview both build through
`Composition.buildContent`, so there is no way for one to apply it and the
other to forget.

**Time.** This is the harder one. App widgets animate against the wall clock:
an `AnimationController` is driven by a `Ticker`, and *every* `Ticker` --
including the ones `SingleTickerProviderStateMixin` creates, which is what
`AnimatedContainer`, `AnimatedOpacity` and `CircularProgressIndicator` all use
underneath -- schedules itself against `SchedulerBinding`. There is no seam in
the widget tree to intercept them: `createTicker` constructs a `Ticker`
directly and never consults an inherited `TickerProvider`.

So the only way to make such a widget deterministic is to control what the
binding thinks the time is. Before each frame is built, the animation clock is
driven to that frame's instant. That does two things a detached tree otherwise
never gets: it ticks every active `Ticker` to composition time, and it drains
post-frame callbacks -- which is how a great many widgets start their animation
in the first place. Without it, the single most common fade-in idiom in Flutter
exports as **nothing at all**, on every frame, silently.

### Entering the timeline in the middle

A `Ticker` treats its *first* tick as elapsed zero. A shard that starts at
frame 45 would therefore restart every animation, and that bug is nearly
invisible -- video that is one animation out still looks like video.

Mounting at frame 0 is not enough either, because a widget inside a `Sequence`
mounts when the sequence says so and its ticker has to anchor *there*. So the
renderer walks the timeline forward to the frame it was asked for, without
painting, exactly the way a play-through would walk it. Determinism is
untouched: the walk always starts at zero, so frame `n` is still the same
everywhere. It is also close to free -- this is the same sweep the declaration
pass already performs over the *whole* timeline, and it stops early.

`tool/verify_ticker_mapping.sh` proves it. `TickerProbe` owns a controller
repeating every 1000ms and paints its value as a grey, so one pixel says
exactly where the animation was:

```text
   1 shard(s): 180 frames, OK
   2 shard(s): 180 frames, OK
   4 shard(s): 180 frames, OK
   8 shard(s): 180 frames, OK
PASS
```

Rendering `WeeklyDeals` across 4 shards takes 3.70 s with the sweep against
4.14 s measured before it, so the cost is inside run-to-run variance.

### What still is not true

- **The preview shows wall-clock timing for these widgets.** It builds the
  composition live in the app's own tree rather than through the renderer, so a
  ticker-driven widget animates on its own while you scrub. Everything that is
  a function of `Video.frame` is unaffected. Fixing it means routing the
  preview through the renderer, which is a real change and is not done.
- **Jumping is not the same as playing through** for state a widget changes
  from a callback rather than from the clock. Ticker-driven animation is
  immune, because a controller is a pure function of elapsed-since-start. The
  exporter and every shard render consecutive frames, so this only shows up
  when something seeks a live renderer around.
- `driveAnimationClock: false` on `CompositionRenderer` turns the whole
  mechanism off, which is also what makes it testable.

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

## On-device export

The CLI shells out to ffmpeg, which is fine on a laptop and impossible on a
phone. So the same renderer also drives a platform encoder directly:

```dart
final ExportResult result = await InAppExporter.export(
  composition: weeklyDeals,
  encoder: NativeVideoEncoder(),
  outputPath: '${Directory.systemTemp.path}/promo.mp4',
  onProgress: (ExportProgress p) => setState(() => _progress = p.fraction),
);
```

`fluttermotion_encoder` is a plugin wrapping **AVAssetWriter** on iOS and
macOS. Frames go across the method channel as raw RGBA and are permuted to
BGRA with `vImagePermuteChannels_ARGB8888` straight into the adaptor's pixel
buffer -- no intermediate `ui.Image`, no PNG round trip. The writer input runs
with `expectsMediaDataInRealTime = false` and the Dart side awaits
`isReadyForMoreMediaData`, so a slow encode backpressures the renderer instead
of queueing frames into memory.

`VideoEncoder` is the seam. `InAppExporter` knows nothing about AVFoundation;
an Android `MediaCodec` implementation is a new class, not a new exporter.

Verified on both platforms against the ffmpeg CLI render of the same
composition (1080x1920, 300 frames):

| | frames | time | output |
|---|---|---|---|
| macOS, in-app | 300 | 6.24 s | 7.7 MB |
| iOS simulator, in-app | 300 | 5.09 s | 8.0 MB |

Per-frame SSIM against the ffmpeg render averages **0.99036**, minimum
0.98794 -- h264 quantisation, not content drift. Mean channel values are
`24.53/38.66/49.62` in-app against `22.52/38.45/50.01` from ffmpeg, which is
the check that actually matters: a red/blue swap is the classic failure of
this path and it would show up here as a swapped pair, not as a small delta.

The preview has an **Export** button wired to the same call, so the moat is
reachable from the tool you are already scrubbing in.

What is not there yet: in-app **audio mixing** (an export with declared audio
writes video only, and says so) and in-app **video decoding** (a composition
containing a `VideoClip` refuses rather than exporting a hole -- decoding it
needs `AVAssetReader`). Android needs a `MediaCodec` encoder.

## Layout

| Path | What |
|---|---|
| `packages/fluttermotion` | The composition framework |
| `packages/fluttermotion_cli` | `fluttermotion render` |
| `packages/fluttermotion_encoder` | AVAssetWriter encoder plugin (iOS/macOS) |
| `example` | A working project with two compositions |
| `benchmarks/spike` | Throughput + determinism harness |
| `tool` | Frame-accuracy verification (video clips, tickers) |

## Validated so far

Measured on an M3 Max, Flutter 3.35 release mode, at 1080x1920 with a complex
composition (40 shadowed cards, gradients, `CustomPaint`, `BackdropFilter`):

- **Determinism is byte-exact.** Identical output across isolated renders and
  across forward and backward scrubbing to the same frame.
- **Rasterisation is the entire cost.** build+layout+paint is 0.5 ms/frame;
  `toImage()` is ~17 ms; GPU readback is 0.2 ms.
- **~0.75x realtime end-to-end** to MP4, single process. A 60 s vertical video
  exports in roughly 80 s.
- **Video clips land on the exact source frame**, identically across 1, 2, 4
  and 8 shards, verified per frame by pixel value rather than by eye.
- **On-device export matches the ffmpeg render.** Run headless on macOS and on
  an iOS simulator with no ffmpeg present, mean SSIM 0.99036 per frame.
- **Widgets that animate on their own `Ticker` are frame-exact**, and identical
  across 1, 2, 4 and 8 shards -- including one mounted mid-timeline by a
  `Sequence`.
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
cd packages/fluttermotion         && flutter test
cd packages/fluttermotion_cli     && dart test
cd packages/fluttermotion_encoder && flutter test
```

114 tests across the three packages (97 framework, 11 CLI, 6 encoder).
The ones that matter assert that a frame is byte-identical when
rendered from a fresh renderer, when reached by playing forward, and when
reached by scrubbing backward from later in the timeline.

## Roadmap

1. ~~Sharded deterministic renderer + test suite + `fluttermotion render`~~ done
2. ~~Scrubber preview (`flutter run`, hot reload)~~ done
3. ~~Declaration pass — asset preloading and audio scheduling~~ done
   (video decode windows still to come)
4. ~~Audio mixing~~ done
5. ~~Video clips~~ done
6. ~~On-device export (the moat)~~ done for video on iOS/macOS
   (in-app audio mixing, in-app video decode, and Android still to come)
7. ~~Widgets from an existing app -- ambient state and their own clocks~~ done
   for the render and export paths (the preview still shows wall-clock timing)

Explicitly deferred: Studio app, timeline UI, cloud rendering, effects library.

## Licence

Source-available under `FSL-1.1-ALv2` — free for everything except building a
competing product, and Apache 2.0 after two years. See `LICENSE.md`,
`NOTICE.md`, and `CLA.md`.
