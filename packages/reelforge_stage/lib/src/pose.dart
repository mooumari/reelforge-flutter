import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart' show ExactCurve;

/// How far one part is from its resting placement.
///
/// Everything is relative to the part, not absolute: [degrees] turns it from
/// wherever it was drawn, [move] shifts it, the scales multiply. A joint at its
/// defaults is a part left alone, which is why a [Pose] only has to mention the
/// parts that are doing something.
@immutable
class Joint {
  const Joint({
    this.degrees = 0,
    this.move = Offset.zero,
    this.scaleX = 1,
    this.scaleY = 1,
    this.opacity = 1,
    this.morph = 0,
    this.weights = const <String, double>{},
  });

  const Joint.rotate(double degrees) : this(degrees: degrees);

  /// Sets the weights of the part's [Blend] shape keys: `{'smile': 1}`,
  /// `{'ah': 0.6, 'smile': 0.4}`.
  const Joint.weigh(Map<String, double> weights) : this(weights: weights);

  /// Picks the shape of the part's morphing shapes: 0 is the first key shape,
  /// 1 the second, 1.5 halfway between the second and the third.
  const Joint.morphTo(double morph) : this(morph: morph);

  const Joint.move(Offset move) : this(move: move);

  /// Uniform scale, or squash and stretch when the axes differ.
  const Joint.scale(double x, [double? y]) : this(scaleX: x, scaleY: y ?? x);

  /// Squash and stretch that keeps the area: taller is thinner, shorter is
  /// wider. [stretch] 1.2 is 20% taller and a sixth narrower; 0.85 squashes.
  const Joint.squash(double stretch)
      : this(scaleX: 1 / stretch, scaleY: stretch);

  static const Joint rest = Joint();

  final double degrees;
  final Offset move;
  final double scaleX;
  final double scaleY;
  final double opacity;

  /// Where between their key shapes the part's [Morph] shapes are. Driven like
  /// any other channel -- keyed in a [Take], blended by [Pose.lerp] -- so a
  /// mouth changing shape is animated exactly as an arm turning is.
  final double morph;

  /// How much of each named shape key the part's [Blend] shapes show; a key
  /// not mentioned is 0. This is how a face is posed: a viseme, an emotion
  /// and a blink are each a few weights, and they add.
  final Map<String, double> weights;

  /// Layers [other] on top: angles, offsets, morphs and weights add; scales
  /// and opacity multiply.
  Joint plus(Joint other) => Joint(
        degrees: degrees + other.degrees,
        move: move + other.move,
        scaleX: scaleX * other.scaleX,
        scaleY: scaleY * other.scaleY,
        opacity: opacity * other.opacity,
        morph: morph + other.morph,
        weights: _addWeights(weights, other.weights),
      );

  static Map<String, double> _addWeights(Map<String, double> a, Map<String, double> b) {
    if (b.isEmpty) return a;
    if (a.isEmpty) return b;
    return <String, double>{
      for (final String k in <String>{...a.keys, ...b.keys}) k: (a[k] ?? 0) + (b[k] ?? 0),
    };
  }

  static Joint lerp(Joint a, Joint b, double t) => Joint(
        degrees: a.degrees + (b.degrees - a.degrees) * t,
        move: Offset.lerp(a.move, b.move, t)!,
        scaleX: a.scaleX + (b.scaleX - a.scaleX) * t,
        scaleY: a.scaleY + (b.scaleY - a.scaleY) * t,
        opacity: a.opacity + (b.opacity - a.opacity) * t,
        morph: a.morph + (b.morph - a.morph) * t,
        weights: a.weights.isEmpty && b.weights.isEmpty
            ? const <String, double>{}
            : <String, double>{
                for (final String k in <String>{...a.weights.keys, ...b.weights.keys})
                  k: (a.weights[k] ?? 0) + ((b.weights[k] ?? 0) - (a.weights[k] ?? 0)) * t,
              },
      );

  @override
  bool operator ==(Object other) =>
      other is Joint &&
      other.degrees == degrees &&
      other.move == move &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY &&
      other.opacity == opacity &&
      other.morph == morph &&
      mapEquals(other.weights, weights);

  @override
  int get hashCode => Object.hash(
        degrees,
        move,
        scaleX,
        scaleY,
        opacity,
        morph,
        Object.hashAllUnordered(
          weights.entries.map((MapEntry<String, double> e) => Object.hash(e.key, e.value)),
        ),
      );

  @override
  String toString() => 'Joint(degrees: $degrees, move: $move, '
      'scale: $scaleX x $scaleY, opacity: $opacity, morph: $morph'
      '${weights.isEmpty ? '' : ', weights: $weights'})';
}

