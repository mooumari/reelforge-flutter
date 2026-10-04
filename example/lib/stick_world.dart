import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart' hide Look;

import 'rain_look.dart';
import 'rain_open_shots.dart' show paintFlame;

/// The flat cartoon world the stick figures live in: a soft sky with outlined
/// clouds, hills, ground with a horizon line and tufts of grass. Every shape is
/// a flat colour with a thin dark line, so a figure with a thick marker line
/// stands out from it the way a figure does in a children's book.
const Color stickInk = Color(0xFF14121A);

/// How wet the weather is, to colour the world: 0 a bright day, 1 a heavy grey.
class StickWorld extends StatelessWidget {
  const StickWorld({super.key, this.gloom = 1, this.horizon = 640, this.speed = 1});

  final double gloom;
  final double horizon;
  final double speed;

  @override
  Widget build(BuildContext context) {
    final double t = Video.frame(context) / Video.fps(context);
    return Stack(fit: StackFit.expand, children: <Widget>[
      ParallaxLayer(depth: 0.0, child: CustomPaint(size: Size.infinite, painter: _SkyPainter(gloom, horizon, t * speed))),
      ParallaxLayer(depth: 0.25, child: CustomPaint(size: Size.infinite, painter: _HillsPainter(gloom, horizon))),
      ParallaxLayer(depth: 1.0, child: CustomPaint(size: Size.infinite, painter: _GroundPainter(gloom, horizon))),
    ]);
  }
}

Color _grey(Color fine, Color grey, double gloom) => Color.lerp(fine, grey, gloom)!;

void _flat(Canvas canvas, Path path, Color fill, {double line = 3, Color edge = const Color(0xFF6E766C)}) {
  canvas.drawPath(path, Paint()..color = fill);
  canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = line..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round..color = edge);
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.gloom, this.horizon, this.t);

  final double gloom, horizon, t;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[
        _grey(const Color(0xFFA9D2EA), const Color(0xFFB8C0BE), gloom),
        _grey(const Color(0xFFE6F1F0), const Color(0xFFDDDFD0), gloom),
      ]).createShader(all),
    );
    // Clouds: outlined puffs on a flat base, drifting.
    final math.Random r = math.Random(31);
    const double margin = 420;
    final double wide = size.width + 2 * margin;
    for (int i = 0; i < 9; i++) {
      final double x = ((r.nextDouble() * wide + t * (6 + i % 3 * 4)) % wide) - margin;
      final double y = 70 + r.nextDouble() * (horizon * 0.5);
      final double s = 0.7 + r.nextDouble() * 0.9;
      _cloud(canvas, Offset(x, y), s, _grey(const Color(0xFFFFFFFF), const Color(0xFFEFEFEA), gloom));
    }
  }

  void _cloud(Canvas canvas, Offset at, double s, Color color) {
    Path p = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(at.dx - 120 * s, at.dy - 8 * s, at.dx + 130 * s, at.dy + 22 * s), Radius.circular(18 * s)));
    for (final (double dx, double dy, double rad) in const <(double, double, double)>[(-70, -6, 30), (-24, -26, 42), (34, -18, 36), (84, -2, 26)]) {
      p = Path.combine(PathOperation.union, p, Path()..addOval(Rect.fromCircle(center: at + Offset(dx * s, dy * s), radius: rad * s)));
    }
    _flat(canvas, p, color, line: 2.5, edge: const Color(0xFF8E9694));
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t || old.gloom != gloom;
}

class _HillsPainter extends CustomPainter {
  const _HillsPainter(this.gloom, this.horizon);

  final double gloom, horizon;

  @override
  void paint(Canvas canvas, Size size) {
    final Path far = Paths.smooth(<Offset>[
      Offset(-80, horizon + 10), Offset(240, horizon - 80), Offset(640, horizon - 40), Offset(1040, horizon - 110), Offset(1460, horizon - 50), Offset(1800, horizon - 90), Offset(2040, horizon - 30),
      Offset(2040, horizon + 40), Offset(-80, horizon + 40),
    ]);
    _flat(canvas, far, _grey(const Color(0xFF9DB7A8), const Color(0xFFA3B0A4), gloom), edge: const Color(0xFF727E74));
    final Path near = Paths.smooth(<Offset>[
      Offset(-80, horizon + 20), Offset(300, horizon - 30), Offset(760, horizon + 4), Offset(1220, horizon - 36), Offset(1700, horizon + 2), Offset(2040, horizon - 20),
      Offset(2040, horizon + 60), Offset(-80, horizon + 60),
    ]);
    _flat(canvas, near, _grey(const Color(0xFFB4CC9A), const Color(0xFFB9C3A0), gloom), edge: const Color(0xFF7C8A6E));
  }

