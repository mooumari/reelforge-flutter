# A reel from ready-made scenes

The kit is a small vocabulary that came out of building a real 60-second reel
and then asking what of it was general: a storyboard of scenes, four ways for
something to arrive, a stagger, two charts, a card, and the two shapes footage
takes in practice.

```dart
import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_kit/reelforge_kit.dart';

const int fps = 30;

const List<BarDatum> shipped = <BarDatum>[
  BarDatum(value: 12, label: 'W27'),
  BarDatum(value: 18, label: 'W28'),
  BarDatum(value: 24, label: 'W29'),
  BarDatum(value: 29, label: 'W30'),
];

final List<Scene> scenes = <Scene>[
  const Scene(
    seconds: 4,
    child: TitleCard(kicker: 'Q3 2026', headline: 'Shipped more, broke less'),
  ),
  const Scene(seconds: 6, child: BarChart(bars: shipped)),
  const Scene(seconds: 3, child: BigStat(value: Counter(to: 83), label: 'releases')),
];

final Composition reel = Composition(
  id: 'Reel',
  width: 1080,
  height: 1920,
  fps: fps,
  durationInFrames: Storyboard.totalFrames(scenes, fps: fps),
  wrapper: (BuildContext context, Widget child) => MotionSurface(
    typography: const MotionTypography(fontFamily: 'Roboto'),
    child: child,
  ),
  builder: (BuildContext context) => Storyboard(scenes: scenes),
);
```

`Storyboard.totalFrames` is how the composition learns its own length, so
adding a scene never means updating a duration by hand.

## The three rules everything here follows

* **Everything is a function of the frame.** No controllers, no clocks.
  Scrubbing backwards lands on exactly the pixels playing forwards did.
* **Timing is in frames, read from context.** A component inside a scene counts
  from that scene's zero, so it never knows where on the timeline it sits.
* **Colour comes from `MotionTheme`, not from arguments.** Restyling a whole
  composition is one widget at the top.

## Arrivals and staggers

```dart
Enter.slideUp(
  child: Stagger(
    step: 4,                       // four frames between children
    children: <Widget>[
      StatCard(title: 'this week', value: '29'),
      StatCard(title: 'this quarter', value: '83'),
    ],
  ),
)
```

`Counter` animates a number toward its target on a spring, `SceneLabel` and
`LabelledScene` handle the caption furniture, and `FootageOverlay` and
`SplitScreen` are the two ways video actually gets used in a data reel.
