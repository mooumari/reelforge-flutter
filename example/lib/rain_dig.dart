import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'rain_set.dart';
import 'rain_timing.dart';

/// "Nobody wrote it down. But they left a lot behind": a cutaway of the
/// ground, the camera sinking through it, and what is found in it lighting
/// up as it is named -- a hearth, stone tools, bones, a painted wall --
/// before it rises to a grass hut where people still live like this, and
/// draws the thread between them.

const int _shot = 3, _line = 3;

// Where things lie, in the world's own coordinates.
const double _surface = 400;
const Offset _hearthAt = Offset(560, 760);
const Offset _toolsAt = Offset(1180, 770);
const Offset _bonesAt = Offset(1780, 770);
const Offset _paintAt = Offset(2420, 730);
const Offset _hutAt = Offset(3280, _surface);

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;

class DigShot extends StatelessWidget {
  const DigShot({super.key});

  @override
  Widget build(BuildContext context) {
    final double t = secondsOf(context);
    final int frame = Video.frame(context);
    int f(double seconds) => (seconds * rainFps).round();

    // The words that matter, in seconds into the shot.
    final double hearth = saidAt(_shot, _line, 10), tools = saidAt(_shot, _line, 11), bones = saidAt(_shot, _line, 12);
    final double paint = saidAt(_shot, _line, 14), today = saidAt(_shot, _line, 18), help = saidAt(_shot, _line, 21);

    // The weather clears as we come up to the people alive now.
    final double clear = along(t, today - 1.6, 1.8);
    final double storm = lerpD(0.9, 0.05, clear);
    final double h = lerpD(0.84, 0.46, clear);
    final Light light = skyLight(h, storm);

    // Under the turf it is quiet: the rain thins while the camera is down there.
    final double below = along(t, hearth - 1.7, 1.2) * (1 - along(t, today - 1.5, 1.6));
    final double rise = today + 0.9;
    return Stack(fit: StackFit.expand, children: <Widget>[
      Camera(
        keyframes: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(760, 330)),
          CameraKeyframe(f(hearth - 1.7), center: const Offset(780, 330), curve: Curves.linear),
          CameraKeyframe(f(hearth - 0.2), center: const Offset(900, 740), curve: Curves.easeInOutCubic),
          CameraKeyframe(f(paint + 0.2), center: const Offset(1760, 760), zoom: 1.04, curve: Curves.easeInOutSine),
          CameraKeyframe(f(today - 1.5), center: const Offset(2200, 740), zoom: 1.0, curve: Curves.easeInOutSine),
          CameraKeyframe(f(today + 0.6), center: const Offset(3150, 470), zoom: 1.0, curve: Curves.easeInOutCubic),
          CameraKeyframe(f(rise), center: const Offset(3200, 470), zoom: 1.05, curve: Curves.linear),
          CameraKeyframe(rainLengths[_shot], center: const Offset(2150, 600), zoom: 0.5, curve: Curves.easeInOutCubic),
        ],
        child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: <Widget>[
          ParallaxLayer(depth: 0.0, child: IceSky(h: h, storm: storm, horizon: 520)),
          ParallaxLayer(depth: 0.05, child: IceClouds(h: h, storm: storm)),
          ParallaxLayer(depth: 0.3, child: _Ridge(h: h, storm: storm)),
          ParallaxLayer(
            depth: 1.0,
            child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: <Widget>[
              CustomPaint(painter: _GroundPainter(h, storm)),
              _Hearth(reveal: along(t, hearth - 0.1, 0.7, Curves.easeOutBack), t: t),
              _Tools(reveal: along(t, tools - 0.1, 0.7, Curves.easeOutBack), t: t - tools),
              _Bones(reveal: along(t, bones - 0.1, 0.7, Curves.easeOutBack)),
              _Painting(reveal: along(t, paint - 0.1, 0.7, Curves.easeOutBack), draw: along(t, paint, 1.6, Curves.easeInOut)),
              _Hut(t: t, frame: frame, light: light, show: along(t, today - 1.4, 0.8)),
              _Thread(progress: along(t, help - 0.1, 1.3, Curves.easeInOutCubic)),
            ]),
          ),
        ]),
      ),
      Rain(intensity: (1 - clear) * (0.9 - 0.7 * below), slant: 12),
    ]);
  }
}