/// Where the parts of one puppet are at one instant, by name.
@immutable
class Pose {
  const Pose([this.joints = const <String, Joint>{}]);

  static const Pose rest = Pose();

  final Map<String, Joint> joints;

  /// The joint called [name], or [Joint.rest] if this pose says nothing of it.
  Joint operator [](String name) => joints[name] ?? Joint.rest;

  /// This pose with [other]'s joints replacing the ones they share.
  ///
  /// For taking over part of a body: a wave overlaid on a walk decides the
  /// arm outright and leaves the legs to the walk.
  Pose overlay(Pose other) => Pose(<String, Joint>{...joints, ...other.joints});

  /// This pose with [other] added to it, joint by joint.
  ///
  /// For layering a little on top of something already moving: breathing on a
  /// pose that is already gesturing.
  Pose plus(Pose other) {
    final Map<String, Joint> out = <String, Joint>{...joints};
    other.joints.forEach((String name, Joint joint) {
      out[name] = (out[name] ?? Joint.rest).plus(joint);
    });
    return Pose(out);
  }

  /// Between [a] and [b]. A joint only one of them mentions is blended against
  /// rest, so a limb that is posed in one and unmentioned in the other eases
  /// to and from where it was drawn.
  static Pose lerp(Pose a, Pose b, double t) => Pose(<String, Joint>{
        for (final String name in <String>{...a.joints.keys, ...b.joints.keys})
          name: Joint.lerp(a[name], b[name], t),
      });

  @override
  bool operator ==(Object other) =>
      other is Pose && mapEquals(other.joints, joints);

  @override
  int get hashCode => Object.hashAllUnordered(
        joints.entries.map((MapEntry<String, Joint> e) =>
            Object.hash(e.key, e.value)),
      );
}

/// A [Pose] that must be reached at [frame], and how to get there.
///
/// [curve] shapes the stretch *ending* at this keyframe, so it reads as "ease
/// into this pose".
@immutable
class Keyframe {
  const Keyframe(this.frame, this.pose, {this.curve = Curves.easeInOut});

  final int frame;
  final Pose pose;
  final Curve curve;
}

/// A named stretch of movement: poses at frames, blended between.
///
/// A take is a pure function of the frame it is asked about, like everything
/// else in a composition. Frames are the take's own -- the first keyframe is
/// where it starts -- so the same take can be played from any point on the
/// timeline by subtracting that point.
///
/// ```dart
/// const Take wave = Take(<Keyframe>[
///   Keyframe(0, Pose.rest),
///   Keyframe(8, Pose({'shoulder': Joint.rotate(-150)})),
///   Keyframe(16, Pose({'shoulder': Joint.rotate(-150), 'hand': Joint.rotate(20)})),
/// ]);
/// final Pose pose = wave.at(frame);
/// ```
@immutable
class Take {
  const Take(this.keyframes, {this.loop = false});

  final List<Keyframe> keyframes;

  /// Repeats from the start once the last keyframe is reached. For a cycle the
  /// last keyframe should repeat the first pose, one beat later, so the seam
  /// is invisible.
  final bool loop;

  /// Frames from the first keyframe to the last.
  int get length => keyframes.last.frame - keyframes.first.frame;

  Pose at(num frame) {
    // Not an assert on the constructor: a list's length is not a constant, and
    // a take should be declarable `const`.
    assert(keyframes.isNotEmpty, 'A take needs at least one keyframe.');
    final int first = keyframes.first.frame;
    double f = frame.toDouble();
    if (loop && length > 0 && f >= first) {
      f = first + (f - first) % length;
    }
    if (f <= first) return keyframes.first.pose;
    if (f >= keyframes.last.frame) return keyframes.last.pose;

    for (int i = 1; i < keyframes.length; i++) {
      final Keyframe to = keyframes[i];
      if (f > to.frame) continue;
      final Keyframe from = keyframes[i - 1];
      final double t = (f - from.frame) / (to.frame - from.frame);
      return Pose.lerp(from.pose, to.pose, to.curve.exact(t));
    }
    return keyframes.last.pose;
  }
}

/// A steady back-and-forth, for the things that never quite stop: breathing,
/// swaying, a held pose that is not quite still.
///
/// [frame] over [fps] is seconds, so [hertz] means the same at any frame rate.
double oscillate(int frame, int fps, {double hertz = 0.5, double phase = 0}) =>
    math.sin((frame / fps * hertz + phase) * 2 * math.pi);
