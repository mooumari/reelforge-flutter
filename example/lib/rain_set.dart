import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

/// An Ice Age valley, as layers: a sky that keeps time, clouds, glacier
/// mountains, tundra, spruce, a river and a mammoth herd.
///
/// The time of day is a number, [h], 0 to 1: 0 is midnight, 0.25 dawn, 0.5
/// noon, 0.75 dusk. [storm], 0 to 1, is how overcast it is. Sky, clouds and
/// the tone laid over the land all follow the pair, so a day can be sped
/// through by turning the one number.

const double valleyGround = 960;

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;
Color _dark(Color c, double t) => _mix(c, const Color(0xFF0C1020), t);
Color _light(Color c, double t) => _mix(c, const Color(0xFFFFFFFF), t);

// --- time of day ---

typedef _Stop = (double, Color, Color, Color);

/// Hour, sky at the top, sky at the horizon, and the tone the land takes.
const List<_Stop> _hours = <_Stop>[
  (0.00, Color(0xFF0A0F2E), Color(0xFF1B2658), Color(0xFF3A4A8C)),
  (0.20, Color(0xFF1E2358), Color(0xFF8A5A8A), Color(0xFF6A6EA8)),
  (0.28, Color(0xFF4A5C98), Color(0xFFF0A67A), Color(0xFFE8C0A8)),
  (0.40, Color(0xFF5C88BC), Color(0xFFC4DCEC), Color(0xFFFFFFFF)),
  (0.60, Color(0xFF5A86BA), Color(0xFFC0D8EA), Color(0xFFFFFFFF)),
  (0.72, Color(0xFF5A68A8), Color(0xFFF2B07C), Color(0xFFF4C8A4)),
  (0.80, Color(0xFF38306E), Color(0xFFDE6E5E), Color(0xFFA888A8)),
  (0.90, Color(0xFF141844), Color(0xFF4A3478), Color(0xFF4E5A98)),
  (1.00, Color(0xFF0A0F2E), Color(0xFF1B2658), Color(0xFF3A4A8C)),
];

(Color, Color, Color) _sky(double h) {
  final double x = h - h.floorToDouble();
  for (int i = 1; i < _hours.length; i++) {
    if (x <= _hours[i].$1) {
      final _Stop a = _hours[i - 1], b = _hours[i];
      final double t = Curves.easeInOut.transform((x - a.$1) / (b.$1 - a.$1));
      return (_mix(a.$2, b.$2, t), _mix(a.$3, b.$3, t), _mix(a.$4, b.$4, t));
    }
  }
  return (_hours.last.$2, _hours.last.$3, _hours.last.$4);
}

/// How much daylight there is at [h], 0 at night and 1 at noon.
double daylight(double h) {
  final double x = h - h.floorToDouble();
  return (math.sin((x - 0.25) * 2 * math.pi) * 0.5 + 0.55).clamp(0.0, 1.0);
}

/// The sky colours at [h] under [storm]: steel grey and flat when it is
/// overcast, dimmer the heavier the cloud.
(Color, Color) skyColors(double h, double storm) {
  final (Color top, Color bottom, Color _) = _sky(h);
  final double day = daylight(h);
  final Color greyTop = _mix(const Color(0xFF1C2638), const Color(0xFF52667C), day);
  final Color greyBottom = _mix(const Color(0xFF2E3E52), const Color(0xFF90A4B2), day);
  return (_mix(top, greyTop, storm * 0.85), _mix(bottom, greyBottom, storm * 0.85));
}

/// The tone laid over the land -- multiplied in -- at [h] under [storm].
Color landTone(double h, double storm) {
  final (Color _, Color _, Color tone) = _sky(h);
  final double day = daylight(h);
  final Color grey = _mix(const Color(0xFF50607A), const Color(0xFFB4C2D0), day);
  return _mix(tone, grey, storm * 0.75);
}

/// The light on people, from the sky, at [h] under [storm]: cool and soft
/// when it is overcast, bluer at night.
Light skyLight(double h, double storm) {
  final double day = daylight(h);
  return Light(
    from: const Offset(-0.35, -0.9),
    shadow: _mix(const Color(0xFF3C4A8A), const Color(0xFF7A84B8), day),
    highlight: _mix(const Color(0xFF8AA0E0), const Color(0xFFE6F0FF), day),
    cast: const Color(0xFF141C3A),
  );
}