// --- the land and the ground under it ---

class _Ridge extends StatelessWidget {
  const _Ridge({required this.h, required this.storm});

  final double h, storm;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _RidgePainter(h, storm));
}

class _RidgePainter extends CustomPainter {
  const _RidgePainter(this.h, this.storm);

  final double h, storm;

  @override
  void paint(Canvas canvas, Size size) {
    final Color tone = landTone(h, storm);
    final Path far = Path()..moveTo(-1200, 400);
    for (double x = -1200; x <= 5200; x += 90) {
      far.lineTo(x, 330 - math.sin(x * 0.0031) * 70 - math.sin(x * 0.011 + 1) * 24);
    }
    far
      ..lineTo(5200, 460)
      ..lineTo(-1200, 460)
      ..close();
    canvas.drawPath(far, Paint()..color = _mix(const Color(0xFF6C86A8), tone, 0.4));
    final Path near = Path()..moveTo(-1200, 420);
    for (double x = -1200; x <= 5200; x += 70) {
      near.lineTo(x, 372 - math.sin(x * 0.005 + 2) * 36 - math.sin(x * 0.019) * 12);
    }
    near
      ..lineTo(5200, 470)
      ..lineTo(-1200, 470)
      ..close();
    canvas.drawPath(near, Paint()..color = _mix(const Color(0xFF4A6A60), tone, 0.5));
  }

  @override
  bool shouldRepaint(_RidgePainter old) => old.h != h || old.storm != storm;
}

/// The grass line and the layers beneath it, with pebbles, roots and the odd
/// darker lens.
class _GroundPainter extends CustomPainter {
  const _GroundPainter(this.h, this.storm);

  final double h, storm;

  static const double _left = -1400, _right = 5400;

  @override
  void paint(Canvas canvas, Size size) {
    final Color tone = landTone(h, storm);
    Color toned(Color c) => c.mix(tone);

    // Bands from the top: turf, topsoil, brown earth, ochre, clay, grey sand,
    // dark earth, rock. Each wavers on its own.
    const List<(Color, double, double, double)> bands = <(Color, double, double, double)>[
      (Color(0xFF5E7C42), _surface, 6, 0.004),
      (Color(0xFF3E2C22), _surface + 26, 10, 0.006),
      (Color(0xFF5C402E), _surface + 120, 16, 0.004),
      (Color(0xFF8C6538), _surface + 260, 22, 0.003),
      (Color(0xFF9C7D58), _surface + 430, 20, 0.005),
      (Color(0xFF706A62), _surface + 570, 24, 0.0035),
      (Color(0xFF4C3B34), _surface + 700, 18, 0.006),
      (Color(0xFF38343E), _surface + 860, 22, 0.004),
    ];
    for (int i = 0; i < bands.length; i++) {
      final (Color color, double y, double amp, double freq) = bands[i];
      final Path p = Path()..moveTo(_left, 2200);
      for (double x = _left; x <= _right; x += 60) {
        p.lineTo(x, y + math.sin(x * freq + i * 1.7) * amp + math.sin(x * freq * 3.1 + i) * amp * 0.35);
      }
      p
        ..lineTo(_right, 2200)
        ..close();
      canvas.drawPath(p, Paint()..color = toned(color));
      // A pale edge where each layer meets the one above.
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _mix(toned(color), const Color(0xFFFFFFFF), 0.18).withValues(alpha: 0.5),
      );
    }

