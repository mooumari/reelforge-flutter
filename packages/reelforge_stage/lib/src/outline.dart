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
