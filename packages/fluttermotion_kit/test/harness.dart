import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';

/// Puts [child] under a [VideoFrame] parked on [frame].
///
/// The kit's components read their timing from context rather than taking it
/// as an argument, so a test that wants to know what frame 12 looks like has
/// to say so the same way a composition would.
Widget at(
  int frame,
  Widget child, {
  int fps = 30,
  int durationInFrames = 100,
  int width = 1080,
  int height = 1920,
}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: VideoFrame(
        frame: frame,
        fps: fps,
        durationInFrames: durationInFrames,
        width: width,
        height: height,
        child: child,
      ),
    );