    // Pebbles and flecks scattered through the layers.
    final math.Random r = math.Random(21);
    for (int i = 0; i < 360; i++) {
      final double x = _left + r.nextDouble() * (_right - _left), y = _surface + 40 + r.nextDouble() * 900;
      final double s = 2 + r.nextDouble() * 9;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: s * 1.5, height: s),
        Paint()..color = (r.nextBool() ? const Color(0xFF000000) : const Color(0xFFFFFFFF)).withValues(alpha: 0.08 + r.nextDouble() * 0.1),
      );
    }
    // Roots hanging from the turf.
    for (int i = 0; i < 60; i++) {
      final double x = _left + r.nextDouble() * (_right - _left);
      final double drop = 30 + r.nextDouble() * 90;
      canvas.drawPath(
        Path()
          ..moveTo(x, _surface + 8)
          ..quadraticBezierTo(x + (r.nextDouble() - 0.5) * 30, _surface + drop * 0.6, x + (r.nextDouble() - 0.5) * 40, _surface + drop),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFB59A72).withValues(alpha: 0.4),
      );
    }
    // Light falling off with depth.
    canvas.drawRect(
      const Rect.fromLTRB(_left, _surface, _right, 2200),
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0x00000000), Color(0x66080A18)], stops: <double>[0.1, 0.55])
            .createShader(const Rect.fromLTRB(_left, _surface, _right, 1500)),
    );
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.h != h || old.storm != storm;
}

/// Small colour helpers, so the painter reads.
extension on Color {
  Color mix(Color tone) => Color.fromARGB(
        (a * 255).round(),
        ((r * tone.r) * 255).round().clamp(0, 255),
        ((g * tone.g) * 255).round().clamp(0, 255),
        ((b * tone.b) * 255).round().clamp(0, 255),
      );
}

// --- the finds ---

/// A label, in small capitals, that comes in with what it names.
Widget _label(String text, Offset at, double reveal) => Positioned(
      left: at.dx - 220,
      top: at.dy,
      width: 440,
      child: Opacity(
        opacity: reveal.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - reveal.clamp(0.0, 1.0)) * 12),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 5, color: Color(0xFFFFF0D2), shadows: <Shadow>[Shadow(color: Color(0xAA0A0A18), blurRadius: 10)]),
          ),
        ),
      ),
    );

/// A warm ring of light round a find as it is found, easing back to a glow.
class _Halo extends CustomPainter {
  const _Halo(this.at, this.radius, this.reveal);

  final Offset at;
  final double radius, reveal;

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;
    final double pulse = reveal < 1 ? 1 : 1;
    final double a = (0.75 - 0.4 * reveal.clamp(0.0, 1.0)) * pulse;
    final Rect r = Rect.fromCircle(center: at, radius: radius * (0.6 + 0.4 * reveal.clamp(0.0, 1.2)));
    canvas.drawCircle(
      at,
      r.width / 2,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: <Color>[const Color(0xFFFFC66E).withValues(alpha: a * 0.7), const Color(0xFFFF9A3C).withValues(alpha: a * 0.2), const Color(0x00FF9A3C)], stops: const <double>[0, 0.5, 1]).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_Halo old) => old.reveal != reveal;
}

Part _stone(Offset at, double rx, double ry, Color color) => Part(at: at, shapes: <Shape>[
      Shape(Paths.ellipse(Offset.zero, rx, ry), color: color, shade: const Shade(form: 0.5, core: 0.35, coreStrength: 0.6, rim: 0.12, rimStrength: 0.5)),
    ]);

class _Hearth extends StatelessWidget {
  const _Hearth({required this.reveal, required this.t});

  final double reveal, t;

