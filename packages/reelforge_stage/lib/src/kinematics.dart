import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'part.dart';
import 'pose.dart';

/// A 2D affine transform: `x' = a*x + c*y + tx`, `y' = b*x + d*y + ty`.
///
/// Its own small type rather than a `Matrix4`, because everything here is
/// flat and solving a leg sixty times a frame should not mean multiplying
/// 4x4s.
@immutable
class Affine {
  const Affine(this.a, this.b, this.c, this.d, this.tx, this.ty);

  static const Affine identity = Affine(1, 0, 0, 1, 0, 0);

  final double a, b, c, d, tx, ty;

  /// What [Drawing] applies for [part] in [joint]: move to the joint, turn,
  /// then scale -- in that order, so a scale never skews a rotation.
  factory Affine.of(Part part, Joint joint) {
    final double r = (part.degrees + joint.degrees) * math.pi / 180;
    final double sx = part.scaleX * joint.scaleX;
    final double sy = part.scaleY * joint.scaleY;
    final double cos = math.cos(r), sin = math.sin(r);
    return Affine(
      cos * sx,
      sin * sx,
      -sin * sy,
      cos * sy,
      part.at.dx + joint.move.dx,
      part.at.dy + joint.move.dy,
    );
  }

  /// This transform, then [inner] inside it.
  Affine operator *(Affine inner) => Affine(
        a * inner.a + c * inner.b,
        b * inner.a + d * inner.b,
        a * inner.c + c * inner.d,
        b * inner.c + d * inner.d,
        a * inner.tx + c * inner.ty + tx,
        b * inner.tx + d * inner.ty + ty,
      );

  Offset apply(Offset p) => Offset(a * p.dx + c * p.dy + tx, b * p.dx + d * p.dy + ty);

  /// [v] as a direction: turned and scaled, not moved.
  Offset applyVector(Offset v) => Offset(a * v.dx + c * v.dy, b * v.dx + d * v.dy);

  double get determinant => a * d - b * c;

  Affine get inverse {
    final double det = determinant;
    assert(det != 0, 'A transform with zero scale has no inverse.');
    final double ia = d / det, ib = -b / det, ic = -c / det, id = a / det;
    return Affine(ia, ib, ic, id, -(ia * tx + ic * ty), -(ib * tx + id * ty));
  }

  Offset get origin => Offset(tx, ty);
}

final Expando<Map<String, List<Part>?>> _paths = Expando<Map<String, List<Part>?>>();

/// The parts from [root] down to the first one called [name], both included.
///
/// Cached per tree: parts are immutable, so the answer never changes, and a
/// walk asks it for every leg on every frame.
List<Part>? pathTo(Part root, String name) {
  final Map<String, List<Part>?> cache = _paths[root] ??= <String, List<Part>?>{};
  return cache.putIfAbsent(name, () {
    List<Part>? search(Part part) {
      if (part.name == name) return <Part>[part];
      for (final Part child in part.children) {
        final List<Part>? found = search(child);
        if (found != null) return <Part>[part, ...found];
      }
      return null;
    }

    return search(root);
  });
}

List<Part> _require(Part root, String name) {
  final List<Part>? path = pathTo(root, name);
  if (path == null) {
    throw ArgumentError.value(name, 'name',
        'No part by that name. Its joints are: ${(root.names.toList()..sort()).join(', ')}');
  }
  return path;
}

Affine _chain(List<Part> parts, Pose pose) {
  Affine m = Affine.identity;
  for (final Part p in parts) {
    m = m * Affine.of(p, p.name.isEmpty ? Joint.rest : pose[p.name]);
  }
  return m;
}

/// Where the part called [name] is, as [Drawing] would draw it: its own frame
/// in the coordinates of the box the drawing is in.
///
/// `frameOf(rig, pose, 'foot').apply(Offset.zero)` is where the ankle is on
/// screen. This is forward kinematics, and it is exactly the painter's
/// arithmetic, so a test that asks it where a foot is gets the pixels' answer.
Affine frameOf(Part root, Pose pose, String name) => _chain(_require(root, name), pose);

/// The frame [name] hangs from: everything above it, but not itself.
Affine parentFrameOf(Part root, Pose pose, String name) {
  final List<Part> path = _require(root, name);
  return _chain(path.sublist(0, path.length - 1), pose);
}

double _deg(double radians) => radians * 180 / math.pi;

