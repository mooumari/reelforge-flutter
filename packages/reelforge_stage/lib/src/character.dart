import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'face.dart';
import 'follow.dart';
import 'gesture.dart';
import 'kinematics.dart';
import 'life.dart';
import 'part.dart';
import 'pose.dart';
import 'shape.dart';
import 'skin.dart';
import 'walk.dart';

/// The proportions of a person, seen three-quarters on and facing right,
/// with the origin between the hips.
///
/// Everything a [Character] draws and every [Garment] that dresses it is
/// measured from these, so a child, a giant and a stooped old man are the
/// same template with different numbers -- and wear the same clothes.
///
/// Three-quarters on, the side of the body nearer the viewer is on the
/// left of the drawing and the chest faces right: the near shoulder and hip
/// are left of the middle, the far ones right of it and mostly hidden, and
/// the front of the body -- buttons, buckle, collar -- runs down [mid].
@immutable
class Body {
  const Body({
    this.headRadius = 64,
    this.neck = 10,
    this.torso = 118,
    this.shoulders = 92,
    this.hips = 80,
    this.belly = 0,
    this.chest = 0,
    this.upperArm = 50,
    this.forearm = 46,
    this.armRadius = 12,
    this.wristRadius = 9.5,
    this.hand = 12,
    this.upperLeg = 58,
    this.lowerLeg = 54,
    this.legRadius = 17,
    this.ankleRadius = 11.5,
    this.foot = 34,
    this.hunch = 0,
    this.head = HeadShape.oval,
  });

  /// Small, big-headed, short-limbed.
  static const Body child = Body(
    headRadius: 60, neck: 6, torso: 82, shoulders: 72, hips: 64, upperArm: 34, forearm: 31,
    armRadius: 10, wristRadius: 8, hand: 10.5, upperLeg: 38, lowerLeg: 35,
    legRadius: 13.5, ankleRadius: 10, foot: 28, head: HeadShape.round,
  );

  /// Broad, heavy, a belly.
  static const Body stocky = Body(
    torso: 124, shoulders: 118, hips: 104, belly: 14, chest: 4, armRadius: 15, wristRadius: 11.5,
    hand: 14, legRadius: 21, ankleRadius: 14, upperLeg: 54, lowerLeg: 50,
  );

  /// Tall and narrow.
  static const Body slim = Body(
    headRadius: 60, torso: 128, shoulders: 82, hips: 70, upperArm: 56, forearm: 51,
    armRadius: 10.5, wristRadius: 8.5, upperLeg: 66, lowerLeg: 62, legRadius: 15,
    ankleRadius: 10.5,
  );

  /// Bent at the shoulders, a little smaller.
  static const Body elder = Body(
    headRadius: 61, torso: 108, shoulders: 88, hips: 82, belly: 6, upperArm: 46, forearm: 42,
    upperLeg: 50, lowerLeg: 48, legRadius: 16, hunch: 9, head: HeadShape.long,
  );

  final double headRadius;
  final double neck;

  /// Hips to the top of the shoulders.
  final double torso;

  /// Across the shoulders, and across the hips, as seen.
  final double shoulders, hips;

  /// How far the front sticks out at the waist, and at the chest.
  final double belly, chest;

  final double upperArm, forearm, armRadius, wristRadius, hand;
  final double upperLeg, lowerLeg, legRadius, ankleRadius, foot;

  /// Degrees the chest leans forward at rest; see [Character.stance].
  final double hunch;

  /// The head's silhouette: a skull, cheeks and a jaw.
  final HeadShape head;

  /// The torso's outline edges: [back] the near side, [front] the far side
  /// and chest.
  double get back => -shoulders / 2;
  double get front => shoulders / 2 + chest;

  /// The front middle of the body -- where buttons go -- at [height] from
  /// the hips (0) to the shoulders (1): to the right of centre, as the chest
  /// is turned that way.
  double mid([double height = 0.5]) => shoulders * 0.2 + belly * 0.5 * (1 - (height - 0.3).abs() * 2).clamp(0.0, 1.0);

  /// The bottom of the sole, below the ankle.
  double get sole => ankleRadius + 6;

