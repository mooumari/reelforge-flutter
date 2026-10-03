import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart' hide Look;

import 'rain_look.dart';
import 'rain_set.dart';

/// The scenery of the rain video's opening, in either [Look]: the valley in a
/// sky of any weather, and the rain.
///
/// The explainer look is the valley from [rain_set.dart]; the doodle look is
/// the same valley drawn again as flat shapes with a marker line round each.

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;

/// Which frame of the boil a doodle's line is on: it changes a few times a
/// second, so the lines shimmer like a hand-drawn cartoon's.
int boilOf(int frame) => frame ~/ 4;

/// The valley, at time of day [h] under [storm], in [look], inside a [Camera]
/// that moves through [camera].
Widget valleyShot(
  Look look,
  BuildContext context, {
  required double h,
  required double storm,
  double rain = 0,
  double riverRise = 0,
  double cloudSpeed = 1,
  List<CameraKeyframe> camera = const <CameraKeyframe>[CameraKeyframe(0, center: Offset(960, 540))],
  Widget? foreground,
}) {
  final int frame = Video.frame(context);
  return Camera(
    keyframes: camera,
    child: Stack(
      fit: StackFit.expand,
      children: look.doodle
          ? _doodleLayers(look, frame, h: h, storm: storm, rain: rain, riverRise: riverRise, cloudSpeed: cloudSpeed, foreground: foreground)
          : valleyLayers(context, h: h, storm: storm, riverRise: riverRise, rain: rain, cloudSpeed: cloudSpeed, foreground: foreground),
    ),
  );
}

/// Rain over the whole frame, in [look].
Widget rainOver(Look look, double intensity, {double slant = 12, int seed = 11}) =>
    look.doodle ? _DoodleRain(intensity: intensity, slant: slant, seed: seed) : Rain(intensity: intensity, slant: slant, seed: seed);

/// Splashes where rain meets the ground: the explainer look only (a doodle's
/// rain simply stops at the ground).
Widget splashes(Look look, {double intensity = 1, int count = 140, double top = 900, double bottom = 1060}) =>
    look.doodle ? const SizedBox.shrink() : RainSplash(left: -100, right: 2020, top: top, bottom: bottom, intensity: intensity, count: count);

/// A figure soaked, in the explainer look; the doodle look has no wet.
Widget soaked(Look look, Widget child, double amount) => look.doodle ? child : wet(child, amount);

// --- the doodle valley ---

List<Widget> _doodleLayers(
  Look look,
  int frame, {
  required double h,
  required double storm,
  required double rain,
  required double riverRise,
  required double cloudSpeed,
  Widget? foreground,
}) {
  final double t = frame / 30;
  final Color tone = landTone(h, storm);
  Widget toned(Widget child) => ColorFiltered(colorFilter: ColorFilter.mode(tone, BlendMode.modulate), child: child);
  final int boil = boilOf(frame);
  return <Widget>[
    ParallaxLayer(depth: 0.0, child: CustomPaint(size: Size.infinite, painter: _DoodleSky(h, storm))),
    ParallaxLayer(depth: 0.04, child: CustomPaint(size: Size.infinite, painter: _DoodleClouds(look, t * cloudSpeed, h, storm, boil))),
    ParallaxLayer(depth: 0.18, child: toned(CustomPaint(size: Size.infinite, painter: _DoodleLand(look, 0, boil, 0)))),
    ParallaxLayer(depth: 0.45, child: toned(CustomPaint(size: Size.infinite, painter: _DoodleLand(look, 1, boil, 0)))),
    ParallaxLayer(depth: 0.7, child: toned(CustomPaint(size: Size.infinite, painter: _DoodleLand(look, 2, boil, 0)))),
    ParallaxLayer(depth: 0.85, child: toned(CustomPaint(size: Size.infinite, painter: _DoodleLand(look, 3, boil, riverRise, t: t)))),
    ParallaxLayer(depth: 1.0, child: toned(CustomPaint(size: Size.infinite, painter: _DoodleLand(look, 4, boil, 0)))),
    if (foreground != null) ParallaxLayer(depth: 1.0, child: foreground),
  ];
}

