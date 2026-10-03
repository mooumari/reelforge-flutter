import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';

// Weather and fire: the things a scene is lit and wetted by.
//
// None of these keeps state. A drop's place is its own hash and the time, so
// frame 400 is the same whether the video was played up to it or jumped to.

double _wrap(double v, double length) => v - (v / length).floorToDouble() * length;

/// A fixed starting point for each of [n] things: x, y and a further number
/// each, all in 0..1, the same on every frame.
List<List<double>> _scatter(int seed, int n, int values) {
  final math.Random r = math.Random(seed);
  return <List<double>>[
    for (int i = 0; i < n; i++) <double>[for (int v = 0; v < values; v++) r.nextDouble()],
  ];
}

/// Rain: slanted streaks in three depths -- fine, pale and slow far away,
/// long, bright and fast near -- that fill the frame.
///
/// [intensity] runs from 0 (nothing) to 1 (a downpour) and is how many of
/// the drops there are; ease it from the outside for rain that starts. The
/// streaks are drawn over the whole box this is given, so put it on the
/// lens -- a [ParallaxLayer] at depth 0 -- and it follows no camera.
class Rain extends StatelessWidget {
  const Rain({
    super.key,
    this.intensity = 1,
    this.slant = 14,
    this.color = const Color(0xFFCFE3FF),
    this.seed = 11,
    this.density = 1,
  });

  final double intensity;

  /// Degrees off vertical; the wind. Positive blows to the right.
  final double slant;

  final Color color;
  final int seed;

  /// A multiplier on how many drops a full [intensity] means.
  final double density;

  @override
  Widget build(BuildContext context) {
    final double t = Video.frame(context) / Video.fps(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _RainPainter(t, intensity.clamp(0.0, 1.0), slant, color, seed, density),
    );
  }
}

class _RainPainter extends CustomPainter {
  const _RainPainter(this.t, this.intensity, this.slant, this.color, this.seed, this.density);

  final double t, intensity, slant, density;
  final Color color;
  final int seed;

