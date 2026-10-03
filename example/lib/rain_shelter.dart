import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'rain_cast.dart';
import 'rain_set.dart';
import 'rain_timing.dart';

/// Day one: the band runs for cover, and what the wet does to a child's body
/// heat is shown as an aura that shrinks and chills; then three kinds of
/// shelter -- a cave, a frame of branches, a frame of mammoth bone -- the
/// last two put up and covered in hides before our eyes.

const double _ground = 940;

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;

// --- the cave, for both shots ---

/// A rocky hill with a dark mouth at [at] (its foot, centre), [size] times
/// the size of the big one, and firelight inside by [glow].
Widget _cave(Offset at, double size, double glow, Light light, double t, {double fire = 0.6}) {
  Shape rock(List<Offset> pts, Color c) => Shape(Paths.smooth(pts), color: c, shade: const Shade(form: 0.5, core: 0.4, coreStrength: 0.7, rim: 0.1, rimStrength: 0.5));
  final Part hill = Part(at: at, scaleX: size, scaleY: size, shapes: <Shape>[
    rock(const <Offset>[Offset(-520, 0), Offset(-500, -180), Offset(-380, -330), Offset(-190, -430), Offset(40, -450), Offset(260, -400), Offset(430, -280), Offset(520, -110), Offset(540, 0)], const Color(0xFF6C6872)),
    // Lighter planes on the shoulders.
    rock(const <Offset>[Offset(-420, -170), Offset(-330, -300), Offset(-150, -390), Offset(-90, -300), Offset(-220, -200)], const Color(0xFF7F7A84)),
    rock(const <Offset>[Offset(120, -380), Offset(280, -360), Offset(400, -250), Offset(300, -230), Offset(190, -300)], const Color(0xFF7A7580)),
    // Turf along the top.
    Shape(Paths.smooth(const <Offset>[Offset(-300, -350), Offset(-190, -428), Offset(40, -448), Offset(250, -398), Offset(180, -380), Offset(30, -420), Offset(-180, -402)]), color: const Color(0xFF55703E)),
    // Cracks.
    Shape(Path()..moveTo(-380, -60)..lineTo(-340, -150)..lineTo(-360, -230), stroke: const Color(0x44181820), strokeWidth: 5),
    Shape(Path()..moveTo(360, -50)..lineTo(330, -140)..lineTo(350, -210), stroke: const Color(0x44181820), strokeWidth: 5),
    // The mouth.
    Shape(Paths.smooth(const <Offset>[Offset(-190, 0), Offset(-196, -150), Offset(-120, -270), Offset(0, -310), Offset(120, -270), Offset(196, -150), Offset(190, 0)]), color: const Color(0xFF14111A)),
  ]);
  final double g = glow.clamp(0.0, 1.0);
  return Stack(clipBehavior: Clip.none, children: <Widget>[
    Drawing(hill, light: light),
    // Firelight: a warm glow in the mouth, a little unsteady.
    CustomPaint(painter: _CaveGlow(at, size, g * Fire.flicker(t, seed: 5))),
    if (g > 0) Opacity(opacity: g, child: Fire(base: at + Offset(0, -6 * size), size: fire * size, strength: g, seed: 4)),
  ]);
}

class _CaveGlow extends CustomPainter {
  const _CaveGlow(this.at, this.size, this.glow);

  final Offset at;
  final double size, glow;

  @override
  void paint(Canvas canvas, Size s) {
    if (glow <= 0) return;
    final Rect r = Rect.fromCenter(center: at + Offset(0, -120 * size), width: 520 * size, height: 460 * size);
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCenter(center: at + Offset(0, -150 * size), width: 380 * size, height: 310 * size))
      ..addRect(Rect.fromLTWH(at.dx - 190 * size, at.dy - 150 * size, 380 * size, 150 * size)));
    canvas.drawRect(
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: <Color>[const Color(0xFFFFB45A).withValues(alpha: 0.7 * glow), const Color(0xFFFF7A2A).withValues(alpha: 0.25 * glow), const Color(0x00FF7A2A)],
          stops: const <double>[0, 0.5, 1],
        ).createShader(Rect.fromCenter(center: at + Offset(0, -20 * size), width: 440 * size, height: 440 * size)),
    );
    canvas.restore();
    // Spill onto the ground outside.
    canvas.drawOval(
      Rect.fromCenter(center: at + Offset(0, 14 * size), width: 560 * size, height: 70 * size),
      Paint()..color = const Color(0xFFFFA84A).withValues(alpha: 0.2 * glow),
    );
  }

  @override
  bool shouldRepaint(_CaveGlow old) => old.glow != glow || old.at != at;
}

