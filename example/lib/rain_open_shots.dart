import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart' hide Look, Say;
import 'package:reelforge_stage/reelforge_stage.dart' as st show Look;

import 'map_view.dart';
import 'rain_cast.dart';
import 'rain_look.dart';
import 'rain_open_set.dart';
import 'rain_open_timing.dart';
import 'rain_set.dart';
import 'rain_timing.dart' show lerpD;
import 'rain_week.dart' show bandCrowd;

/// The opening's first eight shots, each drawn in either [Look]. A shot is a
/// picture for one idea; what lands, lands about a third of a second before
/// the word it is about.
const double _lands = 0.3;

double _t(BuildContext context) => Video.frame(context) / openFps;

double _len(int shot) => openLengths[shot] / openFps;

/// A figure standing on [ground], hunched against the rain by [amount].
Pose hunch(Character c, int seed, int frame, double amount) {
  final double shiver = math.sin(frame * 1.9 + seed * 2.7) * 0.7 + math.sin(frame * 0.8 + seed) * 0.4;
  return c.stance.plus(c.life(seed).at(frame, openFps)).plus(Pose(<String, Joint>{
    'chest': Joint.rotate(9 * amount + shiver * amount),
    'head': Joint.rotate(6 * amount - shiver * 0.5 * amount),
  }));
}

/// [c] drawn in [look] standing at [x] on [ground], [s] times its size.
Widget person(Look look, Character c, double x, double ground, double s, Pose pose, int frame, Light light, {double wetness = 0, Part? rig, double shadow = 80}) {
  final Part base = (rig ?? c.part);
  final Offset at = c.standing(x, ground);
  final Part placed = base.placed(at: Offset(x, ground - (ground - at.dy) * s), scale: s);
  final Posed p = followThrough((int f) => Posed(placed, pose), frame, jiggles: c.jiggles, fps: openFps);
  return Stack(fit: StackFit.expand, children: <Widget>[
    Drawing(groundShadow(x, shadow * s, y: ground + 3)),
    soaked(look, Drawing(p.part, pose: p.pose, light: light, ink: look.pen), wetness),
  ]);
}

// --- shot 0: the map ---

/// Black, then a map of Europe comes up out of it with the ice sheet over the
/// north, and the camera slides toward one valley, where a pin lands.
class MapShot extends StatelessWidget {
  const MapShot(this.look, {super.key});

  final Look look;

  static const double pinLon = 1.2, pinLat = 45.0;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps, len = _len(0);
    final double k = ease(t, 0.4, len - 0.4, Curves.easeInOutSine);
    final MapView view = MapView(lon0: lerpD(14, 3.5, k), lat0: lerpD(54, 47, k), radius: lerpD(1150, 2150, k), centre: const Offset(960, 540));
    final double up = ease(t, 0.5, 1.4, Curves.easeIn);
    final double land = said(0, Say.ago, 0) - _lands;
    final double drop = ease(t, land, 0.35, Curves.easeIn);
    final Offset pin = view.project(pinLon, pinLat);
    final double ripple = ease(t, land + 0.33, 0.9, Curves.easeOut);
    final Offset iceAt = view.project(18, 64);
    final double rain = 0.07 + 0.2 * ease(t, said(0, Say.ago, 7) - 0.2, 1.6);
    return Stack(fit: StackFit.expand, children: <Widget>[
      const ColoredBox(color: Color(0xFF000000)),
      Opacity(
        opacity: up,
        child: CustomPaint(size: Size.infinite, painter: MapPainter(look: look, view: view, ice: ease(t, 1.0, 1.8), frame: boilOf(frame))),
      ),
      Opacity(opacity: up, child: rainOver(look, t < 0.3 ? 0 : rain, slant: 8)),
      // The pin falls on "Twenty" and sends out a ring.
      Positioned.fill(child: CustomPaint(painter: _PinPainter(look, pin + Offset(0, -(1 - drop) * 760), drop, ripple, pin))),
      Positioned(
        left: pin.dx + 40,
        top: pin.dy - 56,
        child: chip(look, '20,000 years ago', size: 46, opacity: ease(t, land + 0.35, 0.5)),
      ),
      Positioned(
        left: iceAt.dx - 150,
        top: iceAt.dy - 20,
        child: chip(look, 'ice sheet (approximate)', size: 34, opacity: ease(t, 2.4, 0.6)),
      ),
      Positioned(
        left: 64,
        bottom: 46,
        child: chip(look, "map: today's coastlines", size: 32, opacity: ease(t, 1.2, 0.6)),
      ),
    ]);
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter(this.look, this.at, this.dropped, this.ripple, this.ground);

