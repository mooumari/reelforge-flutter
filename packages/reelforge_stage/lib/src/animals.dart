import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'face.dart';
import 'follow.dart';
import 'gait.dart';
import 'life.dart';
import 'part.dart';
import 'pose.dart';
import 'shape.dart';
import 'skin.dart';

/// The far side of an animal is darker and cooler, as a person's is.
Color _far(Color c) => Color.lerp(c, const Color(0xFF2A1F4A), 0.18)!;
Color _darker(Color c, double t) => Color.lerp(c, const Color(0xFF2A1F4A), t)!;
Color _lighter(Color c, double t) => Color.lerp(c, const Color(0xFFFFF4E0), t)!;

Path _union(Iterable<Path> paths) => paths.reduce((Path a, Path b) => Path.combine(PathOperation.union, a, b));

/// A lion, or a lioness, or a cub: a four-legged template, seen
/// three-quarters on and facing right, as people are.
///
/// Its rig walks with [Gait] (the joints are a [Quadruped]'s), breathes and
/// blinks with [life], swings its tail on follow-through with [jiggles],
/// and its face is a [FaceStyle], so it takes every [Emotion] and talks
/// with [Speech]. Its root is the near hip.
///
/// Like a [Body], it is numbers: [length] from hip to shoulder, [leg] from
/// hip to ankle, [depth] of the body, and the head's [headRadius]; a cub is
/// the same drawing with a big head and short legs.
@immutable
class Lion {
  const Lion({
    this.coat = const Color(0xFFDDA45E),
    this.belly = const Color(0xFFF2D7A6),
    this.mane,
    this.nose = const Color(0xFF7A3E3A),
    this.eyes = const Color(0xFFF4CB6A),
    this.length = 180,
    this.leg = 124,
    this.depth = 56,
    this.headRadius = 46,
    this.tail = 1,
  });

  /// A male, with a mane.
  static const Lion male = Lion(mane: Color(0xFF9A5226), length: 168, headRadius: 52, depth: 60);

  /// A lioness: no mane, a little slighter.
  static const Lion female = Lion(coat: Color(0xFFD9A867), length: 172, leg: 120, depth: 52, headRadius: 44);

  /// A cub: a big head on a small, short-legged body.
  static const Lion cub = Lion(coat: Color(0xFFE2B276), length: 92, leg: 62, depth: 36, headRadius: 38, tail: 0.8);

  final Color coat, belly;

  /// The mane's colour. Null for none.
  final Color? mane;
  final Color nose, eyes;
  final double length, leg, depth, headRadius;

  /// The tail, against the body's [length].
  final double tail;

  double get _paw => leg * 0.1;

  Offset get chestAt => Offset(length, -depth * 0.08);
  Offset get headAt => Offset(length * 0.38 + depth * 0.25, -depth * 0.95);

  /// The middle of the head, in the head's own space.
  Offset get headCenter => Offset(headRadius * 0.45, -headRadius * 0.3);

  static final Expando<Part> _parts = Expando<Part>();

  /// The rig, built once.
  Part get part => _parts[this] ??= build();

  /// The tail: a chain from the rump.
  Chain get tailChain => Chain(
    'tail',
    segments: 6,
    length: length * 0.95 * tail,
    width: depth * 0.24,
    tipWidth: depth * 0.12,
    color: coat,
    shade: Shade.soft,
    at: Offset(-length * 0.27, -depth * 0.55),
    degrees: 128,
    children: <Part>[
      Part(
        shapes: <Shape>[
          Shape(
            Paths.smooth(<Offset>[
              Offset(-depth * 0.06, -depth * 0.12),
              Offset(depth * 0.2, -depth * 0.15),
              Offset(depth * 0.34, 0),
              Offset(depth * 0.2, depth * 0.15),
              Offset(-depth * 0.06, depth * 0.12),
            ]),
            color: mane ?? _darker(coat, 0.45),
            shade: Shade.soft,
          ),
        ],
      ),
    ],
  );

  /// The legs, for a [Gait].
  Quadruped get quadruped {
    final Offset toe = Offset(_paw * 1.1, _paw * 1.05);
    return Quadruped(
      hindNear: PawLeg(top: 'hipF', middle: 'kneeF', lower: 'hockF', paw: 'footF', toe: toe),
      hindFar: PawLeg(top: 'hipB', middle: 'kneeB', lower: 'hockB', paw: 'footB', toe: toe),
      foreNear: PawLeg(top: 'shoulderF', middle: 'elbowF', lower: 'wristF', paw: 'pawF', toe: toe),
      foreFar: PawLeg(top: 'shoulderB', middle: 'elbowB', lower: 'wristB', paw: 'pawB', toe: toe),
    );
  }