// --- the sky itself ---

/// Sky, sun, moon and stars at [h] and [storm], over the whole frame.
class IceSky extends StatelessWidget {
  const IceSky({super.key, required this.h, this.storm = 0, this.horizon = 700});

  final double h, storm, horizon;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.infinite, painter: _SkyPainter(h, storm, horizon));
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.h, this.storm, this.horizon);

  final double h, storm, horizon;

  @override
  void paint(Canvas canvas, Size size) {
    final (Color top, Color bottom) = skyColors(h, storm);
    final Rect all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[top, bottom], stops: const <double>[0.1, 0.72]).createShader(all),
    );
    final double day = daylight(h);
    final double clear = 1 - storm;

    // Stars, when it is dark and clear.
    final double dark = (1 - day * 1.6).clamp(0.0, 1.0) * clear;
    if (dark > 0) {
      final math.Random r = math.Random(5);
      for (int i = 0; i < 90; i++) {
        final double x = r.nextDouble() * size.width, y = r.nextDouble() * horizon * 0.9, s = 0.8 + r.nextDouble() * 1.8;
        final double tw = 0.6 + 0.4 * math.sin(h * 140 + i);
        canvas.drawCircle(Offset(x, y), s, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: dark * tw * (0.4 + r.nextDouble() * 0.6)));
      }
    }

    // Sun and moon ride the same arc, twelve hours apart.
    void body(double phase, Color core, Color halo, double radius, double glow) {
      final double a = (phase - 0.25) / 0.5 * math.pi;
      if (phase < 0.16 || phase > 0.84) return;
      final Offset at = Offset(size.width * 0.5 - math.cos(a) * size.width * 0.5, horizon - math.sin(a) * (horizon - 150));
      canvas.drawCircle(
        at,
        radius * 4.2,
        Paint()..shader = RadialGradient(colors: <Color>[halo.withValues(alpha: glow), halo.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: at, radius: radius * 4.2)),
      );
      canvas.drawCircle(at, radius, Paint()..color = core);
    }

    final double x = h - h.floorToDouble();
    final double sunWarmth = (1 - (math.sin((x - 0.25) * 2 * math.pi)).abs()).clamp(0.0, 1.0);
    body(x, _mix(const Color(0xFFFFF3C8), const Color(0xFFFFB070), sunWarmth), const Color(0xFFFFD090), 70, 0.5 * clear + 0.12);
    body((x + 0.5) - (x + 0.5).floorToDouble(), const Color(0xFFE8EEFF), const Color(0xFF9AB0E8), 44, 0.32 * clear + 0.06);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.h != h || old.storm != storm || old.horizon != horizon;
}

// --- clouds ---

/// Clouds drifting across, as many and as dark as [storm] says: a few small
/// bright ones when it is fine, a low grey lid when it is not.
class IceClouds extends StatelessWidget {
  const IceClouds({super.key, required this.h, required this.storm, this.speed = 1});

  final double h, storm, speed;

  @override
  Widget build(BuildContext context) {
    final double t = Video.frame(context) / Video.fps(context);
    return CustomPaint(size: Size.infinite, painter: _CloudPainter(t * speed, h, storm));
  }
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter(this.t, this.h, this.storm);

  final double t, h, storm;

