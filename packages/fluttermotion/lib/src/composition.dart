import 'package:flutter/widgets.dart';

/// A video composition: a deterministic function of frame number.
///
/// A composition is *not* a running animation. Frame `n` must always produce
/// the same pixels, whether it is reached by playing forward, scrubbing
/// backward, or rendering in isolation on another machine.
@immutable
class Composition {
  const Composition({
    required this.id,
    required this.width,
    required this.height,
    required this.fps,
    required this.durationInFrames,
    required this.builder,
  })  : assert(width > 0 && height > 0),
        assert(fps > 0),
        assert(durationInFrames > 0);

  /// Stable identifier used to address this composition from the CLI.
  final String id;

  final int width;
  final int height;
  final int fps;
  final int durationInFrames;

  /// Builds the frame. Read the current frame with [Video.frame].
  final WidgetBuilder builder;

  Size get size => Size(width.toDouble(), height.toDouble());

  Duration get duration =>
      Duration(microseconds: (durationInFrames * 1000000) ~/ fps);

  Composition copyWith({
    int? width,
    int? height,
    int? fps,
    int? durationInFrames,
  }) {
    return Composition(
      id: id,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      durationInFrames: durationInFrames ?? this.durationInFrames,
      builder: builder,
    );
  }

  @override
  String toString() =>
      'Composition($id, ${width}x$height @${fps}fps, $durationInFrames frames)';
}