  final Look look;
  final Offset at, ground;
  final double dropped, ripple;

  @override
  void paint(Canvas canvas, Size size) {
    if (dropped <= 0) return;
    if (ripple > 0 && ripple < 1) {
      canvas.drawOval(
        Rect.fromCenter(center: ground, width: 200 * ripple, height: 70 * ripple),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = look.doodle ? 5 : 4
          ..color = (look.doodle ? look.ink : const Color(0xFFFFE0A8)).withValues(alpha: 1 - ripple),
      );
    }
    // A teardrop with its point on the place.
    final Path drop = Path()
      ..moveTo(at.dx, at.dy)
      ..cubicTo(at.dx - 16, at.dy - 30, at.dx - 38, at.dy - 52, at.dx - 38, at.dy - 84)
      ..arcToPoint(Offset(at.dx + 38, at.dy - 84), radius: const Radius.circular(38), clockwise: true)
      ..cubicTo(at.dx + 38, at.dy - 52, at.dx + 16, at.dy - 30, at.dx, at.dy)
      ..close();
    const Color red = Color(0xFFE5533D);
    canvas.drawPath(drop, Paint()..color = red);
    if (look.doodle) canvas.drawPath(drop, Paint()..style = PaintingStyle.stroke..strokeWidth = 6..strokeJoin = StrokeJoin.round..color = look.ink);
    canvas.drawCircle(at + const Offset(0, -84), 14, Paint()..color = look.doodle ? look.paper : const Color(0xFFFFF0E0));
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.at != at || old.ripple != ripple || old.look != look;
}

// --- shot 1: the valley, in a drizzle ---

class ValleyShot extends StatelessWidget {
  const ValleyShot(this.look, {super.key});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final double t = _t(context), len = _len(1);
    final double rain = 0.22 + 0.1 * (t / len);
    return Stack(fit: StackFit.expand, children: <Widget>[
      valleyShot(
        look,
        context,
        h: 0.44,
        storm: 0.1,
        rain: rain,
        camera: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(960, 560), zoom: 1.0),
          CameraKeyframe(openLengths[1], center: const Offset(930, 620), zoom: 1.1, curve: Curves.easeInOutSine),
        ],
        foreground: splashes(look, intensity: rain, count: 60),
      ),
      rainOver(look, rain, slant: 8),
    ]);
  }
}

// --- shot 2: a week, scratched on a stone ---

/// Seven marks, one a beat, starting before "week"; the sky closes in as the
/// last lands.
/// When the first mark is cut into the stone, and the beat between marks: a
/// mark starts before "week" and the last lands before the shot ends.
(double, double) stoneBeat() {
  final double first = math.max(0.15, said(2, Say.week, 2) - 0.45);
  return (first, math.min(0.27, (_len(2) - 0.35 - first) / 7));
}

class StoneShot extends StatelessWidget {
  const StoneShot(this.look, {super.key});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps;
    final (double first, double beat) = stoneBeat();
    final double days = ((t - first) / beat).clamp(0.0, 7.0);
    final double storm = 0.3 + 0.62 * ease(t, first + beat * 4, beat * 3 + 0.2);
    final double rain = 0.35 + 0.65 * ease(t, first + beat * 2, beat * 5);
    return Stack(fit: StackFit.expand, children: <Widget>[
      valleyShot(
        look,
        context,
        h: lerpD(0.45, 0.62, storm),
        storm: storm,
        rain: rain,
        riverRise: 10 * storm,
        camera: const <CameraKeyframe>[CameraKeyframe(0, center: Offset(960, 640), zoom: 1.25)],
      ),
      rainOver(look, rain, slant: 12),
      Positioned(left: 430, top: 330, width: 1060, height: 620, child: CustomPaint(painter: _StonePainter(look, days, boilOf(frame)))),
    ]);
  }
}

