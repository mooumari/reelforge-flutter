# A composition, previewed and rendered

A composition is a deterministic function of frame number. Frame `n` produces
the same pixels whether it is reached by playing forward, scrubbed backward, or
rendered on another machine an hour later.

```dart
import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';

final Composition helloReel = Composition(
  id: 'Hello',
  width: 1080,
  height: 1920,
  fps: 30,
  durationInFrames: 90,
  builder: (BuildContext context) {
    final int frame = Video.frame(context);
    return ColoredBox(
      color: const Color(0xFF101014),
      child: Center(
        child: Opacity(
          // Fade in over the first 20 frames, then hold.
          opacity: interpolate(frame, <int>[0, 20], <int>[0, 1]),
          child: Transform.translate(
            offset: Offset(0, interpolate(frame, <int>[0, 20], <int>[24, 0])),
            child: const Text(
              'Hello, ReelForge',
              textDirection: TextDirection.ltr,
              style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 72),
            ),
          ),
        ),
      ),
    );
  },
);
```

Nothing here reads a clock. There is deliberately no way to ask for wall-clock
time -- `Video.frame`, `Video.time` and `Video.progress` all derive from the
frame being drawn, which is what makes the output reproducible.

## Two entry points

The preview is an ordinary Flutter app, so it hot reloads:

```dart
// lib/video/preview_main.dart
void main() => previewMain(<Composition>[helloReel]);
```

The render host is the same project built for release. The CLI drives it:

```dart
// lib/render_main.dart
void main(List<String> args) => renderMain(args, <Composition>[helloReel]);
```

```bash
dart pub global activate reelforge_cli
reelforge preview
reelforge render --composition Hello --out hello.mp4
```

The host renders off-screen -- no window appears -- because it never draws to
the screen in the first place. Pass `--show-window` to watch it work.

## Sequences, media and your own widgets

```dart
Sequence(
  from: 60,          // starts at frame 60 of the parent
  durationInFrames: 90,
  child: const VideoClip(src: 'assets/clip.mp4', decodeWidth: 960),
)
```

`Sequence` shifts the frame its subtree sees, so a component inside one counts
from that sequence's own zero and never needs to know where on the timeline it
sits. `VideoClip`, `MotionImage` and `Audio` declare media the exporter
resolves before the first frame is drawn.

Widgets lifted out of a real app usually expect ambient state -- a `Theme`, a
`Provider`, `Localizations`. A composition renders in a detached tree that has
none of it, and the failure is quiet rather than loud, so pass a `wrapper`:

```dart
Composition(
  // ...
  wrapper: (BuildContext context, Widget child) =>
      Theme(data: myAppTheme, child: child),
  builder: (BuildContext context) => const ProductCard(),
)
```
