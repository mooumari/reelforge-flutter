import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

const double stageWidth = 1920;
const double stageHeight = 1080;

/// Where feet land. Everything standing in the scene is measured from here.
const double groundY = 860;

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Painted on the lens (depth 0), in screen coordinates.
Part sky() {
  // Seeded, and drawn once: the same stars in every frame, every process.
  final math.Random random = math.Random(11);
  return Part(
    shapes: <Shape>[
      Shape(
        Paths.rect(const Rect.fromLTWH(0, 0, stageWidth, stageHeight)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF150C33), Color(0xFF3D1C6B), Color(0xFFB4457E), Color(0xFFFFA06B)],
          stops: <double>[0, 0.45, 0.78, 1],
        ),
      ),
      for (int i = 0; i < 90; i++)
        Shape(
          Paths.circle(
            Offset(random.nextDouble() * stageWidth, random.nextDouble() * 560),
            0.8 + random.nextDouble() * 2.2,
          ),
          color: Color.fromRGBO(255, 255, 255, 0.35 + random.nextDouble() * 0.55),
        ),
    ],
  );
}

/// A ringed planet: a sphere, a flat shadow cut from it, and a ring that
/// passes in front of the lower half and behind the upper.
Part planet() {
  const Offset c = Offset.zero;
  final Path ball = Paths.circle(c, 150);
  final Path ringBack = Paths.ellipse(c, 270, 56);
  return Part(
    at: const Offset(1380, 300),
    degrees: -16,
    shapes: <Shape>[
      Shape(ringBack, stroke: const Color(0x66FFC8A0), strokeWidth: 16),
      Shape(ball, gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFFFFC9A3), Color(0xFFE0698B)],
      )),
      Shape(
        Path.combine(PathOperation.intersect, ball, Paths.circle(const Offset(-92, -70), 190)),
        color: const Color(0x2A5A1A66),
      ),
      for (final (Offset o, double r) in const <(Offset, double)>[
        (Offset(40, -50), 22), (Offset(-30, 40), 30), (Offset(70, 60), 14),
      ])
        Shape(Paths.circle(o, r), color: const Color(0x22701E5A)),
    ],
    // the near half of the ring crosses the ball
    children: <Part>[
      Part(shapes: <Shape>[
        Shape(
          Path.combine(
            PathOperation.intersect,
            Paths.ellipse(c, 270, 56),
            Paths.rect(const Rect.fromLTRB(-300, 0, 300, 80)),
          ),
          stroke: const Color(0xCCFFD9B8),
          strokeWidth: 16,
        ),
      ]),
    ],
  );
}

/// A ridge line across the world: [amplitude] of wander around [baseY].
Part ridge({
  required Color color,
  required double baseY,
  required double amplitude,
  required int seed,
  double from = -900,
  double to = 3800,
  double step = 230,
  Color? haze,
}) {
  final math.Random random = math.Random(seed);
  final List<Offset> top = <Offset>[
    for (double x = from; x <= to; x += step)
      Offset(x, baseY - amplitude * (0.35 + 0.65 * random.nextDouble())),
  ];
  final Path path = Paths.smooth(top, closed: false)
    ..lineTo(to, stageHeight + 400)
    ..lineTo(from, stageHeight + 400)
    ..close();
  return Part(shapes: <Shape>[
    Shape(path, gradient: verticalGradient(color, haze ?? color)),
  ]);
}

/// One alien tree. Drawn once and placed over and over: the whole forest is
/// this tree at different positions, sizes and facings.
Part tree(Color leaf) {
  final Color dark = _mix(leaf, const Color(0xFF000000), 0.3);
  return Part(shapes: <Shape>[
    Shape(Paths.capsule(const Offset(0, 0), const Offset(0, -150), 9), color: _mix(leaf, const Color(0xFF2A1240), 0.7)),
    Shape(Paths.smooth(const <Offset>[
      Offset(-70, -150), Offset(-52, -230), Offset(0, -270),
      Offset(58, -226), Offset(76, -150), Offset(30, -122), Offset(-34, -124),
    ]), gradient: verticalGradient(_mix(leaf, const Color(0xFFFFFFFF), 0.15), leaf)),
    Shape(Path.combine(
      PathOperation.intersect,
      Paths.smooth(const <Offset>[
        Offset(-70, -150), Offset(-52, -230), Offset(0, -270),
        Offset(58, -226), Offset(76, -150), Offset(30, -122), Offset(-34, -124),
      ]),
      Paths.circle(const Offset(-70, -110), 120),
    ), color: dark.withValues(alpha: 0.35)),
  ]);
}

Part forest({
  required Color leaf,
  required int seed,
  required double baseY,
  required double scale,
  double from = -800,
  double to = 3700,
}) {
  final math.Random random = math.Random(seed);
  final Part symbol = tree(leaf);
  final List<Part> trees = <Part>[];
  for (double x = from; x < to; x += 150 + random.nextDouble() * 330) {
    final double s = scale * (0.7 + random.nextDouble() * 0.7);
    trees.add(symbol.placed(
      at: Offset(x, baseY + random.nextDouble() * 18),
      scale: s,
      scaleX: random.nextBool() ? s : -s,
    ));
  }
  return Part(children: trees);
}

Part ground() => Part(shapes: <Shape>[
      Shape(
        Paths.smooth(<Offset>[
          for (double x = -1200; x <= 4000; x += 400)
            Offset(x, groundY + 2),
        ], closed: false)
          ..lineTo(4000, stageHeight + 400)
          ..lineTo(-1200, stageHeight + 400)
          ..close(),
        gradient: verticalGradient(const Color(0xFF6A3A86), const Color(0xFF2A1450)),
      ),
      // a lit rim along the walking surface
      Shape(
        Paths.smooth(<Offset>[
          for (double x = -1200; x <= 4000; x += 400)
            Offset(x, groundY + 2),
        ], closed: false),
        stroke: const Color(0x66FFB38A),
        strokeWidth: 5,
      ),
    ]);

/// A clump of blades. Foreground silhouettes: dark, large, and moving faster
/// than the action.
Part plants(int seed, {double from = -900, double to = 3800}) {
  final math.Random random = math.Random(seed);
  Part clump(double h) => Part(shapes: <Shape>[
        for (int i = -2; i <= 2; i++)
          Shape(
            Paths.polygon(<Offset>[
              Offset(i * 26 - 16, 0),
              Offset(i * 26 + i * 12, -h * (1 - i.abs() * 0.18)),
              Offset(i * 26 + 16, 0),
            ]),
            color: const Color(0xFF12082B),
          ),
      ]);
  return Part(children: <Part>[
    for (double x = from; x < to; x += 380 + random.nextDouble() * 520)
      clump(180 + random.nextDouble() * 160)
          .placed(at: Offset(x, stageHeight + 40), scale: 1 + random.nextDouble() * 0.6),
  ]);
}
