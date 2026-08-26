/// Ready-made scenes, charts and motion primitives for FlutterMotion.
///
/// Every component here came out of building a real 60-second reel and then
/// asking what of it was general. Nothing was designed in advance, which is
/// why the vocabulary is small: a storyboard of scenes, four ways for
/// something to arrive, a stagger, two charts, a card, and the two shapes
/// footage takes in practice.
///
/// The rules the whole kit follows:
///
///  * **Everything is a function of the frame.** No controllers, no clocks.
///    Scrubbing backwards lands on the same pixels as playing forwards.
///  * **Timing is in frames, read from context.** A component inside a
///    [Sequence] counts from that sequence's own zero, so a scene never knows
///    where on the timeline it sits.
///  * **Colour comes from [MotionTheme], not from arguments.** Restyling a
///    composition is one widget at the top.
///
/// ```dart
/// const int fps = 30;
///
/// final List<Scene> scenes = <Scene>[
///   Scene(seconds: 5, child: TitleCard(kicker: 'Week 42', headline: 'Shipped')),
///   Scene(seconds: 9, child: BarChart(bars: bars)),
/// ];
///
/// final Composition reel = Composition(
///   id: 'Reel',
///   width: 1080,
///   height: 1920,
///   fps: fps,
///   durationInFrames: Storyboard.totalFrames(scenes, fps: fps),
///   wrapper: (BuildContext context, Widget child) =>
///       MotionSurface(typography: MotionTypography(fontFamily: 'Roboto'), child: child),
///   builder: (BuildContext context) => Storyboard(scenes: scenes),
/// );
/// ```
library;

export 'src/cards/card_grid.dart';
export 'src/cards/stat_card.dart';
export 'src/charts/bar_chart.dart';
export 'src/charts/line_chart.dart';
export 'src/media/footage_overlay.dart';
export 'src/media/split_screen.dart';
export 'src/motion/counter.dart';
export 'src/motion/enter.dart';
export 'src/motion/stagger.dart';
export 'src/motion/transitions.dart';
export 'src/storyboard.dart';
export 'src/text/big_stat.dart';
export 'src/text/labelled_scene.dart';
export 'src/text/scene_label.dart';
export 'src/text/title_card.dart';
export 'src/theme.dart';
