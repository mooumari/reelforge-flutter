import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

/// The two ways the rain video can be drawn from one script, one set of
/// timings and one cast: the explainer look (soft gradients, light, weather as
/// atmosphere) and the doodle look (flat colour, a thick marker line round
/// everything, hand lettering, paper).
@immutable
class Look {
  const Look._(this.doodle);

  static const Look explainer = Look._(false);
  static const Look drawn = Look._(true);

  final bool doodle;

  /// Passed to [Drawing] to draw a character in this look.
  Ink? get pen => doodle ? const Ink(width: 6) : null;

  /// The marker's colour, and the ink of lettering on paper.
  Color get ink => const Color(0xFF1C1A24);

  /// The page, in the doodle look.
  Color get paper => const Color(0xFFF4EBD8);

  /// Lettering: Roboto Black in the explainer look, hand lettering in the other.
  TextStyle type(double size, {Color? color, double spacing = 0, FontWeight weight = FontWeight.w800}) => doodle
      ? TextStyle(fontFamily: 'PatrickHand', fontSize: size * 1.12, color: color ?? ink, letterSpacing: spacing * 0.5, height: 1.05)
      : TextStyle(fontFamily: 'Roboto', fontSize: size, fontWeight: weight, color: color ?? const Color(0xFFFFF6E8), letterSpacing: spacing, height: 1.05);

  /// [path] filled with [color] in this look: a soft top-to-bottom gradient
  /// in the explainer look; flat with a wobbly marker line in the doodle one.
  void fill(Canvas canvas, Path path, Color color, {double line = 6, double soften = 0.14, int boil = 0, double wobble = 3, bool outline = true}) {
    if (doodle) {
      final Path p = wobbled(path, wobble, boil);
      canvas.drawPath(p, Paint()..color = color);
      if (outline) canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = line..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round..color = ink);
    } else {
      final Rect b = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, <Color>[
            Color.lerp(color, const Color(0xFFFFFFFF), soften)!,
            Color.lerp(color, const Color(0xFF0C1020), soften)!,
          ]),
      );
    }
  }

  /// [path] with its outline shaken a little, by [amount] pixels, differently
  /// for each [seed]: a line drawn by hand. Change [seed] a few times a second
  /// and the line boils.
  static Path wobbled(Path path, double amount, int seed) {
    if (amount <= 0) return path;
    final Path out = Path();
    for (final ui.PathMetric m in path.computeMetrics()) {
      final int n = math.max(4, (m.length / 22).round());
      final List<Offset> pts = <Offset>[];
      for (int i = 0; i < n; i++) {
        final ui.Tangent t = m.getTangentForOffset(m.length * i / n)!;
        final double a = _noise(i * 12.9898 + seed * 78.233) * math.pi * 2;
        final double r = amount * (0.4 + 0.6 * _noise(i * 39.346 + seed * 11.135));
        pts.add(t.position + Offset(math.cos(a), math.sin(a)) * r);
      }
      if (pts.length < 3) continue;
      // A smooth curve through the shaken points: each is a control point,
      // and the curve passes through the middle of each side.
      final Offset start = m.isClosed ? (pts.last + pts.first) / 2 : pts.first;
      out.moveTo(start.dx, start.dy);
      for (int i = 0; i < pts.length; i++) {
        final bool last = i == pts.length - 1;
        if (last && !m.isClosed) {
          out.lineTo(pts[i].dx, pts[i].dy);
          break;
        }
        final Offset end = (pts[i] + pts[(i + 1) % pts.length]) / 2;
        out.quadraticBezierTo(pts[i].dx, pts[i].dy, end.dx, end.dy);
      }
      if (m.isClosed) out.close();
    }
    return out;
  }

  static double _noise(double x) {
    final double s = math.sin(x) * 43758.5453;
    return s - s.floorToDouble();
  }

  @override
  bool operator ==(Object other) => other is Look && other.doodle == doodle;

  @override
  int get hashCode => doodle.hashCode;
}