// --- shot 5: get out of the wet ---

const int _shot5 = 4, _line5 = 4;

// Where the band ends up: gathered at the mouth of the cave.
const double _caveX = 2150;

final List<(Character, double, double, double)> _runners = <(Character, double, double, double)>[
  // character, start x, finish x, seconds
  (eda, 330, 1560, 4.3),
  (ama, 450, 1710, 3.9),
  (tor, 640, 1990, 3.7),
  (bran, 520, 2110, 4.1),
  (kito, 950, 1850, 3.8),
];

const double _runScale = 1.05;

final List<Walk> _runs = <Walk>[
  for (final (Character c, double x0, double x1, double sec) in _runners)
    Walk(
      rig: c.part,
      route: Performance(fps: rainFps, startX: x0, beats: <Beat>[Move(x1, at: 0.1, seconds: sec, curve: Curves.linear)]).route,
      groundY: _ground,
      fps: rainFps.toInt(),
      scale: _runScale,
      body: c.biped,
      running: true,
    ),
];

class CaveShot extends StatelessWidget {
  const CaveShot({super.key});

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = secondsOf(context);
    int f(double s) => (s * rainFps).round();

    final double wetWord = saidAt(_shot5, _line5, 9), steal = saidAt(_shot5, _line5, 11), kill = saidAt(_shot5, _line5, 21);
    const double h = 0.8, storm = 0.95;
    final Light light = skyLight(h, storm);
    final double glow = along(t, 1.2, 2.5);
    // Body heat: all there until the clothes begin to steal it, then going.
    final double heat = 1 - 0.86 * along(t, steal, kill - steal + 0.4, Curves.easeIn);
    final int kitoAt = _runners.indexWhere((r) => r.$1 == kito);
    final double kx = _runs[kitoAt].xAt(frame);

    return Stack(fit: StackFit.expand, children: <Widget>[
      Camera(
        keyframes: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(1000, 640)),
          CameraKeyframe(f(3.2), center: const Offset(1620, 650), curve: Curves.easeInOutSine),
          CameraKeyframe(f(wetWord - 0.5), center: const Offset(1620, 650), curve: Curves.easeInOutSine),
          CameraKeyframe(f(wetWord + 1.0), center: Offset(_runners[kitoAt].$3 - 60, 760), zoom: 1.9, curve: Curves.easeInOutCubic),
          CameraKeyframe(rainLengths[_shot5], center: Offset(_runners[kitoAt].$3 - 40, 770), zoom: 2.05, curve: Curves.linear),
        ],
        child: Stack(fit: StackFit.expand, children: <Widget>[
          ...valleyLayers(
            context,
            h: h,
            storm: storm,
            riverRise: 20,
            rain: 1,
            foreground: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: <Widget>[
              _cave(const Offset(_caveX, _ground + 8), 1.0, glow, light, t),
              const RainSplash(left: -500, right: 2600, top: 900, bottom: 1060, count: 200),
              CustomPaint(painter: _HeatAura(Offset(kx, _ground - 100), heat, along(t, steal - 0.4, 0.6))),
              for (int i = 0; i < _runs.length; i++) _runner(i, frame, light, t, heat),
            ]),
          ),
        ]),
      ),
      const Rain(slant: 14),
      _DayCard(t: t, until: saidAt(_shot5, _line5, 2) + 0.3),
    ]);
  }

  Widget _runner(int i, int frame, Light light, double t, double heat) {
    final Character c = _runners[i].$1;
    final bool child = c == kito;
    final Posed p = followThrough(
      (int fr) => _runs[i].at(
        fr,
        adjust: (Pose pose) {
          final double sh = math.sin(fr * 1.9 + i * 2.7) * 0.7;
          // Once stopped they huddle; the child shivers harder as heat goes.
          final double cold = child ? (1 - heat) : 0.4;
          return pose.plus(c.stance).plus(c.life(i + 3).at(fr, rainFps)).plus(Pose(<String, Joint>{
            'chest': Joint.rotate(sh * (0.4 + cold * 1.6)),
          }));
        },
      ),
      frame,
      jiggles: c.jiggles,
      fps: rainFps.toInt(),
    );
    return Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: <Widget>[
      Drawing(groundShadow(_runs[i].xAt(frame), 90, y: _ground + 4)),
      wet(Drawing(p.part, pose: p.pose, light: light), 1),
      if (child) CustomPaint(painter: _Drips(Offset(_runs[i].xAt(frame), _ground - 70), t)),
    ]);
  }
}