class _DoodleSky extends CustomPainter {
  const _DoodleSky(this.h, this.storm);

  final double h, storm;

  @override
  void paint(Canvas canvas, Size size) {
    final double day = daylight(h);
    final Color fine = _mix(const Color(0xFF2A3354), const Color(0xFFBEDCEA), day);
    final Color grey = _mix(const Color(0xFF2C3446), const Color(0xFF9DAEB9), day);
    canvas.drawRect(Offset.zero & size, Paint()..color = _mix(fine, grey, storm * 0.9));
  }

  @override
  bool shouldRepaint(_DoodleSky old) => old.h != h || old.storm != storm;
}

/// Clouds as outlined puffs. Every cloud the storm will have is there from
/// the start; the extra ones grow from nothing as it thickens.
class _DoodleClouds extends CustomPainter {
  const _DoodleClouds(this.look, this.t, this.h, this.storm, this.boil);

  final Look look;
  final double t, h, storm;
  final int boil;

  @override
  void paint(Canvas canvas, Size size) {
    final double day = daylight(h);
    final Color fine = _mix(const Color(0xFF8C98BC), const Color(0xFFFFFFFF), day);
    final Color heavy = _mix(const Color(0xFF59647A), const Color(0xFFC6D0D8), day);
    final Color body = _mix(fine, heavy, storm);
    for (int layer = 0; layer < 2; layer++) {
      final math.Random r = math.Random(70 + layer);
      final int base = 3 + layer * 2, extra = 4 + layer * 3;
      const double margin = 700;
      final double wide = size.width + 2 * margin;
      for (int i = 0; i < base + extra; i++) {
        final double ux = r.nextDouble(), uy = r.nextDouble(), us = r.nextDouble();
        final double presence = i < base ? 1.0 : (storm * (extra + 1) - (i - base)).clamp(0.0, 1.0);
        if (presence <= 0) continue;
        final double x = ((ux * wide + t * (12 + layer * 14)) % wide) - margin;
        final double y = 90 + layer * 110 + uy * (140 + storm * 80);
        final double s = (0.8 + us * 0.8) * (1 + layer * 0.3) * (1 + storm * 0.4) * Curves.easeOut.transform(presence);
        _puff(canvas, Offset(x, y), s, body, boil + i);
      }
    }
  }

  static const List<(double, double, double)> _lobes = <(double, double, double)>[(-110, 4, 44), (-56, -24, 60), (6, -38, 70), (66, -20, 58), (116, 6, 44), (0, 14, 56)];

  /// One cloud: the union of its lobes and its flat base, so the marker goes
  /// round the whole of it and not round every lobe.
  void _puff(Canvas canvas, Offset at, double s, Color body, int seed) {
    Path out = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(at.dx - 150 * s, at.dy - 4 * s, at.dx + 150 * s, at.dy + 34 * s), Radius.circular(30 * s)));
    for (final (double dx, double dy, double r) in _lobes) {
      out = Path.combine(PathOperation.union, out, Path()..addOval(Rect.fromCircle(center: at + Offset(dx * s, dy * s), radius: r * s)));
    }
    look.fill(canvas, out, body, line: 5, boil: seed, wobble: 2.5);
  }

  @override
  bool shouldRepaint(_DoodleClouds old) => old.t != t || old.h != h || old.storm != storm || old.boil != boil;
}

/// One band of the doodle valley: 0 far mountains, 1 hills, 2 meadow, 3 river,
/// 4 bank. Each is a flat shape with the marker round its top edge.
class _DoodleLand extends CustomPainter {
  const _DoodleLand(this.look, this.band, this.boil, this.rise, {this.t = 0});