  @override
  Widget build(BuildContext context) {
    final double r = reveal.clamp(0.0, 1.0);
    final Part part = Part(at: _hearthAt, scaleX: 0.85 + 0.15 * r, scaleY: 0.85 + 0.15 * r, opacity: r, children: <Part>[
      // The ash lens under it, and charcoal.
      Part(shapes: <Shape>[
        Shape(Paths.ellipse(const Offset(0, 46), 250, 30), color: const Color(0xFF8C8A86)),
        Shape(Paths.ellipse(const Offset(-20, 40), 190, 18), color: const Color(0xFF6E6C6A)),
        for (int i = 0; i < 14; i++)
          Shape(Paths.ellipse(Offset(-150 + i * 22.0, 30 + (i * 7 % 5)), 9 + (i % 3) * 3, 4), color: const Color(0xFF1B1818)),
      ]),
      // A ring of stones, blackened inside.
      for (int i = 0; i < 9; i++)
        _stone(
          Offset(math.cos(i / 9 * 2 * math.pi + 0.3) * 175, math.sin(i / 9 * 2 * math.pi + 0.3) * 42 + 26),
          34 + (i % 3) * 6,
          24 + (i % 2) * 5,
          Color.lerp(const Color(0xFF7A7570), const Color(0xFF3E3A3A), (math.sin(i / 9 * 2 * math.pi + 0.3) + 1) / 2 * 0.4)!,
        ),
    ]);
    // A ghost of the fire, flickering as it did.
    final double ghost = (reveal.clamp(0.0, 1.0)) * 0.75;
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      CustomPaint(painter: _Halo(_hearthAt + const Offset(0, -30), 330, reveal)),
      Drawing(part, light: const Light(from: Offset(0, -1), shadow: Color(0xFF5B4A5A), highlight: Color(0xFFFFC27A))),
      Opacity(opacity: 0.8, child: Fire(base: _hearthAt + const Offset(0, 20), size: 1.0, strength: ghost, glow: false, seed: 7)),
      _label('A HEARTH', _hearthAt + const Offset(0, 120), r),
    ]);
  }
}

class _Tools extends StatelessWidget {
  const _Tools({required this.reveal, required this.t});

  final double reveal, t;

  @override
  Widget build(BuildContext context) {
    final double r = reveal.clamp(0.0, 1.0);
    // A hand axe: a teardrop, chipped, with the scars of each flake.
    Path axe(double s) => Paths.smooth(<Offset>[
          Offset(0, -150 * s), Offset(34 * s, -92 * s), Offset(58 * s, -20 * s), Offset(62 * s, 40 * s), Offset(40 * s, 96 * s), Offset(0, 118 * s),
          Offset(-40 * s, 96 * s), Offset(-62 * s, 40 * s), Offset(-58 * s, -20 * s), Offset(-34 * s, -92 * s),
        ]);
    const Color flint = Color(0xFF8E99A8);
    final Part part = Part(at: _toolsAt, scaleX: 0.85 + 0.15 * r, scaleY: 0.85 + 0.15 * r, opacity: r, children: <Part>[
      Part(at: const Offset(-30, 0), degrees: -28, shapes: <Shape>[
        Shape(axe(1), color: flint, shade: const Shade(form: 0.5, core: 0.4, coreStrength: 0.7, rim: 0.12, rimStrength: 0.7)),
        Shape(axe(0.78), color: const Color(0xFFB4BECA), shade: Shade.gentle),
        // Flake scars: arcs from the edge towards the middle.
        for (int i = 0; i < 7; i++)
          Shape(
            Path()
              ..moveTo(-50 + i * 17.0, -70 + (i % 3) * 30)
              ..quadraticBezierTo(-30 + i * 15.0, -30 + (i % 2) * 40, -12 + i * 8.0, 20 + (i % 3) * 26),
            stroke: const Color(0xFF59626F),
            strokeWidth: 3,
          ),
      ]),
      // A scraper and a blade, smaller, beside it.
      Part(at: const Offset(120, 70), degrees: 18, shapes: <Shape>[
        Shape(Paths.ellipse(Offset.zero, 54, 40), color: const Color(0xFFA4AEBB), shade: Shade.solid),
        Shape(Paths.ellipse(const Offset(-6, -6), 34, 22), color: const Color(0xFFC0C9D4), shade: Shade.gentle),
      ]),
      Part(at: const Offset(150, -60), degrees: 64, shapes: <Shape>[
        Shape(Paths.smooth(const <Offset>[Offset(-80, 0), Offset(0, -16), Offset(80, -2), Offset(0, 12)]), color: const Color(0xFF9AA5B3), shade: Shade.solid),
      ]),
    ]);
    // A glint sweeping across once, as it is found.
    final double sweep = (t / 0.9).clamp(0.0, 1.0);
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      CustomPaint(painter: _Halo(_toolsAt, 300, reveal)),
      Drawing(part, light: const Light(from: Offset(-0.5, -0.85), shadow: Color(0xFF5A6290), highlight: Color(0xFFFFFFFF))),
      if (sweep > 0 && sweep < 1)
        Positioned(
          left: _toolsAt.dx - 140 + sweep * 280 - 14,
          top: _toolsAt.dy - 130,
          child: Transform.rotate(angle: 0.5, child: Opacity(opacity: math.sin(sweep * math.pi) * 0.9, child: Container(width: 28, height: 260, color: const Color(0xAAFFFFFF)))),
        ),
      _label('STONE TOOLS', _toolsAt + const Offset(0, 150), r),
    ]);
  }
}

