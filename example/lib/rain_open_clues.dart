import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart' hide Look, Say;

import 'map_view.dart';
import 'rain_look.dart';
import 'rain_open_set.dart';
import 'rain_open_shots.dart' show paintFlame;
import 'rain_open_timing.dart';
import 'rain_timing.dart' show lerpD;

/// The opening's clue shots: the valley at dusk and the hand that brushes the
/// mud away, then one object a beat -- ash, tools, bones, a painting -- and
/// the map that ends on people alive today.
const double _lands = 0.3;

double _len(int shot) => openLengths[shot] / openFps;

/// The ground, close up: earth in [look], with the odd pebble.
class _Dirt extends CustomPainter {
  const _Dirt(this.look);

  final Look look;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    if (look.doodle) {
      canvas.drawRect(all, Paint()..color = const Color(0xFFD6B687));
    } else {
      canvas.drawRect(all, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF54402F), Color(0xFF3A2C22)]).createShader(all));
    }
    final math.Random r = math.Random(8);
    for (int i = 0; i < 70; i++) {
      final Offset at = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final double s = 4 + r.nextDouble() * 12;
      if (look.doodle) {
        canvas.drawCircle(at, s * 0.32, Paint()..color = look.ink.withValues(alpha: 0.7));
        if (i % 4 == 0) canvas.drawArc(Rect.fromCenter(center: at + const Offset(40, 14), width: 36, height: 10), math.pi, math.pi, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = look.ink.withValues(alpha: 0.6));
      } else {
        canvas.drawOval(Rect.fromCenter(center: at, width: s * 2, height: s * 1.2), Paint()..color = (i.isEven ? const Color(0xFF6A5340) : const Color(0xFF2C2119)).withValues(alpha: 0.55));
      }
    }
  }

  @override
  bool shouldRepaint(_Dirt old) => old.look != look;
}

Widget _ground(Look look) => CustomPaint(size: Size.infinite, painter: _Dirt(look));

// --- dusk, and the hand ---

class DuskShot extends StatelessWidget {
  const DuskShot(this.look, {super.key});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps;
    // The valley with nobody in it and no writing anywhere.
    final double hand = lineAt(8, Say.clues) - 0.55;
    final double to = ease(t, hand - 0.25, 0.3, Curves.easeInOut);
    final double sweep = ease(t, hand + 0.1, 1.15, Curves.easeInOutSine);
    return Stack(fit: StackFit.expand, children: <Widget>[
      valleyShot(
        look,
        context,
        h: 0.78,
        storm: 0.85,
        rain: 1,
        riverRise: 30,
        cloudSpeed: 0.6,
        camera: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(960, 580), zoom: 1.0),
          CameraKeyframe(openLengths[8], center: const Offset(900, 700), zoom: 1.12, curve: Curves.easeInOutSine),
        ],
        foreground: splashes(look, count: 100),
      ),
      rainOver(look, 1, slant: 12),
      Opacity(
        opacity: to,
        child: Stack(fit: StackFit.expand, children: <Widget>[
          _ground(look),
          CustomPaint(painter: _BrushPainter(look, sweep, boilOf(frame))),
        ]),
      ),
    ]);
  }
}

/// A smear of mud and a hand wiping it off the ground to show what is under
/// it: the edge of a black ring of ash.
class _BrushPainter extends CustomPainter {
  const _BrushPainter(this.look, this.sweep, this.boil);

  final Look look;
  final double sweep;
  final int boil;