/// A ring of warmth round a body, drawn as light: a glow, a ring, a label.
/// Warm and wide when [heat] is 1, small and blue when it is gone.
class _HeatAura extends CustomPainter {
  const _HeatAura(this.at, this.heat, this.show);

  final Offset at;
  final double heat, show;

  @override
  void paint(Canvas canvas, Size size) {
    if (show <= 0) return;
    final Color c = _mix(const Color(0xFF55A0FF), const Color(0xFFFFA23A), heat);
    final double r = 55 + 105 * heat;
    canvas.drawCircle(
      at,
      r * 1.25,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: <Color>[c.withValues(alpha: 0.5 * show), c.withValues(alpha: 0.14 * show), c.withValues(alpha: 0)], stops: const <double>[0, 0.6, 1]).createShader(Rect.fromCircle(center: at, radius: r * 1.25)),
    );
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = c.withValues(alpha: 0.85 * show),
    );
    // Ticks round the ring, thinning out as heat goes.
    final int n = (6 + 26 * heat).round();
    for (int i = 0; i < n; i++) {
      final double a = i / n * math.pi * 2;
      canvas.drawLine(at + Offset(math.cos(a), math.sin(a)) * (r + 10), at + Offset(math.cos(a), math.sin(a)) * (r + 26), Paint()..strokeWidth = 4..strokeCap = StrokeCap.round..color = c.withValues(alpha: 0.7 * show));
    }
    final TextPainter tp = TextPainter(
      text: TextSpan(text: 'BODY HEAT', style: TextStyle(fontFamily: 'Roboto', fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 5, color: c.withValues(alpha: show), shadows: const <Shadow>[Shadow(color: Color(0xAA0A0A18), blurRadius: 8)])),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at + Offset(-tp.width / 2, -r - 54));
  }

  @override
  bool shouldRepaint(_HeatAura old) => old.heat != heat || old.show != show || old.at != at;
}

/// Water running off a soaked hem: drops falling and gathering.
class _Drips extends CustomPainter {
  const _Drips(this.at, this.t);

  final Offset at;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 9; i++) {
      final double age = (t * 1.3 + i * 0.37) % 1;
      final Offset p = at + Offset(-60 + i * 15.0 + math.sin(i * 7.0) * 6, age * age * 64);
      canvas.drawOval(Rect.fromCenter(center: p, width: 5, height: 10), Paint()..color = const Color(0xFFB8D4F0).withValues(alpha: (1 - age) * 0.8));
    }
  }

  @override
  bool shouldRepaint(_Drips old) => old.t != t || old.at != at;
}

/// "DAY 1" and its first tally mark, over the opening of the shot.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.t, required this.until});

  final double t, until;

  @override
  Widget build(BuildContext context) {
    final double inn = along(t, 0.1, 0.5, Curves.easeOutBack), out = along(t, until, 0.5);
    final double o = (inn.clamp(0.0, 1.0) * (1 - out));
    if (o <= 0) return const SizedBox.shrink();
    return Positioned(
      left: 120,
      top: 90,
      child: Opacity(
        opacity: o,
        child: Transform.translate(
          offset: Offset(0, (1 - inn) * 30),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
            const Text('DAY', style: TextStyle(fontSize: 120, fontWeight: FontWeight.w900, letterSpacing: 10, color: Color(0xFFFFF0D2), shadows: <Shadow>[Shadow(color: Color(0xCC0A0A18), blurRadius: 16)])),
            const SizedBox(width: 40),
            CustomPaint(size: const Size(40, 120), painter: _OneMark(along(t, 0.5, 0.4))),
          ]),
        ),
      ),
    );
  }
}

class _OneMark extends CustomPainter {
  const _OneMark(this.p);

  final double p;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawLine(
        const Offset(20, 4),
        Offset(20, 4 + 112 * p),
        Paint()
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFF2B84B),
      );

  @override
  bool shouldRepaint(_OneMark old) => old.p != p;
}

// --- shot 6: a cave, a frame of branches, a frame of bones ---

const int _shot6 = 5, _line6 = 5;

const double _caveAt = 520, _branchAt = 1650, _boneAt = 2850;

