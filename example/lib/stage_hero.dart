
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

// A character, drawn and rigged entirely in code.
//
// The origin is the hip. The figure faces right, hangs straight down at rest,
// and every joint is named so a walk or a gesture can find it. Calling [hero]
// twice with different colours gives two characters on the *same* skeleton --
// which is the point: a walk written once moves all of them.

Color _shade(Color c, [double by = 0.28]) => Color.lerp(c, const Color(0xFF000000), by)!;

/// A limb drawn once, as one outline from the joint to the wrist or ankle,
/// and skinned over the two bones: a bent knee or elbow is a curve, not two
/// capsules hinged at a seam.
Part _limb({
  required String joint,
  required Offset at,
  required double upper,
  required double lower,
  required double upperRadius,
  required double lowerRadius,
  required Color color,
  required String child,
  required Part end,
}) =>
    Part(
      name: joint,
      at: at,
      shapes: <Shape>[
        Shape.skin(
          Skin(
            Paths.taper(Offset.zero, Offset(0, upper + lower), upperRadius, lowerRadius),
            bones: <String>[joint, child],
            tip: Offset(0, lower),
          ),
          color: color,
        ),
      ],
      children: <Part>[
        Part(name: child, at: Offset(0, upper), children: <Part>[end]),
      ],
    );

Part _arm(String side, Offset at, Color suit, Color glove) => _limb(
      joint: 'shoulder$side',
      at: at,
      upper: 56,
      lower: 50,
      upperRadius: 17,
      lowerRadius: 15,
      color: suit,
      child: 'elbow$side',
      end: Part(
        name: 'hand$side',
        at: const Offset(0, 50),
        shapes: <Shape>[Shape(Paths.circle(Offset.zero, 19), color: glove)],
      ),
    );

Part _leg(String side, Offset at, Color suit, Color boot) => _limb(
      joint: 'hip$side',
      at: at,
      upper: 66,
      lower: 60,
      upperRadius: 24,
      lowerRadius: 20,
      color: suit,
      child: 'knee$side',
      end: Part(
        name: 'foot$side',
        at: const Offset(0, 60),
        shapes: <Shape>[
          // Flat-soled, so a foot rolling onto its toe or heel has a real
          // edge to pivot on: see [heroBody].
          Shape(Paths.roundRect(const Rect.fromLTRB(-18, -8, 50, 24), 14), color: boot),
        ],
      ),
    );

Part hero({
  Color suit = const Color(0xFFFF8A3D),
  Color boot = const Color(0xFF3B2A5C),
  Color visor = const Color(0xFF2A1B54),
}) {
  final Color back = _shade(suit);
  final Color glove = const Color(0xFFFFE3C2);

  final Path torso =
      Paths.roundRect(const Rect.fromLTRB(-58, -175, 58, 12), 54);
  // Flat cel shadow: the torso's own outline cut by a larger circle, so the
  // shadow can never leave the body it falls on.
  final Path torsoShade = Path.combine(
    PathOperation.intersect,
    torso,
    Paths.circle(const Offset(-96, -90), 112),
  );

  // One chest joint, drawn as three layers: the back arm behind the torso,
  // the torso, then the head and front arm in front of the front leg. Parts
  // that share a name share a pose, so leaning "chest" leans all three.
  Part chest(List<Part> children) => Part(name: 'chest', children: children);

  return Part(
    name: 'body',
    children: <Part>[
      _leg('B', const Offset(-10, 0), back, _shade(boot, 0.15)),
      chest(<Part>[_arm('B', const Offset(2, -98), back, _shade(glove, 0.12))]),
      chest(<Part>[
        Part(shapes: <Shape>[
          Shape(Paths.roundRect(const Rect.fromLTRB(-92, -150, -44, -48), 18),
              color: _shade(suit, 0.45)),
        ]),
        Part(shapes: <Shape>[
          Shape(torso, gradient: verticalGradient(suit, _shade(suit, 0.12))),
          Shape(torsoShade, color: const Color(0x33000000)),
          // chest panel
          Shape(Paths.roundRect(const Rect.fromLTRB(2, -128, 38, -92), 10),
              color: const Color(0xFF3B2A5C)),
          Shape(Paths.circle(const Offset(14, -110), 5), color: const Color(0xFFFFD166)),
        ]),
      ]),
      _leg('F', const Offset(10, 0), suit, boot),
      chest(<Part>[
        _head(suit, visor),
        _arm('F', const Offset(12, -98), suit, glove),
      ]),
    ],
  );
}