  @override
  void paint(Canvas canvas, Size size) {
    // Under the mud: a ring of ash.
    final Path ash = Path()..addOval(Rect.fromCenter(center: const Offset(960, 620), width: 880, height: 340));
    look.fill(canvas, ash, look.doodle ? const Color(0xFF6C6660) : const Color(0xFF1E1B19), line: 6, boil: boil, wobble: 4, soften: 0.08);
    // The hand's x: from the right edge, across to the left. The mud is what
    // it has not reached yet, to its left, with a heaped, wavy edge where it
    // pushes.
    final double hx = lerpD(1900, 60, sweep);
    final Path mud = Path()..moveTo(-10, -10)..lineTo(hx + 30, -10);
    for (double y = -10; y <= size.height + 10; y += 40) {
      mud.lineTo(hx + 30 + math.sin(y * 0.021 + 1) * 16 + math.sin(y * 0.057) * 9, y);
    }
    mud..lineTo(-10, size.height + 10)..close();
    look.fill(canvas, mud, look.doodle ? const Color(0xFFB08A5C) : const Color(0xFF4A3828), line: 7, boil: boil + 1, wobble: 3, soften: 0.1);
    _hand(canvas, look, Offset(hx + 20, 600), boil);
  }

  @override
  bool shouldRepaint(_BrushPainter old) => old.sweep != sweep || old.boil != boil;
}

/// A hand, flat, fingers pointing left, with its palm at [at].
void _hand(Canvas canvas, Look look, Offset at, int boil) {
  const Color skin = Color(0xFF8A5A3C);
  final Path fingers = Path();
  for (int i = 0; i < 4; i++) {
    final double y = -54 + i * 36.0, len = 150 - (i == 0 || i == 3 ? 20 : 0) + (i == 1 ? 8 : 0);
    fingers.addPath(Paths.capsule(Offset(-30, y), Offset(-30 - len, y + (i - 1.5) * 6), 17), Offset.zero);
  }
  Path hand = Path.combine(PathOperation.union, fingers, Paths.ellipse(const Offset(40, 0), 100, 90));
  hand = Path.combine(PathOperation.union, hand, Paths.capsule(const Offset(10, 70), const Offset(-70, 118), 20));
  hand = Path.combine(PathOperation.union, hand, Paths.capsule(const Offset(120, 20), const Offset(480, 60), 62));
  look.fill(canvas, hand.shift(at), skin, line: 7, boil: boil + 2, wobble: 2, soften: 0.18);
}

// --- ash ---

class AshShot extends StatelessWidget {
  const AshShot(this.look, {super.key});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps;
    final double u = ease(t, 0.0, 0.45, Curves.easeOutBack);
    return _Pushed(
      length: _len(9),
      child: Stack(fit: StackFit.expand, children: <Widget>[
        _ground(look),
        CustomPaint(painter: _HearthPainter(look, u, t, boilOf(frame))),
      ]),
    );
  }
}

/// A slow push-in on a close-up shot.
class _Pushed extends StatelessWidget {
  const _Pushed({required this.child, required this.length});

  final Widget child;
  final double length;

  @override
  Widget build(BuildContext context) {
    final double t = Video.frame(context) / openFps;
    return Transform.scale(scale: 1 + 0.05 * (t / length).clamp(0.0, 1.0), child: child);
  }
}

class _HearthPainter extends CustomPainter {
  const _HearthPainter(this.look, this.u, this.t, this.boil);

  final Look look;
  final double u, t;
  final int boil;