class HutsShot extends StatelessWidget {
  const HutsShot({super.key});

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = secondsOf(context);
    int f(double s) => (s * rainFps).round();
    double w(int word) => saidAt(_shot6, _line6, word);

    // Night falls, a little: the storm is still on but firelight takes over.
    const double h = 0.86, storm = 0.9;
    final Light light = skyLight(h, storm);

    final double frameUp = along(t, w(10) - 0.2, w(13) - w(10) + 0.8, Curves.easeInOut); // branches stand
    final double bonesUp = along(t, w(15) - 0.2, w(17) - w(15) + 1.2, Curves.easeInOut); // bones stack
    final double covered = along(t, w(18) - 0.1, w(20) - w(18) + 0.7, Curves.easeInOut); // hides go over
    final double lit = along(t, w(26), 1.0);

    return Stack(fit: StackFit.expand, children: <Widget>[
      Camera(
        keyframes: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(_caveAt + 100, 680), zoom: 1.15),
          CameraKeyframe(f(w(5)), center: const Offset(_caveAt + 100, 680), zoom: 1.2, curve: Curves.linear),
          CameraKeyframe(f(w(9)) + 20, center: const Offset(_branchAt, 690), zoom: 1.35, curve: Curves.easeInOutCubic),
          CameraKeyframe(f(w(14)), center: const Offset(_branchAt + 60, 690), zoom: 1.35, curve: Curves.linear),
          CameraKeyframe(f(w(15)) + 22, center: const Offset(_boneAt, 690), zoom: 1.3, curve: Curves.easeInOutCubic),
          CameraKeyframe(f(w(20)), center: const Offset(_boneAt, 700), zoom: 1.25, curve: Curves.linear),
          CameraKeyframe(f(w(21)) + 14, center: const Offset(2080, 640), zoom: 0.6, curve: Curves.easeInOutCubic),
          CameraKeyframe(rainLengths[_shot6], center: const Offset(2080, 640), zoom: 0.63, curve: Curves.linear),
        ],
        child: Stack(fit: StackFit.expand, children: <Widget>[
          ...valleyLayers(
            context,
            h: h,
            storm: storm,
            riverRise: 20,
            rain: 1,
            foreground: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: <Widget>[
              _cave(const Offset(_caveAt, _ground + 8), 0.9, 1, light, t),
              _BranchHut(at: Offset(_branchAt, _ground + 6), up: frameUp, covered: covered, light: light, t: t, lit: lit),
              _BoneHut(at: Offset(_boneAt, _ground + 6), up: bonesUp, covered: covered, light: light, t: t, lit: lit),
              _Onlookers(frame: frame, light: light, show: along(t, w(21), 0.8)),
              const RainSplash(left: -500, right: 4200, top: 900, bottom: 1060, count: 260),
              _Mark(label: 'MEZHYRICH, UKRAINE', at: const Offset(_boneAt, 420), show: along(t, w(22) - 0.1, 0.6)),
            ]),
          ),
        ]),
      ),
      const Rain(slant: 14),
    ]);
  }
}

/// A small caption pinned in the world: a line, and the words on it.
class _Mark extends StatelessWidget {
  const _Mark({required this.label, required this.at, required this.show});

  final String label;
  final Offset at;
  final double show;

  @override
  Widget build(BuildContext context) {
    final double s = show.clamp(0.0, 1.0);
    if (s <= 0) return const SizedBox.shrink();
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      CustomPaint(painter: _PinPainter(at, s)),
      Positioned(
        left: at.dx - 320,
        top: at.dy - 90,
        width: 640,
        child: Opacity(
          opacity: s,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: 7, color: Color(0xFFFFF0D2), shadows: <Shadow>[Shadow(color: Color(0xCC0A0A18), blurRadius: 12)]),
          ),
        ),
      ),
    ]);
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter(this.at, this.s);

  final Offset at;
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = const Color(0xFFF2B84B)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(at + const Offset(0, -20), at + Offset(0, -20 + 150 * s), p);
    canvas.drawCircle(at + Offset(0, -20 + 150 * s), 11, p);
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.s != s;
}

/// A dome of branches, bent over and tied: poles grow from the ground one by
/// one, a binding goes round them, then hides drape over the top.
class _BranchHut extends StatelessWidget {
  const _BranchHut({required this.at, required this.up, required this.covered, required this.light, required this.t, required this.lit});