  /// The face: amber eyes, heavy brows, a mouth under the muzzle.
  FaceStyle get face => FaceStyle(
    eyeSpacing: 66,
    eyeY: 0,
    eyeWidth: 25,
    eyeHeight: 23,
    eyeColor: eyes,
    pupilColor: const Color(0xFF2A1A12),
    pupilRadius: 7.5,
    browGap: 21,
    browLength: 28,
    browThickness: 7,
    browColor: _darker(coat, 0.42),
    mouthY: 72,
    mouthWidth: 40,
    mouthColor: const Color(0xFF5A1F2B),
    turnRange: 18,
  );

  double get _faceScale => headRadius / 95;
  Offset get _faceAt => headCenter + Offset(headRadius * 0.3, -headRadius * 0.08);

  /// Breathing, blinks, a drifting head and glancing eyes.
  Life life(int seed) => Life(
    seed: seed,
    head: 'head',
    chest: 'chest',
    eyes: FaceJoints.eyes,
    blinkKey: 'closed',
    pupils: FaceJoints.pupils,
    glance: 1.2,
    headDrift: 1.4,
  );

  /// What swings on follow-through: the tail.
  List<Jiggle> get jiggles => tailChain.jiggles(hertz: 1.4, damping: 0.28, inertia: 1.1, limit: 28);

  /// How it holds itself at rest: the tail hanging, its end curled up.
  Pose get stance => tailChain.curl(-70, taper: 0.9);

  /// A lazy swish of the tail, for idling: add it.
  Pose swish(num frame, int fps) => tailChain.wave(frame, fps, amplitude: 9, hertz: 0.35, taper: 0.8);

  /// Where to place [part] standing still with its feet on [groundY].
  Offset standing(double x, double groundY) => Offset(x, groundY - _paw * 1.05 - leg * 1.02);

  Part build() {
    final double s = length, d = depth;
    // A deep chest behind the forelegs, the belly tucked up towards the
    // hind legs, a round rump.
    final Path torso = Paths.smooth(<Offset>[
      Offset(-s * 0.22, -d * 0.82),
      Offset(s * 0.15, -d * 0.96),
      Offset(s * 0.6, -d * 0.92),
      Offset(s * 0.96, -d * 1.08),
      Offset(s * 1.2, -d * 0.82),
      Offset(s * 1.32, -d * 0.15),
      Offset(s * 1.22, d * 0.58),
      Offset(s * 0.95, d * 0.82),
      Offset(s * 0.6, d * 0.66),
      Offset(s * 0.25, d * 0.42),
      Offset(-s * 0.05, d * 0.42),
      Offset(-s * 0.24, d * 0.25),
      Offset(-s * 0.35, -d * 0.3),
    ]);
    // The underside: a lighter band along the belly, up the chest.
    final Path underside = Path.combine(
      PathOperation.intersect,
      torso,
      Paths.smooth(<Offset>[
        Offset(-s * 0.1, d * 0.42),
        Offset(s * 0.3, d * 0.3),
        Offset(s * 0.8, d * 0.34),
        Offset(s * 1.1, d * 0.1),
        Offset(s * 1.28, -d * 0.35),
        Offset(s * 1.5, -d * 0.2),
        Offset(s * 1.4, d * 1.0),
        Offset(-s * 0.2, d * 1.0),
      ]),
    );
    Shape skinned(Path path, Color color, Shade shade) => Shape.skin(
      Skin(path, bones: const <String>['hips', 'chest'], tip: Offset(s * 0.35, 0)),
      color: color,
      shade: shade,
    );
    Part chest(List<Part> children) => Part(name: 'chest', at: chestAt, children: children);

    return Part(
      name: 'body',
      children: <Part>[
        tailChain.part,
        chest(<Part>[_leg(fore: true, near: false)]),
        _leg(fore: false, near: false),
        Part(name: 'hips', shapes: <Shape>[skinned(torso, coat, Shade.soft), skinned(underside, belly, Shade.gentle)]),
        _leg(fore: false, near: true),
        chest(<Part>[
          // The neck, from the shoulders up into the head.
          Part(
            shapes: <Shape>[
              Shape(
                Paths.smooth(<Offset>[
                  Offset(-s * 0.05, -d * 0.9),
                  Offset(headAt.dx - headRadius * 0.2, headAt.dy - headRadius * 0.5),
                  Offset(headAt.dx + headRadius * 0.7, headAt.dy - headRadius * 0.1),
                  Offset(headAt.dx + headRadius * 0.6, headAt.dy + headRadius * 0.9),
                  Offset(s * 0.25, d * 0.2),
                  Offset(-s * 0.05, -d * 0.2),
                ]),
                color: coat,
                shade: Shade.soft,
              ),
            ],
          ),
          _leg(fore: true, near: true),
          _head(),
        ]),
      ],
    );
  }