class _StonePainter extends CustomPainter {
  const _StonePainter(this.look, this.days, this.boil);

  final Look look;
  final double days;
  final int boil;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    final Path rock = Paths.smooth(<Offset>[
      Offset(0, h), Offset(w * 0.01, h * 0.55), Offset(w * 0.1, h * 0.18), Offset(w * 0.38, h * 0.02), Offset(w * 0.7, h * 0.05),
      Offset(w * 0.95, h * 0.36), Offset(w, h * 0.8), Offset(w * 0.98, h),
    ]);
    if (look.doodle) {
      look.fill(canvas, rock, const Color(0xFFC9C5BE), boil: boil, wobble: 4, line: 9);
    } else {
      canvas.drawPath(rock, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFF8A96A8), Color(0xFF454F64)]).createShader(Offset.zero & size));
      canvas.save();
      canvas.clipPath(rock);
      canvas.drawPath(Paths.polygon(<Offset>[Offset(w * 0.7, 0), Offset(w * 1.1, h * 0.3), Offset(w * 1.1, h), Offset(w * 0.62, h), Offset(w * 0.74, h * 0.5)]), Paint()..color = const Color(0x55141C34));
      canvas.drawPath(Paths.polygon(<Offset>[Offset(w * 0.1, h * 0.3), Offset(w * 0.4, 0), Offset(w * 0.75, 0), Offset(w * 0.5, h * 0.2)]), Paint()..color = const Color(0x33DCE8FF));
      canvas.restore();
    }
    final Paint scratch = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = look.doodle ? 20 : 17
      ..color = look.doodle ? look.ink : const Color(0xFFF4ECD6);
    // Four strokes and the fifth across them; the sixth and seventh start a
    // second bundle.
    for (int i = 0; i < 7; i++) {
      final double u = (days - i).clamp(0.0, 1.0);
      if (u <= 0) continue;
      final int group = i ~/ 5, k = i % 5;
      final double x0 = w * 0.17 + group * w * 0.58;
      if (k < 4) {
        final double x = x0 + k * 62;
        canvas.drawLine(Offset(x, h * 0.3), Offset(x + 8, h * 0.3 + h * 0.46 * u), scratch);
      } else {
        canvas.drawLine(Offset(x0 - 20, h * 0.68), Offset(x0 - 20 + 270 * u, h * 0.36), scratch);
      }
    }
  }

  @override
  bool shouldRepaint(_StonePainter old) => old.days != days || old.boil != boil || old.look != look;
}

// --- shot 3: the camp, and two things it hasn't got ---

class CampShot extends StatelessWidget {
  const CampShot(this.look, {super.key});

  final Look look;