  @override
  void paint(Canvas canvas, Size size) {
    if (u <= 0) return;
    canvas.save();
    canvas.translate(960, 540);
    canvas.scale(1.45 * u.clamp(0.0, 1.2));
    // The black of old fire, spread out, with a ring of stones round it.
    final Path ash = Paths.smooth(const <Offset>[
      Offset(-330, 10), Offset(-270, -110), Offset(-120, -150), Offset(60, -160), Offset(250, -120), Offset(340, 0), Offset(260, 120), Offset(80, 160), Offset(-150, 150), Offset(-290, 100),
    ]);
    look.fill(canvas, ash, look.doodle ? const Color(0xFF58524D) : const Color(0xFF1A1816), line: 7, boil: boil, wobble: 4, soften: 0.06);
    final math.Random r = math.Random(3);
    for (int i = 0; i < 26; i++) {
      final double a = r.nextDouble() * math.pi * 2, d = math.sqrt(r.nextDouble());
      canvas.drawCircle(Offset(math.cos(a) * 280 * d, math.sin(a) * 120 * d), 3 + r.nextDouble() * 5, Paint()..color = look.doodle ? look.paper.withValues(alpha: 0.8) : const Color(0xFF5C5650).withValues(alpha: 0.8));
    }
    // A charred stick or two.
    for (final (Offset a, Offset b) in const <(Offset, Offset)>[(Offset(-120, -20), Offset(80, 40)), (Offset(-40, 60), Offset(160, -30))]) {
      look.fill(canvas, Paths.capsule(a, b, 12), look.doodle ? const Color(0xFF3A3532) : const Color(0xFF0F0D0C), line: 5, boil: boil + 1, wobble: 1.2, soften: 0.08);
    }
    const int stones = 11;
    for (int i = 0; i < stones; i++) {
      final double a = i / stones * math.pi * 2 + 0.2;
      final Offset c = Offset(math.cos(a) * 395, math.sin(a) * 195);
      final double s = 40 + (i * 7 % 5) * 7;
      final Path stone = Paths.ellipse(c, s, s * 0.72);
      look.fill(canvas, stone, i.isEven ? const Color(0xFF8A8680) : const Color(0xFF6E6A66), line: 6, boil: boil + 2 + i, wobble: 2, soften: 0.2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HearthPainter old) => old.u != u || old.boil != boil;
}

// --- tools ---

class ToolsShot extends StatelessWidget {
  const ToolsShot(this.look, {super.key});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps;
    return _Pushed(
      length: _len(10),
      child: Stack(fit: StackFit.expand, children: <Widget>[
        _ground(look),
        CustomPaint(painter: _BladesPainter(look, t, boilOf(frame))),
      ]),
    );
  }
}

class _BladesPainter extends CustomPainter {
  const _BladesPainter(this.look, this.t, this.boil);

  final Look look;
  final double t;
  final int boil;

  /// A leaf-shaped blade [len] long and [wide] across, pointing right.
  static Path blade(double len, double wide) => Path()
    ..moveTo(-len / 2, 0)
    ..quadraticBezierTo(-len * 0.05, -wide, len / 2, 0)
    ..quadraticBezierTo(-len * 0.05, wide, -len / 2, 0)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    const List<(Offset, double, double, double)> laid = <(Offset, double, double, double)>[
      (Offset(560, 640), -0.34, 380, 70),
      (Offset(860, 520), -0.12, 440, 80),
      (Offset(1170, 540), 0.16, 400, 74),
      (Offset(1420, 670), 0.4, 340, 64),
    ];
    canvas.save();
    canvas.translate(960, 540);
    canvas.scale(1.3);
    canvas.translate(-960, -540);
    for (int i = 0; i < laid.length; i++) {
      final (Offset at, double turn, double len, double wide) = laid[i];
      final double u = ease(t, i * 0.1, 0.3, Curves.easeOutBack);
      if (u <= 0) continue;
      canvas.save();
      canvas.translate(at.dx, at.dy + (1 - u.clamp(0.0, 1.0)) * -140);
      canvas.rotate(turn);
      canvas.scale(u.clamp(0.0, 1.2));
      // A shadow on the ground, then the stone.
      canvas.drawPath(blade(len, wide).shift(const Offset(8, 16)), Paint()..color = look.doodle ? const Color(0x33000000) : const Color(0x66120C08));
      look.fill(canvas, blade(len, wide), look.doodle ? const Color(0xFFB9BCC8) : const Color(0xFF7C7873), line: 7, boil: boil + i, wobble: 1.5, soften: 0.25);
      // The ridge down it, and the flake scars either side.
      final Paint ridge = Paint()..style = PaintingStyle.stroke..strokeWidth = look.doodle ? 4 : 3..strokeCap = StrokeCap.round..color = look.doodle ? look.ink : const Color(0xFFC6C0B6);
      canvas.drawLine(Offset(-len * 0.32, 0), Offset(len * 0.34, 0), ridge);
      for (int k = -1; k <= 1; k += 2) {
        canvas.drawLine(Offset(-len * 0.1, k * wide * 0.28), Offset(len * 0.16, k * wide * 0.2), ridge);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BladesPainter old) => old.t != t || old.boil != boil;
}

// --- bones ---

class BonesShot extends StatelessWidget {
  const BonesShot(this.look, {super.key});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps;
    return _Pushed(
      length: _len(11),
      child: Stack(fit: StackFit.expand, children: <Widget>[
        _ground(look),
        CustomPaint(painter: _BonesPainter(look, t, boilOf(frame))),
      ]),
    );
  }
}

class _BonesPainter extends CustomPainter {
  const _BonesPainter(this.look, this.t, this.boil);

