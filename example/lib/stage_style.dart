import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;

/// The style test: one character, finished, before ten are built on it.
///
/// Wyatt walks into a desert at dusk, stops, waves and says hello, with his
/// head close up on the right so the face can be judged at size. Everything
/// is lit by the one low sun: every surface has its light side, its shadow
/// side and a bright rim, and the hat brim shadows his eyes.
const int _fps = 30;
const int _frames = 300;

final Composition stageStyle = Composition(
  id: 'StageStyle',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: _frames,
  builder: (BuildContext context) => typeset(const _StageStyle()),
);

/// The sun is low on the right, and warm.
const Light _sun = Light(
  from: Offset(0.62, -0.78),
  shadow: Color(0xFF8A6AC0),
  highlight: Color(0xFFFFD9A8),
  cast: Color(0xFF2A1640),
);

const Character wyatt = Character(
  body: Body(head: HeadShape.square),
  skin: Color(0xFFE7A77B),
  face: FaceStyle(
    eyeSpacing: 60,
    eyeWidth: 24,
    eyeHeight: 30,
    pupilRadius: 9.5,
    browGap: 30,
    browLength: 26,
    browThickness: 6.5,
    browColor: Color(0xFF4A2E1C),
    mouthY: 52,
    mouthWidth: 38,
    cheeks: Color(0x26E0607A),
  ),
  outfit: <Garment>[
    ShortHair(Color(0xFF6B4226)),
    Moustache(Color(0xFF5A3620)),
    Shirt(Color(0xFFC0483A), vNeck: false),
    Trousers(Color(0xFF3D5A86)),
    Vest(Color(0xFF7A5232)),
    Belt(Color(0xFF3B2416)),
    Bandana(Color(0xFFE2B048)),
    CowboyBoots(Color(0xFF8A5530)),
    CowboyHat(Color(0xFFC49560)),
  ],
);

const double _ground = 975;
const double _scale = 1.85;

final Part _rig = wyatt.build();

final Walk _walk = Walk(
  rig: _rig,
  route: const <Waypoint>[
    Waypoint(0, -200),
    Waypoint(20, -90, curve: Curves.easeInSine),
    Waypoint(74, 560, curve: Curves.linear),
    Waypoint(96, 670, curve: Curves.easeOutSine),
  ],
  groundY: _ground,
  fps: _fps,
  scale: _scale,
  body: wyatt.biped,
);

const int _waveAt = 108;

final Speech _hello = Speech.fromText("Howdy! I'm Wyatt. Pleased to meet y'all.", start: 4.3);

Posed _perform(int frame) => _walk.at(frame, adjust: (Pose pose) {
      Pose out = pose.plus(wyatt.stance).plus(wyatt.life(5).at(frame, _fps));
      final Pose? arm = Character.wave(frame - _waveAt, _fps, from: pose);
      if (arm != null) out = out.overlay(arm);
      final double smile = ((frame - _waveAt + 6) / 10).clamp(0.0, 1.0);
      out = out.plus(wyatt.face.express(Emotion.happy, amount: 0.7 * smile));
      // He looks out at us once he has stopped.
      final double look = ((frame - 96) / 12).clamp(0.0, 1.0);
      out = out.plus(wyatt.face.look(Offset(0.5 * look, 0.1 * look)));
      return out.plus(_hello.at(frame, _fps));
    });

// --- the desert ---


final Part _sky = Part(shapes: <Shape>[
  Shape(
    Paths.rect(const Rect.fromLTRB(0, 0, 1920, 1080)),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF2B2160), Color(0xFF7A3E7E), Color(0xFFE0745A), Color(0xFFF6B26B)],
      stops: <double>[0, 0.38, 0.66, 0.8],
    ),
  ),
  // The sun, low, with a glow round it.
  Shape(Paths.circle(const Offset(1790, 650), 260), color: const Color(0x18FFE2A8)),
  Shape(Paths.circle(const Offset(1790, 650), 170), color: const Color(0x26FFE2A8)),
  Shape(Paths.circle(const Offset(1790, 650), 96), color: const Color(0xFFFFE8B8)),
  for (int i = 0; i < 40; i++)
    Shape(
      Paths.circle(Offset((i * 467.3) % 1920, (i * 131.7) % 330), 1.2 + (i % 3) * 0.7),
      color: Color.fromRGBO(255, 240, 220, 0.25 + (i % 4) * 0.12),
    ),
]);

/// A row of flat-topped mesas.
Part _mesas({required double base, required Color color, required int seed, required double height}) {
  final math.Random r = math.Random(seed);
  final List<Shape> shapes = <Shape>[];
  double x = -100;
  while (x < 2020) {
    final double w = 160 + r.nextDouble() * 260, h = height * (0.5 + r.nextDouble() * 0.6);
    final Path mesa = Paths.smooth(<Offset>[
      Offset(x, base + 20), Offset(x + w * 0.12, base - h * 0.55), Offset(x + w * 0.22, base - h),
      Offset(x + w * 0.78, base - h - 4), Offset(x + w * 0.88, base - h * 0.5), Offset(x + w, base + 20),
    ]);
    shapes.add(Shape(mesa, color: color, shade: const Shade(form: 0.45, core: 0.28, coreStrength: 0.55, rim: 0.03, rimStrength: 0.5)));
    x += w * (0.7 + r.nextDouble() * 0.6);
  }
  shapes.add(Shape(Paths.rect(Rect.fromLTRB(0, base, 1920, 1080)), color: color));
  return Part(shapes: shapes);
}