  @override
  void paint(Canvas canvas, Size size) {
    final (Color top, Color bottom) = skyColors(h, storm);
    final double day = daylight(h);
    // Fine-weather cloud is bright; storm cloud is the dark of the sky it is in.
    final Color fine = _mix(_light(bottom, 0.15), const Color(0xFFF4F4FF), day * 0.7);
    final Color heavy = _mix(_dark(top, 0.25), _dark(bottom, 0.1), 0.4);
    final Color body = _mix(fine, heavy, storm);

    // Layers: far and small and pale, to near and large and heavy.
    for (int layer = 0; layer < 3; layer++) {
      final math.Random r = math.Random(40 + layer);
      final int count = (4 + layer * 3 + storm * (4 + layer * 5)).round();
      final double drift = (14 + layer * 16) * (1 + storm * 0.6);
      final double wide = size.width + 900;
      for (int i = 0; i < count; i++) {
        final double x = ((r.nextDouble() * wide + t * drift) % wide) - 450;
        final double y = 80 + layer * 80 + r.nextDouble() * (150 + storm * 90) - storm * layer * 30;
        final double s = (0.7 + r.nextDouble() * 0.9) * (0.8 + layer * 0.35) * (1 + storm * 0.5);
        final double alpha = (0.5 + layer * 0.2) * (0.3 + storm * 0.7 + (1 - storm) * 0.45).clamp(0.0, 1.0);
        _cloud(canvas, Offset(x, y), s, body, alpha, storm);
      }
    }
  }

  /// A flat-bottomed cloud of overlapping puffs, shaded under and lit on
  /// top. Drawn opaque into a layer of its own and laid down at [alpha], so
  /// the puffs do not show through one another.
  void _cloud(Canvas canvas, Offset at, double s, Color body, double alpha, double storm) {
    final Rect bounds = Rect.fromCenter(center: at + Offset(0, -20 * s), width: 380 * s, height: 220 * s);
    canvas.saveLayer(bounds, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha));
    const List<(double, double, double)> puffs = <(double, double, double)>[
      (-120, 0, 52), (-62, -26, 68), (6, -40, 80), (74, -22, 66), (128, 4, 50), (-30, 6, 60), (46, 8, 58),
    ];
    final Paint fill = Paint()..color = body;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(at.dx - 150 * s, at.dy - 6 * s, at.dx + 150 * s, at.dy + 34 * s), Radius.circular(34 * s)),
      fill,
    );
    for (final (double dx, double dy, double r) in puffs) {
      canvas.drawCircle(at + Offset(dx * s, dy * s), r * s, fill);
    }
    // Shade under, on the cloud only.
    canvas.drawRect(
      Rect.fromLTRB(bounds.left, at.dy + 4 * s, bounds.right, bounds.bottom),
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[_dark(body, 0).withValues(alpha: 0), _dark(body, 0.3)])
            .createShader(Rect.fromLTRB(bounds.left, at.dy + 4 * s, bounds.right, at.dy + 40 * s)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at + Offset(10 * s, -62 * s), width: 170 * s, height: 56 * s),
      Paint()
        ..blendMode = BlendMode.srcATop
        ..color = _light(body, 0.45).withValues(alpha: 0.5 * (1 - storm)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloudPainter old) => old.t != t || old.h != h || old.storm != storm;
}

// --- land ---