/// Turns two joints so the end of a limb lands on [target].
///
/// [upper], [lower] and [end] are three parts in a chain -- hip, knee, ankle;
/// shoulder, elbow, wrist. The bone lengths are read off the rig (how far the
/// lower part sits from the upper, and the end from the lower), so the same
/// call works for any character drawn with joints in those places.
///
/// [target] is in the drawing's own coordinates, the same space as
/// [frameOf]: where on screen the ankle should be. Parents above [upper] keep
/// whatever [pose] says, which is what lets a body bob or lean while its feet
/// stay put.
///
/// Two answers reach any point; [bend] picks one. 1 puts the middle joint
/// counter-clockwise of the line from [upper] to [target] in the rig's own
/// drawing, which for a leg hanging down in a figure facing right is a knee
/// pointing forward. -1 is the other way, an elbow.
///
/// [endDegrees], if given, also turns [end] so that it sits at that angle in
/// the coordinates of the root part (0 is as drawn) -- a foot kept flat
/// however the leg above it is bent.
///
/// A target out of reach is reached for: the limb straightens towards it.
Pose reach(
  Part root,
  Pose pose, {
  required String upper,
  required String lower,
  required String end,
  required Offset target,
  double bend = 1,
  double? endDegrees,
}) {
  final List<Part> path = _require(root, upper);
  final Part upperPart = path.last;
  final Part lowerPart = upperPart.children.firstWhere(
    (Part p) => p.name == lower,
    orElse: () => throw ArgumentError.value(lower, 'lower', 'is not a child of "$upper"'),
  );
  final Part endPart = lowerPart.children.firstWhere(
    (Part p) => p.name == end,
    orElse: () => throw ArgumentError.value(end, 'end', 'is not a child of "$lower"'),
  );

  // Solve in the space the upper joint hangs in. Whatever the parents are
  // doing -- placed, scaled, mirrored, leaning -- is undone once, here, and
  // the rest is the triangle.
  final Affine parent = _chain(path.sublist(0, path.length - 1), pose);
  final Offset t = parent.inverse.apply(target);
  final Joint upperJoint = pose[upper];
  final Offset o = upperPart.at + upperJoint.move;

  final double l1 = lowerPart.at.distance;
  final double l2 = endPart.at.distance;
  final double beta1 = math.atan2(lowerPart.at.dy, lowerPart.at.dx);
  final double beta2 = math.atan2(endPart.at.dy, endPart.at.dx);

  final Offset toTarget = t - o;
  final double d = toTarget.distance
      .clamp((l1 - l2).abs() + 1e-6, (l1 + l2) * (1 - 1e-6))
      .toDouble();
  final double cosA = ((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)).clamp(-1.0, 1.0);
  final double a = math.acos(cosA);
  final double phiT = math.atan2(toTarget.dy, toTarget.dx);
  final double phi1 = phiT - bend.sign * a;
  final Offset elbow = o + Offset(math.cos(phi1), math.sin(phi1)) * l1;
  final Offset toEnd = t - elbow;
  final double phi2 = math.atan2(toEnd.dy, toEnd.dx);

  final double upperDeg = _deg(phi1 - beta1) - upperPart.degrees;
  final double lowerDeg = _deg(phi2 - beta2 - (phi1 - beta1)) - lowerPart.degrees;

  final Map<String, Joint> out = <String, Joint>{
    ...pose.joints,
    upper: _withDegrees(upperJoint, upperDeg),
    lower: _withDegrees(pose[lower], lowerDeg),
  };

  if (endDegrees != null) {
    // The end's angle inside the root: everything between the root and the
    // upper joint, plus the two angles just solved.
    final Affine inner = _chain(path.sublist(1, path.length - 1), pose);
    final double innerDeg = _deg(math.atan2(inner.b, inner.a));
    final double lowerTotal = _deg(phi2 - beta2);
    out[end] = _withDegrees(
      pose[end],
      endDegrees - innerDeg - lowerTotal - endPart.degrees,
    );
  }
  return Pose(out);
}

Joint _withDegrees(Joint j, double degrees) => Joint(
      degrees: _wrap(degrees),
      move: j.move,
      scaleX: j.scaleX,
      scaleY: j.scaleY,
      opacity: j.opacity,
      morph: j.morph,
      weights: j.weights,
    );

/// Into (-180, 180], so blending two solved poses never spins a joint the
/// long way round.
double _wrap(double degrees) {
  double d = degrees % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}