  Offset get hipF => Offset(-hips * 0.2, -legRadius * 0.6);
  Offset get hipB => Offset(hips * 0.24, -legRadius * 0.8);
  Offset get shoulderF => Offset(-shoulders * 0.36, -torso + armRadius + 5);
  Offset get shoulderB => Offset(shoulders * 0.38, -torso + armRadius + 3);

  /// Where the head turns, on top of the neck.
  Offset get headAt => Offset(shoulders * 0.06, -torso - neck);

  /// The middle of the head, in the head's own space.
  Offset get headCenter => Offset(0, -headRadius * 0.82);

  /// Feet on the ground to the top of the head.
  double get height => upperLeg + lowerLeg + sole + torso + neck + headRadius * 1.82;

  /// The torso: rounded shoulders, a waist, the hips, the chest a little
  /// fuller on the side it faces.
  Path get torsoPath {
    final double w = shoulders / 2, hw = hips / 2, t = torso;
    return Paths.smooth(<Offset>[
      Offset(-w * 0.55, -t),
      Offset(-w * 0.92, -t + 10),
      Offset(-w, -t + 26),
      Offset(-w * 0.94, -t * 0.55),
      Offset(-hw * 0.96, -t * 0.2),
      Offset(-hw, -4),
      Offset(-hw * 0.7, 10),
      Offset(0, 14),
      Offset(hw * 0.75, 10),
      Offset(hw + belly * 0.6, -4),
      Offset(hw * 0.98 + belly, -t * 0.25),
      Offset(w * 0.96 + chest, -t * 0.6),
      Offset(w, -t + 24),
      Offset(w * 0.9, -t + 8),
      Offset(w * 0.5, -t),
      Offset(0, -t - 3),
    ]);
  }
}

/// The silhouette of a head, three-quarters on and facing right: the skull
/// round at the back and top, the face side with a cheek, a jaw and a chin
/// that comes forward the way the face looks.
///
/// Points are in head radii from the middle of the head. Every shape shares
/// the same skull -- top at -1, back at -1 -- so hats, hair and helmets fit
/// them all; they differ in the cheek, the jaw and the chin.
@immutable
class HeadShape {
  const HeadShape(this.points);

  /// A soft oval with a gentle jaw: the everyday head.
  static const HeadShape oval = HeadShape(<(double, double)>[
    (0, -1.0), (0.5, -0.9), (0.84, -0.6), (0.97, -0.2), (0.98, 0.15), (0.88, 0.48), (0.66, 0.78),
    (0.36, 0.94), (0.05, 0.92), (-0.32, 0.74), (-0.62, 0.48), (-0.9, 0.15), (-1.0, -0.25), (-0.82, -0.7),
    (-0.45, -0.95),
  ]);

  /// A broad, square jaw: the hero, the soldier, the cowboy.
  static const HeadShape square = HeadShape(<(double, double)>[
    (0, -1.0), (0.5, -0.92), (0.86, -0.62), (0.98, -0.2), (1.0, 0.2), (0.98, 0.56), (0.86, 0.86),
    (0.5, 0.99), (0.1, 0.98), (-0.3, 0.88), (-0.58, 0.62), (-0.88, 0.25), (-1.0, -0.2), (-0.84, -0.68),
    (-0.46, -0.95),
  ]);

  /// Wide cheekbones and a small, pointed chin.
  static const HeadShape heart = HeadShape(<(double, double)>[
    (0, -1.0), (0.52, -0.92), (0.9, -0.6), (1.0, -0.15), (0.95, 0.25), (0.76, 0.6), (0.5, 0.9),
    (0.3, 1.0), (0.06, 0.88), (-0.3, 0.62), (-0.62, 0.38), (-0.92, 0.08), (-1.0, -0.3), (-0.82, -0.72),
    (-0.45, -0.96),
  ]);

