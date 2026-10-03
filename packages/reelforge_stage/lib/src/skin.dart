import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'follow.dart';
import 'kinematics.dart';
import 'outline.dart';
import 'part.dart';
import 'pose.dart';
import 'shape.dart';

/// One outline bent by several joints: an arm that curves at the elbow, a
/// tail that whips, a trunk that curls.
///
/// A puppet built from one rigid shape per part shows its seams at every
/// bend -- the hinge of two capsules. A skin is drawn once, as one outline
/// over the whole limb, and every point of it follows the [bones] it is
/// nearest to, blended where two meet. So a bend is a curve.
///
/// [path] is drawn in the space of the first bone, and the shape goes on that
/// part (`Part(name: 'shoulder', shapes: [Shape.skin(...)])`). The bones are
/// named parts below it, in order down the limb; each covers the stretch from
/// its own joint to the next one's, and the last from its joint to [tip] (in
/// its own space; zero for a point).
///
/// Bound at rest: the outline as drawn is the outline in [Pose.rest].
///
/// A bend keeps its thickness up to about 120 degrees. Tighter than that the
/// two halves of a limb really do overlap on the inside, and the outline
/// creases there as skin would.
@immutable
class Skin {
  const Skin(
    this.path, {
    required this.bones,
    this.tip = Offset.zero,
    this.samples = 96,
    this.falloff = 4,
  }) : assert(bones.length >= 1, 'A skin needs at least one bone.');

  final Path path;
  final List<String> bones;
  final Offset tip;

  /// Points round the outline. More keeps tight curves tight.
  final int samples;

  /// How sharply a point belongs to its nearest bone: weights go as one over
  /// distance to this power. Higher gives tighter, more mechanical bends.
  final double falloff;

  static final Expando<Map<Part, _Binding>> _bindings =
      Expando<Map<Part, _Binding>>();

  _Binding _bind(Part root) {
    final Map<Part, _Binding> byRoot = _bindings[this] ??=
        Map<Part, _Binding>.identity();
    return byRoot.putIfAbsent(root, () => _Binding(this, root));
  }

  /// The outline in [pose], in the first bone's space -- where the painter
  /// has the canvas when it draws this part's shapes.
  Path deformed(Part root, Pose pose) {
    final _Binding b = _bind(root);
    final Affine owner = frameOf(root, pose, bones.first).inverse;
    final List<_Move> moves = <_Move>[
      for (int j = 0; j < bones.length; j++)
        _Move(owner * frameOf(root, pose, bones[j]) * b.restInverse[j]),
    ];
    final List<Offset> out = List<Offset>.generate(b.points.length, (int i) {
      final Offset p = b.points[i];
      final List<double> w = b.weights[i];
      // Blending the bones' matrices point by point (linear blend skinning)
      // pulls a bent joint's inside in on itself until it folds. Blending
      // them as dual numbers -- a turn and a shift together -- swings each
      // point round the joint on an arc instead, so a bend keeps its
      // thickness. Scale, which a dual number cannot carry, is blended
      // apart and applied first.
      double c = 0, sn = 0, dx = 0, dy = 0;
      double sa = 0, sb = 0, sc = 0, sd = 0;
      for (int j = 0; j < moves.length; j++) {
        final double wj = w[j];
        if (wj == 0) continue;
        final _Move m = moves[j];
        c += wj * m.c;
        sn += wj * m.s;
        dx += wj * m.dx;
        dy += wj * m.dy;
        sa += wj * m.sa;
        sb += wj * m.sb;
        sc += wj * m.sc;
        sd += wj * m.sd;
      }
      final double norm = math.sqrt(c * c + sn * sn);
      c /= norm;
      sn /= norm;
      dx /= norm;
      dy /= norm;
      final double cos = c * c - sn * sn, sin = 2 * c * sn;
      final double tx = 2 * (c * dx - sn * dy), ty = 2 * (sn * dx + c * dy);
      final double x = sa * p.dx + sc * p.dy, y = sb * p.dx + sd * p.dy;
      return Offset(cos * x - sin * y + tx, sin * x + cos * y + ty);
    }, growable: false);
    return Paths.smooth(out, closed: b.closed);
  }
}

