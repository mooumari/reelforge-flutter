import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'face.dart';
import 'follow.dart';
import 'kinematics.dart';
import 'life.dart';
import 'part.dart';
import 'pose.dart';
import 'shape.dart';
import 'skin.dart';
import 'walk.dart';

/// The proportions of a person, facing right, with the origin at the hips.
///
/// Everything a [Character] draws and every [Garment] that dresses it is
/// measured from these, so a child, a giant and a hunched old man are the
/// same template with different numbers -- and wear the same clothes.
@immutable
class Body {
  const Body({
    this.headRadius = 60,
    this.neck = 14,
    this.torso = 140,
    this.depth = 96,
    this.belly = 0,
    this.chest = 0,
    this.upperArm = 58,
    this.forearm = 52,
    this.armRadius = 15,
    this.wristRadius = 12,
    this.hand = 15,
    this.upperLeg = 68,
    this.lowerLeg = 62,
    this.legRadius = 21,
    this.ankleRadius = 16,
    this.foot = 50,
    this.hunch = 0,
  });

  /// Small, big-headed, short-limbed.
  static const Body child = Body(
    headRadius: 58, neck: 8, torso: 96, depth: 78, upperArm: 40, forearm: 36,
    armRadius: 12, wristRadius: 10, hand: 12, upperLeg: 46, lowerLeg: 42,
    legRadius: 16, ankleRadius: 13, foot: 38,
  );

  /// Broad, heavy, a belly.
  static const Body stocky = Body(
    torso: 150, depth: 128, belly: 16, chest: 6, armRadius: 18, wristRadius: 14,
    hand: 17, legRadius: 25, ankleRadius: 18, upperLeg: 64, lowerLeg: 58,
  );

  /// Tall and narrow.
  static const Body slim = Body(
    headRadius: 56, torso: 150, depth: 84, upperArm: 64, forearm: 58,
    armRadius: 13, wristRadius: 10, upperLeg: 78, lowerLeg: 72, legRadius: 18,
    ankleRadius: 14,
  );

  /// Bent at the shoulders, a little smaller.
  static const Body elder = Body(
    headRadius: 57, torso: 128, depth: 98, belly: 6, upperArm: 54, forearm: 48,
    upperLeg: 60, lowerLeg: 56, legRadius: 19, hunch: 9,
  );

  final double headRadius;
  final double neck;

  /// Hips to the top of the shoulders.
  final double torso;

  /// Front to back.
  final double depth;

  /// How far the front sticks out at the waist, and at the chest.
  final double belly, chest;

  final double upperArm, forearm, armRadius, wristRadius, hand;
  final double upperLeg, lowerLeg, legRadius, ankleRadius, foot;

  /// Degrees the chest leans forward at rest; see [Character.stance].
  final double hunch;

  double get front => depth / 2;
  double get back => -depth / 2;

  /// The bottom of the sole, below the ankle.
  double get sole => ankleRadius + 8;

  Offset get hipF => Offset(depth * 0.1, 0);
  Offset get hipB => Offset(-depth * 0.1, 0);
  Offset get shoulderF => Offset(depth * 0.12, -torso + armRadius + 8);
  Offset get shoulderB => Offset(-depth * 0.08, -torso + armRadius + 8);

  /// Where the head turns, on top of the neck.
  Offset get headAt => Offset(depth * 0.08, -torso - neck);

  /// The middle of the head, in the head's own space.
  Offset get headCenter => Offset(0, -headRadius * 0.85);

  /// Feet on the ground to the top of the head.
  double get height => upperLeg + lowerLeg + sole + torso + neck + headRadius * 1.85;

  /// The torso, side on: back, belly, chest.
  Path get torsoPath => Paths.smooth(<Offset>[
        Offset(back + 12, -torso),
        Offset(back, -torso * 0.68),
        Offset(back - 2, -torso * 0.3),
        Offset(back + 8, 6),
        Offset(0, 16),
        Offset(front - 6 + belly * 0.4, 6),
        Offset(front + belly, -torso * 0.32),
        Offset(front + chest, -torso * 0.7),
        Offset(front - 16, -torso),
      ]);
}