  @override
  bool shouldRepaint(_HillsPainter old) => old.gloom != gloom;
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter(this.gloom, this.horizon);

  final double gloom, horizon;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect ground = Rect.fromLTRB(-40, horizon, size.width + 40, size.height + 40);
    canvas.drawRect(
      ground,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[
        _grey(const Color(0xFFD6D08A), const Color(0xFFCBC592), gloom),
        _grey(const Color(0xFFC4BA78), const Color(0xFFB8B078), gloom),
      ]).createShader(ground),
    );
    // The horizon, and a few long lines across the plain.
    final Paint edge = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = const Color(0xFF55584A);
    canvas.drawLine(Offset(-40, horizon), Offset(size.width + 40, horizon), edge);
    final math.Random r = math.Random(6);
    final Paint faint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..color = const Color(0x886B6A4A);
    for (int i = 0; i < 5; i++) {
      final double y = horizon + 50 + i * 70 + r.nextDouble() * 20, x = r.nextDouble() * size.width * 0.7;
      final Path line = Path()..moveTo(x, y)..quadraticBezierTo(x + 300, y - 14 + r.nextDouble() * 28, x + 420 + r.nextDouble() * 500, y + 2);
      canvas.drawPath(line, faint);
    }
    // Tufts of grass and pebbles, small and far at the top, large and near.
    for (int i = 0; i < 46; i++) {
      final double v = r.nextDouble();
      final double y = horizon + 30 + v * (size.height - horizon - 20), x = r.nextDouble() * size.width;
      final double s = 0.5 + v * 1.1;
      if (i % 5 == 4) {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 22 * s, height: 11 * s), Paint()..color = const Color(0xFFB3AE98));
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 22 * s, height: 11 * s), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF6B6A5A));
      } else {
        _tuft(canvas, Offset(x, y), s);
      }
    }
  }

  void _tuft(Canvas canvas, Offset at, double s) {
    final Path blade = Path()
      ..moveTo(at.dx - 12 * s, at.dy)
      ..quadraticBezierTo(at.dx - 12 * s, at.dy - 22 * s, at.dx - 18 * s, at.dy - 30 * s)
      ..quadraticBezierTo(at.dx - 2 * s, at.dy - 20 * s, at.dx, at.dy - 4 * s)
      ..quadraticBezierTo(at.dx + 2 * s, at.dy - 26 * s, at.dx + 4 * s, at.dy - 36 * s)
      ..quadraticBezierTo(at.dx + 10 * s, at.dy - 20 * s, at.dx + 10 * s, at.dy - 2 * s)
      ..quadraticBezierTo(at.dx + 16 * s, at.dy - 18 * s, at.dx + 24 * s, at.dy - 26 * s)
      ..quadraticBezierTo(at.dx + 20 * s, at.dy - 8 * s, at.dx + 16 * s, at.dy)
      ..close();
    _flat(canvas, blade, const Color(0xFFA6BB78), line: 2.2, edge: const Color(0xFF4C5A36));
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.gloom != gloom;
}

/// Rain in the same thin line as everything else in the world.
class StickRain extends StatelessWidget {
  const StickRain({super.key, this.intensity = 1, this.slant = 8});

  final double intensity, slant;

  @override
  Widget build(BuildContext context) {
    final double t = Video.frame(context) / Video.fps(context);
    return CustomPaint(size: Size.infinite, painter: _RainPainter(t, intensity, slant));
  }
}

class _RainPainter extends CustomPainter {
  const _RainPainter(this.t, this.intensity, this.slant);

