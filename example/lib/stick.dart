import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

/// A stick figure: a round white head with big eyes, a line for a body and a
/// line for each limb, little black hands, and fur and hair drawn on.
///
/// It is a [Character] in everything but looks, so it walks with [Walk],
/// breathes and glances with `life`, and takes every [Emotion] and [Speech]
/// the real characters do. Draw it with an [Ink] pen: the head and clothes get
/// their marker outline, and the limbs, being thinner than the pen's line,
/// stay plain strokes.
class StickFigure extends Character {
  const StickFigure({
    this.hair = StickHair.none,
    this.hairColor = const Color(0xFF6A4528),
    this.fur,
    this.quiver = false,
    super.face = StickFigure.stickFace,
  }) : super(faceTurn: 0.4);

  /// The stick figure's face: two big white eyes with dot pupils, no brows,
  /// a short line of a mouth.
  static const FaceStyle stickFace = FaceStyle(
    eyeSpacing: 84,
    eyeWidth: 54,
    eyeHeight: 62,
    pupilRadius: 9,
    pupilColor: line,
    highlight: false,
    browThickness: 0,
    mouthY: 64,
    mouthWidth: 56,
    mouthColor: line,
    turnRange: 30,
  );

  static const Color line = Color(0xFF14121A);

  // Measurements, in pixels at scale 1.
  static const double headR = 54, torso = 112, upperArm = 56, forearm = 54, upperLeg = 70, lowerLeg = 68, r = 4.6, sole = r;

  final StickHair hair;
  final Color hairColor;

  /// A fur tunic over the torso, if given.
  final Color? fur;

  /// A quiver of spears on the back.
  final bool quiver;

  Offset get _headAt => const Offset(0, -torso + 2);
  Offset get _headCenter => const Offset(0, -headR + 2);

  @override
  Offset standing(double x, double groundY) => Offset(x, groundY - upperLeg - lowerLeg - sole);

  @override
  Biped get biped {
    const Offset toe = Offset(27, sole), heel = Offset(-5, sole);
    return const Biped(
      front: Leg(hip: 'hipF', knee: 'kneeF', ankle: 'footF', toe: toe, heel: heel),
      back: Leg(hip: 'hipB', knee: 'kneeB', ankle: 'footB', toe: toe, heel: heel),
    );
  }

  @override
  List<Jiggle> get jiggles => const <Jiggle>[];

  /// Arms hanging a little forward, elbows easy, legs not quite together.
  @override
  Pose get stance => const Pose(<String, Joint>{
        'shoulderF': Joint.rotate(-5),
        'elbowF': Joint.rotate(-16),
        'shoulderB': Joint.rotate(8),
        'elbowB': Joint.rotate(-12),
        'hipF': Joint.rotate(-3),
        'hipB': Joint.rotate(3),
      });

  @override
  Part build({Map<String, List<Part>> hold = const <String, List<Part>>{}}) {
    Part limb(String joint, String child, Offset at, double upper, double lower, Part end) => Part(
          name: joint,
          at: at,
          shapes: <Shape>[Shape(Paths.capsule(Offset.zero, Offset(0, upper), r), color: line)],
          children: <Part>[
            Part(
              name: child,
              at: Offset(0, upper),
              shapes: <Shape>[Shape(Paths.capsule(Offset.zero, Offset(0, lower), r), color: line)],
              children: <Part>[end],
            ),
          ],
        );
    Part arm(String side, Offset at) => limb(
          'shoulder$side',
          'elbow$side',
          at,
          upperArm,
          forearm,
          Part(
            name: 'hand$side',
            at: const Offset(0, forearm),
            shapes: <Shape>[Shape(Paths.circle(Offset.zero, 8.5), color: line)],
            children: hold['hand$side'] ?? const <Part>[],
          ),
        );
    Part leg(String side, Offset at) => limb(
          'hip$side',
          'knee$side',
          at,
          upperLeg,
          lowerLeg,
          Part(
            name: 'foot$side',
            at: const Offset(0, lowerLeg),
            shapes: <Shape>[Shape(Paths.capsule(const Offset(-5, 0), const Offset(27, 0), r), color: line)],
          ),
        );
    Part chest(List<Part> children) => Part(name: 'chest', children: children);

    return Part(
      name: 'body',
      children: <Part>[
        chest(<Part>[arm('B', const Offset(3, -torso + 10))]),
        leg('B', const Offset(2, 0)),
        leg('F', const Offset(-2, 0)),
        chest(<Part>[
          Part(shapes: <Shape>[Shape(Paths.capsule(Offset.zero, const Offset(0, -torso + 4), r), color: line)]),
          if (fur != null) _fur(fur!),
          if (quiver) _quiver(),
          _head(),
          arm('F', const Offset(-1, -torso + 10)),
        ]),
      ],
    );
  }

