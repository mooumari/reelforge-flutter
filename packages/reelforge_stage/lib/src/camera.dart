import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';

/// Where the camera should be at [frame].
///
/// A null [center] means "wherever the middle of the frame already is", so a
/// zoom that never pans does not have to know how big the stage is.
@immutable
class CameraKeyframe {
  const CameraKeyframe(
    this.frame, {
    this.center,
    this.zoom = 1,
    this.curve = Curves.easeInOutCubic,
  }) : assert(zoom > 0);

  final int frame;

  /// The point in the world that sits in the middle of the frame.
  final Offset? center;

  /// 1 is the world as drawn; 2 fills the frame with half of it.
  final double zoom;

  /// Shapes the move *into* this keyframe.
  final Curve curve;
}

/// The camera as one frame sees it.
@immutable
class CameraState {
  const CameraState(this.center, this.zoom);

  final Offset center;
  final double zoom;
}

/// A camera over the layers inside it: pan and zoom, with depth.
///
/// Everything in [child] should be a [ParallaxLayer]. The camera itself draws
/// nothing; it decides where the frame is looking and clips to it.
///
/// ```dart
/// Camera(
///   keyframes: const <CameraKeyframe>[
///     CameraKeyframe(0),
///     CameraKeyframe(90, center: Offset(1200, 500), zoom: 1.6),
///   ],
///   child: Stack(children: <Widget>[
///     ParallaxLayer(depth: 0.2, child: Drawing(mountains)),
///     ParallaxLayer(child: Drawing(hero)),
///   ]),
/// )
/// ```
class Camera extends StatelessWidget {
  const Camera({super.key, required this.keyframes, required this.child});

  final List<CameraKeyframe> keyframes;
  final Widget child;

  /// The camera at [frame] looking at a stage of [viewport] size.
  ///
  /// A pure function, exposed so a test (or a caption that has to follow the
  /// action) can ask where the camera is without building anything.
  static CameraState stateAt(
    List<CameraKeyframe> keyframes,
    num frame,
    Size viewport,
  ) {
    assert(keyframes.isNotEmpty, 'A camera needs at least one keyframe.');
    final Offset middle = viewport.center(Offset.zero);
    Offset centerOf(CameraKeyframe k) => k.center ?? middle;

    final CameraKeyframe first = keyframes.first;
    final CameraKeyframe last = keyframes.last;
    if (frame <= first.frame) return CameraState(centerOf(first), first.zoom);
    if (frame >= last.frame) return CameraState(centerOf(last), last.zoom);

    for (int i = 1; i < keyframes.length; i++) {
      final CameraKeyframe to = keyframes[i];
      if (frame > to.frame) continue;
      final CameraKeyframe from = keyframes[i - 1];
      final double t = to.curve
          .transform((frame - from.frame) / (to.frame - from.frame));
      return CameraState(
        Offset.lerp(centerOf(from), centerOf(to), t)!,
        // Zoom is a ratio, so it is blended as one: halfway between 1x and 4x
        // is 2x, which is the same number of doublings either side. Blended
        // linearly the second half of a push-in looks like it is speeding up.
        math.exp(math.log(from.zoom) +
            (math.log(to.zoom) - math.log(from.zoom)) * t),
      );
    }
    return CameraState(centerOf(last), last.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    return ClipRect(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size viewport = constraints.biggest;
          return CameraScope(
            state: stateAt(keyframes, frame, viewport),
            viewport: viewport,
            child: SizedBox.fromSize(size: viewport, child: child),
          );
        },
      ),
    );
  }
}

/// What a [ParallaxLayer] reads to know where the camera is.
class CameraScope extends InheritedWidget {
  const CameraScope({
    super.key,
    required this.state,
    required this.viewport,
    required super.child,
  });

  final CameraState state;
  final Size viewport;

  static CameraScope of(BuildContext context) {
    final CameraScope? scope =
        context.dependOnInheritedWidgetOfExactType<CameraScope>();
    assert(
      scope != null,
      'A ParallaxLayer has to be inside a Camera. With no camera there is '
      'nothing for it to be at a depth from.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(CameraScope oldWidget) =>
      state.center != oldWidget.state.center ||
      state.zoom != oldWidget.state.zoom ||
      viewport != oldWidget.viewport;
}

/// A slab of the scene at a distance from the camera.
///
/// [depth] is how much the layer follows the camera: 1 is the world the
/// camera is looking *at*, moving exactly with it; 0 is painted on the lens and
/// never moves; in between, the layer pans and zooms by that fraction, which is
/// all parallax is. Above 1 is foreground, sweeping past faster than the
/// action.
///
/// The child is laid out at the size of the frame and painted in world
/// coordinates, so a layer's art is drawn with the same numbers whatever its
/// depth.
class ParallaxLayer extends StatelessWidget {
  const ParallaxLayer({super.key, this.depth = 1, required this.child});

  final double depth;
  final Widget child;

  /// How the world point [world] lands on screen through a layer at [depth].
  static Offset project(
    CameraState camera,
    Size viewport,
    double depth,
    Offset world,
  ) {
    final Offset middle = viewport.center(Offset.zero);
    final double scale = math.pow(camera.zoom, depth).toDouble();
    final Offset pan = camera.center - middle;
    return middle + (world - middle - pan * depth) * scale;
  }

  @override
  Widget build(BuildContext context) {
    final CameraScope scope = CameraScope.of(context);
    final Offset middle = scope.viewport.center(Offset.zero);
    final double scale = math.pow(scope.state.zoom, depth).toDouble();
    final Offset shift = middle + (scope.state.center - middle) * depth;

    // screen = middle + (world - shift) * scale, as one matrix.
    final Matrix4 matrix = Matrix4.translationValues(middle.dx, middle.dy, 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1))
      ..multiply(Matrix4.translationValues(-shift.dx, -shift.dy, 0));
    return Transform(
      transform: matrix,
      child: SizedBox.fromSize(size: scope.viewport, child: child),
    );
  }
}