  static Part _hut(double x, double s, Color hide) => Part(at: Offset(x, 936), scaleX: s, scaleY: s, shapes: <Shape>[
        Shape(Paths.polygon(const <Offset>[Offset(-96, 0), Offset(-44, -84), Offset(0, -128), Offset(48, -86), Offset(98, 0)]), color: hide),
        Shape(Paths.polygon(const <Offset>[Offset(-22, 0), Offset(-12, -52), Offset(14, -52), Offset(24, 0)]), color: const Color(0xFF2E1E14)),
        Shape(Paths.polygon(const <Offset>[Offset(-6, -126), Offset(0, -156), Offset(8, -126)]), color: const Color(0xFF3A2A22)),
      ]);

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps;
    final double storm = 0.9;
    // The phone, then the hammer: each in on its "No", struck through.
    final double phoneIn = ease(t, said(3, Say.app, 0) - _lands, 0.3, Curves.easeOutBack);
    final double phoneStrike = ease(t, said(3, Say.app, 0) + 0.05, 0.22, Curves.easeOut);
    final double hammerIn = ease(t, said(3, Say.store, 0) - _lands, 0.3, Curves.easeOutBack);
    final double hammerStrike = ease(t, said(3, Say.store, 0) + 0.05, 0.22, Curves.easeOut);
    final double phoneOut = 1 - ease(t, said(3, Say.store, 0) - _lands - 0.05, 0.22, Curves.easeIn);
    final List<Color> hides = <Color>[const Color(0xFF8A5A36), const Color(0xFF7C5B3E), const Color(0xFF9A6840), const Color(0xFF7E5636), const Color(0xFF8A5E3A)];
    return Stack(fit: StackFit.expand, children: <Widget>[
      valleyShot(
        look,
        context,
        h: 0.62,
        storm: storm,
        rain: 1,
        riverRise: 12,
        cloudSpeed: 0,
        camera: const <CameraKeyframe>[CameraKeyframe(0, center: Offset(960, 580), zoom: 1.0)],
        foreground: Stack(fit: StackFit.expand, children: <Widget>[
          splashes(look, count: 120),
          Drawing(groundShadow(960, 560, y: 940)),
          for (int i = 0; i < 5; i++) Drawing(_hut(640 + i * 160.0 + (i % 2) * 24, 0.42 + (i % 3) * 0.05, hides[i]), ink: look.pen),
          // A fire in the middle, and its smoke going straight up in the
          // still air.
          CustomPaint(painter: _CampFire(look, t, boilOf(frame))),
        ]),
      ),
      rainOver(look, 1, slant: 4),
      Positioned(left: 960 - 210, top: 110, width: 420, height: 420, child: Opacity(opacity: (phoneIn.clamp(0.0, 1.0)) * phoneOut.clamp(0.0, 1.0), child: Transform.scale(scale: 0.4 + 0.6 * phoneIn.clamp(0.0, 1.2) * (0.6 + 0.4 * phoneOut), child: CustomPaint(painter: _IconPainter(look, 'phone', phoneStrike))))),
      Positioned(left: 960 - 210, top: 110, width: 420, height: 420, child: Opacity(opacity: hammerIn.clamp(0.0, 1.0), child: Transform.scale(scale: 0.4 + 0.6 * hammerIn.clamp(0.0, 1.2), child: CustomPaint(painter: _IconPainter(look, 'hammer', hammerStrike))))),
    ]);
  }
}

class _CampFire extends CustomPainter {
  const _CampFire(this.look, this.t, this.boil);

  final Look look;
  final double t;
  final int boil;

  @override
  void paint(Canvas canvas, Size size) {
    const Offset base = Offset(960, 940);
    // Smoke: a column of soft blobs rising, widening and fading.
    for (int i = 0; i < 9; i++) {
      final double u = ((t * 0.28 + i / 9) % 1.0);
      final Offset at = base + Offset(math.sin(u * 5 + i) * 10 * u, -26 - u * 240);
      final Color smoke = look.doodle ? const Color(0xFFE9E4DC) : const Color(0xFF9AA6B8);
      canvas.drawCircle(at, 8 + u * 30, Paint()..color = smoke.withValues(alpha: (1 - u) * (look.doodle ? 0.9 : 0.45)));
      if (look.doodle) canvas.drawCircle(at, 8 + u * 30, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = look.ink.withValues(alpha: 1 - u));
    }
    paintFlame(canvas, look, base, 0.42, t, boil);
  }

  @override
  bool shouldRepaint(_CampFire old) => old.t != t || old.boil != boil;
}

