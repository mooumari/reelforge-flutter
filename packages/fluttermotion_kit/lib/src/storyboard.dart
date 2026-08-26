import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';

import 'motion/transitions.dart';

/// One scene in a [Storyboard]: how long it lasts and what it shows.
///
/// Give it a length in [seconds] or in [frames], not both. Seconds is usually
/// what you mean -- "this beat is nine seconds" survives a change of frame
/// rate, and `270` does not.
@immutable
class Scene {
  const Scene({
    this.seconds,
    this.frames,
    this.child,
    this.builder,
    this.sting,
    this.stingFrames = 30,
    this.transition,
  })  : assert(
          (seconds == null) != (frames == null),
          'Give a Scene either seconds or frames, not both and not neither.',
        ),
        assert(
          (child == null) != (builder == null),
          'Give a Scene either a child or a builder, not both and not neither.',
        );

  /// How long the scene lasts, in seconds.
  final double? seconds;

  /// How long the scene lasts, in frames. Use [seconds] unless you need this.
  final int? frames;

  /// The scene's content, when it can be built up front.
  final Widget? child;

  /// The scene's content, built when the scene is first on screen.
  ///
  /// Use this whenever the content depends on data that is loaded during
  /// startup. A storyboard is usually a top-level `final`, and its length has
  /// to be known before a [Composition] can be constructed -- but the lengths
  /// are the only part that has to exist that early. A builder keeps the
  /// content out of that, so a scene can read data that arrives later without
  /// the durations having to wait for it.
  ///
  /// It is also called *below* the scene's [Sequence], so [Video.frame] inside
  /// it is already rebased to the scene's own zero.
  final WidgetBuilder? builder;

  /// Something to play as the scene begins -- typically an [Audio].
  ///
  /// Mounted outside the transition, so it is unaffected by the scene fading
  /// in, and for [stingFrames] rather than for the whole scene.
  final Widget? sting;

  final int stingFrames;

  /// Overrides the storyboard's transition for this scene alone.
  final SceneTransition? transition;

  /// This scene's length in frames at [fps].
  int lengthAt(int fps) => frames ?? (seconds! * fps).round();
}

/// Plays [scenes] one after another, with a transition between them.
///
/// The lengths are declared once, here, and the start frames are derived --
/// so moving a scene moves its content, its sting and its transition together,
/// and nothing anywhere holds a hardcoded frame number.
///
/// ```dart
/// const int fps = 30;
/// final List<Scene> scenes = <Scene>[
///   Scene(seconds: 5, child: TitleCard(headline: 'Week 42')),
///   Scene(seconds: 9, child: BarChart(bars: bars)),
/// ];
///
/// final Composition reel = Composition(
///   id: 'Reel',
///   width: 1080, height: 1920, fps: fps,
///   durationInFrames: Storyboard.totalFrames(scenes, fps: fps),
///   builder: (BuildContext context) => Storyboard(scenes: scenes),
/// );
/// ```
///
/// [totalFrames] is a static rather than something read from the widget
/// because a [Composition] has to declare its length before any of this is in
/// a tree.
class Storyboard extends StatelessWidget {
  const Storyboard({
    super.key,
    required this.scenes,
    this.transition = const SceneTransition.fade(),
    this.bed,
  });

  final List<Scene> scenes;

  /// Applied to every scene that does not override it.
  final SceneTransition transition;

  /// Something under the whole storyboard -- typically a looping [Audio].
  final Widget? bed;

  /// How many frames [scenes] add up to at [fps].
  static int totalFrames(List<Scene> scenes, {required int fps}) {
    int total = 0;
    for (final Scene scene in scenes) {
      total += scene.lengthAt(fps);
    }
    return total;
  }

  /// The frame each scene starts on, plus a final entry for the end.
  ///
  /// `starts[i]` is scene `i`'s first frame and `starts[i + 1]` is one past
  /// its last, so the list is one longer than [scenes].
  static List<int> startsAt(List<Scene> scenes, {required int fps}) {
    final List<int> starts = <int>[0];
    for (final Scene scene in scenes) {
      starts.add(starts.last + scene.lengthAt(fps));
    }
    return starts;
  }

  @override
  Widget build(BuildContext context) {
    final int fps = Video.fps(context);
    final List<int> starts = startsAt(scenes, fps: fps);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (bed != null) bed!,
        for (int i = 0; i < scenes.length; i++) ...<Widget>[
          if (scenes[i].sting != null)
            Sequence(
              from: starts[i],
              durationInFrames: scenes[i].stingFrames,
              child: scenes[i].sting!,
            ),
          Sequence(
            from: starts[i],
            durationInFrames: starts[i + 1] - starts[i],
            layout: SequenceLayout.fill,
            child: _SceneContent(
              scene: scenes[i],
              transition: scenes[i].transition ?? transition,
            ),
          ),
        ],
      ],
    );
  }
}

/// Builds a scene and applies its transition, inside its rebased timeline.
///
/// A separate widget rather than a call in [Storyboard.build] because both
/// the builder and the transition have to see [Video.frame] *below* the
/// [Sequence] that rebased it, not above.
class _SceneContent extends StatelessWidget {
  const _SceneContent({required this.scene, required this.transition});

  final Scene scene;
  final SceneTransition transition;

  @override
  Widget build(BuildContext context) => transition.build(
        context,
        scene.builder?.call(context) ?? scene.child!,
      );
}
