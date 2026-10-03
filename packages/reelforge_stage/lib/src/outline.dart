import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'shape.dart';

/// One contour of a [Path] as evenly spaced points.
///
/// Spacing by arc length rather than by curve parameter is what makes two
/// unrelated outlines comparable: point 10 of a circle and point 10 of a star
/// are both a tenth of the way round, whatever beziers drew them.
@immutable
class Outline {
  const Outline(this.points, {this.closed = true});

  /// Samples the first contour of [path] at [samples] evenly spaced points.
  ///
  /// A path with more than one contour is a drawing of several shapes, and
  /// morphing several into several has no single right answer -- split it
  /// into one shape per contour instead.
  factory Outline.of(Path path, {int samples = 96}) {
    assert(samples >= 3, 'An outline needs at least three points.');
    final List<ui.PathMetric> contours = path.computeMetrics().toList();
    if (contours.isEmpty) {
      throw ArgumentError.value(path, 'path', 'An empty path has no outline.');
    }
    assert(
      contours.length == 1,
      'Outline.of reads one contour; this path has ${contours.length}.',
    );
    final ui.PathMetric contour = contours.first;
    final bool closed = contour.isClosed;
    // A closed loop's last point would repeat its first, so it is divided
    // into `samples` gaps; an open line keeps both ends.
    final int gaps = closed ? samples : samples - 1;
    return Outline(
      List<Offset>.generate(samples, (int i) {
        final ui.Tangent? at =
            contour.getTangentForOffset(contour.length * i / gaps);
        return at!.position;
      }, growable: false),
      closed: closed,
    );
  }

  final List<Offset> points;
  final bool closed;

