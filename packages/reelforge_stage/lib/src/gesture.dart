import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'pose.dart';

/// A move from one pose to another the way an animator would time it: a small
/// wind-up the other way, a quick move that overshoots, and a settle.
///
/// That shape -- anticipation, action, follow-through -- is most of the
/// difference between a pose that changes and a character that moves. Written
/// as keyframes it is three extra poses for every gesture, worked out by hand;
/// here it is two numbers.
///
/// [lag] staggers joints, in frames: `{'elbow': 2, 'hand': 4}` has the
/// shoulder lead and the hand arrive last, so an arm unrolls rather than
/// swinging as one stiff piece. Animators call it successive breaking of
/// joints.
///
/// ```dart
/// final Gesture raise = Gesture(
///   to: Pose({'shoulder': Joint.rotate(-128), 'elbow': Joint.rotate(-20)}),
///   lag: {'elbow': 2, 'hand': 4},
/// );
/// pose = pose.overlay(raise.at(frame - startFrame));
/// ```
@immutable
class Gesture {
  const Gesture({
    required this.to,
    this.from = Pose.rest,
    this.anticipation = 5,
    this.action = 8,
    this.settle = 10,
    this.windUp = 0.15,
    this.overshoot = 0.12,
    this.lag = const <String, int>{},
  });

  final Pose from;
  final Pose to;

  /// Frames spent winding up.
  final int anticipation;

  /// Frames from the wind-up to the far end of the overshoot.
  final int action;

  /// Frames from the overshoot back to [to].
  final int settle;

  /// How far the wind-up goes the wrong way, as a fraction of the move.
  final double windUp;

  /// How far past [to] the action carries, as a fraction of the move.
  final double overshoot;

  final Map<String, int> lag;

  /// Frames until every joint has settled.
  int get length =>
      anticipation +
      action +
      settle +
      lag.values.fold(0, (int a, int b) => a > b ? a : b);

  Take get _take => Take(<Keyframe>[
        Keyframe(0, from),
        Keyframe(anticipation, Pose.lerp(from, to, -windUp),
            curve: Curves.easeInOutSine),
        // Out of the wind-up fast, into the overshoot slow: the move is
        // mostly over in its first third, as a thrown arm is.
        Keyframe(anticipation + action, Pose.lerp(from, to, 1 + overshoot),
            curve: const Cubic(0.45, 0, 0.15, 1)),
        Keyframe(anticipation + action + settle, to,
            curve: Curves.easeInOutSine),
      ]);

  /// The pose [frame] frames into the gesture. Before 0 it is [from]; after
  /// [length] it is [to], held.
  Pose at(num frame) {
    final Take take = _take;
    if (lag.isEmpty) return take.at(frame);
    final Pose lead = take.at(frame);
    return Pose(<String, Joint>{
      for (final String name in lead.joints.keys)
        name: lag.containsKey(name) ? take.at(frame - lag[name]!)[name] : lead[name],
    });
  }
}