  final Look look;
  final double t;
  final int boil;

  /// A curved tusk from [a0] to [a1] about [c], thick at the root and fine at the tip.
  static Path tusk(Offset c, double radius, double a0, double a1, double thick) {
    const int n = 24;
    final List<Offset> top = <Offset>[], bottom = <Offset>[];
    for (int i = 0; i <= n; i++) {
      final double u = i / n, a = a0 + (a1 - a0) * u, w = thick * (1 - u * 0.92) / 2;
      final Offset dir = Offset(math.cos(a), math.sin(a));
      top.add(c + dir * (radius + w));
      bottom.add(c + dir * (radius - w));
    }
    return Paths.polygon(<Offset>[...top, ...bottom.reversed]);
  }

  static Path longBone(Offset a, Offset b, double r) {
    Path p = Paths.capsule(a, b, r);
    final Offset d = (b - a) / (b - a).distance, n = Offset(-d.dy, d.dx);
    for (final Offset end in <Offset>[a, b]) {
      final Offset out = end == a ? -d : d;
      for (final double side in <double>[-1, 1]) {
        p = Path.combine(PathOperation.union, p, Paths.circle(end + out * r * 0.7 + n * side * r * 0.72, r * 0.95));
      }
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Color bone = look.doodle ? const Color(0xFFFFF7E6) : const Color(0xFFE6D9BC);
    final Color shade = look.doodle ? const Color(0xFFEADBB8) : const Color(0xFFB8A888);
    void piece(int i, Path path, {Color? color}) {
      final double u = ease(t, i * 0.09, 0.3, Curves.easeOutBack);
      if (u <= 0) return;
      canvas.save();
      final Offset mid = path.getBounds().center;
      canvas.translate(mid.dx, mid.dy);
      canvas.scale(u.clamp(0.0, 1.15));
      canvas.translate(-mid.dx, -mid.dy);
      canvas.drawPath(path.shift(const Offset(10, 16)), Paint()..color = look.doodle ? const Color(0x33000000) : const Color(0x66120C08));
      look.fill(canvas, path, color ?? bone, line: 7, boil: boil + i, wobble: 1.8, soften: 0.15);
      canvas.restore();
    }

    // A great curved tusk, a long bone, three ribs and a vertebra.
    piece(0, tusk(const Offset(960, 1040), 600, -math.pi * 0.98, -math.pi * 0.18, 96));
    piece(1, longBone(const Offset(230, 600), const Offset(700, 700), 30));
    for (int i = 0; i < 3; i++) {
      piece(2 + i, tusk(Offset(1420 + i * 90.0, 700), 190 + i * 14, math.pi * 0.05, math.pi * 0.95, 36), color: shade);
    }
    piece(5, Path.combine(PathOperation.union, Paths.circle(const Offset(1240, 880), 54), Paths.capsule(const Offset(1240, 880), const Offset(1330, 940), 26)));
    // Earth heaped over the part still buried.
    for (final (Offset c, double rx, double ry) in const <(Offset, double, double)>[(Offset(900, 1090), 1100, 120)]) {
      final Path mound = Paths.ellipse(c, rx, ry);
      look.fill(canvas, mound, look.doodle ? const Color(0xFFD6B687) : const Color(0xFF45352A), line: 6, boil: boil + 9, wobble: 3, soften: 0.1);
    }
  }

  @override
  bool shouldRepaint(_BonesPainter old) => old.t != t || old.boil != boil;
}

// --- the painting ---

class PaintingShot extends StatelessWidget {
  const PaintingShot(this.look, {super.key});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps;
    return _Pushed(
      length: _len(12),
      child: CustomPaint(size: Size.infinite, painter: _CavePainter(look, t, boilOf(frame))),
    );
  }
}

class _CavePainter extends CustomPainter {
  const _CavePainter(this.look, this.t, this.boil);

