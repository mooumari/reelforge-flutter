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
cd example && flutter run -d macos    # or: fluttermotion preview
```

Scrub the timeline, then edit a widget and save -- hot reload applies to
compositions like any other Flutter code, and the frame you are parked on
redraws immediately.

The preview does not build the composition; it **runs the exporter** and shows
you the frame that comes back. Every frame on screen went through
`CompositionRenderer` at the composition's true size, so parity with the export
is structural rather than something two code paths have to agree about. A test
byte-compares what the canvas holds against a fresh render of the same frame.

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
`example/assets/probe.mp4` (regenerate with `tool/make_probe.py`) states each
frame's own index in eight black-or-white blocks along the top, so reading an
exported frame says exactly which source frame landed there:

```text
  VideoProbe, 1 shard(s): 200 frames, grey drift 1 levels, every frame exact
  VideoProbe, 4 shard(s): 200 frames, grey drift 1 levels, every frame exact
PASS
```

All 200 frames, every shard count, identical to the single-process render.

The probe used to carry its index as a grey value instead, and that was a
mistake worth describing. An exported frame has been through two limited-range
colour round trips and a quantiser, and the two or three levels that costs is
the same size as the difference between one source frame and the next. So the
check needed a tolerance, and a tolerance wide enough to absorb the encoder is
wide enough to hide an off-by-one decoder -- the entire bug class the probe
exists to catch. Black against white survives all of it, and the answer is
exact rather than approximate. The grey is still there, and still reported, but
only as a fidelity number about the *encoder*: see `EncoderProbe`, which paints
the same ramp instead of decoding it, and so measures the encoder with no
decoder anywhere in the measurement.

`VideoProbeHalf` is the same clip in a 30fps composition. That matters because
`probe.mp4` runs at 60fps: a composition at the source's own rate wants one
source frame per composition frame, so "the next frame" and "the frame due at
this instant" are the same answer, and a decoder can be right by accident. At
30fps they differ, and the footage plays at half speed. The script checks both,
so a decoder can no longer pass by never being asked the question.

### Decoding, not buffering

Images are decoded once up front; video cannot be, because a minute of raw
1080p frames is about 15 GB. Instead each clip owns one ffmpeg process and the
renderer pulls one frame per composition frame, awaiting the decode *before* the
frame is built so the tree still paints synchronously. Reads are backpressured,
so ffmpeg never runs more than a few frames ahead.

Scrubbing backwards restarts the decoder; that is the only expensive path, and
the preview coalesces scrub requests so a fast drag costs one restart rather
than one per frame crossed.

The same file placed in two scenes is two decoders, not one. A declaration has
value equality on what it decodes -- same source, same trim, same size -- so
both placements hash to one key, and keeping one decoder per key made the
earlier placement render black. The store keeps a list per key and picks by
window, which works without a `VideoClip` ever having to say which placement it
is: the declaration pass builds windows from runs of consecutive frames, and a
gap is what splits a run, so the windows under one key are disjoint.

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

Or say `loop: true` and the clip wraps instead:

```dart
VideoClip(src: 'assets/clip.mp4', loop: true)
```

Looping is expressed in *source* frames, not composition frames: the decoder
maps composition frame to source frame through one modulo, and the wrap
restarts the pipe for the same reason a backwards scrub does. Nothing else in
the decoder has to know loops exist. A looping clip is not warned about, since
outlasting its source is the point.

Holding the last frame is free either way. It did not used to be: a clip
mounted seven seconds past its own end spawned a fresh ffmpeg per frame, each
one decoding the whole file to find nothing -- 210 processes, and the dominant
cost of the render. The decoder now remembers the source frame it ran dry at
and short-circuits at or beyond it, while a scrub back before that point is
still a normal restart.

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

### Rendering inside a running app

Driving the binding's clock is safe in a headless render host, where nothing
else asks for frames. In a live app -- the preview, or an on-device export --
it is not, and both directions bite.

The engine keeps delivering real frames between the ones the renderer
manufactures, and those would tick the composition's tickers at wall-clock
time. Since a ticker anchors its zero on its *first* tick, one stray real frame
is enough to strand an animation at a timestamp composition time never reaches.
So the composition sits behind a `TickerMode` that is shut except for the
instant a frame is being drawn.

The other direction is worse. While a frame is drawn, the binding is told the
time is *composition* time -- a few seconds from the composition's own zero --
and the surrounding app hears that too. `MotionTickerShield` mutes the app's
tickers for that instant, so they miss the manufactured frames rather than
being dragged onto a clock that means nothing to them. The preview installs one
itself; an app that exports on device should wrap its own root:

```dart
runApp(const MotionTickerShield(child: MyApp()));
```

The shield walks its subtree on each frame rather than flipping one flag,
because `TickerMode` nests -- a `ModalRoute` wraps its contents in one, and the
ticker mixins only ever watch the nearest.

There is one more subtlety, and it is the kind that only shows up on a real
device. A raw timestamp handed to `SchedulerBinding` is not the timestamp
tickers see: the binding subtracts the first raw stamp of its current epoch.
In a render host our own first frame *is* that stamp. In a live app the engine
got there first, and on macOS its stamps are time since boot -- so announcing a
bare composition time of 0.75s announces a frame from hours before the app
started. `FrameClock` measures that shift on every frame and places composition
zero on the app's own timeline instead.

### What still is not true

- **The binding can re-base its epoch under us**, on a warm-up frame or an app
  resume. That can only be noticed one frame late, so the frame it happens on
  lands at the wrong instant and is immediately redrawn at the right one. In
  practice this is a single frame, once, during app start-up.
- **Jumping is not the same as playing through** for state a widget changes
  from a callback rather than from the clock. Ticker-driven animation is
  immune, because a controller is a pure function of elapsed-since-start. The
  exporter and every shard render consecutive frames, so this only shows up
  when something seeks a live renderer around.
- `driveAnimationClock: false` on `CompositionRenderer` turns the whole
  mechanism off, which is also what makes it testable.

## Adding it to an app

### Installing

Nothing is on pub.dev yet -- see `RELEASING.md` for what is still gating that.
Until then, depend on the checkout:

```yaml
dependencies:
  fluttermotion:
    path: ../fluttermotion/packages/fluttermotion
  # Only if you want in-app export, on iOS or macOS:
  fluttermotion_encoder:
    path: ../fluttermotion/packages/fluttermotion_encoder