  /// Long in the face: the elder, the scholar.
  static const HeadShape long = HeadShape(<(double, double)>[
    (0, -1.04), (0.5, -0.95), (0.82, -0.66), (0.93, -0.25), (0.93, 0.2), (0.85, 0.62), (0.65, 0.95),
    (0.36, 1.1), (0.05, 1.07), (-0.3, 0.86), (-0.6, 0.52), (-0.88, 0.12), (-0.98, -0.3), (-0.8, -0.76),
    (-0.44, -1.0),
  ]);

  /// Round and full in the cheek: a child.
  static const HeadShape round = HeadShape(<(double, double)>[
    (0, -1.0), (0.55, -0.88), (0.9, -0.5), (1.02, 0.0), (0.98, 0.4), (0.8, 0.72), (0.5, 0.92),
    (0.15, 0.98), (-0.2, 0.94), (-0.5, 0.8), (-0.76, 0.56), (-0.96, 0.2), (-1.0, -0.3), (-0.8, -0.74),
    (-0.45, -0.95),
  ]);

  final List<(double, double)> points;

  /// Part way from [a] to [b]: `HeadShape.lerp(HeadShape.square,
  /// HeadShape.oval, 0.4)` is a squarish jaw, softened. Every preset has the
  /// same number of points, in the same places round the head, so any two
  /// mix.
  static HeadShape lerp(HeadShape a, HeadShape b, double t) {
    assert(a.points.length == b.points.length, 'Head shapes mix only with the same number of points.');
    return HeadShape(<(double, double)>[
      for (int i = 0; i < a.points.length; i++)
        (
          a.points[i].$1 + (b.points[i].$1 - a.points[i].$1) * t,
          a.points[i].$2 + (b.points[i].$2 - a.points[i].$2) * t,
        ),
    ]);
  }

  /// This shape with the jaw and chin pushed out (or in, negative) by
  /// [jaw], and the whole head made [width] times as wide: small changes
  /// that make two people with the same preset look like two people.
  HeadShape adjusted({double jaw = 0, double width = 1}) => HeadShape(<(double, double)>[
        for (final (double x, double y) in points)
          (
            x * width + (y > 0.2 && x > -0.4 ? jaw * 0.6 * (y - 0.2) : 0),
            y + (y > 0.2 ? jaw * (y - 0.2) : 0),
          ),
      ]);

  /// The outline around [center], [radius] to a head radius.
  Path outline(Offset center, double radius) => (_outlines[this] ??= <String, Path>{}).putIfAbsent('$center $radius', () => Paths.smooth(<Offset>[
            for (final (double x, double y) in points) center + Offset(x * radius, y * radius),
          ]));

  static final Expando<Map<String, Path>> _outlines = Expando<Map<String, Path>>();
}

/// A sleeve, a trouser leg, a glove, a boot's shaft: a length of a limb in
/// one colour, skinned to the limb so it bends with it.
///
/// [from] and [to] are fractions of the limb, 0 at the shoulder or hip and 1
/// at the wrist or ankle; the ends are cut straight, as cloth is. [side]
/// limits it to one arm or leg.
@immutable
class Cover {
  const Cover(this.color, {this.from = 0, this.to = 1, this.extra = 2.5, this.side});

  final Color color;
  final double from, to;

  /// How much wider than the limb: cloth sits on top of it.
  final double extra;