/// The mountains and the ice sheet behind them, pale with distance.
final Part valleyMountains = () {
  Part range(List<Offset> ridge, Color rock, Color snow, double snowline, double haze) {
    final Path body = Paths.polygon(<Offset>[...ridge, Offset(ridge.last.dx, 1100), Offset(ridge.first.dx, 1100)]);
    // Snow: the body above the snowline, with a ragged lower edge.
    final math.Random r = math.Random(ridge.length);
    final List<Offset> edge = <Offset>[
      for (double x = ridge.first.dx - 10; x <= ridge.last.dx + 10; x += 38) Offset(x, snowline + (r.nextDouble() - 0.4) * 46 + math.sin(x * 0.02) * 24),
    ];
    final Path cap = Path.combine(
      PathOperation.intersect,
      body,
      Paths.polygon(<Offset>[Offset(edge.first.dx, 0), Offset(edge.last.dx, 0), ...edge.reversed]),
    );
    // Each peak's far face, in shadow: from the summit down its right-hand
    // slope, which is what makes a triangle a mountain.
    final List<Path> faces = <Path>[];
    for (int i = 1; i < ridge.length - 1; i++) {
      final Offset p = ridge[i];
      if (p.dy >= ridge[i - 1].dy || p.dy >= ridge[i + 1].dy) continue;
      final Offset q = ridge[i + 1];
      faces.add(Path.combine(
        PathOperation.intersect,
        body,
        Paths.polygon(<Offset>[p, q, Offset(q.dx - 40, 1000), Offset(p.dx + (q.dx - p.dx) * 0.12, 1000)]),
      ));
    }
    final Path shadowed = faces.fold(Path(), (Path a, Path b) => Path.combine(PathOperation.union, a, b));
    return Part(shapes: <Shape>[
      Shape(
        body,
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[rock, _mix(rock, const Color(0xFFB8C8E0), haze)], stops: const <double>[0.2, 0.75]),
      ),
      Shape(shadowed, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[_dark(rock, 0.28).withValues(alpha: 0.7), _dark(rock, 0.1).withValues(alpha: 0)], stops: const <double>[0.1, 0.9])),
      Shape(cap, color: snow),
      Shape(Path.combine(PathOperation.intersect, cap, shadowed), color: _mix(snow, const Color(0xFF7C8CC0), 0.38)),
    ]);
  }

  return Part(children: <Part>[
    // The ice sheet: a long pale wall on the horizon.
    range(
      const <Offset>[
        Offset(-120, 640), Offset(120, 560), Offset(330, 590), Offset(580, 520), Offset(860, 566), Offset(1100, 530), Offset(1380, 580),
        Offset(1640, 536), Offset(1900, 590), Offset(2060, 560), Offset(2200, 600),
      ],
      const Color(0xFFA8BCD8),
      const Color(0xFFEEF4FF),
      620,
      0.5,
    ),
    // The peaks.
    range(
      const <Offset>[
        Offset(-140, 700), Offset(60, 560), Offset(190, 430), Offset(260, 470), Offset(380, 330), Offset(480, 420), Offset(560, 470),
        Offset(700, 600), Offset(900, 660), Offset(1160, 640), Offset(1300, 520), Offset(1420, 400), Offset(1500, 330), Offset(1610, 440),
        Offset(1760, 520), Offset(1860, 470), Offset(1960, 560), Offset(2100, 640),
      ],
      const Color(0xFF6E86AE),
      const Color(0xFFF6F8FF),
      520,
      0.3,
    ),
  ]);
}();

Part _spruce(Offset at, double scale, Color needles, {double lean = 0}) {
  const Shade shade = Shade(form: 0.4, core: 0.3, coreStrength: 0.55, rim: 0.08, rimStrength: 0.4);
  return Part(at: at, scaleX: scale, scaleY: scale, degrees: lean, shapes: <Shape>[
    Shape(Paths.rect(const Rect.fromLTRB(-7, -40, 7, 0)), color: const Color(0xFF3A2A22)),
    for (int i = 0; i < 5; i++)
      Shape(
        Paths.polygon(<Offset>[
          Offset(0, -240 + i * 38.0 - 30),
          Offset(66 - i * 4.0 + i * 14.0, -150 + i * 30.0 + (i > 2 ? 8 : 0)),
          Offset(30 + i * 8.0, -142 + i * 30.0),
          Offset(0, -150 + i * 30.0 + 22),
          Offset(-30 - i * 8.0, -142 + i * 30.0),
          Offset(-66 + i * 4.0 - i * 14.0, -150 + i * 30.0 + (i > 2 ? 8 : 0)),
        ]),
        color: _mix(needles, const Color(0xFFD8E8F0), i == 0 ? 0.24 : 0.06),
        shade: shade,
      ),
  ]);
}

/// A boulder, lit from the left.
Part _rock(Offset at, double scale, Color color) => Part(at: at, scaleX: scale, scaleY: scale, shapes: <Shape>[
      Shape(
        Paths.smooth(const <Offset>[Offset(-48, 0), Offset(-44, -28), Offset(-18, -46), Offset(20, -42), Offset(46, -20), Offset(50, 0)]),
        color: color,
        shade: const Shade(form: 0.45, core: 0.4, coreStrength: 0.7, rim: 0.1, rimStrength: 0.5),
      ),
    ]);

Part _tuft(Offset at, double scale, Color color) {
  final math.Random r = math.Random(at.dx.round() + 3);
  return Part(at: at, scaleX: scale, scaleY: scale, shapes: <Shape>[
    for (int i = 0; i < 7; i++)
      Shape(
        Paths.smooth(<Offset>[Offset(-5 + i * 2.2, 0), Offset(-22 + i * 7 + r.nextDouble() * 8, -26 - r.nextDouble() * 24), Offset(-1 + i * 2.2, 0)]),
        color: _mix(color, const Color(0xFFD6C27A), r.nextDouble() * 0.5),
      ),
  ]);
}

