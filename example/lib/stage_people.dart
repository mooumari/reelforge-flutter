import 'package:flutter/widgets.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

// Front-on people for talking shots, all on one face rig.
//
// A person is a head, a neck and shoulders, with a [FaceStyle] for the face.
// Six of them below look nothing alike -- different heads, hair, eyes, a
// robot, an alien -- and every expression, mouth shape and glance works on
// all six, because they all pose the same joints.

enum Hair { none, short, bob, bun }

Color _shade(Color c, [double by = 0.2]) => Color.lerp(c, const Color(0xFF000000), by)!;

/// A person, origin at the middle of the shoulders, head 130 above.
Part person({
  required Color skin,
  required Color shirt,
  Color hair = const Color(0xFF2B1A12),
  Hair hairStyle = Hair.short,
  FaceStyle face = const FaceStyle(),
  Path? headShape,
  List<Part> extras = const <Part>[],
}) {
  final Path head = headShape ?? Paths.ellipse(Offset.zero, 92, 98);
  return Part(
    name: 'body',
    children: <Part>[
      Part(shapes: <Shape>[
        Shape(Paths.roundRect(const Rect.fromLTRB(-135, -6, 135, 260), 90),
            gradient: verticalGradient(shirt, _shade(shirt, 0.25))),
        Shape(Paths.rect(const Rect.fromLTRB(-25, -48, 25, 4)), color: _shade(skin, 0.18)),
        Shape(Paths.smooth(const <Offset>[Offset(-40, -6), Offset(0, 22), Offset(40, -6)]),
            color: _shade(skin, 0.18)),
      ]),
      Part(
        name: 'head',
        at: const Offset(0, -130),
        children: <Part>[
          if (hairStyle == Hair.bob)
            Part(name: 'hairBack', shapes: <Shape>[
              Shape(Paths.roundRect(const Rect.fromLTRB(-118, -112, 118, 70), 70), color: hair),
            ]),
          if (hairStyle == Hair.bun)
            Part(name: 'hairBack', shapes: <Shape>[
              Shape(Paths.circle(const Offset(0, -112), 40), color: hair),
            ]),
          Part(name: 'ears', shapes: <Shape>[
            if (headShape == null) ...<Shape>[
              Shape(Paths.ellipse(const Offset(-90, 12), 16, 22), color: _shade(skin, 0.08)),
              Shape(Paths.ellipse(const Offset(90, 12), 16, 22), color: _shade(skin, 0.08)),
            ],
          ]),
          Part(shapes: <Shape>[
            Shape(head, gradient: verticalGradient(skin, _shade(skin, 0.1))),
            // Cel shadow down one side, cut to the head.
            Shape(
              Path.combine(PathOperation.intersect, head, Paths.circle(const Offset(-150, 10), 115)),
              color: const Color(0x1E000000),
            ),
          ]),
          Part(at: const Offset(0, 4), children: <Part>[face.build()]),
          if (hairStyle != Hair.none)
            Part(name: 'hairFront', shapes: <Shape>[Shape(_fringe(hairStyle), color: hair)]),
          ...extras,
        ],
      ),
    ],
  );
}

Path _fringe(Hair style) => switch (style) {
      Hair.short => Paths.smooth(const <Offset>[
          Offset(-94, 2), Offset(-100, -44), Offset(-76, -92), Offset(-28, -114),
          Offset(30, -112), Offset(78, -88), Offset(100, -42), Offset(94, 2),
          Offset(82, -30), Offset(56, -52), Offset(16, -58), Offset(-22, -50),
          Offset(-58, -54), Offset(-84, -28),
        ]),
      Hair.bob => Paths.smooth(const <Offset>[
          Offset(-100, 30), Offset(-104, -46), Offset(-70, -98), Offset(0, -114),
          Offset(70, -98), Offset(104, -46), Offset(100, 30), Offset(84, 20),
          Offset(80, -40), Offset(40, -52), Offset(-10, -50), Offset(-60, -48),
          Offset(-82, -36), Offset(-84, 20),
        ]),
      Hair.bun => Paths.smooth(const <Offset>[
          Offset(-92, -10), Offset(-90, -60), Offset(-50, -98), Offset(0, -106),
          Offset(50, -98), Offset(90, -60), Offset(92, -10), Offset(70, -50),
          Offset(20, -66), Offset(-30, -64), Offset(-72, -48),
        ]),
      Hair.none => Path(),
    };