/// A sleeve, a trouser leg, a glove: a length of a limb in one colour,
/// skinned to the limb so it bends with it.
///
/// [from] and [to] are fractions of the limb, 0 at the shoulder or hip and 1
/// at the wrist or ankle. [side] limits it to one arm or leg.
@immutable
class Cover {
  const Cover(this.color, {this.from = 0, this.to = 1, this.extra = 2.5, this.side});

  final Color color;
  final double from, to;

  /// How much wider than the limb: cloth sits on top of it.
  final double extra;

  /// `'F'` or `'B'` for one side only; null for both.
  final String? side;
}

/// One thing a [Character] wears -- or is: hair, a beard, a hat, a robe,
/// boots, a robot arm.
///
/// A garment is told the body's measurements through a [Fitting] and adds
/// its drawings to the layers it belongs in. Garments are applied in order,
/// so a belt listed after a robe goes over it.
@immutable
abstract class Garment {
  const Garment();

  void dress(Fitting fit);
}

/// What a [Garment] dresses: the body's measurements, and the layers it adds
/// drawings to, back to front.
///
/// Chest-space layers turn with the chest, head-space layers with the head;
/// body-space layers stay with the hips. Head-space coordinates are around
/// [headCenter], in units of the [Body.headRadius] if the garment uses [h].
class Fitting {
  Fitting._(this.body, this.skin, this.eyeNear, this.eyeFar, this.mouth, this.faceScale, this.eyeRadius, this.browTop);

  final Body body;
  final Color skin;

  /// Where the eyes and mouth are, in head space, as the face is drawn: for
  /// glasses, implants, a moustache.
  final Offset eyeNear, eyeFar, mouth;

  /// How big the face is drawn, against a [FaceStyle]'s own units.
  final double faceScale;

  /// Half the larger of the eye's width and height, as drawn.
  final double eyeRadius;

  /// The top of the brows, or of the eyes if there are none, in head space.
  final double browTop;

  /// The part of the head the face is on, for anything that covers the rest
  /// of the head -- a headscarf, a helmet -- to cut out.
  Path get faceWindow {
    final double left = eyeNear.dx - eyeRadius - r * 0.22, right = eyeFar.dx + eyeRadius + r * 0.3;
    final double top = browTop - r * 0.12, bottom = mouth.dy + r * 0.42;
    return Paths.ellipse(
      Offset((left + right) / 2, (top + bottom) / 2),
      (right - left) / 2,
      (bottom - top) / 2,
    );
  }

  double get r => body.headRadius;
  Offset get headCenter => body.headCenter;

  /// [x], [y] in head radii from the middle of the head, in head space.
  Offset h(double x, double y) => headCenter + Offset(x * r, y * r);

  /// A smooth outline through points given in head radii; see [h].
  Path headPath(List<(double, double)> points, {bool closed = true}) =>
      Paths.smooth(<Offset>[for (final (double x, double y) in points) h(x, y)], closed: closed);

  /// The torso between two heights, as fractions from the hips (0) to the
  /// shoulders (1): a belt, a shirt, a breastplate.
  Path torsoBand(double from, double to) => Path.combine(
        PathOperation.intersect,
        body.torsoPath,
        Paths.rect(Rect.fromLTRB(
          body.back - 40,
          to >= 1 ? -body.torso - 60 : -body.torso * to,
          body.front + body.belly + body.chest + 40,
          from <= 0 ? 40 : -body.torso * from,
        )),
      );

  // Limbs.
  final List<Cover> arms = <Cover>[];
  final List<Cover> legs = <Cover>[];

  /// The feet: shapes in ankle space, for a tone (the far foot is darker).
  /// Null is bare feet.
  List<Shape> Function(Color Function(Color) tone)? feet;

  /// Glove colour, by side (`'F'`, `'B'`); a side not given is bare.
  final Map<String, Color> hands = <String, Color>{};

  // Chest space, back to front.
  final List<Part> behind = <Part>[];
  final List<Shape> torso = <Shape>[];
  final List<Part> overTorso = <Part>[];

