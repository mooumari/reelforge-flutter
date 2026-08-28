# reelforge_kit

Ready-made scenes, charts and motion primitives for
[ReelForge](../../README.md) compositions.

`reelforge` gives you a frame number and Flutter. This gives you somewhere
to start.

Every component here was a bespoke widget in the example reel first; what is
in the package is what survived being made general. Nothing was designed in
advance, which is why the vocabulary is small.

```dart
final List<Scene> scenes = <Scene>[
  Scene(seconds: 5, builder: (_) => TitleCard(
    kicker: 'Q3 2026',
    headline: 'Shipped more, broke less',
    subhead: '47 releases · 3 incidents',
  )),
  Scene(seconds: 9, builder: (_) => LabelledScene(
    label: 'Shipped per week',
    child: BarChart(bars: bars),
  )),
];

final Composition reel = Composition(
  id: 'Reel',
  width: 1080,
  height: 1920,
  fps: 30,
  durationInFrames: Storyboard.totalFrames(scenes, fps: 30),
  wrapper: (BuildContext context, Widget child) => MotionSurface(
    typography: const MotionTypography(fontFamily: 'Roboto'),
    child: child,
  ),
  builder: (BuildContext context) => Storyboard(scenes: scenes),
);
```

## The rules

**Everything is a function of the frame.** No controllers, no tickers, no
clocks. A `Counter` interpolates against `Video.frame` rather than counting up,
which is why scrubbing backwards through one lands on the number it showed on
the way past.

**Timing is read from context, in frames.** A component inside a `Sequence`
counts from that sequence's own zero, so a scene never knows where on the
timeline it sits.

**Colour comes from `MotionTheme`, not from arguments.** Restyling a
composition is one widget at the top. The palette is named by role rather than
by hue, so a component that asks for `accent` keeps working when the accent
turns orange.

## What is in it

| | |
|---|---|
| `Storyboard`, `Scene` | Lengths in seconds; start frames derived |
| `SceneTransition` | `fade`, `slide`, `scale`, `none` |
| `Enter` | `fade`, `slideUp/Down/Left/Right`, `scale`, `spring` |
| `Stagger` | Start each child a few frames after the last |
| `Counter` | A number that counts, deterministically |
| `BarChart`, `LineChart` | Data in, motion out |
| `StatCard`, `CardGrid` | A panel whose sign picks its colour, and a grid of them |
| `TitleCard`, `SceneLabel`, `LabelledScene` | Words |
| `BigStat`, `BigStatList` | One number that is the whole point of the frame |
| `FootageOverlay`, `SplitScreen` | The two shapes footage takes in practice |
| `MotionTheme`, `MotionSurface` | Palette and type |

## Licence

Source-available under `FSL-1.1-ALv2`. See the repository root.