final Part _far = _mesas(base: 700, color: const Color(0xFFB0587A), seed: 3, height: 170);
final Part _near = _mesas(base: 790, color: const Color(0xFF8C3F6E), seed: 9, height: 120);

/// A saguaro, lit.
Part _cactus(Offset at, double scale) {
  const Color green = Color(0xFF4F8A5B);
  const Shade shade = Shade(form: 0.4, core: 0.45, coreStrength: 0.7, rim: 0.14, rimStrength: 0.5);
  return Part(at: at, scaleX: scale, scaleY: scale, shapes: <Shape>[
    Shape(Paths.capsule(const Offset(0, 0), const Offset(0, -230), 26), color: green, shade: shade),
    Shape(
      Paths.smooth(<Offset>[
        const Offset(-12, -110), const Offset(-62, -118), const Offset(-74, -150), const Offset(-72, -190),
        const Offset(-52, -192), const Offset(-50, -150), const Offset(-40, -138), const Offset(-12, -136),
      ]),
      color: green,
      shade: shade,
    ),
    Shape(
      Paths.smooth(<Offset>[
        const Offset(12, -140), const Offset(56, -146), const Offset(66, -176), const Offset(64, -214),
        const Offset(84, -214), const Offset(86, -172), const Offset(76, -128), const Offset(12, -118),
      ]),
      color: green,
      shade: shade,
    ),
  ]);
}

final Part _groundPart = Part(shapes: <Shape>[
  Shape(
    Paths.smooth(const <Offset>[
      Offset(-100, 880), Offset(500, 860), Offset(1100, 875), Offset(1700, 855), Offset(2020, 870),
      Offset(2020, 1180), Offset(-100, 1180),
    ]),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFFE39A6A), Color(0xFFB8625E)],
    ),
  ),
  for (final (double, double, double) rock in <(double, double, double)>[(260, 1010, 34), (1180, 940, 22), (90, 930, 16)])
    Shape(
      Paths.smooth(<Offset>[
        Offset(rock.$1 - rock.$3, rock.$2), Offset(rock.$1 - rock.$3 * 0.7, rock.$2 - rock.$3 * 0.7),
        Offset(rock.$1 + rock.$3 * 0.2, rock.$2 - rock.$3), Offset(rock.$1 + rock.$3, rock.$2 - rock.$3 * 0.3),
        Offset(rock.$1 + rock.$3 * 1.1, rock.$2),
      ]),
      color: const Color(0xFF9C5A5E),
      shade: Shade.solid,
    ),
]);

final Part _cacti = Part(children: <Part>[
  _cactus(const Offset(1250, 880), 0.9),
  _cactus(const Offset(150, 872), 0.55),
]);

const Offset _closeUpAt = Offset(1450, 330);
const double _closeUpRadius = 240;

class _StageStyle extends StatelessWidget {
  const _StageStyle();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final Posed p = _perform(frame);
    final double x = _walk.xAt(frame);

    // The close-up: the same rig in the same pose, the head filling a
    // circle. Where the head is, in the rig's own space, at this pose.
    final Offset head = frameOf(_rig, p.pose, 'head').apply(wyatt.body.headCenter + const Offset(0, 20));
    const double zoom = 3.4;
    final double inset = ((frame - 100) / 14).clamp(0.0, 1.0);

    return Stack(
      children: <Widget>[
        Drawing(_sky),
        Drawing(_far, light: _sun),
        Drawing(_near, light: _sun),
        Drawing(_groundPart, light: _sun),
        Drawing(_cacti, light: _sun),
        Drawing(Part(at: Offset(x + 6, _ground + 2), shapes: <Shape>[
          Shape(Paths.ellipse(Offset.zero, 80 * _scale * 0.62, 11 * _scale * 0.62), color: const Color(0x552A1640)),
        ])),
        Drawing(p.part, pose: p.pose, light: _sun),
        if (inset > 0)
          Positioned(
            left: _closeUpAt.dx - _closeUpRadius,
            top: _closeUpAt.dy - _closeUpRadius,
            width: _closeUpRadius * 2,
            height: _closeUpRadius * 2,
            child: Opacity(
              opacity: inset,
              child: Transform.scale(
                scale: 0.85 + 0.15 * Curves.easeOutBack.transform(inset),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFE8B8), width: 6),
                  ),
                  child: ClipOval(
                    child: Stack(children: <Widget>[
                      const ColoredBox(color: Color(0xFF7A3E7E), child: SizedBox.expand()),
                      Drawing(
                        _rig.placed(at: const Offset(_closeUpRadius, _closeUpRadius) - head * zoom, scale: zoom),
                        pose: p.pose,
                        light: _sun,
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