  final Offset at;
  final double up, covered, lit, t;
  final Light light;

  static const int _poles = 9;
  static const double _w = 240, _hgt = 330;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      CustomPaint(painter: _PolesPainter(at, up, covered)),
      if (covered > 0) Drawing(_hideCover(at, _w + 40, _hgt + 20, covered, 3), light: light),
      // A doorway of light in the front once it is covered.
      CustomPaint(painter: _DoorGlow(at + const Offset(40, 0), 0.9, covered * lit)),
    ]);
  }
}

class _PolesPainter extends CustomPainter {
  const _PolesPainter(this.at, this.up, this.covered);

  final Offset at;
  final double up, covered;

  @override
  void paint(Canvas canvas, Size size) {
    if (covered >= 1) return;
    final Paint pole = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6B4A2C);
    final Paint hi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9A7448);
    for (int i = 0; i < _BranchHut._poles; i++) {
      final double u = i / (_BranchHut._poles - 1);
      // Each pole starts a moment after the last.
      final double p = ((up * 1.6 - u * 0.6)).clamp(0.0, 1.0);
      final double x0 = -_BranchHut._w + u * 2 * _BranchHut._w;
      final Path path = Path()
        ..moveTo(at.dx + x0, at.dy)
        ..quadraticBezierTo(at.dx + x0 * 0.95, at.dy - _BranchHut._hgt * 1.05, at.dx + x0 * 0.1, at.dy - _BranchHut._hgt);
      for (final ui.PathMetric m in path.computeMetrics()) {
        final Path part = m.extractPath(0, m.length * Curves.easeOutBack.transform(p).clamp(0.0, 1.0));
        canvas.drawPath(part, pole);
        canvas.drawPath(part, hi..strokeWidth = 3);
      }
    }
    // Two bindings round the middle, drawn once the poles are up.
    final double bind = ((up - 0.7) / 0.3).clamp(0.0, 1.0);
    if (bind > 0) {
      for (final double hh in <double>[0.35, 0.65]) {
        final double half = _BranchHut._w * (1 - hh) * 0.95;
        canvas.drawLine(at + Offset(-half * bind, -_BranchHut._hgt * hh), at + Offset(half * bind, -_BranchHut._hgt * hh), Paint()..strokeWidth = 6..strokeCap = StrokeCap.round..color = const Color(0xFFC9B070));
      }
    }
  }

  @override
  bool shouldRepaint(_PolesPainter old) => old.up != up || old.covered != covered || old.at != at;
}

/// Hides stitched into a dome over a frame, hanging from the apex: [grow] is
/// how much of the drop has come down.
Part _hideCover(Offset at, double halfW, double height, double grow, int seed) {
  final double g = Curves.easeOutCubic.transform(grow.clamp(0.0, 1.0));
  final math.Random r = math.Random(seed);
  // The hem, ragged, going round the base of the dome.
  final List<Offset> edge = <Offset>[];
  const int n = 14;
  for (int i = 0; i <= n; i++) {
    final double u = i / n;
    edge.add(Offset(-halfW + u * 2 * halfW, 0));
  }
  final Path dome = Path()..moveTo(-halfW, 0);
  dome.cubicTo(-halfW * 1.02, -height * 0.7, -halfW * 0.4, -height * 1.02, 0, -height);
  dome.cubicTo(halfW * 0.4, -height * 1.02, halfW * 1.02, -height * 0.7, halfW, 0);
  for (int i = n; i >= 0; i--) {
    dome.lineTo(edge[i].dx + (r.nextDouble() - 0.5) * 14, (i.isEven ? 8 : -6) + r.nextDouble() * 6);
  }
  dome.close();
  const List<Color> hides = <Color>[Color(0xFF8A5E3A), Color(0xFF6A4426), Color(0xFFA67A4A)];
  return Part(at: at + Offset(0, -height), scaleY: g, opacity: g > 0 ? 1 : 0, children: <Part>[
    Part(at: Offset(0, height), shapes: <Shape>[
      Shape(dome, color: hides[0], shade: const Shade(form: 0.55, core: 0.4, coreStrength: 0.7, rim: 0.1, rimStrength: 0.4)),
      // Patches, each a different hide, with stitching round them.
      for (int i = 0; i < 6; i++) ...<Shape>[
        Shape(
          Paths.smooth(<Offset>[
            Offset(-halfW * 0.7 + i * halfW * 0.28, -height * (0.22 + (i % 3) * 0.2)) + const Offset(-50, -34),
            Offset(-halfW * 0.7 + i * halfW * 0.28, -height * (0.22 + (i % 3) * 0.2)) + const Offset(46, -40),
            Offset(-halfW * 0.7 + i * halfW * 0.28, -height * (0.22 + (i % 3) * 0.2)) + const Offset(52, 30),
            Offset(-halfW * 0.7 + i * halfW * 0.28, -height * (0.22 + (i % 3) * 0.2)) + const Offset(-44, 36),
          ]),
          color: hides[(i + 1) % 3],
        ),
        Shape(
          Paths.smooth(<Offset>[
            Offset(-halfW * 0.7 + i * halfW * 0.28, -height * (0.22 + (i % 3) * 0.2)) + const Offset(-50, -34),
            Offset(-halfW * 0.7 + i * halfW * 0.28, -height * (0.22 + (i % 3) * 0.2)) + const Offset(46, -40),
            Offset(-halfW * 0.7 + i * halfW * 0.28, -height * (0.22 + (i % 3) * 0.2)) + const Offset(52, 30),
            Offset(-halfW * 0.7 + i * halfW * 0.28, -height * (0.22 + (i % 3) * 0.2)) + const Offset(-44, 36),
          ]),
          stroke: const Color(0x88201208),
          strokeWidth: 3,
        ),
      ],
      Shape(Path()..moveTo(0, -height)..quadraticBezierTo(18, -height * 0.5, 4, 0), stroke: const Color(0x66201208), strokeWidth: 4),
    ]),
  ]);
}

