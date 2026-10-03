import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'stage_hero.dart';

/// Outlines that move rather than only turn, in four panels:
///
///  * the same two-bone arm drawn as two rigid capsules and as one skin;
///  * one shape morphing through key outlines, driven by a joint;
///  * a mouth morphing through key shapes, beside the hero talking;
///  * chains -- a critter's tail swinging on follow-through, kelp swaying on
///    a travelling wave.
const int _fps = 30;

final Composition stageShapes = Composition(
  id: 'StageShapes',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: 240,
  builder: (BuildContext context) => typeset(const _StageShapes()),
);

const Color _ink = Color(0xFF2A1B54);

// --- rigid vs skinned ---

Part _arm(String name, {required bool skinned, required Offset at}) {
  const Color fill = Color(0xFFFF8A3D);
  const double upper = 120, lower = 110;
  return Part(
    name: name,
    at: at,
    children: <Part>[
      Part(
        name: '${name}Shoulder',
        shapes: <Shape>[
          if (skinned)
            Shape.skin(
              Skin(
                Paths.taper(Offset.zero, const Offset(0, upper + lower), 34, 26),
                bones: <String>['${name}Shoulder', '${name}Elbow'],
                tip: const Offset(0, lower),
              ),
              color: fill,
              stroke: _ink,
              strokeWidth: 5,
            )
          else
            Shape(Paths.taper(Offset.zero, const Offset(0, upper), 34, 30),
                color: fill, stroke: _ink, strokeWidth: 5),
          Shape(Paths.circle(Offset.zero, 12), color: _ink),
        ],
        children: <Part>[
          Part(
            name: '${name}Elbow',
            at: const Offset(0, upper),
            shapes: <Shape>[
              if (!skinned)
                Shape(Paths.taper(Offset.zero, const Offset(0, lower), 30, 26),
                    color: fill, stroke: _ink, strokeWidth: 5),
              Shape(Paths.circle(Offset.zero, 9), color: _ink),
            ],
            children: <Part>[
              Part(
                at: const Offset(0, lower),
                shapes: <Shape>[
                  Shape(Paths.circle(Offset.zero, 30),
                      color: const Color(0xFFFFE3C2), stroke: _ink, strokeWidth: 5),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

final Part _rigid = _arm('rigid', skinned: false, at: const Offset(300, 170));
final Part _skinned = _arm('skin', skinned: true, at: const Offset(660, 170));

Pose _armPose(String name, int frame) {
  final double t = frame / _fps;
  return Pose(<String, Joint>{
    '${name}Shoulder': Joint.rotate(-35 + 25 * math.sin(2 * math.pi * 0.45 * t)),
    '${name}Elbow': Joint.rotate(-75 - 55 * math.sin(2 * math.pi * 0.45 * t - 0.6)),
  });
}

// --- morph ---

final List<Path> _morphKeys = <Path>[
  Paths.circle(Offset.zero, 110),
  Paths.smooth(const <Offset>[
    Offset(0, -120), Offset(70, -70), Offset(130, 10), Offset(60, 60),
    Offset(20, 120), Offset(-80, 90), Offset(-120, 0), Offset(-70, -80),
  ]),
  Paths.polygon(<Offset>[
    for (int i = 0; i < 10; i++)
      Offset.fromDirection(-math.pi / 2 + i * math.pi / 5, i.isEven ? 135 : 58),
  ]),
  Paths.smooth(const <Offset>[
    Offset(0, -140), Offset(60, -30), Offset(85, 50), Offset(0, 115),
    Offset(-85, 50), Offset(-60, -30),
  ]),
  Paths.circle(Offset.zero, 110),
];
const List<Color> _morphColors = <Color>[
  Color(0xFF4FD1C5), Color(0xFF8BD450), Color(0xFFFFD166), Color(0xFFFF6B8B), Color(0xFF4FD1C5),
];
final Morph _morph = Morph(_morphKeys, samples: 160);

/// Holds each key, then moves to the next: four changes in eight seconds.
double _morphAt(int frame) {
  final int i = math.min(frame ~/ 60, 3);
  final double move = ((frame - i * 60 - 24) / 36).clamp(0.0, 1.0);
  return i + Curves.easeInOutCubic.transform(move);
}

Part _morphPart(double m) {
  final int i = math.min(m.floor(), _morphColors.length - 2);
  return Part(
    name: 'blob',
    at: const Offset(960 + 480, 290),
    shapes: <Shape>[
      Shape.morph(_morph, color: Color.lerp(_morphColors[i], _morphColors[i + 1], m - i)),
    ],
  );
}

final Part _morphKeysRow = Part(children: <Part>[
  for (int i = 0; i < 4; i++)
    Part(
      at: Offset(960 + 480 + (i - 1.5) * 110, 475),
      scaleX: 0.28,
      scaleY: 0.28,
      shapes: <Shape>[Shape(_morphKeys[i], color: _morphColors[i].withValues(alpha: 0.55))],
    ),
]);

// --- the talking head ---

/// Mouth keys in the order a mouth passes through them: shut in a smile,
/// wide as in "ee", open as in "ah", round as in "oo".
final Morph _mouthShapes = Morph(<Path>[
  Paths.smooth(const <Offset>[
    Offset(-12, -2), Offset(0, 1), Offset(12, -2), Offset(7, 2), Offset(0, 4), Offset(-7, 2),
  ]),
  Paths.smooth(const <Offset>[
    Offset(-15, -2), Offset(0, 0), Offset(15, -2), Offset(10, 4), Offset(0, 7), Offset(-10, 4),
  ]),
  Paths.smooth(const <Offset>[
    Offset(-12, -3), Offset(0, -2), Offset(12, -3), Offset(9, 7), Offset(0, 13), Offset(-9, 7),
  ]),
  Paths.ellipse(const Offset(0, 4), 7, 8),
]);

final Part _hero = hero().placed(at: const Offset(330, 540 + 500), scale: 1.6);
final Life _life = heroLife(3);

final Part _mouthKeys = Part(children: <Part>[
  for (int i = 0; i < 4; i++)
    Part(
      name: 'key$i',
      at: Offset(760, 540 + 170 + i * 90),
      scaleX: 3,
      scaleY: 3,
      shapes: <Shape>[Shape.morph(_mouthShapes, color: const Color(0xFFFF9E80))],
    ),
]);
const Pose _mouthKeyPose = Pose(<String, Joint>{
  'key1': Joint.morphTo(1),
  'key2': Joint.morphTo(2),
  'key3': Joint.morphTo(3),
});

// --- chains ---

const double _ground = 1040;
const double _critterRadius = 46;
final Chain _tail = Chain(
  'tail',
  segments: 7,
  length: 170,
  width: 18,
  tipWidth: 8,
  color: Color(0xFFB0703C),
  at: Offset(-38, 8),
  degrees: 195,
  children: <Part>[
    Part(shapes: <Shape>[Shape(Paths.circle(Offset(6, 0), 13), color: Color(0xFF7A4520))]),
  ],
);

final Part _critter = Part(
  name: 'critter',
  children: <Part>[
    Part(
      name: 'critterBody',
      shapes: <Shape>[
        Shape(Paths.circle(Offset.zero, _critterRadius),
            gradient: verticalGradient(const Color(0xFFD08A4E), const Color(0xFFB0703C))),
        Shape(Paths.ellipse(const Offset(16, 12), 24, 20), color: const Color(0xFFF2D2A9)),
        Shape(Paths.ellipse(const Offset(10, -12), 6, 8), color: _ink),
        Shape(Paths.ellipse(const Offset(32, -12), 6, 8), color: _ink),
      ],
      children: <Part>[_tail.part],
    ),
  ],
);
final List<Jiggle> _tailJiggles = _tail.jiggles(hertz: 2, damping: 0.3, inertia: 0.6, limit: 9);

const int _hop = 24;
const double _hopLength = 72;

/// Hops to the right with squash and stretch; the tail is only curled and
/// gently swayed -- every swing from a landing is follow-through.
Posed _critterAt(int frame) {
  final int n = frame ~/ _hop;
  final double p = (frame % _hop) / _hop;
  double x, lift, stretch, lean;
  if (p < 0.25) {
    // On the ground: absorb the landing, then crouch into the next jump.
    final double g = p / 0.25;
    x = n * _hopLength;
    lift = 0;
    stretch = 0.85 + 0.3 * g - 0.22 * math.sin(math.pi * g);
    lean = 6 * g;
  } else {
    final double a = (p - 0.25) / 0.75;
    x = (n + Curves.easeInOut.transform(a)) * _hopLength;
    lift = 120 * math.sin(math.pi * a);
    stretch = 1 + 0.15 * math.cos(math.pi * a);
    lean = 6 - 12 * a;
  }
  final double y = _ground - _critterRadius * stretch - lift;
  return Posed(
    _critter.placed(at: Offset(70 + 960 + x, y)),
    _tail.curl(70).plus(_tail.wave(frame, _fps, amplitude: 4, hertz: 0.6)).overlay(
          Pose(<String, Joint>{
            'critterBody': Joint(degrees: lean, scaleX: 1 / stretch, scaleY: stretch),
          }),
        ),
  );
}

final List<Chain> _kelp = <Chain>[
  for (int i = 0; i < 5; i++)
    Chain(
      'kelp$i',
      segments: 6,
      length: 150 + 40.0 * ((i * 7) % 3),
      width: 22,
      tipWidth: 6,
      color: Color.lerp(const Color(0xFF2E8B57), const Color(0xFF7FD17F), i / 4),
      at: Offset(1060 + i * 190.0, _ground + 8),
      degrees: -90,
    ),
];
final Part _kelpPart = Part(children: <Part>[for (final Chain c in _kelp) c.part]);

Pose _kelpPose(int frame) => <Pose>[
      for (int i = 0; i < _kelp.length; i++)
        _kelp[i].wave(frame, _fps, amplitude: 7, hertz: 0.35 + 0.05 * i, phase: i * 1.3, taper: 0.6),
    ].fold(Pose.rest, (Pose a, Pose b) => a.overlay(b));

class _StageShapes extends StatelessWidget {
  const _StageShapes();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double m = _morphAt(frame);
    final Posed critter = followThrough(_critterAt, frame, jiggles: _tailJiggles, fps: _fps);
    final Pose heroPose = _life.at(frame, _fps).plus(talk(frame % 75, _fps));
    return Stack(
      children: <Widget>[
        const ColoredBox(color: Color(0xFF241245), child: SizedBox.expand()),
        Drawing(Part(shapes: <Shape>[
          Shape(Paths.rect(const Rect.fromLTRB(958, 0, 962, 1080)), color: const Color(0xFF120828)),
          Shape(Paths.rect(const Rect.fromLTRB(0, 538, 1920, 542)), color: const Color(0xFF120828)),
          Shape(Paths.rect(const Rect.fromLTRB(962, _ground, 1920, 1080)), color: const Color(0xFF3B1F66)),
        ])),
        // Top left.
        Drawing(_rigid, pose: _armPose('rigid', frame)),
        Drawing(_skinned, pose: _armPose('skin', frame)),
        // Top right.
        Drawing(_morphKeysRow),
        Drawing(_morphPart(m), pose: Pose(<String, Joint>{'blob': Joint.morphTo(m)})),
        // Bottom left, clipped to its panel.
        Positioned(
          left: 0,
          top: 542,
          width: 958,
          height: 538,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomLeft,
              minWidth: 1920,
              maxWidth: 1920,
              minHeight: 1080,
              maxHeight: 1080,
              child: Stack(children: <Widget>[
                Drawing(_hero, pose: heroPose),
                Drawing(_mouthKeys, pose: _mouthKeyPose),
              ]),
            ),
          ),
        ),
        // Bottom right.
        Drawing(_kelpPart, pose: _kelpPose(frame)),
        Drawing(critter.part, pose: critter.pose),
        const Positioned(left: 40, top: 24, child: _Label('Skinned limbs', 'left: two rigid parts   right: one outline over two bones')),
        const Positioned(left: 1000, top: 24, child: _Label('Morph', 'one shape through key outlines, posed like a joint')),
        const Positioned(left: 40, top: 566, child: _Label('Mouth shapes', 'right: a morph through four keys   left: speech')),
        const Positioned(left: 1000, top: 566, child: _Label('Chains', 'tail: follow-through   kelp: a travelling wave')),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.title, this.detail);

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF))),
          Text(detail, style: const TextStyle(fontSize: 22, color: Color(0xBBFFFFFF))),
        ],
      );
}