  final double t, intensity, slant;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final math.Random r = math.Random(17);
    const int all = 260;
    final int count = (all * intensity.clamp(0.0, 1.0)).round();
    final double lean = math.tan(slant * math.pi / 180);
    final Paint drop = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = 3..color = const Color(0xAA4F6E8C);
    for (int i = 0; i < all; i++) {
      final double ux = r.nextDouble(), up = r.nextDouble(), speed = 1100 + r.nextDouble() * 500, len = 34 + r.nextDouble() * 34;
      if (i >= count) continue;
      final double y = ((up * 1500 + t * speed) % (size.height + 300)) - 150;
      final double x = ux * (size.width + 400) - 200;
      canvas.drawLine(Offset(x, y), Offset(x + len * lean, y + len), drop);
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => old.t != t || old.intensity != intensity;
}

// --- props ---

/// A hide tent: hides stretched over crossed poles, patched, a dark doorway.
Part hideTent(double x, double ground, double scale) => Part(at: Offset(x, ground), scaleX: scale, scaleY: scale, shapes: <Shape>[
      Shape(Paths.polygon(const <Offset>[Offset(-8, -196), Offset(-30, -262), Offset(-18, -266), Offset(4, -202)]), color: const Color(0xFF6A4528)),
      Shape(Paths.polygon(const <Offset>[Offset(8, -196), Offset(36, -256), Offset(48, -250), Offset(20, -196)]), color: const Color(0xFF6A4528)),
      Shape(Paths.polygon(const <Offset>[Offset(-150, 0), Offset(-14, -204), Offset(16, -204), Offset(150, 0)]), color: const Color(0xFFB59470)),
      Shape(Paths.polygon(const <Offset>[Offset(-92, -70), Offset(-40, -150), Offset(-4, -122), Offset(-30, -40)]), color: const Color(0xFF977552)),
      Shape(Paths.polygon(const <Offset>[Offset(40, -140), Offset(78, -78), Offset(34, -40), Offset(8, -96)]), color: const Color(0xFFCBAA82)),
      Shape(Paths.polygon(const <Offset>[Offset(-40, 0), Offset(-14, -112), Offset(16, -112), Offset(44, 0)]), color: const Color(0xFF4A3524)),
    ]);

/// A ring of stones round a fire's place.
Part fireStones(double x, double ground, double scale) => Part(at: Offset(x, ground), scaleX: scale, scaleY: scale, shapes: <Shape>[
      for (int i = 0; i < 9; i++)
        Shape(
          Paths.ellipse(Offset(math.cos(i / 9 * math.pi * 2) * 118, math.sin(i / 9 * math.pi * 2) * 30), 30 + (i % 3) * 5, 17 + (i % 2) * 3),
          color: i.isEven ? const Color(0xFFB7B5AA) : const Color(0xFF9E9C92),
        ),
    ]);

/// A rock to sit a few of them on.
Part rock(double x, double ground, double scale) => Part(at: Offset(x, ground), scaleX: scale, scaleY: scale, shapes: <Shape>[
      Shape(Paths.smooth(const <Offset>[Offset(-70, 0), Offset(-64, -30), Offset(-30, -58), Offset(26, -56), Offset(64, -26), Offset(72, 0)]), color: const Color(0xFFA8A89E)),
      Shape(Paths.polygon(const <Offset>[Offset(10, -52), Offset(52, -24), Offset(60, 0), Offset(30, 0), Offset(22, -30)]), color: const Color(0xFF8C8C84)),
    ]);

/// A spear held upright: the hand is its origin.
Part spear({double length = 270, double lift = 70}) => Part(shapes: <Shape>[
      Shape(Paths.capsule(Offset(0, lift), Offset(0, lift - length), 3.4), color: const Color(0xFF6A4528)),
      Shape(Paths.polygon(<Offset>[Offset(0, lift - length - 36), Offset(-9, lift - length + 4), Offset(9, lift - length + 4)]), color: const Color(0xFF9AA0A8)),
    ]);

/// A stirring stick: a short length of branch in the hand.
Part stick() => Part(shapes: <Shape>[Shape(Paths.capsule(const Offset(-8, -14), const Offset(70, 70), 3.6), color: const Color(0xFF6A4528))]);

/// A fire painted with its flames dancing: a base at [base] in the world.
class FireLight extends StatelessWidget {
  const FireLight({super.key, required this.base, this.size = 1});

  final Offset base;
  final double size;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    return CustomPaint(size: Size.infinite, painter: _FirePainter(base, size, frame / 30, frame ~/ 4));
  }
}

class _FirePainter extends CustomPainter {
  const _FirePainter(this.base, this.size, this.t, this.boil);

  final Offset base;
  final double size, t;
  final int boil;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Smoke, a column of outlined puffs.
    for (int i = 0; i < 8; i++) {
      final double u = (t * 0.26 + i / 8) % 1.0;
      final Offset at = base + Offset(math.sin(u * 5 + i) * 14 * u * size, (-30 - u * 260) * size);
      final double rad = (9 + u * 30) * size;
      canvas.drawCircle(at, rad, Paint()..color = const Color(0xFFEDEDE8).withValues(alpha: (1 - u) * 0.9));
      canvas.drawCircle(at, rad, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..color = const Color(0xFF7E8480).withValues(alpha: (1 - u)));
    }
    paintFlame(canvas, Look.drawn, base, size * 0.55, t, boil);
  }

  @override
  bool shouldRepaint(_FirePainter old) => old.t != t || old.base != base;
}