  final Look look;
  final double t;
  final int boil;

  /// The horse: a body, a neck, a head, four legs and a tail, as one outline.
  static Path horse() {
    Path p = Paths.ellipse(const Offset(0, 0), 215, 88);
    void add(Path q) => p = Path.combine(PathOperation.union, p, q);
    // An arched neck from the shoulders up to a small head that slopes down.
    add(Paths.polygon(const <Offset>[Offset(90, -70), Offset(170, -230), Offset(250, -250), Offset(256, -190), Offset(190, 20)]));
    add(Paths.taper(const Offset(236, -232), const Offset(360, -140), 40, 22));
    add(Paths.polygon(const <Offset>[Offset(240, -262), Offset(236, -312), Offset(268, -268)]));
    // Legs thick at the top, fine at the hoof, the near pair walking.
    add(Paths.taper(const Offset(140, 30), const Offset(170, 232), 30, 11));
    add(Paths.taper(const Offset(90, 50), const Offset(62, 236), 28, 11));
    add(Paths.taper(const Offset(-130, 30), const Offset(-170, 232), 34, 12));
    add(Paths.taper(const Offset(-170, 20), const Offset(-224, 220), 30, 11));
    add(Paths.taper(const Offset(-205, -30), const Offset(-292, 120), 16, 6));
    return p;
  }

  /// The black mane running up the neck.
  static Path mane() => Paths.polygon(const <Offset>[
        Offset(170, -236), Offset(150, -262), Offset(190, -258), Offset(184, -290), Offset(222, -272), Offset(232, -306), Offset(252, -262), Offset(256, -250), Offset(214, -214), Offset(170, -150),
      ]);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    // The wall: rough rock, lit from the lamp low on the left.
    canvas.drawRect(all, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: look.doodle ? const <Color>[Color(0xFFC8A47A), Color(0xFFB08C62)] : const <Color>[Color(0xFF6A5448), Color(0xFF3A2C28)]).createShader(all));
    final math.Random r = math.Random(12);
    for (int i = 0; i < 40; i++) {
      final Offset at = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final double w = 80 + r.nextDouble() * 220;
      final Path crack = Path()..moveTo(at.dx, at.dy)..quadraticBezierTo(at.dx + w * 0.4, at.dy + 20 - r.nextDouble() * 40, at.dx + w, at.dy + r.nextDouble() * 24 - 12);
      canvas.drawPath(crack, Paint()..style = PaintingStyle.stroke..strokeWidth = look.doodle ? 3 : 2..strokeCap = StrokeCap.round..color = look.doodle ? look.ink.withValues(alpha: 0.35) : const Color(0x33100804));
    }
    // The horse, painted a stroke at a time: revealed from nose to tail.
    final double reveal = ease(t, 0.0, 0.9, Curves.easeOut);
    final Path h = horse().shift(const Offset(1060, 600));
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(1560 - reveal * 1260 - 100, 0, 1560, size.height));
    look.fill(canvas, h, look.doodle ? const Color(0xFFD9704A) : const Color(0xFF9A3F26), line: 8, boil: boil, wobble: 2, soften: 0.12);
    // A dark mane and belly line, black pigment.
    canvas.drawPath(
      mane().shift(const Offset(1060, 600)),
      Paint()..color = look.doodle ? look.ink : const Color(0xFF1C100C),
    );
    canvas.restore();
    // Lamp light: dark everywhere but round the lamp, and it flutters.
    final double flick = Fire.flicker(t, seed: 5);
    const Offset lamp = Offset(520, 900);
    if (!look.doodle) {
      canvas.drawRect(
        all,
        Paint()..shader = RadialGradient(colors: <Color>[const Color(0x00000000), const Color(0x99080404), const Color(0xDD080404)], stops: const <double>[0.0, 0.55, 1.0]).createShader(Rect.fromCircle(center: lamp + const Offset(260, -240), radius: 1250 * flick)),
      );
    }
    canvas.drawCircle(lamp, 520 * flick, Paint()..shader = RadialGradient(colors: <Color>[look.doodle ? const Color(0x33FFE08A) : const Color(0x55FFB060), const Color(0x00FFB060)]).createShader(Rect.fromCircle(center: lamp, radius: 520 * flick)));
    // The lamp: a hollowed stone with a small flame.
    look.fill(canvas, Path()..addArc(Rect.fromCenter(center: lamp + const Offset(0, 20), width: 190, height: 110), 0, math.pi), const Color(0xFF8A847C), line: 7, boil: boil + 4, wobble: 1.5, soften: 0.2);
    paintFlame(canvas, look, lamp + const Offset(0, 6), 0.5, t, boil);
  }

  @override
  bool shouldRepaint(_CavePainter old) => old.t != t || old.boil != boil;
}