class _Bones extends StatelessWidget {
  const _Bones({required this.reveal});

  final double reveal;

  @override
  Widget build(BuildContext context) {
    final double r = reveal.clamp(0.0, 1.0);
    const Color ivory = Color(0xFFE9DEC6), shade = Color(0xFFBBA982);
    Shape bone(Offset a, Offset b, double w) => Shape(Paths.capsule(a, b, w), color: ivory, shade: const Shade(form: 0.4, core: 0.35, coreStrength: 0.6, rim: 0.1, rimStrength: 0.5));
    Shape knob(Offset c, double rr) => Shape(Paths.circle(c, rr), color: ivory, shade: Shade.solid);
    final Part part = Part(at: _bonesAt, scaleX: 0.85 + 0.15 * r, scaleY: 0.85 + 0.15 * r, opacity: r, children: <Part>[
      // A tusk: a long curve, thick at the root, tapering to a point.
      Part(shapes: <Shape>[
        Shape(
          Paths.smooth(const <Offset>[
            Offset(-190, 70), Offset(-170, -10), Offset(-90, -86), Offset(30, -110), Offset(120, -80), Offset(170, -20), Offset(176, -40),
            Offset(130, -110), Offset(30, -140), Offset(-100, -120), Offset(-190, -34), Offset(-218, 50),
          ]),
          color: ivory,
          shade: const Shade(form: 0.5, core: 0.4, coreStrength: 0.7, rim: 0.1, rimStrength: 0.6),
        ),
        Shape(Paths.smooth(const <Offset>[Offset(-180, 60), Offset(-150, 0), Offset(-80, -70), Offset(30, -96), Offset(110, -74)], closed: false), stroke: shade, strokeWidth: 3),
      ]),
      // A femur, with its two knuckles.
      Part(at: const Offset(30, 92), degrees: -8, shapes: <Shape>[
        bone(const Offset(-130, 0), const Offset(130, 0), 14),
        knob(const Offset(-134, -10), 18), knob(const Offset(-136, 12), 17), knob(const Offset(136, -9), 17), knob(const Offset(138, 11), 16),
      ]),
      // Ribs, curving, in a row.
      for (int i = 0; i < 4; i++)
        Part(at: Offset(-90 + i * 52.0, 20 + (i % 2) * 8), degrees: 8 + i * 4, shapes: <Shape>[
          Shape(
            Path()
              ..moveTo(0, 0)
              ..quadraticBezierTo(60, 40, 18, 110),
            stroke: ivory,
            strokeWidth: 15,
          ),
        ]),
      // A jaw, with teeth.
      Part(at: const Offset(190, 50), degrees: 14, shapes: <Shape>[
        Shape(Paths.smooth(const <Offset>[Offset(-70, -24), Offset(10, -34), Offset(70, -10), Offset(80, 30), Offset(10, 26), Offset(-60, 20)]), color: ivory, shade: Shade.solid),
        for (int i = 0; i < 5; i++) Shape(Paths.roundRect(Rect.fromLTWH(-48 + i * 20.0, -38, 12, 14), 4), color: const Color(0xFFF4EBD6)),
      ]),
    ]);
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      CustomPaint(painter: _Halo(_bonesAt, 320, reveal)),
      Drawing(part, light: const Light(from: Offset(-0.5, -0.85), shadow: Color(0xFF8A7098), highlight: Color(0xFFFFF4DA))),
      _label('BONES', _bonesAt + const Offset(0, 160), r),
    ]);
  }
}