  final Look look;
  final int band, boil;
  final double rise, t;

  static const List<Offset> _ridgeFar = <Offset>[
    Offset(-140, 640), Offset(120, 560), Offset(330, 592), Offset(580, 520), Offset(860, 566), Offset(1100, 534), Offset(1380, 580), Offset(1640, 536), Offset(1900, 590), Offset(2100, 600),
  ];
  static const List<Offset> _ridgeNear = <Offset>[
    Offset(-140, 720), Offset(60, 580), Offset(190, 440), Offset(260, 480), Offset(380, 330), Offset(480, 430), Offset(560, 480), Offset(700, 610), Offset(900, 670),
    Offset(1160, 650), Offset(1300, 530), Offset(1420, 410), Offset(1500, 340), Offset(1610, 450), Offset(1760, 530), Offset(1860, 480), Offset(1960, 570), Offset(2100, 650),
  ];

  Path _ridge(List<Offset> pts) => Paths.polygon(<Offset>[...pts, Offset(pts.last.dx, 1100), Offset(pts.first.dx, 1100)]);

  Path _snow(List<Offset> pts, double line) => Path.combine(
        PathOperation.intersect,
        _ridge(pts),
        Paths.polygon(<Offset>[
          Offset(pts.first.dx, 0),
          Offset(pts.last.dx, 0),
          for (double x = pts.last.dx; x >= pts.first.dx; x -= 36) Offset(x, line + math.sin(x * 0.045) * 26 + ((x ~/ 36) % 2) * 14),
        ]),
      );

  @override
  void paint(Canvas canvas, Size size) {
    switch (band) {
      case 0:
        look.fill(canvas, _ridge(_ridgeFar), const Color(0xFFD9E6EE), boil: boil, wobble: 3, line: 5);
        look.fill(canvas, _snow(_ridgeFar, 600), const Color(0xFFFFFFFF), boil: boil + 1, wobble: 3, line: 4);
        look.fill(canvas, _ridge(_ridgeNear), const Color(0xFF8DA2B8), boil: boil + 2, wobble: 3, line: 6);
        look.fill(canvas, _snow(_ridgeNear, 500), const Color(0xFFFFFFFF), boil: boil + 3, wobble: 3, line: 5);
      case 1:
        look.fill(
          canvas,
          Paths.smooth(const <Offset>[Offset(-140, 760), Offset(260, 700), Offset(700, 760), Offset(1100, 700), Offset(1560, 770), Offset(2080, 710), Offset(2080, 1100), Offset(-140, 1100)]),
          const Color(0xFF9FBA8A),
          boil: boil + 4,
          wobble: 3,
        );
      case 2:
        look.fill(
          canvas,
          Paths.smooth(const <Offset>[Offset(-140, 800), Offset(380, 784), Offset(900, 796), Offset(1460, 780), Offset(2080, 796), Offset(2080, 1100), Offset(-140, 1100)]),
          const Color(0xFFB7CC8A),
          boil: boil + 5,
          wobble: 3,
        );
      case 3:
        final double y = 836 - rise;
        look.fill(
          canvas,
          Paths.smooth(<Offset>[Offset(-140, y), Offset(500, y - 8), Offset(1000, y + 6), Offset(1500, y - 6), Offset(2080, y), Offset(2080, 1100), Offset(-140, 1100)]),
          const Color(0xFF86BAD6),
          boil: boil + 6,
          wobble: 3,
        );
        // Ripples: short strokes that drift along the water.
        final Paint ripple = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85);
        for (int i = 0; i < 14; i++) {
          final double x = ((i * 157.0 + t * (18 + (i % 3) * 7)) % 2200) - 140;
          final double yy = y + 22 + (i % 4) * 11;
          canvas.drawArc(Rect.fromCenter(center: Offset(x, yy), width: 46 + (i % 3) * 14, height: 14), math.pi * 1.1, math.pi * 0.8, false, ripple);
        }
      case 4:
        look.fill(
          canvas,
          Paths.smooth(const <Offset>[Offset(-140, 886), Offset(300, 874), Offset(760, 884), Offset(1200, 868), Offset(1640, 880), Offset(2080, 870), Offset(2080, 1100), Offset(-140, 1100)]),
          const Color(0xFFD3C29A),
          boil: boil + 7,
          wobble: 3,
        );
        // Tufts of grass along the bank: three short strokes each.
        final Paint tuft = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = look.ink;
        for (int i = 0; i < 16; i++) {
          final double x = 60 + i * 124.0 + (i * 37 % 41), y = 930 + (i * 53 % 90);
          canvas.drawLine(Offset(x, y), Offset(x - 9, y - 22), tuft);
          canvas.drawLine(Offset(x, y), Offset(x + 1, y - 28), tuft);
          canvas.drawLine(Offset(x, y), Offset(x + 10, y - 20), tuft);
        }
    }
  }

  @override
  bool shouldRepaint(_DoodleLand old) => old.boil != boil || old.rise != rise || old.t != t || old.band != band;
}