Part _head(Color suit, Color visor) {
  final Path helmet = Paths.circle(Offset.zero, 80);
  final Path helmetShade = Path.combine(
    PathOperation.intersect,
    helmet,
    Paths.circle(const Offset(-70, 20), 96),
  );
  return Part(
    name: 'head',
    at: const Offset(2, -176),
    children: <Part>[
      // antenna, behind the helmet so only the stalk and bulb show
      Part(
        name: 'antenna',
        at: const Offset(-6, -70),
        shapes: <Shape>[
          Shape(Paths.capsule(Offset.zero, const Offset(0, -46), 4),
              color: _shade(suit, 0.3)),
          Shape(Paths.circle(const Offset(0, -52), 11), color: const Color(0xFFFFD166)),
        ],
      ),
      Part(shapes: <Shape>[
        Shape(helmet, gradient: verticalGradient(Color.lerp(suit, const Color(0xFFFFFFFF), 0.18)!, suit)),
        Shape(helmetShade, color: const Color(0x2E000000)),
      ]),
      Part(
        at: const Offset(14, 0),
        shapes: <Shape>[
          Shape(Paths.ellipse(Offset.zero, 58, 44),
              gradient: verticalGradient(visor, _shade(visor, 0.3))),
          // glint
          Shape(Paths.smooth(const <Offset>[
            Offset(-38, -24),
            Offset(-14, -34),
            Offset(-26, -14),
          ]), color: const Color(0x55FFFFFF)),
        ],
        children: <Part>[
          // The face rig every character shares, sized to the visor.
          Part(at: const Offset(16, -6), children: <Part>[heroFace.build()]),
        ],
      ),
    ],
  );
}

/// The hero's joints, for a [Walk]: the default names, with the boot's sole.
const Leg _front = Leg(hip: 'hipF', knee: 'kneeF', ankle: 'footF', toe: Offset(40, 24), heel: Offset(-10, 24));
const Leg _back = Leg(hip: 'hipB', knee: 'kneeB', ankle: 'footB', toe: Offset(40, 24), heel: Offset(-10, 24));
const Biped heroBody = Biped(front: _front, back: _back);

/// The antenna is carried, not animated: it lags every turn of the head and
/// every lurch of the body, then settles.
const List<Jiggle> heroJiggles = <Jiggle>[
  Jiggle('antenna', bone: Offset(0, -52), hertz: 2.2, damping: 0.22, inertia: 1.4),
];

/// Breathing, a drifting head, blinks and glances -- different for every
/// [seed], so two characters never blink in unison.
Life heroLife(int seed) => Life(
      seed: seed,
      head: 'head',
      chest: 'chest',
      eyes: FaceJoints.eyes,
      blinkKey: 'closed',
    );

/// White eyes with no pupils, no brows, on a dark visor: the hero's face
/// is mostly eyes and mouth, and every expression still reads on it.
const FaceStyle heroFace = FaceStyle(
  eyeSpacing: 28,
  eyeWidth: 14,
  eyeHeight: 18,
  pupilColor: Color(0xFFFFFFFF),
  pupilRadius: 4,
  highlight: false,
  browThickness: 0,
  mouthY: 26,
  mouthWidth: 24,
  mouthColor: Color(0xFFFF9E80),
  tongueColor: Color(0xFFE0607A),
);

/// A wave as an animator would time it: wind up, raise the arm with the elbow
/// and hand trailing, waggle the forearm with the hand a beat behind, then
/// lower it with a little settle.
///
/// [from] is where the arm already is; returns null when the wave is over, so
/// the caller can leave the arm to whatever else drives it.
const Pose _armUp = Pose(<String, Joint>{
  'shoulderF': Joint.rotate(-128),
  'elbowF': Joint.rotate(-6),
  'handF': Joint.rotate(0),
});

Gesture _raise(Pose from) => Gesture(
      from: from,
      to: _armUp,
      anticipation: 4,
      action: 9,
      settle: 8,
      windUp: 0.08,
      overshoot: 0.1,
      lag: const <String, int>{'elbowF': 2, 'handF': 4},
    );

Gesture _lower(Pose to) => Gesture(
      from: _armUp,
      to: to,
      anticipation: 3,
      action: 10,
      settle: 9,
      windUp: 0.05,
      overshoot: 0.06,
      lag: const <String, int>{'elbowF': 2, 'handF': 3},
    );

int _waggle(int fps) => (1.2 * fps).round();

/// How many frames [wave] lasts.
int waveLength(int fps) {
  final Gesture raise = _raise(Pose.rest);
  return raise.anticipation + raise.action + _waggle(fps) + _lower(Pose.rest).length;
}

Pose? wave(int frame, int fps, {required Pose from}) {
  final Gesture raise = _raise(from);
  final Gesture lower = _lower(from);
  final int waggle = _waggle(fps);

  if (frame < 0) return null;
  final int rise = raise.anticipation + raise.action;
  if (frame < rise + waggle ~/ 4) return raise.at(frame);
  final int w = frame - rise;
  if (w < waggle) {
    // The waggle grows in and dies away, and the hand trails the forearm by a
    // quarter turn: overlapping action, without a keyframe in sight.
    final double t = w / fps;
    final double envelope = math.sin(math.pi * (w / waggle)).clamp(0.0, 1.0);
    const double hz = 2.4;
    final Pose base = raise.at(frame);
    return base.plus(Pose(<String, Joint>{
      // Out from the head and back, never across the face.
      'elbowF': Joint.rotate(22 * envelope * (0.5 + 0.5 * math.sin(2 * math.pi * hz * t))),
      'handF': Joint.rotate(16 * envelope * math.sin(2 * math.pi * hz * t - math.pi / 2)),
    }));
  }
  final int l = w - waggle;
  if (l < lower.length) return lower.at(l);
  return null;
}

/// What the hero says when it reaches Pip.
final Speech heroLine = Speech.fromText('Hey Pip! Look at this place.');

/// The hero saying [heroLine], [frame] frames in, and pleased about it.
Pose talk(int frame, int fps) =>
    heroLine.at(frame, fps).plus(heroFace.express(Emotion.happy, amount: 0.8));