/// The far hills and a forest of spruce on them.
final Part valleyHills = Part(children: <Part>[
  Part(shapes: <Shape>[
    Shape(
      Paths.smooth(const <Offset>[
        Offset(-140, 760), Offset(260, 690), Offset(640, 712), Offset(1000, 672), Offset(1400, 716), Offset(1780, 684), Offset(2080, 724),
        Offset(2080, 1100), Offset(-140, 1100),
      ]),
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF6C8A82), Color(0xFF4A6860)]),
      shade: const Shade(form: 0.3, core: 0.15, coreStrength: 0.4, rim: 0.03),
    ),
  ]),
  for (int i = 0; i < 26; i++) _spruce(Offset(-60 + i * 82.0 + (i * 37 % 41), 716 + math.sin(i * 1.9) * 16 + (i % 3) * 6), 0.26 + (i % 4) * 0.05, const Color(0xFF3C5A52)),
]);

/// The far meadow, behind the river: low and soft.
final Part valleyMeadow = Part(children: <Part>[
  Part(shapes: <Shape>[
    Shape(
      Paths.smooth(const <Offset>[
        Offset(-140, 796), Offset(380, 784), Offset(900, 794), Offset(1460, 780), Offset(2080, 794), Offset(2080, 1100), Offset(-140, 1100),
      ]),
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF758F66), Color(0xFF5E7848)]),
    ),
  ]),
  for (int i = 0; i < 18; i++) _tuft(Offset(20 + i * 108.0 + (i * 37 % 29), 806 + (i * 53 % 30)), 0.34 + (i % 3) * 0.08, const Color(0xFF7C9A52)),
]);

/// The near bank: the ground people stand on, over the river's edge.
final Part valleyBank = Part(children: <Part>[
  Part(shapes: <Shape>[
    Shape(
      Paths.smooth(const <Offset>[
        Offset(-140, 886), Offset(300, 874), Offset(760, 884), Offset(1200, 868), Offset(1640, 880), Offset(2080, 870), Offset(2080, 1100), Offset(-140, 1100),
      ]),
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF7A9660), Color(0xFF55703F), Color(0xFF3A502E)], stops: <double>[0, 0.35, 1]),
      shade: const Shade(form: 0.0, core: 0.0, rim: 0.012, rimStrength: 0.5),
    ),
    // Patches of dry tundra grass on the moss.
    Shape(Paths.ellipse(const Offset(420, 980), 380, 36), color: const Color(0x226A5A30)),
    Shape(Paths.ellipse(const Offset(1500, 1010), 480, 44), color: const Color(0x226A5A30)),
  ]),
  _spruce(const Offset(110, 900), 0.72, const Color(0xFF2F4A44)),
  _spruce(const Offset(236, 912), 0.5, const Color(0xFF35544C), lean: 1.5),
  _spruce(const Offset(1830, 896), 0.66, const Color(0xFF2F4A44), lean: -1),
  _spruce(const Offset(1726, 908), 0.44, const Color(0xFF35544C)),
  _rock(const Offset(560, 940), 0.9, const Color(0xFF6A7480)),
  _rock(const Offset(1330, 950), 0.62, const Color(0xFF727C88)),
  for (int i = 0; i < 34; i++) _tuft(Offset(30 + i * 58.0 + (i * 37 % 29), 920 + (i * 53 % 150)), 0.55 + (i % 4) * 0.16, const Color(0xFF7C9A52)),
]);

// --- river ---

/// A river across the middle distance. [rise], in pixels, is how far it has
/// come up the bank.
class IceRiver extends StatelessWidget {
  const IceRiver({super.key, required this.h, required this.storm, this.rise = 0, this.rain = 0});

  final double h, storm, rise, rain;

  @override
  Widget build(BuildContext context) {
    final double t = Video.frame(context) / Video.fps(context);
    return CustomPaint(size: Size.infinite, painter: _RiverPainter(t, h, storm, rise, rain));
  }
}

