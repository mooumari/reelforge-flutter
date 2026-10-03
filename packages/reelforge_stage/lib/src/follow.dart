import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'kinematics.dart';
import 'part.dart';
import 'pose.dart';

/// A part placed and posed: everything [Drawing] needs for one frame.
@immutable
class Posed {
  const Posed(this.part, this.pose);

  final Part part;
  final Pose pose;
}

/// A part that is carried rather than driven: an antenna, a tail, an ear, a
/// strand of hair, the end of a scarf.
///
/// It hangs off its joint on a damped spring. When what it hangs from turns or
/// lurches, it lags, overshoots and settles -- the follow-through that makes
/// the difference between a puppet and a character.
@immutable
class Jiggle {
  const Jiggle(
    this.joint, {
    required this.bone,
    this.hertz = 2.4,
    this.damping = 0.28,
    this.inertia = 1,
    this.limit = 40,
  });

  final String joint;

  /// The part's length and direction as drawn, from its joint to its tip: an
  /// antenna drawn straight up 46px is `Offset(0, -46)`. How hard a lurch
  /// swings it depends on how long it is.
  final Offset bone;

  /// How fast it swings back. Low is floppy, high is stiff.
  final double hertz;

  /// 0 swings for ever, 1 settles without overshooting.
  final double damping;

  /// How much it is thrown about, 1 being a free hanging weight.
  final double inertia;

  /// Degrees either way it may swing, so a violent move cannot fold it in half.
  final double limit;
}

/// [performance] at [frame], with every [Jiggle] swinging on its own spring.
///
/// Springs carry state, and a frame here may not. So each frame is simulated
/// from rest, starting [window] frames earlier and replaying the motion that
/// leads up to it. The spring forgets its start within a few swings (a 2.4Hz
/// spring at 0.28 damping has lost 99% of it in under a second), so a window
/// a little longer than that is indistinguishable from having played the
/// whole video -- and frame 900 is still the same pixels however it is
/// reached.
///
/// Jiggles are solved in order, each one seeing the swing of those before it,
/// so a chain listed root first -- tail1, tail2, tail3 -- whips.
Posed followThrough(
  Posed Function(int frame) performance,
  int frame, {
  required List<Jiggle> jiggles,
  required int fps,
  int window = 36,
  int substeps = 4,
}) {
  final int from = frame - window;
  final List<Posed> history = <Posed>[
    for (int f = from - 2; f <= frame; f++) performance(math.max(f, 0)),
  ];
  // Each jiggle's offset over the window, in degrees; later jiggles' poses
  // include earlier ones' so a chain is coupled.
  final List<Map<String, double>> offsets =
      List<Map<String, double>>.generate(history.length, (_) => <String, double>{});

  Pose poseAt(int i) {
    final Map<String, double> extra = offsets[i];
    if (extra.isEmpty) return history[i].pose;
    final Map<String, Joint> joints = <String, Joint>{...history[i].pose.joints};
    extra.forEach((String name, double deg) {
      joints[name] = (joints[name] ?? Joint.rest).plus(Joint.rotate(deg));
    });
    return Pose(joints);
  }

  final double dt = 1 / fps;
  for (final Jiggle j in jiggles) {
    // The anchor's motion: where the joint is and how its parent is turned,
    // at every frame of the window.
    final List<Offset> anchor = <Offset>[];
    final List<double> turn = <double>[];
    final List<Offset> dir = <Offset>[];
    final List<double> length = <double>[];
    final List<double> mirror = <double>[];
    for (int i = 0; i < history.length; i++) {
      final Pose p = poseAt(i);
      final Affine parent = parentFrameOf(history[i].part, p, j.joint);
      final Affine own = frameOf(history[i].part, p, j.joint);
      anchor.add(own.origin);
      turn.add(math.atan2(parent.b, parent.a));
      // The spring swings in screen space; a joint inside a mirrored
      // character turns the other way on screen for the same degrees.
      mirror.add(parent.determinant < 0 ? -1 : 1);
      final Offset world = own.applyVector(j.bone);
      length.add(math.max(world.distance, 1e-3));
      dir.add(world / math.max(world.distance, 1e-3));
    }

    final double omega = 2 * math.pi * j.hertz;
    final double k = omega * omega;
    final double c = 2 * j.damping * omega;
    final double h = dt / substeps;
    double angle = 0, velocity = 0; // radians, of the swing away from as-posed
    for (int i = 2; i < history.length; i++) {
      // Accelerations by central difference, per second squared.
      final Offset accel = (anchor[i] - anchor[i - 1] * 2 + anchor[i - 2]) / (dt * dt);
      final double spin = _unwrap(turn[i] - 2 * turn[i - 1] + turn[i - 2]) / (dt * dt);
      // A weight on a stick: the anchor lurching sideways to the stick turns
      // it the other way; the parent spinning leaves it behind.
      final Offset u = dir[i];
      final double fromLurch = (accel.dx * u.dy - accel.dy * u.dx) / length[i];
      final double drive = j.inertia * (fromLurch - spin);
      for (int s = 0; s < substeps; s++) {
        velocity += (drive - k * angle - c * velocity) * h;
        angle += velocity * h;
      }
      final double limit = j.limit * math.pi / 180;
      if (angle.abs() > limit) {
        angle = angle.sign * limit;
        velocity = 0;
      }
      offsets[i][j.joint] = mirror[i] * angle * 180 / math.pi;
    }
  }

  final int last = history.length - 1;
  return Posed(history[last].part, poseAt(last));
}

double _unwrap(double radians) {
  double r = radians;
  while (r > math.pi) {
    r -= 2 * math.pi;
  }
  while (r < -math.pi) {
    r += 2 * math.pi;
  }
  return r;
}