/// A flame with its base at [base], [size] times about 180 tall.
void paintFlame(Canvas canvas, Look look, Offset base, double size, double t, int boil) {
  double sway(double k) => math.sin(t * 7.3 + k) * 6 + math.sin(t * 12.1 + k * 2) * 3;
  Path tongue(double w, double hgt, double k) => Paths.smooth(<Offset>[
        base + Offset(-w, 0) * size,
        base + Offset(-w * 1.05, -hgt * 0.35) * size,
        base + Offset(-w * 0.45 + sway(k) * 0.5, -hgt * 0.72) * size,
        base + Offset(sway(k) * 1.2, -hgt) * size,
        base + Offset(w * 0.5 + sway(k) * 0.5, -hgt * 0.68) * size,
        base + Offset(w * 1.05, -hgt * 0.32) * size,
        base + Offset(w, 0) * size,
        base + Offset(0, w * 0.35) * size,
      ]);
  if (!look.doodle) {
    final double flick = Fire.flicker(t);
    canvas.drawCircle(
      base + Offset(0, -70 * size),
      260 * size * flick,
      Paint()..shader = RadialGradient(colors: <Color>[const Color(0xAAFFB060), const Color(0x00FFB060)]).createShader(Rect.fromCircle(center: base + Offset(0, -70 * size), radius: 260 * size * flick)),
    );
  }
  look.fill(canvas, tongue(54, 180, 0), const Color(0xFFF2762E), line: 6, boil: boil, wobble: 2, soften: 0.05);
  look.fill(canvas, tongue(34, 124, 1.7), const Color(0xFFFFB63D), line: 4, boil: boil + 1, wobble: 1.5, outline: look.doodle, soften: 0.05);
  look.fill(canvas, tongue(16, 66, 3.1), const Color(0xFFFFE9A0), line: 3, boil: boil + 2, wobble: 1, outline: false, soften: 0.02);
  // Logs under it.
  for (final double side in <double>[-1, 1]) {
    final Path log = Paths.capsule(base + Offset(side * 70 * size, 8 * size), base + Offset(-side * 30 * size, -2 * size), 15 * size);
    look.fill(canvas, log, const Color(0xFF6A4528), line: 5, boil: boil + 3, wobble: 1.5, soften: 0.12);
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.look, this.kind, this.strike);

  final Look look;
  final String kind;
  final double strike;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    // The badge.
    if (look.doodle) {
      canvas.drawCircle(c, r, Paint()..color = look.paper);
      canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 9..color = look.ink);
    } else {
      canvas.drawCircle(c + const Offset(0, 8), r, Paint()..color = const Color(0x55060A1A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      canvas.drawCircle(c, r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF2E4270), Color(0xFF1A2548)]).createShader(Rect.fromCircle(center: c, radius: r)));
    }
    final Color line = look.doodle ? look.ink : const Color(0xFFFFF6E8);
    final Paint stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = look.doodle ? 9 : 8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = line;
    if (kind == 'phone') {
      final RRect body = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: r * 0.82, height: r * 1.34), const Radius.circular(26));
      canvas.drawRRect(body, Paint()..color = look.doodle ? const Color(0xFFBFE1EA) : const Color(0xFF3B5486));
      canvas.drawRRect(body, stroke);
      // A rain cloud on the screen.
      final Offset cc = c + const Offset(0, -10);
      final Path cloud = Path()
        ..addOval(Rect.fromCircle(center: cc + const Offset(-22, 6), radius: 22))
        ..addOval(Rect.fromCircle(center: cc + const Offset(6, -6), radius: 30))
        ..addOval(Rect.fromCircle(center: cc + const Offset(34, 8), radius: 20))
        ..addRect(Rect.fromLTRB(cc.dx - 40, cc.dy + 6, cc.dx + 52, cc.dy + 28));
      canvas.drawPath(cloud, Paint()..color = look.doodle ? const Color(0xFFFFFFFF) : const Color(0xFFD8E4F8));
      for (int i = 0; i < 3; i++) {
        canvas.drawLine(cc + Offset(-22.0 + i * 26, 44), cc + Offset(-30.0 + i * 26, 64), Paint()..color = look.doodle ? const Color(0xFF3E6C96) : const Color(0xFF8FB4FF)..strokeWidth = 6..strokeCap = StrokeCap.round);
      }
      canvas.drawCircle(c + Offset(0, r * 0.56), 8, Paint()..color = line);
    } else {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.6);
      final RRect handle = RRect.fromRectAndRadius(const Rect.fromLTRB(-14, -40, 14, 150), const Radius.circular(10));
      canvas.drawRRect(handle, Paint()..color = const Color(0xFFB98350));
      canvas.drawRRect(handle, stroke);
      final RRect head = RRect.fromRectAndRadius(const Rect.fromLTRB(-76, -88, 76, -34), const Radius.circular(12));
      canvas.drawRRect(head, Paint()..color = look.doodle ? const Color(0xFFB8C2CC) : const Color(0xFF9AA6BA));
      canvas.drawRRect(head, stroke);
      canvas.restore();
    }
    // The strike: a red bar across the badge, drawn from corner to corner.
    if (strike > 0) {
      final Offset a = c + Offset(-r * 0.78, -r * 0.78), b = c + Offset(r * 0.78, r * 0.78);
      final Offset e = Offset.lerp(a, b, strike)!;
      if (look.doodle) canvas.drawLine(a, e, Paint()..strokeWidth = 30..strokeCap = StrokeCap.round..color = look.ink);
      canvas.drawLine(a, e, Paint()..strokeWidth = look.doodle ? 18 : 20..strokeCap = StrokeCap.round..color = const Color(0xFFE5533D));
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.strike != strike || old.kind != kind || old.look != look;
}