```

and put the CLI on your `PATH`:

```bash
dart pub global activate --source path <checkout>/packages/fluttermotion_cli
```

Once published, both become the usual `flutter pub add fluttermotion` and
`dart pub global activate fluttermotion_cli`.

### Starting a project

```bash
fluttermotion init
```

`init` adds the dependency, writes a starter composition in `lib/video/`, the
preview entry point beside it and `lib/render_main.dart`, and checks the two
things that are not obvious until they bite: that the project has a macOS
target at all, and that App Sandbox will stop the render host reaching ffmpeg.
It never overwrites, so running it twice is safe.

`--fix-entitlements` is opt-in and says what it did. `flutter create`
scaffolds a sandboxed macOS target, so every new project needs this -- but it
edits the entitlements your *release* build is signed with, and an app that
ships through the Mac App Store has to be sandboxed. Put it back before you
ship.

From a bare `flutter create` to an MP4 is about 17 seconds, most of it the
macOS build. That path is checked from outside the repo -- `flutter create`,
`pub add`, `fluttermotion init`, `fluttermotion render` -- rather than assumed
from the fact that the tests pass.

## Preview from the CLI

```bash
dart run bin/fluttermotion.dart preview --project ../../my_app
```

`flutter run` on the preview entry point `init` wrote, on this desktop, with
the terminal handed straight through -- so `r` still hot reloads. It saves
remembering `-d macos -t lib/video/preview_main.dart`, which is worth saving
because this is where the work happens; a render is what you do when it already
looks right.

An app that has the encoder plugin can hand the preview both halves of the
in-app pipeline:

```dart
previewMain(
  <Composition>[intro],
  encoderFactory: NativeVideoEncoder.new,      // adds an Export button
  videoBackendFactory: NativeVideoBackend.new, // scrub video without ffmpeg
);
```

## Render

```bash
cd packages/fluttermotion_cli
dart run bin/fluttermotion.dart list   --project ../../example
dart run bin/fluttermotion.dart render --project ../../example \
  --composition WeeklyDeals --out deals.mp4