  /// Body space, over both legs: robes, skirts, coat tails.
  final List<Part> overLegs = <Part>[];

  // Head space, back to front.
  final List<Part> headBack = <Part>[];
  final List<Part> underFace = <Part>[];
  final List<Part> hair = <Part>[];
  final List<Part> headwear = <Part>[];
  final List<Part> faceFront = <Part>[];

  /// Set by anything that covers the hair or ears: a headscarf, a helmet.
  bool hideHair = false;
  bool hideEars = false;

  /// Parts that swing on follow-through: capes, ponytails.
  final List<Jiggle> jiggles = <Jiggle>[];

  /// A point along a leg as posed: [along] 0 at the hip, 1 at the ankle.
  Offset legPoint(Where w, String side, double along) {
    final Offset hip = w.point('hip$side'), knee = w.point('knee$side'), ankle = w.point('foot$side');
    final double l1 = body.upperLeg, l2 = body.lowerLeg;
    final double d = along * (l1 + l2);
    return d <= l1 ? Offset.lerp(hip, knee, d / l1)! : Offset.lerp(knee, ankle, (d - l1) / l2)!;
  }

  /// A skirt's outline from the waist to [length] down the legs (0 hips, 1
  /// ankles), wide enough to cover both legs however far apart they are:
  /// robes, kilts, dresses, coat tails. [flare] widens the hem.
  Path skirt(Where w, {double length = 0.95, double flare = 0.5, double waist = 0.15}) {
    final Body b = body;
    final Offset f = legPoint(w, 'F', length), k = legPoint(w, 'B', length);
    final double reach = b.legRadius * (1 + flare);
    final double front = math.max(f.dx, k.dx) + reach, back = math.min(f.dx, k.dx) - reach;
    final double hem = math.max(f.dy, k.dy) + 4;
    Offset chest(double x, double y) => w.point('chest', Offset(x, y));
    return Paths.smooth(<Offset>[
      chest(b.back - 1, -b.torso * waist),
      chest(b.back - 3, 10),
      Offset(back, hem - 10),
      Offset(back + (front - back) * 0.3, hem),
      Offset(back + (front - back) * 0.7, hem),
      Offset(front, hem - 10),
      chest(b.front + b.belly * 0.6 + 3, 10),
      chest(b.front + b.belly + 1, -b.torso * waist),
    ]);
  }
}

/// A person built from a [Body], a [FaceStyle] and an outfit of [Garment]s.
///
/// [part] is a rig every motion in this package already knows: it walks with
/// [biped], breathes and blinks with [life], waves with any gesture written
/// for `shoulderF`, `elbowF` and `handF`, and its face takes every
/// [Emotion], [Speech] and glance. Drawn side on, facing right, with the face
/// turned three-quarters towards the viewer.
///
/// Ten characters are ten lists of garments -- the clothes, hair, beards and
/// hats are reusable, and a new one is a small [Garment] class.
@immutable
class Character {
  const Character({
    this.body = const Body(),
    this.skin = const Color(0xFFE0A47C),
    this.face = const FaceStyle(),
    this.outfit = const <Garment>[],
    this.faceTurn = 0.55,
    this.faceSize = 1,
  });

  final Body body;
  final Color skin;
  final FaceStyle face;
  final List<Garment> outfit;

  /// How far round the face is drawn: 0 front on, 1 three-quarters.
  final double faceTurn;

  /// The face's size on the head; 1 fits a [FaceStyle] drawn for a head of
  /// radius 95 to this body's head.
  final double faceSize;

  static final Expando<Part> _parts = Expando<Part>();
  static final Expando<Fitting> _fittings = Expando<Fitting>();

  /// The rig, built once per character.
  Part get part => _parts[this] ??= build();

  /// What follow-through should swing: capes, ponytails.
  List<Jiggle> get jiggles => _fitting.jiggles;

  /// The legs and feet, for a [Walk].
  Biped get biped {
    final Offset toe = Offset(body.foot * 0.85, body.sole), heel = Offset(-body.foot * 0.22, body.sole);
    return Biped(
      front: Leg(hip: 'hipF', knee: 'kneeF', ankle: 'footF', toe: toe, heel: heel),
      back: Leg(hip: 'hipB', knee: 'kneeB', ankle: 'footB', toe: toe, heel: heel),
    );
  }