// --- shot 4: the twenty ---

class BandShot extends StatelessWidget {
  const BandShot(this.look, {super.key});

  final Look look;

  static final List<Character> _all = <Character>[tor, ama, eda, kito, bran, ...bandCrowd()];

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps;
    final Light light = skyLight(0.62, 0.9);
    // One more figure every tenth of a second or so, from "twenty" to "people".
    final double from = said(4, Say.people, 1) - _lands, over = 1.3;
    final double counted = 20 * ease(t, from, over, Curves.easeOut);
    final List<Widget> people = <Widget>[];
    // Three rows, back to front, so the near ones cover the far.
    for (int row = 0; row < 3; row++) {
      for (int i = 0; i < 20; i++) {
        if (i % 3 != row) continue;
        final double pop = ((counted - i) * 1.4).clamp(0.0, 1.0);
        if (pop <= 0) continue;
        final double u = Curves.easeOutBack.transform(pop);
        final double x = 380 + (i * 131 % 1160) + row * 30 + (i % 2) * 22, ground = 800 + row * 85;
        final double s = (0.85 + row * 0.1) * u;
        people.add(person(look, _all[i], x, ground, s, hunch(_all[i], i + 4, frame, 1), frame, light, wetness: 1));
      }
    }
    return Stack(fit: StackFit.expand, children: <Widget>[
      valleyShot(
        look,
        context,
        h: 0.64,
        storm: 0.92,
        rain: 1,
        riverRise: 14,
        cloudSpeed: 0.3,
        camera: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(960, 640), zoom: 1.05),
          CameraKeyframe(openLengths[4], center: const Offset(980, 670), zoom: 1.16, curve: Curves.easeInOutSine),
        ],
        foreground: Stack(fit: StackFit.expand, children: <Widget>[splashes(look, count: 100, top: 880, bottom: 1080), ...people]),
      ),
      rainOver(look, 1, slant: 12),
      Positioned(
        left: 0,
        right: 0,
        top: 90,
        child: Center(
          child: Opacity(
            opacity: ease(t, from, 0.3),
            child: Text('${counted.floor().clamp(0, 20)}', style: look.type(150, color: look.doodle ? look.ink : const Color(0xFFFFF6E8))),
          ),
        ),
      ),
    ]);
  }
}

// --- shot 5: what do you do? ---

/// A slow push on faces looking up, and nothing else.
class FacesShot extends StatelessWidget {
  const FacesShot(this.look, {super.key});

  final Look look;

  static const List<(Character, double, double)> _faces = <(Character, double, double)>[
    (eda, 330, 2.3),
    (ama, 800, 2.7),
    (tor, 1290, 2.9),
    (kito, 1700, 2.3),
  ];

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final Light light = skyLight(0.66, 0.95);
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < _faces.length; i++) {
      final (Character c, double x, double s) = _faces[i];
      final Performance act = Performance(fps: openFps, startX: x, beats: <Beat>[
        const Feel(Emotion.worried, at: 0.0, amount: 0.8),
        st.Look(Offset(0.15 + i * 0.1, -0.95), at: 0.2 + i * 0.2),
      ]);
      final Pose pose = hunch(c, i + 21, frame, 0.5).plus(Pose(<String, Joint>{'head': Joint.rotate(-17), 'chest': Joint.rotate(-3)})).plus(act.face(c.face, frame));
      out.add(person(look, c, x, 1500, s, pose, frame, light, wetness: 1, shadow: 0));
    }
    return Stack(fit: StackFit.expand, children: <Widget>[
      valleyShot(
        look,
        context,
        h: 0.66,
        storm: 0.95,
        rain: 1,
        cloudSpeed: 0.2,
        camera: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(960, 400), zoom: 1.0),
          CameraKeyframe(openLengths[5], center: const Offset(960, 420), zoom: 1.12, curve: Curves.easeInOutSine),
        ],
        foreground: Stack(fit: StackFit.expand, children: out),
      ),
      rainOver(look, 1, slant: 10),
      // Rain heavier at the front.
      rainOver(look, 0.5, slant: 14, seed: 4),
    ]);
  }
}