// --- today ---

/// A map of Africa with the pin on Tanzania, and a small camp drawn beside it.
class TodayShot extends StatelessWidget {
  const TodayShot(this.look, {super.key});

  final Look look;

  static const double pinLon = 34.6, pinLat = -3.5;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / openFps, len = _len(13);
    final double k = ease(t, 0.0, len, Curves.easeInOutSine);
    final MapView view = MapView(lon0: lerpD(20, 27, k), lat0: lerpD(2, -2, k), radius: lerpD(900, 1500, k), centre: Offset(lerpD(700, 480, k), 540));
    final double land = said(13, Say.today, 4) - _lands;
    final double drop = ease(t, land, 0.35, Curves.easeIn);
    final double hot = ease(t, land + 0.3, 0.6);
    final Offset pin = view.project(pinLon, pinLat);
    final double inset = ease(t, said(13, Say.today, 6) - _lands, 0.5, Curves.easeOutBack);
    const double r = 270;
    const Offset centre = Offset(1480, 540);
    return Stack(fit: StackFit.expand, children: <Widget>[
      CustomPaint(size: Size.infinite, painter: MapPainter(look: look, view: view, highlight: const <String>{'Tanzania'}, highlightAmount: hot, frame: boilOf(frame))),
      Positioned.fill(child: CustomPaint(painter: _TodayPin(look, pin + Offset(0, -(1 - drop) * 700), drop))),
      if (inset > 0)
        Positioned(
          left: centre.dx - r,
          top: centre.dy - r,
          width: 2 * r,
          height: 2 * r,
          child: Transform.scale(scale: inset.clamp(0.0, 1.1), child: CustomPaint(painter: _CampPainter(look, t, boilOf(frame)))),
        ),
      Positioned(
        left: centre.dx - 300,
        width: 600,
        top: centre.dy + r + 30,
        child: Center(child: chip(look, 'Hadza camp, Tanzania', size: 38, opacity: inset)),
      ),
    ]);
  }
}

class _TodayPin extends CustomPainter {
  const _TodayPin(this.look, this.at, this.dropped);

  final Look look;
  final Offset at;
  final double dropped;