/// Breathing, a drifting head, blinks and glances for a [person].
Life personLife(int seed) => Life(
      seed: seed,
      head: 'head',
      eyes: FaceJoints.eyes,
      blinkKey: 'closed',
      pupils: FaceJoints.pupils,
      glance: 2,
      headDrift: 1.6,
    );

/// [FaceStyle.turn] for a [person]: the features slide, and the hair and
/// ears go the other way a little, which is what sells the head as round.
Pose personTurn(FaceStyle face, double amount, {bool hair = true}) => face.turn(amount).plus(Pose(<String, Joint>{
      'head': Joint.rotate(amount * 3),
      if (hair) 'hairFront': Joint.move(Offset(amount * face.turnRange * 0.35, 0)),
      'ears': Joint.move(Offset(-amount * face.turnRange * 0.4, 0)),
    }));

final Path _robotHead = Paths.roundRect(Rect.fromCenter(center: Offset.zero, width: 190, height: 176), 46);
final Path _alienHead = Paths.smooth(const <Offset>[
  Offset(0, -120), Offset(90, -96), Offset(118, -20), Offset(70, 70),
  Offset(0, 104), Offset(-70, 70), Offset(-118, -20), Offset(-90, -96),
]);

/// Six people, nothing alike, one rig.
final List<(String, Part, FaceStyle)> cast = () {
  const FaceStyle ana = FaceStyle(cheeks: Color(0x33FF4D6D));
  final FaceStyle bea = FaceStyle(
    eyeWidth: 34, eyeHeight: 40, pupilRadius: 11, cheeks: const Color(0x44FF6B6B),
    browColor: const Color(0xFF8C3A12),
    nose: <Shape>[Shape(Paths.ellipse(Offset.zero, 6, 4), color: const Color(0x33000000))],
  );
  final FaceStyle carl = FaceStyle(
    eyeWidth: 26, eyeHeight: 30, pupilRadius: 8, browThickness: 10, browColor: const Color(0xFF1A1A1A),
    mouthWidth: 52,
    nose: <Shape>[Shape(Paths.smooth(const <Offset>[Offset(-10, 4), Offset(0, -16), Offset(10, 4), Offset(0, 9)]),
        color: const Color(0x33000000))],
  );
  const FaceStyle dina = FaceStyle(eyeSpacing: 58, browThickness: 5, browLength: 28, mouthWidth: 40);
  const FaceStyle robot = FaceStyle(
    eyeWidth: 40, eyeHeight: 28, eyeColor: Color(0xFF7FF3FF), pupilColor: Color(0xFF0B2A33),
    pupilRadius: 8, highlight: false, browThickness: 0, mouthColor: Color(0xFF0B2A33),
    teethColor: Color(0xFF7FF3FF), tongueColor: Color(0xFF0B2A33), mouthWidth: 56,
  );
  const FaceStyle alien = FaceStyle(
    eyeSpacing: 74, eyeWidth: 46, eyeHeight: 58, eyeY: -14, eyeColor: Color(0xFF111827),
    pupilColor: Color(0xFF111827), pupilRadius: 14, browThickness: 0, mouthY: 62, mouthWidth: 30,
  );
  return <(String, Part, FaceStyle)>[
    ('Ana', person(skin: const Color(0xFFE8B48A), shirt: const Color(0xFF4F7CFF), face: ana), ana),
    ('Bea', person(skin: const Color(0xFFF6D2B8), shirt: const Color(0xFF2EC4B6), hair: const Color(0xFFC0501F), hairStyle: Hair.bob, face: bea), bea),
    ('Carl', person(skin: const Color(0xFF7A4A2E), shirt: const Color(0xFFFFB703), hairStyle: Hair.none, face: carl), carl),
    ('Dina', person(skin: const Color(0xFFC98E62), shirt: const Color(0xFFE76F51), hair: const Color(0xFF1B1B1B), hairStyle: Hair.bun, face: dina), dina),
    ('Unit 7', person(
      skin: const Color(0xFFB8C2CC), shirt: const Color(0xFF445566), hairStyle: Hair.none, face: robot,
      headShape: _robotHead,
      extras: <Part>[
        Part(shapes: <Shape>[
          Shape(Paths.capsule(const Offset(0, -88), const Offset(0, -122), 4), color: const Color(0xFF8899AA)),
          Shape(Paths.circle(const Offset(0, -126), 9), color: const Color(0xFFFF5D73)),
        ]),
      ],
    ), robot),
    ('Zib', person(skin: const Color(0xFF8BD450), shirt: const Color(0xFF7B2CBF), hairStyle: Hair.none, face: alien, headShape: _alienHead), alien),
  ];
}();