/// A cave wall with a hand and a bison: the hand stencilled in ochre, the
/// bison drawn on in black, line by line.
class _Painting extends StatelessWidget {
  const _Painting({required this.reveal, required this.draw});

  final double reveal, draw;

  @override
  Widget build(BuildContext context) {
    final double r = reveal.clamp(0.0, 1.0);
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      CustomPaint(painter: _Halo(_paintAt, 380, reveal)),
      Opacity(opacity: r, child: CustomPaint(painter: _WallPainter(_paintAt, draw))),
      _label('CAVE PAINTINGS', _paintAt + const Offset(0, 230), r),
    ]);
  }
}

class _WallPainter extends CustomPainter {
  const _WallPainter(this.at, this.draw);

  final Offset at;
  final double draw;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    final Path wall = Paths.smooth(const <Offset>[
      Offset(-290, -150), Offset(-150, -190), Offset(60, -178), Offset(260, -196), Offset(310, -60), Offset(290, 100), Offset(180, 186), Offset(-40, 170), Offset(-250, 190), Offset(-310, 40),
    ]);
    canvas.drawPath(wall, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFA08A72), Color(0xFF6A5648)]).createShader(const Rect.fromLTRB(-310, -196, 310, 190)));
    canvas.save();
    canvas.clipPath(wall);
    final math.Random r = math.Random(9);
    for (int i = 0; i < 140; i++) {
      canvas.drawCircle(Offset(-300 + r.nextDouble() * 600, -190 + r.nextDouble() * 380), 1 + r.nextDouble() * 3, Paint()..color = Color.fromRGBO(r.nextBool() ? 0 : 255, r.nextBool() ? 0 : 255, 255, 0.05));
    }
    // A stencilled hand: the palm, four fingers and a thumb, with the spray
    // of ochre round it.
    final Paint ochre = Paint()..color = const Color(0xFFB7472A).withValues(alpha: 0.9);
    final Offset p = const Offset(-190, 20);
    for (int i = 0; i < 150; i++) {
      final double a = r.nextDouble() * math.pi * 2, d = 60 + r.nextDouble() * 80;
      canvas.drawCircle(p + Offset(math.cos(a) * d * 0.9, math.sin(a) * d), 1 + r.nextDouble() * 2.4, ochre..color = const Color(0xFFB7472A).withValues(alpha: 0.18 + r.nextDouble() * 0.3));
    }
    final Paint hand = Paint()..color = const Color(0xFF6A5648);
    canvas.drawCircle(p, 80, Paint()..color = const Color(0xFFB7472A).withValues(alpha: 0.28));
    canvas.drawOval(Rect.fromCenter(center: p + const Offset(0, 20), width: 70, height: 84), hand);
    // A finger, turned about its base.
    void finger(Offset base, double length, double angle) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-8, -length, 16, length), const Radius.circular(8)), hand);
      canvas.restore();
    }

    for (final (double dx, double len, double ang) in const <(double, double, double)>[(-28, 66, -0.28), (-9, 78, -0.08), (12, 74, 0.1), (31, 58, 0.3)]) {
      finger(p + Offset(dx, 0), len, ang);
    }
    finger(p + const Offset(30, 34), 52, 1.0);
    canvas.restore();

    // The bison: a hump, a low head, horns and short legs, in one line.
    final Path bison = Path()
      ..moveTo(210, 90)
      ..cubicTo(190, 70, 190, 30, 160, 10)
      ..cubicTo(120, -20, 70, -50, 20, -34)
      ..cubicTo(-30, -20, -50, 20, -20, 40)
      ..cubicTo(-30, 70, -30, 100, -26, 120)
      ..lineTo(-6, 120)
      ..cubicTo(-2, 90, 10, 80, 40, 80)
      ..cubicTo(90, 82, 120, 84, 140, 90)
      ..cubicTo(150, 110, 150, 120, 150, 128)
      ..lineTo(172, 128)
      ..cubicTo(176, 110, 190, 100, 210, 90)
      ..close();
    final Path horns = Path()
      ..moveTo(-20, 40)
      ..cubicTo(-46, 24, -52, 6, -40, -12)
      ..moveTo(-8, 28)
      ..cubicTo(-30, 18, -34, 0, -24, -14);
    // Drawn on by trimming the outline to how far along it is.
    void stroke(Path path, double upTo, Paint paint) {
      for (final ui.PathMetric m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * upTo), paint);
      }
    }

    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF1B1512);
    canvas.drawPath(bison, Paint()..color = const Color(0xFFA84A2C).withValues(alpha: 0.5 * ((draw - 0.7) / 0.3).clamp(0.0, 1.0)));
    stroke(bison, draw, line);
    stroke(horns, ((draw - 0.4) * 2).clamp(0.0, 1.0), line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WallPainter old) => old.draw != draw || old.at != at;
}

