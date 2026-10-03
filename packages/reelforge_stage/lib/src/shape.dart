import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'kinematics.dart';
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
    this.shade,
  })  : morph = null,
        skin = null,
        blend = null,
        live = null,
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
    this.shade,
  })  : path = null,
        skin = null,
        blend = null,
        live = null,
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
    this.shade,
  })  : path = null,
        morph = null,
        blend = null,
        live = null,
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
    this.shade,
  })  : path = null,
        morph = null,
        skin = null,
        live = null,
        assert(
          color == null || gradient == null,
          'A shape is filled with a colour or a gradient, not both.',
        );

  /// A shape whose outline is worked out from the pose as it is drawn: [live]
  /// is given [Where] the drawing's joints are, and returns a path in this
  /// part's space. For outlines that depend on several limbs at once -- a
  /// robe that has to cover both legs mid-stride, a rope between two hands.
  ///
  /// It runs every time the part is painted, so keep it cheap, and keep it a
  /// function of [Where] alone.
  const Shape.live(
    Path Function(Where where) this.live, {
    this.color,
    this.gradient,
    this.stroke,
    this.strokeWidth = 0,
    this.shade,
  })  : path = null,
        morph = null,
        skin = null,
        blend = null,
        assert(
          color == null || gradient == null,
          'A shape is filled with a colour or a gradient, not both.',
        );

  /// The outline, for a still shape. Exactly one of [path], [morph], [skin],
  /// [blend] and [live] is set.
  final Path? path;
  final Morph? morph;
  final Skin? skin;
  final Blend? blend;
  final Path Function(Where where)? live;

  /// Flat fill. Null leaves the inside undrawn, unless there is a [gradient].
  final Color? color;

  /// Fill shaded across the path's own bounds, so the same gradient follows
  /// the shape wherever the part is placed.
  final Gradient? gradient;

  final Color? stroke;
  final double strokeWidth;

  /// How the [Drawing]'s [Light] falls on this shape; null is unlit.
  final Shade? shade;

  /// Draws [outline] in this shape's fill and stroke at the canvas's current
  /// transform. [Drawing] works out the outline -- still, morphed or bent --
  /// and, for a [shade]d shape, which way the light comes from in this
  /// shape's own coordinates.
  void paint(Canvas canvas, Path outline, {Light? light, Offset toLight = Offset.zero, Ink? ink, double inkScale = 1}) {
    final Path path = outline;
    if (ink != null) {
      _paintInked(canvas, path, ink, inkScale);
      return;
    }
    final Shade? sh = light == null || toLight == Offset.zero ? null : shade;
    if (sh != null && sh.cast > 0) sh._paintCast(canvas, path, light!, toLight);
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
      if (sh != null) sh._paintLight(canvas, path, light!, toLight, color);
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

  void _paintInked(Canvas canvas, Path path, Ink ink, double scale) {
    Color? flat = color;
    if (flat == null && gradient != null) {
      final List<Color> cs = gradient!.colors;
      flat = cs[cs.length ~/ 2];
    }
    final double line = ink.width / scale;
    final bool outlined = ink.width > 0;
    if (flat != null && flat.a > 0) {
      canvas.drawPath(path, Paint()..style = PaintingStyle.fill..color = flat);
      final Rect box = path.getBounds();
      final bool big = box.shortestSide >= ink.thin * line;
      if (outlined && flat.a >= ink.seeThrough && big) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = line
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = ink.color,
        );
      }
    }
    if (stroke != null && strokeWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(strokeWidth, line * 0.6)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = stroke!,
      );
    }
  }
}

/// A doodle: every shape flat in its own colour, with a thick dark line round
/// it, the way a person draws with a marker. Light and shade are dropped.
///
/// [width] is in the drawing's own units, so lines scale with the picture and
/// the camera. Shapes thinner than about two line widths (hairs, creases,
/// stitches) are left unoutlined, or the line would swallow them, and so are
/// the see-through ones.
@immutable
class Ink {
  const Ink({this.color = const Color(0xFF1C1A24), this.width = 5, this.thin = 2.2, this.seeThrough = 0.9});