class _RiverPainter extends CustomPainter {
  const _RiverPainter(this.t, this.h, this.storm, this.rise, this.rain);

  final double t, h, storm, rise, rain;

  @override
  void paint(Canvas canvas, Size size) {
    final (Color top, Color bottom) = skyColors(h, storm);
    final double day = daylight(h);
    final Color water = _mix(_mix(bottom, const Color(0xFF4A7C94), 0.55), const Color(0xFF6C5A44), rain * 0.45);
    final Color deep = _dark(water, 0.3);
    // The far shore wavers a little; the near one is the bank drawn over it.
    final Path river = Path()..moveTo(-100, 800 - rise * 0.5);
    for (double x = -100; x <= size.width + 100; x += 60) {
      river.lineTo(x, 800 - rise * 0.5 + math.sin(x * 0.004 + 1) * 10);
    }
    river
      ..lineTo(size.width + 100, 910)
      ..lineTo(-100, 910)
      ..close();
    final Rect bounds = river.getBounds();
    canvas.drawPath(river, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[_light(water, 0.14), deep]).createShader(bounds));
    // A bright edge along the far bank.
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _light(water, 0.5).withValues(alpha: 0.25 + 0.25 * day),
    );
    // Long glints sliding down the current.
    final math.Random r = math.Random(8);
    for (int i = 0; i < 26; i++) {
      final double x = ((r.nextDouble() * (size.width + 400) + t * (24 + r.nextDouble() * 26)) % (size.width + 400)) - 200;
      final double y = 812 - rise * 0.5 + r.nextDouble() * 70;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 40 + r.nextDouble() * 70, height: 2.4), const Radius.circular(2)),
        Paint()..color = _light(water, 0.6).withValues(alpha: (0.18 + 0.2 * day) * (0.6 + 0.4 * math.sin(t * 2 + i))),
      );
    }
  }

  @override
  bool shouldRepaint(_RiverPainter old) => old.t != t || old.h != h || old.storm != storm || old.rise != rise || old.rain != rain;
}

// --- mammoths ---

/// A woolly mammoth walking left to right, about [height] tall at the
/// shoulder, [step] seconds into its walk.
Part mammoth(double height, double step, {Color wool = const Color(0xFF6E4332), Color dark = const Color(0xFF4A2C22)}) {
  final double u = height / 100;
  final double sway = math.sin(step * 2.6);
  Part leg(double x, double phase) {
    final double a = math.sin(step * 2.6 + phase) * 7;
    return Part(at: Offset(x * u, 32 * u), degrees: a, shapes: <Shape>[
      Shape(Paths.roundRect(Rect.fromLTRB(-10 * u, 0, 10 * u, 62 * u), 8 * u), color: dark, shade: Shade.soft),
      Shape(Paths.roundRect(Rect.fromLTRB(-12 * u, 54 * u, 12 * u, 66 * u), 5 * u), color: _dark(dark, 0.3)),
    ]);
  }

  return Part(at: Offset(0, -2 * u * sway.abs()), children: <Part>[
    // Far legs, then the body, then the near legs.
    leg(-44, math.pi),
    leg(30, 0),
    Part(shapes: <Shape>[
      // The long coat hangs below the belly in a ragged fringe.
      Shape(
        Paths.smooth(<Offset>[
          Offset(-84 * u, -6 * u), Offset(-90 * u, -50 * u), Offset(-40 * u, -78 * u), Offset(20 * u, -78 * u), Offset(62 * u, -62 * u), Offset(86 * u, -30 * u),
          Offset(80 * u, 18 * u), Offset(30 * u, 40 * u), Offset(-40 * u, 42 * u),
        ]),
        color: wool,
        shade: const Shade(form: 0.4, core: 0.3, coreStrength: 0.55, rim: 0.08),
      ),
      for (int i = 0; i < 9; i++)
        Shape(
          Paths.polygon(<Offset>[Offset((-70 + i * 17) * u, 30 * u), Offset((-62 + i * 17) * u, 54 * u - (i % 2) * 8 * u), Offset((-54 + i * 17) * u, 30 * u)]),
          color: _dark(wool, 0.08),
        ),
      // The high domed head and the hump behind it.
      Shape(Paths.ellipse(Offset(78 * u, -62 * u), 34 * u, 38 * u), color: _light(wool, 0.04), shade: Shade.soft),
      Shape(Paths.ellipse(Offset(-18 * u, -80 * u), 40 * u, 22 * u), color: wool, shade: Shade.soft),
    ]),
    // The trunk, swinging a little, and the tusks.
    Part(at: Offset(100 * u, -44 * u), degrees: sway * 4, shapes: <Shape>[
      Shape(Paths.taper(Offset.zero, Offset(14 * u, 54 * u), 13 * u, 6 * u), color: _dark(wool, 0.04), shade: Shade.soft),
      Shape(Paths.taper(Offset(14 * u, 54 * u), Offset(6 * u, 72 * u), 6 * u, 4 * u), color: _dark(wool, 0.06)),
    ]),
    Part(at: Offset(92 * u, -34 * u), shapes: <Shape>[
      Shape(
        Path()
          ..moveTo(0, 0)
          ..cubicTo(22 * u, 20 * u, 36 * u, 4 * u, 34 * u, -22 * u),
        stroke: const Color(0xFFF1E6CC),
        strokeWidth: 6 * u,
      ),
    ]),
    leg(-62, 0),
    leg(48, math.pi),
  ]);
}