  /// A leg's three bones, top to bottom: thigh, shin, hock to paw; or upper
  /// arm, forearm, wrist to paw.
  List<double> _bones(bool fore) => fore ? <double>[leg * 0.4, leg * 0.44, leg * 0.14] : <double>[leg * 0.36, leg * 0.4, leg * 0.26];

  Part _leg({required bool fore, required bool near}) {
    final String side = near ? 'F' : 'B';
    final Color Function(Color) tone = near ? (Color c) => c : _far;
    final double l = leg, p = _paw;
    final List<double> bones = _bones(fore);
    final double knee = bones[0], lower = bones[0] + bones[1], end = lower + bones[2];
    final String top = fore ? 'shoulder$side' : 'hip$side';
    final String middle = fore ? 'elbow$side' : 'knee$side';
    final String joint = fore ? 'wrist$side' : 'hock$side';
    final String paw = fore ? 'paw$side' : 'foot$side';
    // The far legs are a little further along and higher up: further away.
    final Offset at = Offset(near ? 0 : l * 0.11, near ? 0 : -depth * 0.1);
    // Thick at the top, slim from the hock or wrist down.
    final Path limb = Path.combine(
      PathOperation.union,
      Paths.taper(Offset.zero, Offset(0, lower), l * (fore ? 0.16 : 0.17), l * (fore ? 0.085 : 0.075)),
      Paths.taper(Offset(0, lower), Offset(0, end), l * (fore ? 0.085 : 0.075), l * 0.07),
    );
    // The haunch and the shoulder blade: the big muscle at the top of the
    // leg, which gives a cat its shape.
    final Path muscle = fore
        ? Paths.ellipse(Offset(l * 0.02, l * 0.04), l * 0.2, l * 0.3)
        : Paths.smooth(<Offset>[
            Offset(-l * 0.28, l * 0.02),
            Offset(-l * 0.16, -l * 0.26),
            Offset(l * 0.12, -l * 0.24),
            Offset(l * 0.24, l * 0.04),
            Offset(l * 0.14, l * 0.3),
            Offset(-l * 0.1, l * 0.36),
          ]);
    return Part(
      name: top,
      at: at,
      shapes: <Shape>[
        Shape.skin(
          Skin(limb, bones: <String>[top, middle, joint], tip: Offset(0, bones[2])),
          color: tone(coat),
          shade: Shade.soft,
        ),
        Shape(muscle, color: tone(coat), shade: Shade.soft),
      ],
      children: <Part>[
        Part(
          name: middle,
          at: Offset(0, knee),
          children: <Part>[
            Part(
              name: joint,
              at: Offset(0, bones[1]),
              children: <Part>[
                Part(
                  name: paw,
                  at: Offset(0, bones[2]),
                  shapes: <Shape>[
                    Shape(
                      Paths.smooth(<Offset>[
                        Offset(-p * 1.3, -p * 0.7),
                        Offset(p * 0.2, -p * 0.85),
                        Offset(p * 1.15, -p * 0.05),
                        Offset(p * 1.5, p * 0.7),
                        Offset(p * 1.15, p * 1.05),
                        Offset(-p * 1.0, p * 1.05),
                        Offset(-p * 1.5, p * 0.35),
                      ]),
                      color: tone(_lighter(coat, 0.08)),
                      shade: Shade.soft,
                    ),
                    // Toes.
                    for (final double x in <double>[0.15, 0.75])
                      Shape(
                        Paths.capsule(Offset(p * x, p * 0.55), Offset(p * (x + 0.08), p * 1.0), p * 0.06),
                        color: tone(_darker(coat, 0.35)),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Part _head() {
    final double r = headRadius;
    Offset h(double x, double y) => headCenter + Offset(x * r, y * r);
    Path path(List<(double, double)> points) => Paths.smooth(<Offset>[for (final (double x, double y) in points) h(x, y)]);
    final Color ear = _darker(coat, 0.05), inner = _darker(coat, 0.4);
    final Color? m = mane;

    return Part(
      name: 'head',
      at: headAt,
      children: <Part>[
        if (m != null) _mane(m, h),
        // The ears, far then near: round, dark inside.
        Part(
          shapes: <Shape>[
            Shape(Paths.circle(h(0.3, -0.86), r * 0.24), color: _far(ear), shade: Shade.soft),
            Shape(Paths.circle(h(0.32, -0.84), r * 0.12), color: _far(inner)),
            if (m == null) ...<Shape>[
              Shape(Paths.circle(h(-0.42, -0.8), r * 0.28), color: ear, shade: Shade.soft),
              Shape(Paths.circle(h(-0.38, -0.76), r * 0.15), color: inner),
            ],
          ],
        ),
        // The skull, broad, with full cheeks.
        Part(
          shapes: <Shape>[
            Shape(
              path(const <(double, double)>[
                (-0.95, 0.0),
                (-0.85, -0.6),
                (-0.3, -0.98),
                (0.4, -0.95),
                (0.92, -0.5),
                (1.08, 0.05),
                (0.95, 0.55),
                (0.55, 0.92),
                (-0.1, 0.95),
                (-0.72, 0.62),
              ]),
              color: coat,
              shade: const Shade(form: 0.4, core: 0.24, coreStrength: 0.55, rim: 0.1),
            ),
            // Paler fur round the eyes and down the bridge of the nose.
            Shape(
              path(const <(double, double)>[(0.02, -0.28), (0.5, -0.38), (0.9, -0.18), (0.98, 0.2), (0.62, 0.3), (0.22, 0.12)]),
              color: _lighter(coat, 0.22),
              shade: Shade.gentle,
            ),
          ],
        ),
        // On a maned lion the mane comes up over the crown, and the near ear
        // pokes out of it.
        if (m != null) ...<Part>[
          _crown(m, h),
          Part(
            shapes: <Shape>[
              Shape(Paths.circle(h(-0.42, -0.86), r * 0.26), color: ear, shade: Shade.soft),
              Shape(Paths.circle(h(-0.38, -0.82), r * 0.14), color: inner),
            ],
          ),
        ],
        // The muzzle: two whisker pads and a chin, pale.
        Part(
          shapes: <Shape>[
            Shape(Paths.ellipse(h(0.66, 0.84), r * 0.3, r * 0.17), color: _darker(belly, 0.12), shade: Shade.gentle),
            Shape(
              _union(<Path>[Paths.ellipse(h(0.42, 0.52), r * 0.34, r * 0.28), Paths.ellipse(h(0.9, 0.48), r * 0.28, r * 0.25)]),
              color: belly,
              shade: const Shade(form: 0.35, core: 0.2, coreStrength: 0.4, rim: 0.08),
            ),
            for (final (double, double) dot in const <(double, double)>[(0.28, 0.5), (0.38, 0.6), (0.48, 0.5), (0.98, 0.48), (1.05, 0.56)])
              Shape(Paths.circle(h(dot.$1, dot.$2), r * 0.025), color: _darker(belly, 0.35)),
          ],
        ),
        Part(at: _faceAt, scaleX: _faceScale, scaleY: _faceScale, children: <Part>[face.build(turn: 0.7)]),
        // The nose: broad, rounded, on the end of the muzzle.
        Part(
          shapes: <Shape>[
            Shape(
              path(const <(double, double)>[(0.5, 0.18), (0.98, 0.14), (0.9, 0.32), (0.74, 0.42), (0.6, 0.34)]),
              color: nose,
              shade: const Shade(form: 0.5, core: 0.3, coreStrength: 0.6, rim: 0.16),
            ),
          ],
        ),
        if (m != null) _ruff(m, h),
      ],
    );
  }

  /// The mane: a mass of lit locks round the back of the head, over the
  /// shoulders and down the chest.
  Part _mane(Color color, Offset Function(double, double) h) {
    final double r = headRadius;
    final Offset c = h(-0.25, 0.15);
    final Color dark = _darker(color, 0.24);
    const Shade fur = Shade(form: 0.4, core: 0.3, coreStrength: 0.6, rim: 0.12, rimStrength: 0.5);
    return Part(shapes: <Shape>[
      Shape(_scallops(c, 1.0), color: dark, shade: fur),
      Shape(_scallops(c, 0.74, phase: 0.5), color: color, shade: fur),
      // A few darker strands for the direction it falls in.
      for (int i = 0; i < 9; i++)
        Shape(
          _strand(c, -math.pi * 0.9 + i * math.pi * 0.22, r * 0.95, r * (1.35 + (i % 3) * 0.12)),
          color: _darker(color, 0.14),
        ),
    ]);
  }

  /// The mane over the top of the head: a band of locks hugging the skull
  /// from behind the ear to above the brow, their points swept forward.
  Part _crown(Color color, Offset Function(double, double) h) {
    const Shade fur = Shade(form: 0.4, core: 0.3, coreStrength: 0.6, rim: 0.12, rimStrength: 0.5);
    // Round the skull from behind (left) to over the brow, in radians from
    // pointing forward, clockwise.
    Path band(double from, double to, double outer, double inner, int locks) {
      Offset at(double a, double radius) => h(math.cos(a) * radius, math.sin(a) * radius * 1.02);
      final double step = (to - from) / locks;
      return Paths.smooth(<Offset>[
        for (int i = 0; i <= locks * 2; i++) at(from + step * i / 2, outer + (i.isEven ? 0.06 : 0) - 0.04 * (i / (locks * 2))),
        // Back along the inside: a point every lock, swept forward.
        for (int i = locks; i >= 0; i--) ...<Offset>[
          at(from + step * i + step * 0.35, inner - 0.04),
          if (i > 0) at(from + step * (i - 0.5), inner + 0.16),
        ],
      ]);
    }

    return Part(shapes: <Shape>[
      Shape(band(math.pi * 0.95, math.pi * 1.72, 1.12, 0.72, 7), color: _darker(color, 0.1), shade: fur),
      Shape(band(math.pi * 1.05, math.pi * 1.66, 1.06, 0.82, 6), color: color, shade: fur),
    ]);
  }

  /// How far the mane reaches from its middle at angle [a]: further below
  /// and behind, where it hangs.
  double _maneReach(double a) =>
      headRadius * (1.55 + 0.45 * math.max(0, math.sin(a)) + 0.3 * math.max(0, -math.cos(a)));

  /// The mane's outline at [size]: soft scallops, each a lock, swept back.
  Path _scallops(Offset c, double size, {double phase = 0}) {
    const int n = 15;
    return Paths.smooth(<Offset>[
      for (int k = 0; k < n * 2; k++)
        () {
          final double a = 2 * math.pi * (k + phase) / (n * 2) - math.pi / 2;
          final double reach = _maneReach(a) * size * (k.isEven ? 1 : 0.86);
          return c + Offset(math.cos(a), math.sin(a)) * reach + Offset(-headRadius * 0.12 * size * (k.isEven ? 1 : 0), 0);
        }(),
    ]);
  }

  /// A thin lock along the mane, from [from] to [to] out from its middle.
  Path _strand(Offset c, double a, double from, double to) {
    final Offset dir = Offset(math.cos(a), math.sin(a));
    final Offset across = Offset(-dir.dy, dir.dx) * headRadius * 0.05;
    final Offset start = c + dir * from, end = c + dir * to + Offset(-headRadius * 0.12, 0);
    return Paths.smooth(<Offset>[start - across, Offset.lerp(start, end, 0.5)! - across * 0.8, end, Offset.lerp(start, end, 0.5)! + across, start + across]);
  }

  /// The front of the mane: a ruff round the near cheek and under the chin,
  /// framing the face.
  Part _ruff(Color color, Offset Function(double, double) h) {
    return Part(shapes: <Shape>[
      Shape(
        Paths.smooth(<Offset>[
          h(-0.62, -0.62), h(-1.08, -0.5), h(-0.92, -0.18), h(-1.25, 0.12), h(-0.95, 0.4), h(-1.05, 0.78),
          h(-0.6, 0.8), h(-0.48, 1.2), h(-0.12, 0.98), h(0.12, 1.32), h(0.36, 1.02), h(0.62, 1.18), h(0.7, 0.92),
          h(0.3, 0.86), h(-0.3, 0.72), h(-0.66, 0.36), h(-0.76, -0.1),
        ]),
        color: _lighter(color, 0.08),
        shade: const Shade(form: 0.4, core: 0.3, coreStrength: 0.55, rim: 0.12, rimStrength: 0.5),
      ),
    ]);
  }
}