  final Color color;
  final double width;

  /// Shapes narrower than this many line widths are not outlined.
  final double thin;

  /// Fills fainter than this are not outlined.
  final double seeThrough;

  /// The same pen, [factor] times as wide: finer lines for a face.
  Ink scaled(double factor) => Ink(color: color, width: width * factor, thin: thin, seeThrough: seeThrough);

  @override
  bool operator ==(Object other) =>
      other is Ink && other.color == color && other.width == width && other.thin == thin && other.seeThrough == seeThrough;

  @override
  int get hashCode => Object.hash(color, width, thin, seeThrough);
}

/// Where the light in a [Drawing] comes from, and its colours.
///
/// Flat illustration still has light: every shape is a little lighter on the
/// side facing it and darker on the side away, with a bright edge where the
/// light grazes it and a shadow where one shape sits on another. That is
/// most of what makes a flat drawing look solid; [Shade] does it from the
/// outline alone, for any shape that asks.
@immutable
class Light {
  const Light({
    this.from = const Offset(-0.55, -0.83),
    this.shadow = const Color(0xFF7A68B8),
    this.highlight = const Color(0xFFFFE8C8),
    this.cast = const Color(0xFF241848),
  });

  /// Towards the light, in the drawing's coordinates: the default is up and
  /// to the left. Need not be unit length.
  final Offset from;

  /// Multiplied into a shape's shadow side: a cool colour, so shadows shift
  /// hue rather than only going grey.
  final Color shadow;

  /// Screened into a shape's lit edge.
  final Color highlight;

  /// The colour of a shadow one shape casts on another.
  final Color cast;

  @override
  bool operator ==(Object other) =>
      other is Light && other.from == from && other.shadow == shadow && other.highlight == highlight && other.cast == cast;

  @override
  int get hashCode => Object.hash(from, shadow, highlight, cast);
}

/// How a shape takes the [Light]: a soft gradient across it, a crescent of
/// shadow on the side away from the light, a thin bright rim on the side
/// towards it, and optionally a shadow cast on whatever it is drawn over.
///
/// The crescent and the rim are the outline shifted against itself, so they
/// follow any shape -- a head, a bent arm, a hat brim -- and turn as the part
/// turns, because the light is worked out in the shape's own space.
@immutable
class Shade {
  const Shade({
    this.form = 0.35,
    this.core = 0.4,
    this.coreStrength = 0.75,
    this.rim = 0.12,
    this.rimStrength = 0.55,
    this.cast = 0,
    this.castStrength = 0.3,
  });

  /// A body part: everything on.
  static const Shade solid = Shade();

  /// Cloth and hair: a little softer.
  static const Shade soft = Shade(form: 0.3, core: 0.32, coreStrength: 0.6, rim: 0.1, rimStrength: 0.4);

  /// Only the gradient: small things, faces' features.
  static const Shade gentle = Shade(form: 0.3, core: 0, rim: 0);

  /// The strength of the gradient across the shape, 0 to 1.
  final double form;

  /// How far the shadow crescent reaches in, as a fraction of the shape's
  /// thickness; 0 for none.
  final double core;
  final double coreStrength;

  /// The rim's width, as a fraction of the thickness; 0 for none.
  final double rim;
  final double rimStrength;

  /// How far this shape's shadow falls on what is under it, in its own
  /// units, away from the light. Only lands on things already drawn in the
  /// same [Drawing]: a hat brim shades the face, not the sky.
  final double cast;
  final double castStrength;

  static final Expando<double> _thickness = Expando<double>();