```

The CLI builds your project with that entry point, asks the resulting binary
what compositions it defines, then spawns it once per shard to render
contiguous frame ranges in parallel and stream-copies the segments together.

### The host inherits your app's entitlements

The render host is a macOS build of *your app*, which is what makes any of this
work -- your plugins, fonts, assets and pubspec all come along. It is also what
makes App Sandbox a problem: a sandboxed app may not execute a binary outside
its own bundle, and reaching ffmpeg is exactly that. A sandboxed project builds
for as long as your app takes to build and then dies at the encode step with a
bare `Operation not permitted`.

So the CLI reads `macos/Runner/Release.entitlements` *before* building and says
so if `com.apple.security.app-sandbox` is `<true/>`. The host is a developer
tool that is never distributed, so it is safe to build it without the sandbox:
turn that key off while you render, or give the host its own build
configuration with its own entitlements. `--allow-sandbox` builds anyway, which
is correct if the host reaches ffmpeg some other way, such as a copy inside the
bundle.

This is the one adoption step that is not just "add a dependency", and it will
apply to most shipping apps.

### What an app has to supply

Anything the app normally sets up before its first frame has to be set up
before the first *rendered* frame too. If your widgets read providers, and
those providers read a store that is opened asynchronously at startup, the
render entry point has to open it as well:

```dart
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await preparePromo();               // whatever your app's bootstrap does
  await renderMain(args, <Composition>[solveReel]);
}
```

The ambient state itself goes in `Composition.wrapper`, assembled the way
`main.dart` assembles it -- a `ProviderScope` with the same overrides, the app's
`Theme`, and whatever `InheritedWidget`s the app's own widgets expect to find.

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
macOS and **MediaCodec** plus **MediaMuxer** on Android. Frames go across the method channel as raw RGBA and are permuted to
BGRA with `vImagePermuteChannels_ARGB8888` straight into the adaptor's pixel
buffer -- no intermediate `ui.Image`, no PNG round trip. The writer input runs
with `expectsMediaDataInRealTime = false` and the Dart side awaits
`isReadyForMoreMediaData`, so a slow encode backpressures the renderer instead
of queueing frames into memory.

`VideoEncoder` is the seam on the way out and `VideoBackend` the seam on the
way in. `InAppExporter` knows nothing about AVFoundation, MediaCodec or
ffmpeg, and adding Android was a new pair of classes rather than a new
exporter -- which is the claim that seam was made to support.

Android needs more of the work done by hand. AVAssetWriter takes a BGRA pixel
buffer and converts; MediaCodec takes YUV, so the colour conversion lives in
the plugin, and which matrix it uses is part of the file's meaning rather than
an implementation detail. All three paths now choose by height -- BT.709 for
high definition, BT.601 below -- convert accordingly and write it into the
file. See [Colour is not a detail](#colour-is-not-a-detail).

Verified against the ffmpeg CLI render of the same composition
(1080x1920, 300 frames, `WeeklyDeals`):

| | frames | time | SSIM vs CLI |
|---|---|---|---|
| macOS, in-app | 300 | 8.41 s | 0.99169 mean, 0.98964 min |
| Android emulator, in-app | 300 | 21.69 s | 0.98202 mean, 0.98019 min |

And on the whole 60-second reel -- 1800 frames of 1080x1920 with footage,
charts and a mixed soundtrack -- the Android export runs in **206.6 s** on the
emulator and scores **0.99416** mean SSIM against the CLI render, minimum
0.98291.

No frame on either falls below 0.98. Both probes are exact on both, at the
source's frame rate and at half it.

Run them with `tool/macos_export.sh` and `tool/android_export.sh`. Both scripts
exist for reasons worth knowing. Android has no argv -- an activity is started
rather than a process invoked, `--dart-entrypoint-args` arrives empty and
`stdout` reaches nobody, so an export there reports neither success nor
failure and simply leaves no file. And on macOS the CLI's own render step
builds into the same path as the in-app app bundle, so a CLI render silently
replaces the in-app binary with the render host; both accept `--composition`
and both produce an mp4, so the substitution does not fail, it just measures
ffmpeg twice and calls one of them the in-app path.

#### Colour is not a detail

ffmpeg converts RGB to YUV with BT.601 whatever the frame size, and writes no
colour metadata at all. An HD render was therefore BT.601 pixels in a file
that every player reads as BT.709. AVAssetWriter picked for itself and tagged
nothing. The Android encoder hard-coded BT.601 and, alone among the three,
said so in the file.

Nothing about that fails loudly. It tints. And it cost something to find:
matching Android to the CLI *before* fixing the CLI made the correct matrix
score worse than the wrong one, because the reference was the thing that was
wrong.

#### Fonts travel with the composition

A composition is a pure function of its frame number -- on one machine. Across
two it is not, unless its fonts come with it. The example bundled none, so it
drew in SF on macOS and Roboto on Android, and the two exports agreed on every
shape and disagreed on every glyph: 3.4% of pixels off by more than 32 levels,
all of them inside text, worth 0.033 of SSIM on its own. Bundle the fonts.

The preview has an **Export** button wired to the same call, so the moat is
reachable from the tool you are already scrubbing in.

### Audio, with no ffmpeg

An in-app export mixes its declared sound too. The clips are laid out on an
`AVMutableComposition` -- one track each, so overlapping sounds sum rather than
replacing one another and each can carry its own volume -- read back through
`AVAssetReaderAudioMixOutput`, and written as an AAC track by the same
`AVAssetWriter` that is writing the video.

The writer *pulls* the sound, through `requestMediaDataWhenReady`, rather than
being handed it. That detail is the difference between a working export and a
hang, and both wrong answers look reasonable.

An `AVAssetWriter` interleaves its inputs, and stops readying one that has run
ahead of the others until they catch up. Push the whole sound in before the
first frame and it is never readied again -- the writer is waiting for video
that the Dart side cannot send, because it is still waiting for `start` to
return. Leave audio until the end and it is the same deadlock the other way.
Neither shows up on a short composition, whose audio fits inside the
interleaving window whole; the 60-second reel hung on the first try, in the
same place every time, with no error and a 33 KB file.

Pulling gets it right by not choosing: the writer takes audio on its own queue
whenever it has room, so both inputs advance together and neither waits on the
other.

Inside an app, `Audio(src: 'assets/music.mp3')` is an asset key rather than a
path -- on iOS not even a file. Native code cannot open either, so an asset is
spilled to a real file once, keeping its extension, because `AVURLAsset`
decides what a file is by looking at it.

Verified against the ffmpeg mix of the same composition, per 50 ms window:
levels agree to within 0.2%, and both put the two chimes at 0.65 s and 3.00 s.
`AudioProbe` measures it exactly -- one 20 ms click mounted on frame 60 lands
at **1000.0 ms** in the CLI render, the macOS in-app export and the Android
in-app export alike.

#### Android has no AVMutableComposition

None of the above exists on Android. `MediaMuxer` only muxes and `MediaCodec`
only codes one stream at a time, so the mix itself is written out: every clip
decoded to PCM, resampled to a common rate, summed onto one timeline at its
own offset and volume, and encoded once. Summing rather than averaging, so
two clips over the same frames are heard together rather than quietened by
each other -- the same rule the Apple path gets from having one track per clip.

It happens before the first video frame, because `MediaMuxer` will not accept
a track added after `start()` and the video track cannot be added until the
video encoder has produced its format. So the audio is encoded up front and
held: a minute of stereo AAC at 128 kbps is under a megabyte.

An AAC encoder emits priming samples ahead of the audio it was given, and
nothing compensates for that on its own. On `AudioProbe` that put a click
meant for frame 60 at frame 62.79 -- 46 ms, which is exactly 2048 samples at
44.1kHz and exactly what the format specifies. The mixer pads the front to a
whole number of AAC frames and drops that many packets, which cancels it
exactly rather than approximately.

Measured on `WeeklyDeals` -- music at volume 0.4 under two chimes -- the
Android mix tracks the ffmpeg one to a median of 3.3% and a worst of 7.3% per
100 ms window. Its track runs the full length of the video, where the CLI and
the Apple path stop at the last sounding sample; the difference is trailing
silence, not placement.

The probe uses a WAV deliberately. An MP3 declares an encoder delay that ffmpeg
strips and AVFoundation keeps, which showed up as the in-app mix running 12 ms
behind the CLI's on `chime.mp3` -- inaudible, under a frame at 60fps, and worth
knowing about if you are placing sound to the sample. Use a format with no
priming offset when that matters.

### Video, with no ffmpeg

A composition containing a `VideoClip` decodes in-app too, through
`AVAssetReader` behind the same `VideoBackend` seam the CLI fills with ffmpeg.
Pass `videoBackend: NativeVideoBackend()` and the export needs no binary
anywhere:

```dart
await InAppExporter.export(
  composition: myPromo,
  encoder: NativeVideoEncoder(),
  videoBackend: NativeVideoBackend(),
  outputPath: path,
);
```

The hard part is not decoding, it is landing on the *same* frames ffmpeg does --
otherwise the same composition exports differently depending on where you
exported it from, and a sharded CLI render disagrees with itself at the shard
boundaries. `AVAssetReader.timeRange` gives that, but only if the start time is
exact. A seek expressed in floating-point seconds does not survive the trip:
`CMTime(seconds: 1.483333, preferredTimescale: 600)` truncates to 889/600, a
hair before frame 89 at 60fps, and the reader starts on frame 88 -- one whole
frame early, silently, and only for some seeks. The seek is a rational by
construction instead: `CMTime(value: sourceFrame, timescale: fps)`.

Measured against ffmpeg's `fps=N:start_time=T` grid on a file whose frames
encode their own index, the two agree frame-for-frame from zero, from
mid-stream and at the tail, and run dry at the same frame. End to end,
`VideoProbe` exported in-app matches the CLI render on **all 200 frames**, with
a largest mean-grey difference of 0.01 -- h264 re-encode noise, not a frame
mismatch.

As with audio, `VideoClip(src: 'assets/clip.mp4')` is an asset key inside an
app rather than a path, so it is spilled to a real file once; both go through
the same `SourceFiles` resolver.

On Android the same seam is filled by `MediaExtractor` and `MediaCodec`. The
shape is the same as the Apple one -- hold the frame on screen and one
lookahead, so "is this still the frame due at this instant?" stays answerable
-- but the slack that question allows has to be half a *source* frame, not
half a composition frame. It was the latter at first, which at 30fps into
60fps footage is a whole source frame, so every instant landing exactly on a
frame took the next one instead: 19 of `VideoProbeHalf`'s 60 clip frames
wrong, and every one of them plausible.

## Layout

| Path | What |
|---|---|
| `packages/fluttermotion` | The composition framework |
| `packages/fluttermotion_cli` | `fluttermotion init` / `preview` / `render` |
| `packages/fluttermotion_encoder` | Platform encoder + decoder plugin (iOS/macOS/Android) |
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
- **In-app video decoding lands on the same frames as ffmpeg**, at the source's
  frame rate and at half it. All 200 frames of `VideoProbe` and all 60 clip
  frames of `VideoProbeHalf` identical between the in-app export and the CLI
  render, including the clip's entry and exit, read per frame by pixel value.
- **The whole 60-second reel exports from inside an app**, no ffmpeg anywhere:
  1800 frames at 1080x1920 with three looping clips and eight sounds, in
  13.64 s single-process -- **4.40x realtime**, inside 450 MB max RSS, which is
  what says the decoders stream rather than accumulate. Mean SSIM against the
  CLI render is 0.99775, worst frame 0.99438, nothing below 0.98; the residue
  is two independent H.264 encodes of the same pixels.
- **A 60-second, eight-scene reel renders deterministically.** 1800 frames at
  1080x1920, three video clips, eight audio clips and data loaded from JSON.
  Encoded near-losslessly so the comparison measures the renderer rather than
  the encoder, the worst per-frame difference between a 1-shard and a 4-shard
  render is 0.035 grey levels, with no frame over 3. At the default settings it
  renders in 10.32 s -- **5.81x realtime**.
- **Widgets that animate on their own `Ticker` are frame-exact**, and identical
  across 1, 2, 4 and 8 shards -- including one mounted mid-timeline by a
  `Sequence`.
- **Two real third-party apps host a render.** A puzzle game (riverpod,
  `shared_preferences`, custom painters, custom fonts) rendered a 16 s
  1080x1920 promo drawn by its own `CustomPainter`, from its own models and
  theme, in 2.29 s of render time -- 6.98x realtime -- for a path dependency
  and one entry point. A plugin-heavy editor (flutter_rust_bridge with a Rust
  cdylib, `audio_session`, `image_picker`, `file_picker`, `path_provider`) also
  built and ran a headless host; it is where the entitlements rule above came
  from.
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

187 tests across the three packages (123 framework, 40 CLI, 24 encoder).
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
6. ~~On-device export (the moat)~~ done on iOS, macOS and Android -- video
   decode, audio mixing and encode all in-app, no ffmpeg anywhere
7. ~~Widgets from an existing app -- ambient state and their own clocks~~ done
   for the render, export and preview paths, including inside a live app

Explicitly deferred: Studio app, timeline UI, cloud rendering, effects library.

## Licence

Source-available under `FSL-1.1-ALv2` — free for everything except building a
competing product, and Apache 2.0 after two years. See `LICENSE.md`,
`NOTICE.md`, and `CLA.md`.