// --- shot 6: three jobs ---

class JobsShot extends StatelessWidget {
  const JobsShot(this.look, {super.key});

  final Look look;

  static const List<double> _ringX = <double>[400, 960, 1520];
  static const double _ringY = 520, _ringR = 205;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps;
    final int boil = boilOf(frame);
    final double warm = ease(t, lineAt(6, Say.warm) - _lands, 0.35, Curves.easeOutBack);
    final double fed = ease(t, lineAt(6, Say.fed) - _lands, 0.7, Curves.easeOut);
    final double together = lineAt(6, Say.together) - _lands;
    final Light light = skyLight(0.55, 0.3);
    // The rings draw in a beat apart, finishing before "three".
    final double threeAt = said(6, Say.jobs, 9);
    final List<double> ring = <double>[for (int i = 0; i < 3; i++) ease(t, threeAt - 1.3 + i * 0.28, 0.7)];

    final List<Widget> gathering = <Widget>[];
    const List<(Character, double, double, double)> folk = <(Character, double, double, double)>[
      (tor, -86, 0.0, 0.46), (ama, 40, 0.18, 0.44), (eda, -20, 0.36, 0.38), (kito, 96, 0.54, 0.36),
    ];
    for (int i = 0; i < folk.length; i++) {
      final (Character c, double dx, double delay, double s) = folk[i];
      final double u = Curves.easeOutBack.transform(ease(t, together + delay, 0.4, Curves.linear));
      if (u <= 0) continue;
      final Pose pose = c.stance.plus(c.life(i + 40).at(frame, openFps));
      gathering.add(person(look, c, _ringX[2] + dx, 690 + (i % 2) * 18, s * u, pose, frame, light, shadow: 70));
    }

    final TextStyle label = look.type(58, spacing: 2);
    return Stack(fit: StackFit.expand, children: <Widget>[
      look.doodle
          ? ColoredBox(color: look.paper)
          : const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF1C2646), Color(0xFF2F3C68)]))),
      Positioned.fill(child: CustomPaint(painter: _RingsPainter(look, ring, warm, boil, t))),
      // Flame in the first ring.
      Positioned.fill(child: CustomPaint(painter: _WarmPainter(look, warm, t, boil))),
      // Dried meat on a rack in the second.
      Positioned.fill(child: CustomPaint(painter: _MeatPainter(look, fed, boil))),
      // People gather in the third.
      ...gathering,
      Positioned(
        left: 0,
        right: 0,
        top: 96,
        child: Center(child: caption(look, 'THREE JOBS', size: 76, spacing: 6, opacity: ease(t, threeAt - 0.3, 0.4), color: look.doodle ? look.ink : const Color(0xFFFFC857))),
      ),
      for (final (int i, String text) in <(int, String)>[(0, 'STAY WARM'), (1, 'STAY FED'), (2, 'STAY TOGETHER')])
        Positioned(
          left: _ringX[i] - 300,
          width: 600,
          top: _ringY + _ringR + 60,
          child: Center(
            child: Opacity(
              opacity: ease(t, <double>[lineAt(6, Say.warm), lineAt(6, Say.fed), lineAt(6, Say.together)][i] - _lands, 0.35),
              child: Text(text, style: label),
            ),
          ),
        ),
    ]);
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter(this.look, this.draw, this.warm, this.boil, this.t);

  final Look look;
  final List<double> draw;
  final double warm, t;
  final int boil;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      if (draw[i] <= 0) continue;
      final Offset c = Offset(JobsShot._ringX[i], JobsShot._ringY);
      final Rect box = Rect.fromCircle(center: c, radius: JobsShot._ringR);
      // The floor of the ring, a little lit.
      canvas.drawOval(box, Paint()..color = (look.doodle ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF)).withValues(alpha: (look.doodle ? 0.5 : 0.07) * draw[i]));
      final Path arc = Path()..addArc(box, -math.pi / 2, math.pi * 2 * draw[i]);
      canvas.drawPath(
        look.doodle ? Look.wobbled(arc, 2.5, boil + i) : arc,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = look.doodle ? 10 : 8
          ..strokeCap = StrokeCap.round
          ..color = look.doodle ? look.ink : const Color(0xFFFFF6E8).withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => true;
}