  /// About how thick the shape is: twice its area over its perimeter -- a
  /// bar's width, a disc's radius -- so a crescent is in proportion on a
  /// finger and a head alike.
  static double _thick(Path path) => _thickness[path] ??= () {
        double area = 0, perimeter = 0;
        for (final ui.PathMetric m in path.computeMetrics()) {
          perimeter += m.length;
          if (!m.isClosed || m.length == 0) continue;
          const int n = 48;
          Offset? first, prev;
          double a = 0;
          for (int i = 0; i < n; i++) {
            final Offset p = m.getTangentForOffset(m.length * i / n)!.position;
            if (prev != null) a += prev.dx * p.dy - p.dx * prev.dy;
            first ??= p;
            prev = p;
          }
          a += prev!.dx * first!.dy - first.dx * prev.dy;
          area += a.abs() / 2;
        }
        return perimeter == 0 ? 0.0 : 2 * area / perimeter;
      }();

  /// Everything outside [hole], for drawing round it inside a clip.
  static Path _outside(Path hole, Rect bounds) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(bounds.inflate(bounds.longestSide + 100))
    ..addPath(hole, Offset.zero);

  /// The shadow side of [base]: darker and a little richer, nudged towards
  /// the light's shadow colour -- never washed with it, or skin in shadow
  /// turns the colour of the sky and looks see-through.
  static Color shadowOf(Color base, Light light, [double strength = 1]) {
    final HSLColor hsl = HSLColor.fromColor(base);
    final Color deeper = hsl
        .withLightness((hsl.lightness * (1 - 0.26 * strength)).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * (1 + 0.12 * strength)).clamp(0.0, 1.0))
        .toColor();
    return Color.lerp(deeper, light.shadow, 0.14 * strength)!;
  }

  void _paintLight(Canvas canvas, Path path, Light light, Offset toLight, Color? base) {
    final Offset l = toLight / toLight.distance;
    final Rect b = path.getBounds();
    final double t = _thick(path);
    final Color dark = base == null ? light.shadow : shadowOf(base, light);
    canvas.save();
    canvas.clipPath(path);
    if (form > 0) {
      final double extent = (l.dx.abs() * b.width + l.dy.abs() * b.height) / 2;
      canvas.drawRect(
        b,
        Paint()
          ..shader = ui.Gradient.linear(
            b.center + l * extent,
            b.center - l * extent,
            <Color>[
              light.highlight.withValues(alpha: 0.35 * form),
              light.highlight.withValues(alpha: 0),
              dark.withValues(alpha: 0),
              dark.withValues(alpha: (base == null ? 0.7 : 1.0) * form),
            ],
            const <double>[0, 0.45, 0.55, 1],
          ),
      );
    }
    if (core > 0 && t > 0) {
      canvas.drawPath(
        _outside(path.shift(l * (core * t)), b),
        base == null
            ? (Paint()
              ..blendMode = BlendMode.multiply
              ..color = Color.lerp(const Color(0xFFFFFFFF), light.shadow, coreStrength)!)
            : (Paint()..color = shadowOf(base, light, coreStrength).withValues(alpha: base.a)),
      );
    }
    if (rim > 0 && t > 0) {
      canvas.drawPath(
        _outside(path.shift(-l * (rim * t)), b),
        Paint()
          ..blendMode = BlendMode.screen
          ..color = Color.lerp(const Color(0xFF000000), light.highlight, rimStrength)!,
      );
    }
    canvas.restore();
  }

  void _paintCast(Canvas canvas, Path path, Light light, Offset toLight) {
    final Offset l = toLight / toLight.distance;
    canvas.drawPath(
      path.shift(-l * cast),
      Paint()
        ..blendMode = BlendMode.srcATop
        ..color = light.cast.withValues(alpha: castStrength),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Shade &&
      other.form == form &&
      other.core == core &&
      other.coreStrength == coreStrength &&
      other.rim == rim &&
      other.rimStrength == rimStrength &&
      other.cast == cast &&
      other.castStrength == castStrength;

  @override
  int get hashCode => Object.hash(form, core, coreStrength, rim, rimStrength, cast, castStrength);
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