  /// Twice the enclosed area, signed by which way round the points go.
  double get _winding {
    double sum = 0;
    for (int i = 0; i < points.length; i++) {
      final Offset a = points[i], b = points[(i + 1) % points.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum;
  }

  /// This outline, renumbered to start and turn like [other] as closely as
  /// it can, so that a morph moves every point a short way rather than
  /// spinning the shape inside out.
  Outline alignedTo(Outline other) {
    assert(points.length == other.points.length && closed == other.closed);
    List<Offset> p = points;
    final int n = p.length;
    if (!closed) {
      // An open line can only be read forwards or backwards.
      double cost(List<Offset> q) =>
          (q.first - other.points.first).distanceSquared +
          (q.last - other.points.last).distanceSquared;
      final List<Offset> reversed = p.reversed.toList(growable: false);
      return Outline(cost(reversed) < cost(p) ? reversed : p, closed: false);
    }
    if (_winding.sign != other._winding.sign) {
      p = p.reversed.toList(growable: false);
    }
    int best = 0;
    double bestCost = double.infinity;
    for (int shift = 0; shift < n; shift++) {
      double cost = 0;
      for (int i = 0; i < n && cost < bestCost; i++) {
        cost += (p[(i + shift) % n] - other.points[i]).distanceSquared;
      }
      if (cost < bestCost) {
        bestCost = cost;
        best = shift;
      }
    }
    return Outline(
      List<Offset>.generate(n, (int i) => p[(i + best) % n], growable: false),
      closed: true,
    );
  }

  static Outline lerp(Outline a, Outline b, double t) => Outline(
        List<Offset>.generate(
          a.points.length,
          (int i) => Offset.lerp(a.points[i], b.points[i], t)!,
          growable: false,
        ),
        closed: a.closed,
      );

  /// Back to a path, rounded through the points.
  Path toPath() => Paths.smooth(points, closed: closed);
}

/// A shape that changes between key outlines: a mouth from shut to open to
/// round, a blob into a planet, a seed into a tree.
///
/// The keys can be any paths -- drawn with [Paths], by hand, or built from
/// one another. Each is sampled into an [Outline] and aligned to the first,
/// then [at] blends between neighbours. Put one in a [Shape.morph] and the
/// part's [Joint.morph] picks the shape, so morphing is posed and keyed like
/// any other joint.
class Morph {
  Morph(List<Path> keys, {this.samples = 96})
      : assert(keys.length >= 2, 'A morph needs at least two key shapes.'),
        _keys = keys;

  final List<Path> _keys;
  final int samples;

  int get length => _keys.length;

  late final List<Outline> outlines = () {
    final Outline first = Outline.of(_keys.first, samples: samples);
    final List<Outline> out = <Outline>[first];
    for (final Path key in _keys.skip(1)) {
      final Outline o = Outline.of(key, samples: samples);
      assert(
        o.closed == first.closed,
        'A morph cannot go between a closed shape and an open line.',
      );
      // Each key is aligned to the one before it, which is the pair that is
      // actually blended -- aligning everything to the first can leave two
      // neighbours a half turn apart.
      out.add(o.alignedTo(out.last));
    }
    return out;
  }();

  /// The outline at [t]: 0 is the first key, 1 the second, 2.5 halfway from
  /// the third to the fourth. Clamped to the keys there are.
  Outline outlineAt(double t) {
    final double c = t.clamp(0.0, (length - 1).toDouble());
    final int i = math.min(c.floor(), length - 2);
    return Outline.lerp(outlines[i], outlines[i + 1], c - i);
  }

  final Map<double, Path> _cache = <double, Path>{};

  /// The path at [t]; see [outlineAt].
  ///
  /// Keys are drawn resampled too, not as the original path: passing through
  /// a key mid-animation must not pop from the rounded resampling to the
  /// exact corners and back. Use enough [samples] for the sharpest corner.
  Path at(double t) {
    final double c = t.clamp(0.0, (length - 1).toDouble());
    if (_cache.length > 512) _cache.clear();
    return _cache[c] ??= outlineAt(c).toPath();
  }
}

/// A shape with named shape keys that mix: a mouth that can be "ah" and
/// smiling at once, an eye that is wide and blinking.
///
/// Where a [Morph] is a line of shapes -- from the first, through the
/// second, to the third -- a blend is a base shape plus any amount of each
/// key's difference from it, which is what a face needs: speech jumps from
/// any mouth shape to any other, and emotion sits on top of it.
///
/// Each key is sampled and aligned to [base], so the keys can be drawn
/// independently. They blend best drawn alike -- the same number of corners
/// in the same places -- because then every point's move is the obvious one.
///
/// The part's [Joint.weights] say how much of each key to show. A key in
/// [overriding] replaces the others as it comes in rather than adding to
/// them: a blink closes a smiling eye, rather than adding "shut" to
/// "smiling" and turning the eye inside out.
class Blend {
  Blend(
    Path base,
    Map<String, Path> keys, {
    this.samples = 96,
    this.overriding = const <String>{},
  })  : _basePath = base,
        _keyPaths = keys,
        assert(
          overriding.every(keys.containsKey),
          'Overriding keys must be keys of the blend.',
        );

  final Path _basePath;
  final Map<String, Path> _keyPaths;
  final int samples;
  final Set<String> overriding;

  Iterable<String> get keys => _keyPaths.keys;

  late final Outline base = Outline.of(_basePath, samples: samples);

  late final Map<String, List<Offset>> _deltas = <String, List<Offset>>{
    for (final MapEntry<String, Path> key in _keyPaths.entries)
      key.key: () {
        final Outline o = Outline.of(key.value, samples: samples).alignedTo(base);
        return <Offset>[
          for (int i = 0; i < samples; i++) o.points[i] - base.points[i],
        ];
      }(),
  };

  /// The outline for [weights]. Names that are not keys are ignored, so one
  /// face pose can weigh the eyes and the mouth in the same map.
  Outline outlineFor(Map<String, double> weights) {
    double keep = 1;
    for (final String k in overriding) {
      keep *= 1 - (weights[k] ?? 0).clamp(0.0, 1.0);
    }
    final List<double> xs = <double>[for (final Offset p in base.points) p.dx];
    final List<double> ys = <double>[for (final Offset p in base.points) p.dy];
    weights.forEach((String name, double w) {
      final List<Offset>? d = _deltas[name];
      if (d == null || w == 0) return;
      final double scaled = overriding.contains(name) ? w : w * keep;
      for (int i = 0; i < samples; i++) {
        xs[i] += d[i].dx * scaled;
        ys[i] += d[i].dy * scaled;
      }
    });
    return Outline(
      <Offset>[for (int i = 0; i < samples; i++) Offset(xs[i], ys[i])],
      closed: base.closed,
    );
  }

  final Map<String, Path> _cache = <String, Path>{};

  /// The path for [weights]; see [outlineFor].
  Path at(Map<String, double> weights) {
    final List<String> names = weights.keys.where(_keyPaths.containsKey).toList()..sort();
    final String id = <String>[
      for (final String n in names)
        if (weights[n] != 0) '$n=${weights[n]}',
    ].join(',');
    if (_cache.length > 1024) _cache.clear();
    return _cache[id] ??= outlineFor(weights).toPath();
  }
}
