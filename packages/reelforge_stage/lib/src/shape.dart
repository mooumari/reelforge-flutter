import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import 'outline.dart';
import 'skin.dart';

/// One filled and/or stroked outline.
///
/// A shape is the only thing in this package that draws. A [Path] is already a
/// perfectly good way to describe a drawing in code, so there is no shape
/// language on top of it: build the path however you like, or with [Paths],
/// and hand it over. Treat the path as frozen once it is in a shape -- parts
/// are shared between every place they appear.
///
/// The outline can also move: [Shape.morph] changes between key shapes as
/// its part's [Joint.morph] says, [Shape.blend] mixes shape keys by its
/// part's [Joint.weights], and [Shape.skin] bends with the joints under it.
@immutable
class Shape {
  const Shape(
    Path this.path, {
    this.color,
    this.gradient,
    this.stroke,
    this.strokeWidth = 0,
  })  : morph = null,
        skin = null,
        blend = null,
        assert(
          color == null || gradient == null,
          'A shape is filled with a colour or a gradient, not both.',
        );

  /// A shape whose outline is [morph] at the part's [Joint.morph].
  const Shape.morph(
    Morph this.morph, {
    this.color,
    this.gradient,
    this.stroke,
    this.strokeWidth = 0,
  })  : path = null,
        skin = null,
        blend = null,
        assert(
          color == null || gradient == null,
          'A shape is filled with a colour or a gradient, not both.',
        );

  /// A shape whose outline is [skin], bent by its bones.
  const Shape.skin(
    Skin this.skin, {
    this.color,
    this.gradient,
    this.stroke,
    this.strokeWidth = 0,
  })  : path = null,
        morph = null,
        blend = null,
        assert(
          color == null || gradient == null,
          'A shape is filled with a colour or a gradient, not both.',
        );

  /// A shape whose outline is [blend] at the part's [Joint.weights].
  const Shape.blend(
    Blend this.blend, {
    this.color,
    this.gradient,
    this.stroke,
    this.strokeWidth = 0,
  })  : path = null,
        morph = null,
        skin = null,
        assert(
          color == null || gradient == null,
          'A shape is filled with a colour or a gradient, not both.',
        );

  /// The outline, for a still shape. Exactly one of [path], [morph], [skin]
  /// and [blend] is set.
  final Path? path;
  final Morph? morph;
  final Skin? skin;
  final Blend? blend;

  /// Flat fill. Null leaves the inside undrawn, unless there is a [gradient].
  final Color? color;

  /// Fill shaded across the path's own bounds, so the same gradient follows
  /// the shape wherever the part is placed.
  final Gradient? gradient;

  final Color? stroke;
  final double strokeWidth;

  /// Draws [outline] in this shape's fill and stroke at the canvas's current
  /// transform. [Drawing] works out the outline -- still, morphed or bent.
  void paint(Canvas canvas, Path outline) {
    final Path path = outline;
    if (color != null || gradient != null) {
      final Paint fill = Paint()..style = PaintingStyle.fill;
      if (gradient != null) {
        // The shader's own colours carry their alpha; the paint's colour is
        // only the modulator, so it stays opaque.
        fill
          ..color = const Color(0xFFFFFFFF)
          ..shader = gradient!.createShader(path.getBounds());
      } else {
        fill.color = color!;
      }
      canvas.drawPath(path, fill);
    }
    if (stroke != null && strokeWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = stroke!,
      );
    }
  }
}

/// Outlines worth having a name for.
///
/// Everything is built from `Path`'s own verbs; these only save the arithmetic
/// of the shapes a flat illustration is made of -- balls, bars, limbs, hills.
abstract final class Paths {
  static Path circle(Offset center, double radius) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  static Path ellipse(Offset center, double rx, double ry) => Path()
    ..addOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2));

  static Path rect(Rect rect) => Path()..addRect(rect);

  static Path roundRect(Rect rect, double radius) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

  /// A bar from [a] to [b] with round ends: the shape of an arm, a leg, a
  /// finger. Zero length gives a circle.
  static Path capsule(Offset a, Offset b, double radius) {
    final Offset d = b - a;
    final Path bar = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-radius, -radius, d.distance + radius * 2, radius * 2),
          Radius.circular(radius),
        ),
      );
    final Matrix4 m = Matrix4.translationValues(a.dx, a.dy, 0)
      ..rotateZ(math.atan2(d.dy, d.dx));
    return bar.transform(m.storage);
  }

  /// A [capsule] that thins from [radiusA] at [a] to [radiusB] at [b]: a
  /// limb, a horn, a tail, a carrot.
  static Path taper(Offset a, Offset b, double radiusA, double radiusB) {
    final Offset d = b - a;
    final double length = d.distance;
    final double angle = math.atan2(d.dy, d.dx);
    // Where the straight sides touch the end circles: turned from square by
    // the slope the difference in radius gives them.
    final double tilt = length == 0
        ? 0
        : math.asin(((radiusA - radiusB) / length).clamp(-1.0, 1.0));
    final double side = math.pi / 2 - tilt;
    final Rect start = Rect.fromCircle(center: a, radius: radiusA);
    final Rect end = Rect.fromCircle(center: b, radius: radiusB);
    return Path()
      ..arcTo(end, angle - side, 2 * side, true)
      ..arcTo(start, angle + side, 2 * (math.pi - side), false)
      ..close();
  }

  static Path polygon(List<Offset> points) {
    assert(points.length >= 3, 'A polygon needs at least three points.');
    return Path()..addPolygon(points, true);
  }

  /// A curve that passes through every point, rounded between them.
  ///
  /// This is how hills, clouds and blobs are drawn without placing a single
  /// bezier handle: set down the points you want the outline to hit. Closed by
  /// default; pass `closed: false` for an open line such as a mouth.
  static Path smooth(List<Offset> points, {bool closed = true}) {
    assert(points.length >= 2, 'A curve needs at least two points.');
    final int n = points.length;
    Offset at(int i) => closed
        ? points[(i % n + n) % n]
        : points[i.clamp(0, n - 1)];

    final Path path = Path()..moveTo(points[0].dx, points[0].dy);
    final int segments = closed ? n : n - 1;
    for (int i = 0; i < segments; i++) {
      // Catmull-Rom as a cubic: each handle is a sixth of the chord between
      // the neighbours, which is what makes the curve pass *through* points
      // rather than merely lean towards them.
      final Offset c1 = at(i) + (at(i + 1) - at(i - 1)) / 6;
      final Offset c2 = at(i + 1) - (at(i + 2) - at(i)) / 6;
      final Offset p = at(i + 1);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p.dx, p.dy);
    }
    if (closed) path.close();
    return path;
  }
}

/// Linear-gradient shorthand for the common case: [from] to [to], top to
/// bottom.
LinearGradient verticalGradient(Color from, Color to) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[from, to],
    );
