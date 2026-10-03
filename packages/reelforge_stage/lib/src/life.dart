import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart' show ExactCurve;

import 'pose.dart';

/// Smooth random wandering in about `[-1, 1]`, as a pure function of [t].
///
/// Value noise: a seeded random number at every whole [t], eased between. The
/// same seed and [t] give the same value in every process, which is the whole
/// reason not to use `Random` per frame -- that would be a fresh number every
/// time, and a render sharded four ways would twitch at three seams.
double noise(int seed, double t) {
  final int i = t.floor();
  final double f = t - i;
  final double u = f * f * f * (f * (f * 6 - 15) + 10); // smootherstep
  return _hash(seed, i) * (1 - u) + _hash(seed, i + 1) * u;
}

/// Several octaves of [noise]: big slow drift with small quick detail on top,
/// which is what makes it read as alive rather than as a wave.
double drift(int seed, double t, {int octaves = 3}) {
  double sum = 0, amplitude = 1, frequency = 1, norm = 0;
  for (int o = 0; o < octaves; o++) {
    sum += noise(seed + o * 7919, t * frequency) * amplitude;
    norm += amplitude;
    amplitude *= 0.5;
    frequency *= 2.1;
  }
  return sum / norm;
}

double _hash(int seed, int i) {
  // A small integer hash (splitmix-ish), masked to 32 bits so it is the same
  // number on the VM and on the web.
  int h = (seed * 0x27d4eb2d + i * 0x165667b1) & 0xffffffff;
  h = ((h ^ (h >> 15)) * 0x85ebca6b) & 0xffffffff;
  h = ((h ^ (h >> 13)) * 0xc2b2ae35) & 0xffffffff;
  h = h ^ (h >> 16);
  return (h & 0xffffff) / 0x7fffff - 1;
}

/// The motion of somebody who is not doing anything: breathing, a head that
/// drifts, eyes that blink and glance.
///
/// It is what keeps a held pose from being a frozen one. Layer it with
/// [Pose.plus] over whatever else the character is doing -- it only ever adds
/// small amounts, so it reads under a gesture as well as on its own.
///
/// Every character should get a different [seed]; two characters on the same
/// seed breathe and blink in unison, which looks like a mistake.
@immutable
class Life {
  const Life({
    this.seed = 1,
    this.head,
    this.chest,
    this.eyes = const <String>[],
    this.blinkKey,
    this.pupils = const <String>[],
    this.breathsPerMinute = 16,
    this.blinkEvery = const (2.2, 5.5),
    this.headDrift = 2.2,
    this.glance = 2.5,
  });

  final int seed;

  /// Joint that turns with the head's drift. Null leaves the head alone.
  final String? head;

  /// Joint that swells a little with each breath.
  final String? chest;

  /// Joints that close for a blink (by `scaleY`) and shift for a glance.
  final List<String> eyes;

  /// If set, a blink weighs this shape key of the [eyes] -- a [Blend] eye
  /// shutting -- instead of squashing them.
  final String? blinkKey;

  /// If given, these glance instead of the [eyes]: pupils moving inside eyes
  /// that stay put.
  final List<String> pupils;

  final double breathsPerMinute;

  /// Seconds between blinks, shortest and longest.
  final (double, double) blinkEvery;

  /// Degrees the head wanders, at most.
  final double headDrift;

  /// Pixels the eyes shift when they glance, at most.
  final double glance;

  Pose at(int frame, int fps) {
    final double t = frame / fps;
    final Map<String, Joint> joints = <String, Joint>{};

    if (chest != null) {
      final double breath = math.sin(t * breathsPerMinute / 60 * 2 * math.pi);
      joints[chest!] = Joint(scaleY: 1 + 0.012 * breath, move: Offset(0, -0.8 * breath));
    }
    if (head != null) {
      joints[head!] = Joint.rotate(headDrift * drift(seed, t * 0.45));
    }
    if (eyes.isNotEmpty) {
      final double open = _openness(frame, fps);
      final Offset look = _glance(t);
      final bool pupilsLook = pupils.isNotEmpty;
      for (final String eye in eyes) {
        joints[eye] = blinkKey == null
            ? Joint(move: pupilsLook ? Offset.zero : look, scaleY: open)
            : Joint(
                move: pupilsLook ? Offset.zero : look,
                weights: <String, double>{blinkKey!: ((1 - open) / 0.92).clamp(0.0, 1.0)},
              );
      }
      for (final String pupil in pupils) {
        joints[pupil] = Joint.move(look);
      }
    }
    return Pose(joints);
  }

  /// 1 open, near 0 shut. Blinks fall at seeded intervals, worked out from the
  /// start every time so frame 900 does not depend on having seen frame 899.
  double _openness(int frame, int fps) {
    final double t = frame / fps;
    final (double lo, double hi) = blinkEvery;
    double at = lo * 0.5 + (_hash(seed + 101, 0) * 0.5 + 0.5) * (hi - lo) * 0.5;
    int n = 1;
    while (at + 0.25 < t) {
      at += lo + (_hash(seed + 101, n) * 0.5 + 0.5) * (hi - lo);
      n++;
    }
    // Close fast, open slower. Counted in thirtieths of a second, so the
    // blink lasts the same time at any frame rate.
    final double since = (t - at) * 30;
    if (since < 0 || since > 7) return 1;
    if (since < 2) return 1 - 0.92 * (since / 2);
    if (since < 3) return 0.08;
    return 0.08 + 0.92 * Curves.easeOut.exact((since - 3) / 4);
  }

  /// Eyes hold still, then dart: a glance is fast, the hold is long.
  Offset _glance(double t) {
    const double hold = 1.6;
    final int i = (t / hold).floor();
    final double f = t / hold - i;
    Offset target(int k) => Offset(_hash(seed + 31, k), _hash(seed + 37, k) * 0.5) * glance;
    final double dart = Curves.easeOutCubic.exact((f / 0.08).clamp(0.0, 1.0));
    return Offset.lerp(target(i - 1), target(i), dart)!;
  }
}
