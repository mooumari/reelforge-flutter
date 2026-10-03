import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

/// The savanna at sunset, as parts: a sky with a low sun, hills, a plain
/// with an acacia and tufts of grass, and a ground shadow to stand
/// characters on. Shared by every scene set there.

/// The sun, low behind them on the right.
const Light savannaSun = Light(
  from: Offset(0.72, -0.62),
  shadow: Color(0xFF7A4A9E),
  highlight: Color(0xFFFFD49A),
  cast: Color(0xFF3A1A46),
);

const double savannaGround = 940;

// --- the savanna ---

final Part savannaSky = Part(shapes: <Shape>[
  Shape(
    Paths.rect(const Rect.fromLTRB(0, 0, 1920, 1080)),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF34245E), Color(0xFF8A3F6E), Color(0xFFE8784E), Color(0xFFFFB45E)],
      stops: <double>[0, 0.35, 0.62, 0.74],
    ),
  ),
  Shape(
    Paths.circle(const Offset(1500, 690), 420),
    gradient: const RadialGradient(colors: <Color>[Color(0x88FFE0A0), Color(0x22FFC880), Color(0x00FFC880)], stops: <double>[0.3, 0.6, 1]),
  ),
  Shape(Paths.circle(const Offset(1500, 690), 150), color: const Color(0xFFFFE6B0)),
]);

/// A flat-topped acacia: a crooked trunk, branches, and a canopy of lit
/// clumps.
Part _acacia(Offset at, double scale, Color color, {bool flip = false}) {
  const Shade shade = Shade(form: 0.45, core: 0.3, coreStrength: 0.6, rim: 0.1, rimStrength: 0.5);
  final Color bark = Color.lerp(color, const Color(0xFF1A1030), 0.2)!;
  return Part(at: at, scaleX: flip ? -scale : scale, scaleY: scale, shapes: <Shape>[
    Shape(
      Paths.smooth(const <Offset>[
        Offset(-14, 0), Offset(-10, -90), Offset(-30, -170), Offset(-90, -230), Offset(-80, -240), Offset(-14, -186),
        Offset(6, -150), Offset(40, -220), Offset(110, -250), Offset(116, -238), Offset(52, -200), Offset(14, -110), Offset(14, 0),
      ]),
      color: bark,
      shade: shade,
    ),
    for (final (double, double, double) c in const <(double, double, double)>[
      (-150, -258, 70), (-60, -282, 90), (50, -290, 96), (150, -268, 78), (230, -252, 50), (-220, -246, 44),
    ])
      Shape(Paths.ellipse(Offset(c.$1, c.$2), c.$3 * 1.25, c.$3 * 0.42), color: color, shade: shade),
  ]);
}

final Part savannaDistance = Part(children: <Part>[
  Part(shapes: <Shape>[
    Shape(
      Paths.smooth(const <Offset>[
        Offset(-100, 760), Offset(240, 690), Offset(560, 720), Offset(820, 664), Offset(1180, 712), Offset(1600, 676),
        Offset(2020, 724), Offset(2020, 1180), Offset(-100, 1180),
      ]),
      color: const Color(0xFFB0587A),
      shade: const Shade(form: 0.35, core: 0.2, coreStrength: 0.4, rim: 0.03),
    ),
  ]),
  _acacia(const Offset(300, 718), 0.42, const Color(0xFF8C4570)),
  _acacia(const Offset(1760, 700), 0.36, const Color(0xFF8C4570), flip: true),
  _acacia(const Offset(1040, 706), 0.28, const Color(0xFF8C4570)),
]);

final Part savannaPlain = Part(children: <Part>[
  Part(shapes: <Shape>[
    Shape(
      Paths.smooth(const <Offset>[
        Offset(-100, 820), Offset(500, 800), Offset(1100, 816), Offset(1700, 796), Offset(2020, 812),
        Offset(2020, 1180), Offset(-100, 1180),
      ]),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFE29A58), Color(0xFFC0684E), Color(0xFF9A4E52)],
        stops: <double>[0, 0.5, 1],
      ),
    ),
  ]),
  _acacia(const Offset(150, 836), 0.95, const Color(0xFF6E3A5E)),
  for (int i = 0; i < 26; i++) _tuft(Offset(40 + i * 73.0 + (i * 37 % 29), 850 + (i * 53 % 70)), 0.6 + (i % 4) * 0.15),
]);

/// A clump of dry grass.
Part _tuft(Offset at, double scale) {
  final math.Random r = math.Random(at.dx.round());
  return Part(at: at, scaleX: scale, scaleY: scale, shapes: <Shape>[
    for (int i = 0; i < 6; i++)
      Shape(
        Paths.smooth(<Offset>[
          Offset(-6 + i * 2.5, 0), Offset(-20 + i * 8 + r.nextDouble() * 6, -30 - r.nextDouble() * 24), Offset(-2 + i * 2.5, 0),
        ]),
        color: Color.lerp(const Color(0xFFC07848), const Color(0xFFF0B064), r.nextDouble())!,
      ),
  ]);
}

Part savannaShadow(double x, double rx) => Part(at: Offset(x, savannaGround + 4), shapes: <Shape>[
      Shape(Paths.ellipse(Offset.zero, rx, rx * 0.12), color: const Color(0x553A1A46)),
    ]);