/// Rain as short marker dashes.
class _DoodleRain extends StatelessWidget {
  const _DoodleRain({required this.intensity, required this.slant, required this.seed});

  final double intensity, slant;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final double t = Video.frame(context) / Video.fps(context);
    return CustomPaint(size: Size.infinite, painter: _DoodleRainPainter(t, intensity, slant, seed));
  }
}

class _DoodleRainPainter extends CustomPainter {
  const _DoodleRainPainter(this.t, this.intensity, this.slant, this.seed);

  final double t, intensity, slant;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final math.Random r = math.Random(seed);
    const int all = 230;
    final int count = (all * intensity.clamp(0.0, 1.0)).round();
    final double lean = math.tan(slant * math.pi / 180);
    final Paint dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = const Color(0xFF3E6C96);
    for (int i = 0; i < all; i++) {
      final double ux = r.nextDouble(), up = r.nextDouble(), speed = 900 + r.nextDouble() * 500, len = 38 + r.nextDouble() * 30;
      // Drops are always there; a thinner rain simply draws fewer of them,
      // the same ones every time.
      if (i >= count) continue;
      final double y = ((up * 1300 + t * speed) % (size.height + 260)) - 130;
      final double x = ux * (size.width + 400) - 200;
      canvas.drawLine(Offset(x, y), Offset(x + len * lean, y + len), dash);
    }
  }

  @override
  bool shouldRepaint(_DoodleRainPainter old) => old.t != t || old.intensity != intensity;
}

// --- bits drawn in both looks ---

/// Lettering in [look] at [at], centred, with a small fade-and-rise.
Widget caption(Look look, String text, {required double size, double opacity = 1, Color? color, double spacing = 0, FontWeight weight = FontWeight.w800, TextAlign align = TextAlign.center}) =>
    Opacity(opacity: opacity.clamp(0.0, 1.0), child: Text(text, textAlign: align, style: look.type(size, color: color, spacing: spacing, weight: weight)));

/// A little interpolation: 0 before [from], 1 after [from] + [over] seconds.
double ease(double t, double from, double over, [Curve curve = Curves.easeInOut]) => curve.transform(((t - from) / over).clamp(0.0, 1.0));

/// A short line of lettering on a chip, so it reads over a busy map.
Widget chip(Look look, String text, {required double size, double opacity = 1}) => Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: look.doodle ? look.paper : const Color(0xCC0E1B38),
          borderRadius: BorderRadius.circular(size * 0.4),
          border: look.doodle ? Border.all(color: look.ink, width: 4) : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.5, vertical: size * 0.18),
          child: Text(text, style: look.type(size, color: look.doodle ? look.ink : const Color(0xFFFFF6E8), weight: FontWeight.w600)),
        ),
      ),
    );