/// One bone's move from rest, split for blending: a turn as half-angle
/// cosine and sine, the shift as a dual part, and what is left of the
/// matrix once the turn is taken out -- its scale and any shear.
class _Move {
  factory _Move(Affine m) {
    final double angle = math.atan2(m.b, m.a);
    final double cos = math.cos(angle), sin = math.sin(angle);
    // Half angles in (-90, 90], so every bone's turn is blended the short way
    // round from the first bone, which never turns relative to itself.
    final double c = math.cos(angle / 2), s = math.sin(angle / 2);
    return _Move._(
      c,
      s,
      0.5 * (c * m.tx + s * m.ty),
      0.5 * (c * m.ty - s * m.tx),
      // R(-angle) * the linear part.
      cos * m.a + sin * m.b,
      -sin * m.a + cos * m.b,
      cos * m.c + sin * m.d,
      -sin * m.c + cos * m.d,
    );
  }

  const _Move._(this.c, this.s, this.dx, this.dy, this.sa, this.sb, this.sc, this.sd);

  final double c, s, dx, dy;
  final double sa, sb, sc, sd;
}

class _Binding {
  factory _Binding(Skin skin, Part root) {
    final Affine owner = frameOf(root, Pose.rest, skin.bones.first).inverse;
    final List<Affine> rest = <Affine>[
      for (final String bone in skin.bones) owner * frameOf(root, Pose.rest, bone),
    ];
    // Each bone as a segment in the first bone's space.
    final List<(Offset, Offset)> segments = <(Offset, Offset)>[
      for (int j = 0; j < rest.length; j++)
        (
          rest[j].origin,
          j + 1 < rest.length ? rest[j + 1].origin : rest[j].apply(skin.tip),
        ),
    ];
    final Outline outline = Outline.of(skin.path, samples: skin.samples);
    final List<List<double>> weights = <List<double>>[
      for (final Offset p in outline.points) _weigh(p, segments, skin.falloff),
    ];
    return _Binding._(
      outline.points,
      outline.closed,
      weights,
      <Affine>[for (final Affine r in rest) r.inverse],
    );
  }

  const _Binding._(this.points, this.closed, this.weights, this.restInverse);

  final List<Offset> points;
  final bool closed;
  final List<List<double>> weights;

  /// Undoes each bone's rest placement, so a point is carried by how far the
  /// bone has moved from rest rather than by where it is.
  final List<Affine> restInverse;