  /// `'F'` (near) or `'B'` (far) for one side only; null for both.
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
    final double left = eyeNear.dx - eyeRadius - r * 0.2, right = math.min(eyeFar.dx + eyeRadius + r * 0.3, r * 1.0);
    final double top = browTop - r * 0.12, bottom = mouth.dy + r * 0.36;
    return Paths.ellipse(
      Offset((left + right) / 2, (top + bottom) / 2),
      (right - left) / 2,
      (bottom - top) / 2,
    );
  }

  double get r => body.headRadius;
  Offset get headCenter => body.headCenter;

  /// The head's outline, in head space; see [HeadShape].
  Path get headOutline => body.head.outline(headCenter, r);

  /// Where the ear is, in head space.
  Offset get ear => h(-0.4, 0.08);

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
          body.back - 60,
          to >= 1 ? -body.torso - 60 : -body.torso * to,
          body.front + body.belly + 60,
          from <= 0 ? 60 : -body.torso * from,
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
    Offset chest(double x, double y) => w.point('chest', Offset(x, y));
    final double hw = b.hips / 2;
    final Offset hipBack = chest(-hw - 3, 8), hipFront = chest(hw + b.belly * 0.6 + 3, 8);
    // Cloth hangs from the hips: the hem is never narrower than they are,
    // or it reads as a nappy.
    final double front = math.max(math.max(f.dx, k.dx) + reach, hipFront.dx + reach * flare);
    final double back = math.min(math.min(f.dx, k.dx) - reach, hipBack.dx - reach * flare);
    final double hem = math.max(f.dy, k.dy) + 4;
    return Paths.smooth(<Offset>[
      chest(-hw * 0.96, -b.torso * waist),
      hipBack,
      Offset(back, hem - 10),
      Offset(back + (front - back) * 0.3, hem),
      Offset(back + (front - back) * 0.7, hem),
      Offset(front, hem - 10),
      hipFront,
      chest(hw * 0.98 + b.belly, -b.torso * waist),
      chest(b.mid(waist), -b.torso * waist - 3),
    ]);
  }
}

/// A person built from a [Body], a [FaceStyle] and an outfit of [Garment]s.
///
/// [part] is a rig every motion in this package already knows: it walks with
/// [biped], breathes and blinks with [life], gestures with `shoulderF`,
/// `elbowF` and `handF`, and its face takes every [Emotion], [Speech] and
/// glance. Drawn three-quarters on, facing right: every part of it -- body,
/// head, face, ear, hair, clothes -- is drawn from that one angle, so they
/// agree about which way it is facing. Every surface is [Shade]d, so a
/// [Drawing]'s [Light] gives it form.
///
/// Ten characters are ten lists of garments -- the clothes, hair, beards and
/// hats are reusable, and a new one is a small [Garment] class.
@immutable
class Character {
  const Character({
    this.body = const Body(),
    this.skin = const Color(0xFFE6A97F),
    this.face = Character.defaultFace,
    this.outfit = const <Garment>[],
    this.faceTurn = 0.7,
    this.faceSize = 1,
  });

  /// A small, clean face: modest eyes with big pupils, thin brows, a little
  /// nose turned the way the head is.
  static const FaceStyle defaultFace = FaceStyle(
    eyeSpacing: 60,
    eyeWidth: 24,
    eyeHeight: 30,
    pupilRadius: 9.5,
    browGap: 30,
    browLength: 26,
    browThickness: 6,
    mouthY: 50,
    mouthWidth: 40,
    noseY: 26,
    nose: <Shape>[],
  );

  final Body body;
  final Color skin;
  final FaceStyle face;
  final List<Garment> outfit;

  /// How far round the face is drawn: 0 front on, 1 well turned.
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
    final Offset toe = Offset(body.foot * 0.85, body.sole), heel = Offset(-body.foot * 0.25, body.sole);
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

  static const Pose _armUp = Pose(<String, Joint>{
    'shoulderF': Joint.rotate(128),
    'elbowF': Joint.rotate(44),
    'handF': Joint.rotate(-10),
  });

  /// A wave hello with the near arm, [frame] frames after it starts: up and
  /// out to the side, away from the face, the forearm upright and the hand
  /// waggling a beat behind it, then back down to where the arm is in
  /// [from] -- the pose it is overlaid on. Null before and after.
  static Pose? wave(int frame, int fps, {Pose from = Pose.rest}) {
    if (frame < 0) return null;
    final Pose arm = Pose(<String, Joint>{for (final String j in _armUp.joints.keys) j: from[j]});
    final Gesture raise = Gesture(
      from: arm, to: _armUp, anticipation: 4, action: 10, settle: 8, windUp: 0.06, overshoot: 0.1,
      lag: const <String, int>{'elbowF': 2, 'handF': 4},
    );
    final Gesture lower = Gesture(
      from: _armUp, to: arm, anticipation: 3, action: 11, settle: 9, windUp: 0.05, overshoot: 0.06,
      lag: const <String, int>{'elbowF': 2, 'handF': 3},
    );
    final int rise = raise.anticipation + raise.action, waggle = (fps * 1.33).round();
    if (frame < rise + 8) return raise.at(frame);
    final int w = frame - rise;
    if (w < waggle) {
      final double t = w / fps, envelope = math.sin(math.pi * w / waggle);
      return raise.at(frame).plus(Pose(<String, Joint>{
        'elbowF': Joint.rotate(-18 * envelope * math.sin(2 * math.pi * 2.3 * t)),
        'handF': Joint.rotate(-14 * envelope * math.sin(2 * math.pi * 2.3 * t - math.pi / 2)),
      }));
    }
    final int l = w - waggle;
    return l < lower.length ? lower.at(l) : null;
  }