  @override
  void paint(Canvas canvas, Size size) {
    if (dropped <= 0) return;
    final Path drop = Path()
      ..moveTo(at.dx, at.dy)
      ..cubicTo(at.dx - 16, at.dy - 30, at.dx - 38, at.dy - 52, at.dx - 38, at.dy - 84)
      ..arcToPoint(Offset(at.dx + 38, at.dy - 84), radius: const Radius.circular(38))
      ..cubicTo(at.dx + 38, at.dy - 52, at.dx + 16, at.dy - 30, at.dx, at.dy)
      ..close();
    canvas.drawPath(drop, Paint()..color = const Color(0xFFE5533D));
    if (look.doodle) canvas.drawPath(drop, Paint()..style = PaintingStyle.stroke..strokeWidth = 6..strokeJoin = StrokeJoin.round..color = look.ink);
    canvas.drawCircle(at + const Offset(0, -84), 14, Paint()..color = look.doodle ? look.paper : const Color(0xFFFFF0E0));
  }

  @override
  bool shouldRepaint(_TodayPin old) => old.at != at;
}

/// A round window onto a camp on the savanna: an acacia, grass huts, a fire.
class _CampPainter extends CustomPainter {
  const _CampPainter(this.look, this.t, this.boil);

  final Look look;
  final double t;
  final int boil;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    final Path window = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    canvas.save();
    canvas.clipPath(window);
    // Sky and ground.
    canvas.drawRect(Offset.zero & size, Paint()..color = look.doodle ? const Color(0xFFBEE0EE) : const Color(0xFF8FB4D0));
    canvas.drawRect(Rect.fromLTRB(0, c.dy + 40, size.width, size.height), Paint()..color = look.doodle ? const Color(0xFFE8C98A) : const Color(0xFFB89A62));
    canvas.drawLine(Offset(0, c.dy + 40), Offset(size.width, c.dy + 40), Paint()..strokeWidth = look.doodle ? 5 : 2..color = look.doodle ? look.ink : const Color(0x55402A18));
    // An acacia: a pale trunk and a flat canopy.
    look.fill(canvas, Paths.polygon(<Offset>[c + const Offset(-130, 60), c + const Offset(-120, -40), c + const Offset(-92, -92), c + const Offset(-84, -40), c + const Offset(-80, 60)]), const Color(0xFF6A4E36), line: 5, boil: boil, wobble: 1.2);
    look.fill(canvas, Path()..addOval(Rect.fromCenter(center: c + const Offset(-100, -110), width: 250, height: 70)), look.doodle ? const Color(0xFF9CC070) : const Color(0xFF5E7E3C), line: 6, boil: boil + 1, wobble: 2);
    // Three domed huts of branches and grass.
    for (final (double x, double s) in const <(double, double)>[(40, 1.0), (150, 0.86), (-20, 0.72)]) {
      final Offset b = c + Offset(x, 70 - (s < 0.8 ? 14 : 0));
      look.fill(canvas, Path()..addArc(Rect.fromCenter(center: b, width: 110 * s, height: 130 * s * 1.2), math.pi, math.pi)..close(), const Color(0xFFC7A25C), line: 5, boil: boil + 2, wobble: 1.5);
      final Paint grass = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = look.doodle ? look.ink.withValues(alpha: 0.6) : const Color(0x66644A20);
      for (int i = -2; i <= 2; i++) {
        canvas.drawArc(Rect.fromCenter(center: b, width: (110 - (i.abs()) * 28) * s, height: 156 * s), math.pi * 1.05, math.pi * 0.9, false, grass);
      }
    }
    // A cooking fire in front and its smoke.
    for (int i = 0; i < 5; i++) {
      final double u = (t * 0.3 + i / 5) % 1.0;
      canvas.drawCircle(c + Offset(math.sin(u * 5 + i) * 6, 60 - u * 140), 6 + u * 16, Paint()..color = (look.doodle ? const Color(0xFFFFFFFF) : const Color(0xFFE4E0DA)).withValues(alpha: (1 - u) * 0.8));
    }
    paintFlame(canvas, look, c + const Offset(-10, 108), 0.3, t, boil);
    canvas.restore();
    canvas.drawPath(window, Paint()..style = PaintingStyle.stroke..strokeWidth = look.doodle ? 10 : 6..color = look.doodle ? look.ink : const Color(0xFFFFF6E8));
  }

  @override
  bool shouldRepaint(_CampPainter old) => old.t != t || old.boil != boil;
}