  static List<double> _weigh(
    Offset p,
    List<(Offset, Offset)> segments,
    double falloff,
  ) {
    final List<double> w = <double>[
      for (final (Offset a, Offset b) in segments)
        1 / math.pow(_distanceToSegment(p, a, b) + 1e-3, falloff),
    ];
    final double sum = w.fold(0, (double s, double x) => s + x);
    return <double>[for (final double x in w) x / sum];
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final Offset ab = b - a;
    final double len2 = ab.distanceSquared;
    if (len2 == 0) return (p - a).distance;
    final double t =
        (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}

/// A row of joints with one skin over them: a tail, a trunk, a tentacle, a
/// braid, a scarf end, a snake.
///
/// The chain is drawn along its own +x axis from its root joint, tapering
/// from [width] to [tipWidth]; place and turn it with [at] and [degrees].
/// Its joints are called `name0`, `name1`, ... so a pose or [wave] can turn
/// them, and [jiggles] lets follow-through swing them.
@immutable
class Chain {
  const Chain(
    this.name, {
    this.segments = 6,
    required this.length,
    required this.width,
    this.tipWidth,
    this.color,
    this.gradient,
    this.stroke,
    this.strokeWidth = 0,
    this.shade,
    this.at = Offset.zero,
    this.degrees = 0,
    this.children = const <Part>[],
  }) : assert(segments >= 1);

  final String name;
  final int segments;
  final double length;
  final double width;

  /// Width at the end; defaults to a third of [width].
  final double? tipWidth;
  final Color? color;
  final Gradient? gradient;
  final Color? stroke;
  final double strokeWidth;

  /// Form for a [Light], as on any [Shape].
  final Shade? shade;
  final Offset at;
  final double degrees;

  /// Hung on the last joint, at the tip: a tail tuft, a hand, a flower.
  final List<Part> children;

  double get _segment => length / segments;

  List<String> get names =>
      List<String>.generate(segments, (int i) => '$name$i', growable: false);

  /// The tapered outline along +x, rounded at both ends.
  Path get outline {
    final double w0 = width / 2, w1 = (tipWidth ?? width / 3) / 2;
    const int n = 12;
    final List<Offset> top = <Offset>[], bottom = <Offset>[];
    for (int i = 0; i <= n; i++) {
      final double t = i / n;
      // Thickest a little way in, so the root reads as attached rather than
      // pinched.
      final double half = w0 + (w1 - w0) * math.pow(t, 0.9);
      top.add(Offset(length * t, -half));
      bottom.add(Offset(length * t, half));
    }
    return Paths.smooth(<Offset>[
      Offset(-w0, 0),
      ...top,
      Offset(length + w1, 0),
      ...bottom.reversed,
    ]);
  }

  Part get part {
    // A soft falloff spreads each bend over the neighbouring joints, so a
    // whipping chain reads as one curve rather than a row of hinges.
    final Skin skin = Skin(outline, bones: names, tip: Offset(_segment, 0), falloff: 2);
    Part link(int i) => Part(
          name: '$name$i',
          at: i == 0 ? at : Offset(_segment, 0),
          degrees: i == 0 ? degrees : 0,
          shapes: i == 0
              ? <Shape>[
                  Shape.skin(
                    skin,
                    color: color,
                    gradient: gradient,
                    stroke: stroke,
                    strokeWidth: strokeWidth,
                    shade: shade,
                  ),
                ]
              : const <Shape>[],
          children: i + 1 < segments
              ? <Part>[link(i + 1)]
              : <Part>[
                  if (children.isNotEmpty)
                    Part(at: Offset(_segment, 0), children: children),
                ],
        );
    return link(0);
  }

  /// A travelling wave down the chain: each joint swings [amplitude] degrees
  /// a little later than the one above it, so the motion runs to the tip
  /// like a cat's tail or a fish's body.
  ///
  /// [wavelength] is in joints -- how many it takes for the wave to come
  /// round again; the default puts about one curve along the chain. [taper]
  /// grows the swing towards the tip (0 even, 1 from nothing at the root).
  Pose wave(
    num frame,
    int fps, {
    double amplitude = 10,
    double hertz = 0.8,
    double? wavelength,
    double phase = 0,
    double taper = 0.5,
    double bias = 0,
  }) {
    final double t = frame / fps;
    final double lambda = wavelength ?? segments.toDouble();
    return Pose(<String, Joint>{
      for (int i = 0; i < segments; i++)
        '$name$i': Joint.rotate(
          bias / segments +
              amplitude *
                  (1 - taper + taper * (segments == 1 ? 1 : i / (segments - 1))) *
                  math.sin(2 * math.pi * (hertz * t - i / lambda) + phase),
        ),
    });
  }

  /// A curl: every joint turned the same way so the chain rolls up by
  /// [degrees] in all, more of it towards the tip when [taper] is high.
  Pose curl(double degrees, {double taper = 0.5}) {
    final List<double> share = <double>[
      for (int i = 0; i < segments; i++)
        1 - taper + taper * (segments == 1 ? 1 : 2 * i / (segments - 1)),
    ];
    final double total = share.fold(0, (double s, double x) => s + x);
    return Pose(<String, Joint>{
      for (int i = 0; i < segments; i++)
        '$name$i': Joint.rotate(degrees * share[i] / total),
    });
  }

  /// Follow-through for every joint, root first, so each swings on the one
  /// above it and the chain trails behind whatever carries it.
  List<Jiggle> jiggles({
    double hertz = 1.8,
    double damping = 0.3,
    double inertia = 1,
    double limit = 35,
  }) =>
      <Jiggle>[
        for (int i = 0; i < segments; i++)
          Jiggle(
            '$name$i',
            bone: Offset(_segment, 0),
            // Further out is lighter and quicker, as on a real tail.
            hertz: hertz * (1 + 0.25 * i / segments),
            damping: damping,
            inertia: inertia,
            limit: limit,
          ),
      ];
}
