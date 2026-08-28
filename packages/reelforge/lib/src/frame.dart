import 'package:flutter/widgets.dart';

/// Carries the current frame down the tree.
///
/// Only widgets that actually read the frame rebuild when it advances, which
/// is why a 40-card composition costs ~0.5 ms of build+layout+paint per frame.
class VideoFrame extends InheritedWidget {
  const VideoFrame({
    super.key,
    required this.frame,
    required this.fps,
    required this.durationInFrames,
    required this.width,
    required this.height,
    required super.child,
  });

  final int frame;
  final int fps;
  final int durationInFrames;
  final int width;
  final int height;

  static VideoFrame of(BuildContext context) {
    final VideoFrame? result =
        context.dependOnInheritedWidgetOfExactType<VideoFrame>();
    assert(
      result != null,
      'No VideoFrame found in the widget tree.\n'
      'Video.frame() may only be called inside a Composition being rendered '
      'or previewed. If you are seeing this in a normal app screen, the widget '
      'is being used outside a composition.',
    );
    return result!;
  }

  @override
  bool updateShouldNotify(VideoFrame oldWidget) {
    return frame != oldWidget.frame ||
        fps != oldWidget.fps ||
        durationInFrames != oldWidget.durationInFrames ||
        width != oldWidget.width ||
        height != oldWidget.height;
  }
}

/// Frame-derived values available to any widget inside a composition.
///
/// There is deliberately no way to ask for wall-clock time. Everything a
/// composition draws must be a function of [frame].
abstract final class Video {
  /// The frame currently being rendered, starting at 0.
  ///
  /// Inside a [Sequence] this is local to that sequence.
  static int frame(BuildContext context) => VideoFrame.of(context).frame;

  static int fps(BuildContext context) => VideoFrame.of(context).fps;

  static int durationInFrames(BuildContext context) =>
      VideoFrame.of(context).durationInFrames;

  /// Seconds elapsed at the current frame. Derived, never measured.
  static double time(BuildContext context) {
    final VideoFrame f = VideoFrame.of(context);
    return f.frame / f.fps;
  }

  /// Progress through the composition or enclosing sequence, in `[0, 1]`.
  static double progress(BuildContext context) {
    final VideoFrame f = VideoFrame.of(context);
    if (f.durationInFrames <= 1) return 0;
    return (f.frame / (f.durationInFrames - 1)).clamp(0.0, 1.0);
  }

  static Size size(BuildContext context) {
    final VideoFrame f = VideoFrame.of(context);
    return Size(f.width.toDouble(), f.height.toDouble());
  }
}