  /// Breathing, blinks, a drifting head and glancing pupils; seed it
  /// differently for every character.
  Life life(int seed) => Life(
        seed: seed,
        head: 'head',
        chest: 'chest',
        eyes: FaceJoints.eyes,
        blinkKey: 'closed',
        pupils: FaceJoints.pupils,
        glance: 1.4,
        headDrift: 1.8,
      );

  /// How the character holds itself at rest: an elder's stoop. Add it to
  /// whatever else it is doing.
  Pose get stance => body.hunch == 0
      ? Pose.rest
      : Pose(<String, Joint>{
          'chest': Joint.rotate(body.hunch),
          'head': Joint.rotate(-body.hunch * 0.7),
        });

  /// Feet on the ground, at [groundY]: where to place [part] when not
  /// walking. ([Walk] places it itself.)
  Offset standing(double x, double groundY) =>
      Offset(x, groundY - body.upperLeg - body.lowerLeg - body.sole);

  double get _faceScale => body.headRadius / 95 * faceSize;

  Offset get _faceAt => body.headCenter + Offset(body.headRadius * 0.1, -body.headRadius * 0.02);

  Fitting get _fitting => _fittings[this] ??= _dress();

  Fitting _dress() {
    final Part faceRig = Part(at: _faceAt, scaleX: _faceScale, scaleY: _faceScale, children: <Part>[
      face.build(turn: faceTurn),
    ]);
    Offset where(String name, [Offset local = Offset.zero]) => frameOf(faceRig, Pose.rest, name).apply(local);
    final Fitting fit = Fitting._(
      body,
      skin,
      where(FaceJoints.eyeL),
      where(FaceJoints.eyeR),
      where(FaceJoints.mouth),
      _faceScale,
      math.max(face.eyeWidth, face.eyeHeight) / 2 * _faceScale,
      _faceAt.dy + (face.eyeY - (face.browThickness > 0 ? face.browGap + face.browThickness + 6 : face.eyeHeight / 2)) * _faceScale,
    );
    for (final Garment g in outfit) {
      g.dress(fit);
    }
    return fit;
  }

  static Color _far(Color c) => Color.lerp(c, const Color(0xFF1B1030), 0.2)!;

  /// The rig, with [hold] hung on its hands: `{'handF': [sword]}`. Things
  /// held are drawn in the hand's space, the hand at the origin.
  Part build({Map<String, List<Part>> hold = const <String, List<Part>>{}}) {
    final Fitting fit = _fitting;
    final Body b = body;
    Part chest(List<Part> children) => Part(name: 'chest', children: children);

    return Part(
      name: 'body',
      children: <Part>[
        if (fit.behind.isNotEmpty) chest(fit.behind),
        chest(<Part>[_arm('B', fit, _far, hold['handB'] ?? const <Part>[])]),
        _leg('B', fit, _far),
        chest(<Part>[
          Part(shapes: <Shape>[
            Shape(Paths.capsule(b.headAt + const Offset(0, 6), b.headAt + Offset(0, -b.headRadius * 0.4), b.depth * 0.14),
                color: Color.lerp(skin, const Color(0xFF000000), 0.12)),
            Shape(b.torsoPath, color: skin),
            ...fit.torso,
          ]),
        ]),
        _leg('F', fit, (Color c) => c),
        if (fit.overLegs.isNotEmpty) Part(children: fit.overLegs),
        chest(<Part>[
          ...fit.overTorso,
          _head(fit),
          _arm('F', fit, (Color c) => c, hold['handF'] ?? const <Part>[]),
        ]),
      ],
    );
  }