// --- people alive now ---

const Character _mara = Character(
  body: Body(head: HeadShape.heart, torso: 120, shoulders: 82, hips: 76),
  skin: Color(0xFF7A4B32),
  face: FaceStyle(
    eyeSpacing: 60, eyeWidth: 26, eyeHeight: 32, pupilRadius: 10.5, pupilColor: Color(0xFF1A100A), browGap: 30, browLength: 26,
    browThickness: 5, browColor: Color(0xFF1E1410), mouthY: 52, mouthWidth: 38, cheeks: Color(0x22C0503A),
  ),
  outfit: <Garment>[
    Buzz(Color(0xFF1E1410)),
    Shirt(Color(0xFFD4584A), sleeves: 0.3, collar: false),
    Skirt(Color(0xFF3F6E8C), length: 0.78),
    BeadNecklace(Color(0xFFE8D2A0), count: 9),
  ],
);

/// A hut of grass, a cooking fire with a pot on it, and a woman at it: the
/// Hadza of Tanzania, who build such huts for the wet season.
class _Hut extends StatelessWidget {
  const _Hut({required this.t, required this.frame, required this.light, required this.show});

  final double t;
  final int frame;
  final Light light;
  final double show;

  @override
  Widget build(BuildContext context) {
    final double s = show.clamp(0.0, 1.0);
    if (s <= 0) return const SizedBox.shrink();
    // The dome, in courses of thatch.
    final Part hut = Part(at: _hutAt + const Offset(-90, 0), opacity: s, shapes: <Shape>[
      Shape(
        Paths.smooth(const <Offset>[Offset(-190, 0), Offset(-176, -110), Offset(-100, -190), Offset(0, -214), Offset(100, -190), Offset(176, -110), Offset(190, 0)]),
        color: const Color(0xFFC9A55A),
        shade: const Shade(form: 0.45, core: 0.4, coreStrength: 0.6, rim: 0.08, rimStrength: 0.4),
      ),
      for (int i = 0; i < 7; i++)
        Shape(
          Path()
            ..moveTo(-180 + i * 12.0, -20 - i * 22.0)
            ..quadraticBezierTo(0, -42 - i * 24.0, 180 - i * 12.0, -20 - i * 22.0),
          stroke: const Color(0xFF9C7A38),
          strokeWidth: 4,
        ),
      // The low door.
      Shape(Paths.smooth(const <Offset>[Offset(50, 0), Offset(50, -62), Offset(80, -90), Offset(110, -62), Offset(110, 0)]), color: const Color(0xFF241810)),
    ]);
    final Part fire = Part(at: _hutAt + const Offset(150, 0), opacity: s, children: <Part>[
      for (int i = 0; i < 6; i++) _stone(Offset(-40 + i * 16.0, 4 + (i % 2) * 4), 14, 9, const Color(0xFF6E6A66)),
      // A black pot.
      Part(at: const Offset(0, -34), shapes: <Shape>[
        Shape(Paths.ellipse(const Offset(0, 0), 36, 30), color: const Color(0xFF26262C), shade: Shade.solid),
        Shape(Paths.ellipse(const Offset(0, -26), 34, 7), color: const Color(0xFF111116)),
      ]),
    ]);
    final Performance idle = Performance(fps: rainFps, startX: 0, beats: <Beat>[const Feel(Emotion.happy, at: 0, amount: 0.5)]);
    final Offset at = _mara.standing(_hutAt.dx + 250, _hutAt.dy + 4);
    final Part woman = _mara.part.placed(at: Offset(_hutAt.dx + 250, _hutAt.dy + 4 - (_hutAt.dy + 4 - at.dy) * 0.95), scale: 0.95);
    final Posed p = followThrough(
      (int f) => Posed(woman, _mara.stance.plus(_mara.life(21).at(f, rainFps)).plus(idle.face(_mara.face, f)).plus(Pose(<String, Joint>{
            // She stirs: the near hand moves over the pot in a slow circle.
            'shoulderF': Joint.rotate(-32 + math.sin(f * 0.16) * 5),
            'elbowF': Joint.rotate(24 + math.cos(f * 0.16) * 8),
          }))),
      frame,
      jiggles: _mara.jiggles,
      fps: rainFps,
    );
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      Opacity(opacity: s, child: Drawing(groundShadowAt(_hutAt.dx + 250, 80, _hutAt.dy + 4))),
      Drawing(hut, light: light),
      Drawing(fire, light: light),
      Opacity(opacity: s, child: Fire(base: _hutAt + const Offset(150, -4), size: 0.55, strength: s, seed: 2)),
      Drawing(p.part, pose: p.pose, light: light),
      // Smoke from the pot, rising and spreading.
      Opacity(opacity: s, child: CustomPaint(painter: _SmokePainter(_hutAt + const Offset(150, -90), t))),
      _label('TANZANIA, TODAY', _hutAt + const Offset(40, 80), s),
    ]);
  }
}

