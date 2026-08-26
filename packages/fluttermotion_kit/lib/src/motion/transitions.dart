import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';

/// How a scene arrives and how it leaves.
///
/// Applied against the scene's *own* timeline: inside a [Sequence] the frame
/// is rebased to zero and the duration is the sequence's, so a transition
/// never has to be told where on the global timeline its scene sits. That is
/// what lets a storyboard be reordered without touching anything here.
@immutable
abstract class SceneTransition {
  const SceneTransition();

  /// Cuts. No entrance, no exit.
  const factory SceneTransition.none() = _NoTransition;

  /// Fades up over [frames] and back down over the last [frames].
  const factory SceneTransition.fade({int frames}) = _FadeTransition;

  /// Slides in from [offset] and back out to it, fading as it goes.
  const factory SceneTransition.slide({
    int frames,
    Offset offset,
    Curve curve,
    bool fade,
  }) = _SlideTransition;

  /// Grows in from [scale] and shrinks back to it.
  const factory SceneTransition.scale({
    int frames,
    double scale,
    Curve curve,
    bool fade,
  }) = _ScaleTransition;

  Widget build(BuildContext context, Widget child);

  /// 0 at the very start, 1 through the middle, 0 at the very end.
  ///
  /// Written as the smaller of an in-ramp and an out-ramp rather than as one
  /// four-point interpolation, because a scene shorter than two transitions
  /// would make that range non-monotonic. Here it just overlaps, which is the
  /// sensible reading of "fade for 8 frames" on a 10-frame scene.
  @protected
  static double edge(BuildContext context, int frames) {
    if (frames <= 0) return 1;
    final int frame = Video.frame(context);
    final int length = Video.durationInFrames(context);
    final double rising =
        interpolate(frame, <num>[0, frames], <num>[0, 1]);
    // Against `length - 1` rather than `length`: the last frame a scene is on
    // screen for is `length - 1`, and fading towards a frame that never
    // renders leaves the scene visible at 1/frames when the next one cuts in.
    final double falling = interpolate(
      frame,
      <num>[length - 1 - frames, length - 1],
      <num>[1, 0],
    );
    return rising < falling ? rising : falling;
  }
}

class _NoTransition extends SceneTransition {
  const _NoTransition();

  @override
  Widget build(BuildContext context, Widget child) => child;
}

class _FadeTransition extends SceneTransition {
  const _FadeTransition({this.frames = 8});

  final int frames;

  @override
  Widget build(BuildContext context, Widget child) => Opacity(
        opacity: SceneTransition.edge(context, frames).clamp(0.0, 1.0),
        child: child,
      );
}

class _SlideTransition extends SceneTransition {
  const _SlideTransition({
    this.frames = 10,
    this.offset = const Offset(0, 80),
    this.curve = Curves.easeOutCubic,
    this.fade = true,
  });

  final int frames;
  final Offset offset;
  final Curve curve;
  final bool fade;

  @override
  Widget build(BuildContext context, Widget child) {
    final double t = curve.transform(
      SceneTransition.edge(context, frames).clamp(0.0, 1.0),
    );
    Widget result =
        Transform.translate(offset: offset * (1 - t), child: child);
    if (fade) result = Opacity(opacity: t, child: result);
    return result;
  }
}

class _ScaleTransition extends SceneTransition {
  const _ScaleTransition({
    this.frames = 10,
    this.scale = 0.94,
    this.curve = Curves.easeOutCubic,
    this.fade = true,
  });

  final int frames;
  final double scale;
  final Curve curve;
  final bool fade;

  @override
  Widget build(BuildContext context, Widget child) {
    final double t = curve.transform(
      SceneTransition.edge(context, frames).clamp(0.0, 1.0),
    );
    Widget result =
        Transform.scale(scale: scale + (1 - scale) * t, child: child);
    if (fade) result = Opacity(opacity: t, child: result);
    return result;
  }
}