class _WarmPainter extends CustomPainter {
  const _WarmPainter(this.look, this.lit, this.t, this.boil);

  final Look look;
  final double lit, t;
  final int boil;

  @override
  void paint(Canvas canvas, Size size) {
    if (lit <= 0) return;
    final double u = lit.clamp(0.0, 1.2);
    paintFlame(canvas, look, Offset(JobsShot._ringX[0], 650), 1.25 * u, t, boil);
  }

  @override
  bool shouldRepaint(_WarmPainter old) => true;
}

/// A rod across the ring and strips of dried meat hanging from it.
class _MeatPainter extends CustomPainter {
  const _MeatPainter(this.look, this.hang, this.boil);

  final Look look;
  final double hang;
  final int boil;

  @override
  void paint(Canvas canvas, Size size) {
    if (hang <= 0) return;
    final double cx = JobsShot._ringX[1];
    final Offset a = Offset(cx - 150, 400), b = Offset(cx + 150, 400);
    // Two forks and the rod across.
    for (final Offset p in <Offset>[a, b]) {
      look.fill(canvas, Paths.capsule(p + const Offset(0, 6), p + const Offset(0, 170), 9), const Color(0xFF6A4528), line: 5, boil: boil, wobble: 1.2);
    }
    look.fill(canvas, Paths.capsule(a + const Offset(-16, 0), b + const Offset(16, 0), 9), const Color(0xFF80573A), line: 5, boil: boil + 1, wobble: 1.2);
    // Strips: each drops from the rod, longest in the middle.
    const List<double> lengths = <double>[170, 215, 245, 205, 160];
    for (int i = 0; i < 5; i++) {
      final double x = a.dx + 22 + i * 64.0, hgt = lengths[i] * hang;
      if (hgt < 4) continue;
      final Path strip = Paths.smooth(<Offset>[
        Offset(x - 17, 410), Offset(x - 21, 410 + hgt * 0.4), Offset(x - 12, 410 + hgt * 0.8), Offset(x, 410 + hgt), Offset(x + 13, 410 + hgt * 0.78), Offset(x + 21, 410 + hgt * 0.4), Offset(x + 17, 410),
      ]);
      look.fill(canvas, strip, const Color(0xFF9B3B2E), line: 5, boil: boil + 2 + i, wobble: 1.5, soften: 0.18);
      // A streak of fat down it.
      canvas.drawLine(Offset(x - 4, 420), Offset(x - 2, 410 + hgt * 0.8), Paint()..strokeWidth = 5..strokeCap = StrokeCap.round..color = const Color(0xCCF2D6C0));
    }
  }

  @override
  bool shouldRepaint(_MeatPainter old) => true;
}

// --- shot 7: the title ---

class TitleShot extends StatelessWidget {
  const TitleShot(this.look, {super.key});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final double t = _t(context);
    const List<String> words = <String>['WHAT DID', 'ANCIENT HUMANS', 'DO WHEN IT RAINED', 'ALL WEEK?'];
    final double progress = ease(t, 0.15, 1.4, Curves.linear);
    return Stack(fit: StackFit.expand, children: <Widget>[
      look.doodle
          ? ColoredBox(color: look.paper)
          : const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF141C38), Color(0xFF25305A)]))),
      rainOver(look, 0.9, slant: 10),
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          for (int i = 0; i < words.length; i++)
            Builder(builder: (BuildContext _) {
              final double u = ((progress * 4 - i * 0.6) / 1.2).clamp(0.0, 1.0);
              final bool last = i == 3;
              final Color accent = look.doodle ? const Color(0xFFD9482F) : const Color(0xFFFFC857);
              return Opacity(
                opacity: u,
                child: Transform.translate(
                  offset: Offset(0, (1 - u) * 34),
                  child: Text(
                    words[i],
                    style: look.type(last ? 150 : 118, color: last ? accent : (look.doodle ? look.ink : const Color(0xFFFFF6E8)), spacing: look.doodle ? 3 : -1, weight: FontWeight.w900),
                  ),
                ),
              );
            }),
        ]),
      ),
    ]);
  }
}