Part groundShadowAt(double x, double rx, double y) => Part(at: Offset(x, y), shapes: <Shape>[
      Shape(Paths.ellipse(Offset.zero, rx, rx * 0.13), color: const Color(0x33101830)),
    ]);

class _SmokePainter extends CustomPainter {
  const _SmokePainter(this.at, this.t);

  final Offset at;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 9; i++) {
      final double age = ((t * 0.35 + i / 9) % 1);
      final Offset p = at + Offset(math.sin(age * 5 + i) * 18 + age * 40, -age * 230);
      canvas.drawCircle(p, 14 + age * 46, Paint()..color = const Color(0xFFE8E4E0).withValues(alpha: (1 - age) * 0.22));
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) => old.t != t;
}

/// A thread of light from the ancient hearth, up through the ground and over
/// to the hut's fire: what the one tells us about the other.
class _Thread extends StatelessWidget {
  const _Thread({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ThreadPainter(progress));
}

class _ThreadPainter extends CustomPainter {
  const _ThreadPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final Path path = Path()
      ..moveTo(_hearthAt.dx, _hearthAt.dy - 30)
      ..cubicTo(_hearthAt.dx, _surface - 260, _hutAt.dx + 150, _surface - 300, _hutAt.dx + 150, _hutAt.dy - 60);
    for (final ui.PathMetric m in path.computeMetrics()) {
      final Path part = m.extractPath(0, m.length * progress);
      canvas.drawPath(part, Paint()..style = PaintingStyle.stroke..strokeWidth = 22..strokeCap = StrokeCap.round..color = const Color(0xFFFFC66E).withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      canvas.drawPath(part, Paint()..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round..color = const Color(0xFFFFE2A0));
      // A bright bead at the head of it.
      final ui.Tangent? head = m.getTangentForOffset(m.length * progress);
      if (head != null && progress < 1) canvas.drawCircle(head.position, 12, Paint()..color = const Color(0xFFFFFFFF));
    }
  }

  @override
  bool shouldRepaint(_ThreadPainter old) => old.progress != progress;
}