class _DoorGlow extends CustomPainter {
  const _DoorGlow(this.at, this.scale, this.glow);

  final Offset at;
  final double scale, glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (glow <= 0) return;
    final Rect door = Rect.fromLTWH(at.dx - 40 * scale, at.dy - 120 * scale, 80 * scale, 120 * scale);
    canvas.drawRRect(
      RRect.fromRectAndCorners(door, topLeft: Radius.circular(40 * scale), topRight: Radius.circular(40 * scale)),
      Paint()..color = Color.lerp(const Color(0xFF14101A), const Color(0xFFFFB45A), 0.8 * glow)!,
    );
    canvas.drawCircle(
      at + Offset(0, -60 * scale),
      220 * scale,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: <Color>[const Color(0xFFFFA84A).withValues(alpha: 0.35 * glow), const Color(0x00FFA84A)]).createShader(Rect.fromCircle(center: at + Offset(0, -60 * scale), radius: 220 * scale)),
    );
  }

  @override
  bool shouldRepaint(_DoorGlow old) => old.glow != glow || old.at != at;
}

/// A mammoth-bone hut, as dug up at Mezhyrich: a ring of skulls at the base,
/// long bones leaning in, tusks arched over the door. Each piece drops into
/// place in turn; then the hides go over.
class _BoneHut extends StatelessWidget {
  const _BoneHut({required this.at, required this.up, required this.covered, required this.light, required this.t, required this.lit});

  final Offset at;
  final double up, covered, lit, t;
  final Light light;

  static const double _w = 300, _hgt = 360;