  /// A nod hello, for hands too full to wave: the head dips, the chest a
  /// little with it, and comes back up. Add it; null before and after.
  static Pose? nod(int frame, int fps) {
    const Pose down = Pose(<String, Joint>{'head': Joint.rotate(14), 'chest': Joint.rotate(4)});
    const Gesture dip = Gesture(to: down, anticipation: 3, action: 8, settle: 6, windUp: 0.15, overshoot: 0.1);
    const Gesture rise = Gesture(from: down, to: Pose.rest, anticipation: 2, action: 10, settle: 8, windUp: 0.05, overshoot: 0.08);
    final int hold = (fps * 0.25).round();
    if (frame < 0) return null;
    if (frame < dip.length + hold) return dip.at(frame);
    final int r = frame - dip.length - hold;
    return r < rise.length ? rise.at(r) : null;
  }

  /// The near foot on the ground at [groundY] -- the far one a touch higher,
  /// as it is further back: where to place [part] when not walking. ([Walk]
  /// places it itself.)
  Offset standing(double x, double groundY) =>
      Offset(x, groundY - body.hipF.dy - body.upperLeg - body.lowerLeg - body.sole);

  double get _faceScale => body.headRadius / 95 * faceSize;

  /// The middle of the face: towards the side the head is turned.
  Offset get _faceAt => body.headCenter + Offset(body.headRadius * 0.16, -body.headRadius * 0.06);

  Fitting get _fitting => _fittings[this] ??= _dress();

  Part get _faceRig => Part(at: _faceAt, scaleX: _faceScale, scaleY: _faceScale, children: <Part>[
        face.build(turn: faceTurn),
      ]);

  Fitting _dress() {
    final Part faceRig = _faceRig;
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

  /// The far side of the body is a little darker and cooler: it is further
  /// from the light, and it pushes it back.
  static Color _far(Color c) => Color.lerp(c, const Color(0xFF2A1F4A), 0.16)!;

  static Color _darker(Color c, double t) => Color.lerp(c, const Color(0xFF2A1F4A), t)!;

  /// The rig, with [hold] hung on its hands: `{'handF': [sword]}`. Things
  /// held are drawn in the hand's space, the hand at the origin; things in
  /// the far hand are behind the body.
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
        _leg('F', fit, (Color c) => c),
        chest(<Part>[
          Part(shapes: <Shape>[
            Shape(
              Paths.capsule(b.headAt + const Offset(0, 14), b.headAt + Offset(0, -b.headRadius * 0.5), b.headRadius * 0.24),
              color: _darker(skin, 0.1),
              shade: Shade.solid,
            ),
            Shape(b.torsoPath, color: skin, shade: Shade.solid),
            ...fit.torso,
          ]),
        ]),
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
    return Part(
      name: 'head',
      at: b.headAt,
      children: <Part>[
        ...fit.headBack,
        Part(shapes: <Shape>[
          // The jaw casts a small shadow on the neck and collar under it;
          // the shape itself is not drawn.
          Shape(Paths.ellipse(fit.h(0.08, 0.5), r * 0.55, r * 0.42), shade: Shade(form: 0, core: 0, rim: 0, cast: r * 0.14, castStrength: 0.32)),
          Shape(fit.headOutline, color: skin, shade: const Shade(form: 0.4, core: 0.2, coreStrength: 0.55, rim: 0.08)),
        ]),
        ...fit.underFace,
        Part(at: _faceAt, scaleX: _faceScale, scaleY: _faceScale, children: <Part>[face.build(turn: faceTurn)]),
        // A nose, turned with the head: a soft rounded bump, its tip towards
        // the way the face looks, lit like the rest of the head.
        Part(shapes: <Shape>[
          Shape(
            Paths.smooth(<Offset>[
              fit.h(0.36, -0.02), fit.h(0.47, 0.14), fit.h(0.47, 0.25), fit.h(0.36, 0.28), fit.h(0.28, 0.22), fit.h(0.31, 0.1),
            ]),
            color: _darker(skin, 0.05),
            shade: const Shade(form: 0.5, core: 0.5, coreStrength: 0.8, rim: 0.12),
          ),
        ]),
        if (!fit.hideHair) ...fit.hair,
        if (!fit.hideEars)
          Part(shapes: <Shape>[
            Shape(Paths.ellipse(fit.ear, r * 0.14, r * 0.2), color: skin, shade: Shade.solid),
            Shape(Paths.ellipse(fit.ear + Offset(r * 0.02, 0), r * 0.06, r * 0.1), color: _darker(skin, 0.22)),
          ]),
        ...fit.headwear,
        ...fit.faceFront,
      ],
    );
  }