  /// A fur tunic: a ragged shape round the torso from shoulders to hips.
  Part _fur(Color color) {
    final math.Random rnd = math.Random(4);
    const double t = torso;
    double j(double a) => (rnd.nextDouble() - 0.5) * a;
    final List<Offset> pts = <Offset>[
      Offset(-24, -t + 2), Offset(-36 + j(4), -t + 24), Offset(-31 + j(5), -t * 0.62), Offset(-38 + j(4), -t * 0.4), Offset(-32 + j(5), -t * 0.18),
      for (int i = 0; i <= 8; i++) Offset(-34 + i * (68 / 8) + j(4), i.isEven ? 34 + j(6) : 10 + j(5)),
      Offset(36 + j(4), -t * 0.2), Offset(31 + j(5), -t * 0.42), Offset(38 + j(4), -t * 0.64), Offset(34 + j(4), -t + 26), Offset(24, -t + 2), const Offset(0, -t - 3),
    ];
    final Color dark = Color.lerp(color, const Color(0xFF2A1A10), 0.35)!;
    return Part(shapes: <Shape>[
      Shape(Paths.polygon(pts), color: color),
      // Tufts of darker fur.
      for (int i = 0; i < 6; i++)
        Shape(
          Paths.polygon(<Offset>[
            Offset(-20 + i * 8.0 + j(3), -t * 0.62 + (i % 3) * 22),
            Offset(-15 + i * 8.0, -t * 0.62 + (i % 3) * 22 + 15 + j(4)),
            Offset(-10 + i * 8.0 + j(3), -t * 0.62 + (i % 3) * 22 + 2),
          ]),
          color: dark,
        ),
    ]);
  }

  /// A quiver of spears slung on the back, spearheads over the shoulder.
  Part _quiver() => Part(at: const Offset(-30, -torso + 34), degrees: -16, shapes: <Shape>[
        for (int i = 0; i < 3; i++) Shape(Paths.capsule(Offset(-6.0 + i * 8, 0), Offset(-8.0 + i * 8, -118 - i * 14), 2.8), color: const Color(0xFF6A4528)),
        for (int i = 0; i < 3; i++)
          Shape(
            Paths.polygon(<Offset>[Offset(-8.0 + i * 8, -150 - i * 14), Offset(-14.0 + i * 8, -120 - i * 14), Offset(-2.0 + i * 8, -120 - i * 14)]),
            color: const Color(0xFF9AA0A8),
          ),
        Shape(Paths.roundRect(const Rect.fromLTRB(-20, -6, 20, 70), 9), color: const Color(0xFF8A6038)),
        Shape(Paths.rect(const Rect.fromLTRB(-20, 20, 20, 29)), color: const Color(0xFF5A3C22)),
      ]);

  Part _head() {
    final Part faceRig = Part(
      at: _headCenter + const Offset(headR * 0.1, headR * 0.06),
      scaleX: headR / 95,
      scaleY: headR / 95,
      children: <Part>[face.build(turn: faceTurn)],
    );
    return Part(name: 'head', at: _headAt, children: <Part>[
      if (hair == StickHair.shaggy) _locks(),
      Part(shapes: <Shape>[Shape(Paths.circle(_headCenter, headR), color: const Color(0xFFFFFFFF))]),
      faceRig,
      if (hair != StickHair.none) _hair(),
    ]);
  }

  /// Long hair hanging down behind the head.
  Part _locks() {
    final math.Random rnd = math.Random(9);
    final Offset c = _headCenter;
    final List<Offset> pts = <Offset>[
      c + const Offset(-headR * 0.2, -headR * 1.08),
      c + const Offset(-headR * 0.95, -headR * 0.8),
      for (int i = 0; i <= 7; i++) c + Offset(-headR * (1.28 - i * 0.07) + (rnd.nextDouble() - 0.5) * 8, headR * (-0.55 + i * 0.28 + (i.isEven ? 0.12 : 0))),
      c + const Offset(-headR * 0.6, headR * 1.3),
      c + const Offset(-headR * 0.3, headR * 0.6),
      c + const Offset(-headR * 0.1, -headR * 0.3),
    ];
    return Part(shapes: <Shape>[Shape(Paths.polygon(pts), color: hairColor)]);
  }

  /// A mop of hair over the top of the head, ragged at the fringe.
  Part _hair() {
    final Offset c = _headCenter;
    final math.Random rnd = math.Random(hair == StickHair.shaggy ? 21 : 5);
    final List<Offset> outer = <Offset>[
      for (int d = 160; d <= 345; d += 9)
        c + Offset(math.cos(d * math.pi / 180), math.sin(d * math.pi / 180)) * (headR * ((d ~/ 9).isEven ? 1.1 : 1.24 + (hair == StickHair.shaggy ? 0.1 : 0)) + rnd.nextDouble() * 5),
    ];
    // The fringe, ragged, back along above the eyes.
    final List<Offset> fringe = <Offset>[
      for (int i = 0; i <= 8; i++)
        c + Offset(headR * (0.98 - i * 0.2), headR * (-0.5 + (i.isEven ? 0.2 : -0.04) + (i > 5 ? 0.12 : 0))) + Offset(0, rnd.nextDouble() * 4),
    ];
    return Part(shapes: <Shape>[Shape(Paths.polygon(<Offset>[...outer, ...fringe]), color: hairColor)]);
  }
}

/// How a [StickFigure]'s hair is drawn.
enum StickHair { none, messy, shaggy }