  @override
  Widget build(BuildContext context) {
    const Color ivory = Color(0xFFE2D8BE);
    const Shade bone = Shade(form: 0.45, core: 0.35, coreStrength: 0.6, rim: 0.1, rimStrength: 0.5);
    // Piece number [i] of [n]: how far through its drop it is.
    double piece(int i, int n) => Curves.easeOutBack.transform(((up * 1.5 - i / n * 0.5)).clamp(0.0, 1.0));

    final List<Part> parts = <Part>[];
    const int skulls = 5;
    for (int i = 0; i < skulls; i++) {
      final double x = -_w * 0.9 + i * (_w * 1.8 / (skulls - 1));
      final double p = piece(i, 17);
      parts.add(Part(at: Offset(x, -40 - (1 - p) * 420), opacity: p.clamp(0.0, 1.0), children: <Part>[
        Part(shapes: <Shape>[
          Shape(Paths.ellipse(Offset.zero, 62, 46), color: const Color(0xFFD9CFB8), shade: bone),
          Shape(Paths.ellipse(const Offset(-8, -14), 36, 22), color: const Color(0xFFEDE4CC), shade: Shade.gentle),
          Shape(Paths.ellipse(const Offset(26, 6), 10, 12), color: const Color(0xFF2A2420)),
          // The tusk, curling out and up.
          Shape(Path()..moveTo(34, 18)..quadraticBezierTo(90, 60, 60, -40), stroke: ivory, strokeWidth: 16),
        ]),
      ]));
    }
    // Long bones leaning in from both sides.
    for (int i = 0; i < 8; i++) {
      final bool left = i.isEven;
      final int k = i ~/ 2;
      final double p = piece(5 + i, 17);
      final double x = (left ? -1 : 1) * (_w * 0.78 - k * 52.0);
      parts.add(Part(
        at: Offset(x, -100 - (1 - p) * 460),
        degrees: (left ? 1 : -1) * (8 + k * 11.0),
        opacity: p.clamp(0.0, 1.0),
        shapes: <Shape>[
          Shape(Paths.capsule(const Offset(0, 0), Offset(0, -(190 + k * 22.0)), 20), color: ivory, shade: bone),
          Shape(Paths.circle(const Offset(-8, 2), 17), color: ivory, shade: Shade.solid),
          Shape(Paths.circle(const Offset(10, 4), 16), color: ivory, shade: Shade.solid),
        ],
      ));
    }
    // Tusks as the roof beams: two arches over the middle.
    for (int i = 0; i < 4; i++) {
      final double p = piece(13 + i, 17);
      final double side = i.isEven ? -1 : 1;
      parts.add(Part(at: Offset(side * (50 + (i ~/ 2) * 100.0), -120 - (1 - p) * 420), scaleX: side * 0.62, scaleY: 0.62, opacity: p.clamp(0.0, 1.0), shapes: <Shape>[
        Shape(
          Paths.smooth(const <Offset>[Offset(0, 0), Offset(40, -60), Offset(60, -130), Offset(50, -200), Offset(30, -260), Offset(46, -266), Offset(78, -200), Offset(86, -130), Offset(66, -50), Offset(14, 14)]),
          color: ivory,
          shade: bone,
        ),
      ]));
    }
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      Drawing(Part(at: at, children: parts), light: light),
      if (covered > 0) Drawing(_hideCover(at, _w + 40, _hgt, covered, 8), light: light),
      CustomPaint(painter: _DoorGlow(at + const Offset(60, 0), 1.05, covered * lit)),
      // Smoke from the hole in the top.
      if (lit > 0) Opacity(opacity: lit, child: CustomPaint(painter: _SmokePlume(at + const Offset(0, -_hgt + 20), t))),
    ]);
  }
}

class _SmokePlume extends CustomPainter {
  const _SmokePlume(this.at, this.t);

  final Offset at;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 9; i++) {
      final double age = (t * 0.3 + i / 9) % 1;
      canvas.drawCircle(
        at + Offset(math.sin(age * 5 + i) * 16 + age * 60, -age * 260),
        14 + age * 52,
        Paint()..color = const Color(0xFFD8D4DC).withValues(alpha: (1 - age) * 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(_SmokePlume old) => old.t != t;
}

/// Three of the band by the new hut, shoulders up against the wet.
class _Onlookers extends StatelessWidget {
  const _Onlookers({required this.frame, required this.light, required this.show});

  final int frame;
  final Light light;
  final double show;

  static const List<(Character, double, double)> _who = <(Character, double, double)>[
    (tor, 3270, 0.95),
    (kito, 3360, 0.85),
    (ama, 3440, 0.95),
  ];

  @override
  Widget build(BuildContext context) {
    final double o = show.clamp(0.0, 1.0);
    if (o <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: o,
      child: Stack(clipBehavior: Clip.none, children: <Widget>[
        for (int i = 0; i < _who.length; i++) _one(i),
      ]),
    );
  }

  Widget _one(int i) {
    final (Character c, double x, double s) = _who[i];
    final double shiver = math.sin(frame * 1.9 + i * 2.7) * 0.7;
    final Pose pose = c.stance.plus(c.life(i + 30).at(frame, rainFps)).plus(Pose(<String, Joint>{'chest': Joint.rotate(7 + shiver), 'head': Joint.rotate(5 - shiver * 0.5)}));
    final Posed p = followThrough((int f) => Posed(stand(c, x, _ground + 4, s), pose), frame, jiggles: c.jiggles, fps: rainFps.toInt());
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      Drawing(groundShadow(x, 80 * s, y: _ground + 7)),
      wet(Drawing(p.part, pose: p.pose, light: light), 1),
    ]);
  }
}