  Part _arm(String side, Fitting fit, Color Function(Color) tone, List<Part> held) {
    final Body b = body;
    final double h = b.hand;
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
        shapes: <Shape>[
          // A mitten and a thumb.
          Shape(
            Paths.smooth(<Offset>[
              Offset(-h * 0.75, -h * 0.1), Offset(-h * 0.8, h * 0.8), Offset(-h * 0.2, h * 1.45),
              Offset(h * 0.55, h * 1.2), Offset(h * 0.8, h * 0.4), Offset(h * 0.6, -h * 0.2),
            ]),
            color: tone(fit.hands[side] ?? skin),
            shade: Shade.solid,
          ),
          Shape(Paths.ellipse(Offset(h * 0.85, h * 0.45), h * 0.32, h * 0.45), color: tone(_darker(fit.hands[side] ?? skin, 0.06))),
        ],
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
        shapes: fit.feet?.call(tone) ?? <Shape>[Shape(Character.shoe(b), color: tone(skin), shade: Shade.solid)],
      ),
    );
  }

  /// A foot or a plain shoe, three-quarters on, in ankle space: a rounded
  /// wedge pointing forward, flat on the sole.
  static Path shoe(Body b, {double toe = 1, double top = 0.8}) {
    final double f = b.foot * toe, r = b.ankleRadius, s = b.sole;
    return Paths.smooth(<Offset>[
      Offset(-r * 0.95, -r * top),
      Offset(r * 0.6, -r * top * 0.95),
      Offset(f * 0.62, s * 0.2),
      Offset(f * 0.92, s * 0.62),
      Offset(f * 0.8, s),
      Offset(f * 0.2, s + 0.5),
      Offset(-r * 1.0, s),
      Offset(-r * 1.15, s * 0.45),
    ]);
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
    Shape skinned(double from, double to, double extra, Color color, Shade shade) {
      Path path = Paths.taper(Offset.zero, Offset(0, length), radius(0) + extra, radius(1) + extra);
      // Cloth ends are cut straight across the limb.
      if (from > 0 || to < 1) {
        path = Path.combine(
          PathOperation.intersect,
          path,
          Paths.rect(Rect.fromLTRB(-99, from > 0 ? from * length : -99, 99, to < 1 ? to * length : length + 99)),
        );
      }
      return Shape.skin(
        Skin(path, bones: <String>[joint, child], tip: Offset(0, lower)),
        color: color,
        shade: shade,
      );
    }

    return Part(
      name: joint,
      at: at,
      shapes: <Shape>[
        skinned(0, 1, 0, skinColor, Shade.solid),
        for (final Cover c in covers) skinned(c.from, c.to, c.extra, tone(c.color), Shade.soft),
      ],
      children: <Part>[
        Part(name: child, at: Offset(0, upper), children: <Part>[end]),
      ],
    );
  }
}