  Part _head(Fitting fit) {
    final Body b = body;
    final double r = b.headRadius;
    final Offset c = b.headCenter;
    return Part(
      name: 'head',
      at: b.headAt,
      children: <Part>[
        ...fit.headBack,
        Part(shapes: <Shape>[
          Shape(Paths.ellipse(c, r, r * 1.02), color: skin),
          // Cel shadow on the back of the head, cut to the head.
          Shape(
            Path.combine(PathOperation.intersect, Paths.ellipse(c, r, r * 1.02),
                Paths.circle(c + Offset(-r * 1.55, r * 0.1), r * 1.2)),
            color: const Color(0x1C000000),
          ),
        ]),
        ...fit.underFace,
        Part(at: _faceAt, scaleX: _faceScale, scaleY: _faceScale, children: <Part>[face.build(turn: faceTurn)]),
        if (!fit.hideHair) ...fit.hair,
        if (!fit.hideEars)
          Part(shapes: <Shape>[
            Shape(Paths.ellipse(c + Offset(-r * 0.2, r * 0.12), r * 0.15, r * 0.21),
                color: Color.lerp(skin, const Color(0xFF000000), 0.06)),
            Shape(Paths.ellipse(c + Offset(-r * 0.19, r * 0.12), r * 0.06, r * 0.1),
                color: Color.lerp(skin, const Color(0xFF000000), 0.18)),
          ]),
        ...fit.headwear,
        ...fit.faceFront,
      ],
    );
  }

  Part _arm(String side, Fitting fit, Color Function(Color) tone, List<Part> held) {
    final Body b = body;
    return _limb(
      joint: 'shoulder$side',
      child: 'elbow$side',
      at: side == 'F' ? b.shoulderF : b.shoulderB,
      upper: b.upperArm,
      lower: b.forearm,
      r0: b.armRadius,
      r1: b.wristRadius,
      skinColor: tone(skin),
      covers: <Cover>[for (final Cover c in fit.arms) if (c.side == null || c.side == side) c],
      tone: tone,
      end: Part(
        name: 'hand$side',
        at: Offset(0, b.forearm),
        shapes: <Shape>[Shape(Paths.circle(Offset(0, b.hand * 0.35), b.hand), color: tone(fit.hands[side] ?? skin))],
        children: held,
      ),
    );
  }

  Part _leg(String side, Fitting fit, Color Function(Color) tone) {
    final Body b = body;
    return _limb(
      joint: 'hip$side',
      child: 'knee$side',
      at: side == 'F' ? b.hipF : b.hipB,
      upper: b.upperLeg,
      lower: b.lowerLeg,
      r0: b.legRadius,
      r1: b.ankleRadius,
      skinColor: tone(skin),
      covers: <Cover>[for (final Cover c in fit.legs) if (c.side == null || c.side == side) c],
      tone: tone,
      end: Part(
        name: 'foot$side',
        at: Offset(0, b.lowerLeg),
        shapes: fit.feet?.call(tone) ??
            <Shape>[
              Shape(
                Paths.roundRect(
                  Rect.fromLTRB(-b.foot * 0.3, -b.ankleRadius * 0.7, b.foot * 0.95, b.sole),
                  b.ankleRadius * 0.8,
                ),
                color: tone(skin),
              ),
            ],
      ),
    );
  }

  /// One skinned outline for the bare limb, then one per cover, all bent by
  /// the same two bones.
  Part _limb({
    required String joint,
    required String child,
    required Offset at,
    required double upper,
    required double lower,
    required double r0,
    required double r1,
    required Color skinColor,
    required List<Cover> covers,
    required Color Function(Color) tone,
    required Part end,
  }) {
    final double length = upper + lower;
    double radius(double t) => r0 + (r1 - r0) * t;
    Shape skinned(double from, double to, double extra, Color color) => Shape.skin(
          Skin(
            Paths.taper(Offset(0, from * length), Offset(0, to * length), radius(from) + extra, radius(to) + extra),
            bones: <String>[joint, child],
            tip: Offset(0, lower),
          ),
          color: color,
        );
    return Part(
      name: joint,
      at: at,
      shapes: <Shape>[
        skinned(0, 1, 0, skinColor),
        for (final Cover c in covers) skinned(c.from, c.to, c.extra, tone(c.color)),
      ],
      children: <Part>[
        Part(name: child, at: Offset(0, upper), children: <Part>[end]),
      ],
    );
  }
}