/// A herd, far off: each walks at its own pace along the plain.
Part mammothHerd(double t, {double x = 0, double y = 800}) => Part(children: <Part>[
      for (int i = 0; i < 5; i++)
        mammoth(62 - (i % 3) * 6.0, t * (0.7 + i * 0.07) + i * 3.3, wool: _mix(const Color(0xFF6E4332), const Color(0xFF8A8CB0), 0.35))
            .placed(at: Offset(x + 150 + i * 130.0 + t * 7 + (i * 97 % 60), y - 6 + (i % 2) * 10), scale: 1),
    ]);

/// A flat shadow on the ground under something standing at [x].
Part groundShadow(double x, double rx, {double y = valleyGround}) => Part(at: Offset(x, y + 4), shapes: <Shape>[
      Shape(Paths.ellipse(Offset.zero, rx, rx * 0.13), color: const Color(0x44101830)),
    ]);

// --- putting a day together ---

/// The whole valley at [h] under [storm], as a stack of layers to go inside a
/// [Camera]: sky, clouds, mountains, hills, river, plain -- each a
/// [ParallaxLayer] at its own depth, the land toned by the time of day.
List<Widget> valleyLayers(BuildContext context, {required double h, required double storm, double riverRise = 0, double rain = 0, Widget? foreground}) {
  final double t = Video.frame(context) / Video.fps(context);
  final Color tone = landTone(h, storm);
  Widget toned(Widget child) => ColorFiltered(colorFilter: ColorFilter.mode(tone, BlendMode.modulate), child: child);
  final Light light = skyLight(h, storm);
  return <Widget>[
    ParallaxLayer(depth: 0.0, child: IceSky(h: h, storm: storm)),
    ParallaxLayer(depth: 0.04, child: IceClouds(h: h, storm: storm)),
    ParallaxLayer(depth: 0.18, child: toned(Drawing(valleyMountains, light: light))),
    ParallaxLayer(depth: 0.45, child: toned(Drawing(valleyHills, light: light))),
    ParallaxLayer(depth: 0.7, child: toned(Drawing(valleyMeadow, light: light))),
    ParallaxLayer(depth: 0.7, child: toned(Drawing(mammothHerd(t, y: 800), light: light))),
    ParallaxLayer(depth: 0.85, child: toned(IceRiver(h: h, storm: storm, rise: riverRise, rain: rain))),
    ParallaxLayer(depth: 1.0, child: toned(Drawing(valleyBank, light: light))),
    if (foreground != null) ParallaxLayer(depth: 1.0, child: foreground),
  ];
}

/// [child] soaked: darker and bluer by [amount], on its own pixels only.
Widget wet(Widget child, double amount) => ColorFiltered(
      colorFilter: ColorFilter.mode(const Color(0xFF1B2A44).withValues(alpha: 0.38 * amount.clamp(0.0, 1.0)), BlendMode.srcATop),
      child: child,
    );