  // Far, middle, near: how many, how long, how fast (px/s), how wide, how bright.
  static const List<(int, double, double, double, double)> _layers = <(int, double, double, double, double)>[
    (520, 34, 1500, 1.6, 0.22),
    (300, 60, 2300, 2.4, 0.36),
    (130, 104, 3400, 3.6, 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final double tan = math.tan(slant * math.pi / 180);
    for (int l = 0; l < _layers.length; l++) {
      final (int count, double length, double speed, double width, double alpha) = _layers[l];
      final int n = (count * density).round();
      final Paint paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = color.withValues(alpha: alpha);
      final double fall = size.height + length * 2;
      final List<Offset> from = <Offset>[], to = <Offset>[];
      final List<List<double>> drops = _scatter(seed + l * 101, n, 3);
      for (int i = 0; i < n; i++) {
        final List<double> d = drops[i];
        // Drops come in as the rain does: the first i/n of them are there at
        // intensity i/n.
        if (i / n > intensity) continue;
        final double y = _wrap(d[1] * fall + t * speed * (0.9 + d[2] * 0.2), fall) - length;
        final double x = d[0] * (size.width + fall * tan.abs()) - (tan > 0 ? fall * tan : 0) + y * tan;
        from.add(Offset(x, y));
        to.add(Offset(x + length * tan, y + length));
      }
      for (int i = 0; i < from.length; i++) {
        canvas.drawLine(from[i], to[i], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) =>
      old.t != t || old.intensity != intensity || old.slant != slant || old.color != color || old.density != density;
}

/// Drops landing: ripples that open and fade on the ground between [top]
/// and [bottom], in the world's own coordinates.
///
/// Lower down is nearer, so ripples there are bigger. [intensity] is as
/// [Rain]'s.
class RainSplash extends StatelessWidget {
  const RainSplash({
    super.key,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    this.intensity = 1,
    this.color = const Color(0xFFDCEBFF),
    this.seed = 29,
    this.count = 90,
  });

  final double left, right, top, bottom;
  final double intensity;
  final Color color;
  final int seed;
  final int count;

  @override
  Widget build(BuildContext context) {
    final double t = Video.frame(context) / Video.fps(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _SplashPainter(this, t),
    );
  }
}

class _SplashPainter extends CustomPainter {
  const _SplashPainter(this.s, this.t);

  final RainSplash s;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double intensity = s.intensity.clamp(0.0, 1.0);
    if (intensity <= 0) return;
    final List<List<double>> spots = _scatter(s.seed, s.count, 4);
    for (int i = 0; i < s.count; i++) {
      if (i / s.count > intensity) continue;
      final List<double> p = spots[i];
      // Each spot ripples once every 0.55 to 1.1 seconds, out of step.
      final double period = 0.55 + p[2] * 0.55;
      final double age = _wrap(t / period + p[3], 1);
      final double depth = p[1];
      final double rx = (6 + depth * 20) * (0.35 + age);
      final double a = (1 - age) * (0.25 + depth * 0.4);
      final Offset at = Offset(s.left + p[0] * (s.right - s.left), s.top + depth * (s.bottom - s.top));
      final Rect ring = Rect.fromCenter(center: at, width: rx * 2, height: rx * 0.5);
      canvas.drawOval(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + depth * 1.6
          ..color = s.color.withValues(alpha: a),
      );
      // The splash itself: a few drops thrown up, in the first part of the ripple.
      if (age < 0.4) {
        final double u = age / 0.4;
        final Paint drop = Paint()..color = s.color.withValues(alpha: (1 - u) * (0.35 + depth * 0.4));
        for (int k = -1; k <= 1; k++) {
          canvas.drawCircle(at + Offset(k * (4 + depth * 9) * u, -(10 + depth * 18) * math.sin(u * math.pi) * (1 - k.abs() * 0.3)), 1.1 + depth * 1.3, drop);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SplashPainter old) => old.t != t || old.s.intensity != s.intensity;
}

/// A fire: flames that lick and sway, a glow, sparks drifting up.
///
/// Drawn with its base at [base] in the world, [size] times a flame about
/// 150 high. [Fire.flicker] gives the light's own flutter for the same
/// moment, so what the fire lights can flicker in step with it.
class Fire extends StatelessWidget {
  const Fire({
    super.key,
    required this.base,
    this.size = 1,
    this.seed = 3,
    this.strength = 1,
    this.glow = true,
  });

  final Offset base;
  final double size;
  final int seed;

  /// 0 is out, 1 is burning well; in between it is just catching or dying.
  final double strength;

  /// Whether to paint the soft light around it.
  final bool glow;

  /// How bright the fire is at [seconds], about 0.85 to 1.15, as a number to
  /// scale a light by. The same on every frame it is asked.
  static double flicker(double seconds, {int seed = 3}) {
    final double t = seconds + seed * 7.3;
    return 1 +
        0.07 * math.sin(t * 11.0) +
        0.05 * math.sin(t * 17.3 + 1.3) +
        0.04 * math.sin(t * 5.1 + 0.4) +
        0.03 * math.sin(t * 29.0 + 2.1);
  }

  @override
  Widget build(BuildContext context) {
    final double t = Video.frame(context) / Video.fps(context);
    return CustomPaint(size: Size.infinite, painter: _FirePainter(this, t));
  }
}

class _FirePainter extends CustomPainter {
  const _FirePainter(this.f, this.t);

  final Fire f;
  final double t;

  /// One tongue of flame, from [base] up to [tip], [width] wide, bending
  /// with [sway].
  static Path _tongue(Offset base, double height, double width, double sway, double lean) {
    final Offset tip = base + Offset(sway * height * 0.28 + lean * height * 0.2, -height);
    final Offset a = base + Offset(-width / 2, 0), b = base + Offset(width / 2, 0);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx - width * 0.35, a.dy - height * 0.35, base.dx + sway * height * 0.12 - width * 0.12, base.dy - height * 0.72, tip.dx, tip.dy)
      ..cubicTo(base.dx + sway * height * 0.12 + width * 0.12, base.dy - height * 0.72, b.dx + width * 0.35, b.dy - height * 0.35, b.dx, b.dy)
      ..cubicTo(b.dx - width * 0.1, b.dy + height * 0.1, a.dx + width * 0.1, a.dy + height * 0.1, a.dx, a.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double strength = f.strength.clamp(0.0, 1.0);
    if (strength <= 0) return;
    final double s = f.size * (0.35 + 0.65 * strength);
    final double flick = Fire.flicker(t, seed: f.seed);
    final Offset base = f.base;

    if (f.glow) {
      final Rect r = Rect.fromCircle(center: base + Offset(0, -70 * s), radius: 520 * s * flick);
      canvas.drawCircle(
        r.center,
        r.width / 2,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFFF9A3C).withValues(alpha: 0.55 * strength),
              const Color(0xFFFF6A2A).withValues(alpha: 0.2 * strength),
              const Color(0x00FF6A2A),
            ],
            stops: const <double>[0, 0.35, 1],
          ).createShader(r),
      );
    }

    // Tongues, back to front: red outside, orange, yellow, a white heart.
    const List<(double, double, double, Color)> layers = <(double, double, double, Color)>[
      (1.0, 1.0, 0, Color(0xFFE5432A)),
      (0.84, 0.82, 1, Color(0xFFFF7A2F)),
      (0.62, 0.6, 2, Color(0xFFFFC23D)),
      (0.36, 0.38, 3, Color(0xFFFFF3C4)),
    ];
    for (final (double h, double w, double k, Color color) in layers) {
      for (int i = 0; i < 5; i++) {
        final double phase = f.seed * 1.7 + i * 2.1 + k * 0.9;
        final double rise = 0.78 + 0.22 * math.sin(t * (7.5 + i * 1.3) + phase);
        final double sway = math.sin(t * (4.2 + i * 0.8) + phase * 1.3) * 0.55 + math.sin(t * 9.1 + phase) * 0.25;
        final double spread = (i - 2) * 22 * s * w;
        final double mid = 1 - (i - 2).abs() * 0.22;
        canvas.drawPath(
          _tongue(base + Offset(spread, 0), 150 * s * h * rise * mid, (54 + 10 * (1 - h)) * s * w, sway, (i - 2) * 0.25),
          Paint()..color = color,
        );
      }
    }

    // Sparks: each rises for about two seconds, drifting and cooling.
    final List<List<double>> sparks = _scatter(f.seed + 500, 26, 4);
    for (int i = 0; i < sparks.length; i++) {
      final List<double> p = sparks[i];
      final double life = 1.4 + p[2] * 1.4;
      final double age = _wrap(t / life + p[3], 1);
      if (i / sparks.length > strength) continue;
      final double rise = age * (190 + p[0] * 240) * s;
      final double drift = math.sin(age * 6 + p[1] * 9) * 26 * s + (p[1] - 0.5) * 120 * s * age;
      final Offset at = base + Offset(drift, -40 * s - rise);
      final double a = (1 - age) * (1 - age);
      canvas.drawCircle(
        at,
        (1.2 + p[2] * 2.2) * s * (1 - age * 0.5),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Color.lerp(const Color(0xFFFFE2A0), const Color(0xFFFF6A2A), age)!.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_FirePainter old) => old.t != t || old.f.base != f.base || old.f.strength != f.strength || old.f.size != f.size;
}

/// A flash across the whole frame: [flashes] are the seconds at which
/// lightning strikes; each is a quick double flicker.
class Lightning extends StatelessWidget {
  const Lightning({super.key, required this.flashes, this.color = const Color(0xFFD8E4FF)});

  final List<double> flashes;
  final Color color;

  /// How bright the flash is at [seconds]: 0 away from a strike, up to 1.
  static double flash(List<double> flashes, double seconds) {
    double out = 0;
    for (final double at in flashes) {
      final double u = seconds - at;
      if (u < 0 || u > 0.7) continue;
      // A bright stroke, a dark beat, a lesser stroke, then a fade.
      final double a = u < 0.06 ? u / 0.06 : math.exp(-(u - 0.06) * 18);
      final double b = u > 0.16 && u < 0.34 ? math.exp(-(u - 0.16) * 10) * 0.7 : 0;
      out = math.max(out, math.max(u < 0.16 ? a : 0, b));
    }
    return out.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final double a = flash(flashes, Video.frame(context) / Video.fps(context));
    if (a <= 0) return const SizedBox.shrink();
    return IgnorePointer(child: ColoredBox(color: color.withValues(alpha: 0.55 * a), child: const SizedBox.expand()));
  }
}
