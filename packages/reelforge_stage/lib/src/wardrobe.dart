import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'character.dart';
import 'part.dart';
import 'shape.dart';
import 'skin.dart';

// A wardrobe of [Garment]s. Each fits any [Body]: head pieces are drawn in
// head radii around the middle of the head, torso pieces from the torso's
// own outline, limb pieces as [Cover]s along the limb. So the cowboy hat fits
// the child, and the robe fits the giant.

Color _dark(Color c, [double t = 0.22]) => Color.lerp(c, const Color(0xFF000000), t)!;
Color _light(Color c, [double t = 0.25]) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;

/// [shape] with [pattern] drawn inside it only.
Part _patterned(Path shape, Color color, Path pattern, Color patternColor) => Part(
      clip: true,
      shapes: <Shape>[Shape(shape, color: color)],
      children: <Part>[
        Part(shapes: <Shape>[Shape(pattern, color: patternColor)]),
      ],
    );

/// A flat cel shadow down the back of [shape].
Shape _shade(Path shape, Rect bounds, [double alpha = 0.14]) => Shape(
      Path.combine(
        PathOperation.intersect,
        shape,
        Paths.circle(Offset(bounds.left - bounds.width * 0.55, bounds.center.dy), bounds.width * 0.85),
      ),
      color: Color.fromRGBO(0, 0, 0, alpha),
    );

// --- hair ---

/// The cap of hair every style starts from: over the top and back of the
/// head, a hairline above the face.
Path _cap(Fitting f, {double back = 0.25}) => f.headPath(<(double, double)>[
      (-0.98, back), (-1.07, -0.22), (-0.9, -0.7), (-0.5, -1.0), (0.05, -1.1),
      (0.55, -0.95), (0.88, -0.6), (0.95, -0.32), (0.7, -0.5), (0.38, -0.6),
      (0.05, -0.62), (-0.25, -0.5), (-0.42, -0.18), (-0.55, back),
    ]);

class ShortHair extends Garment {
  const ShortHair(this.color);
  final Color color;

  @override
  void dress(Fitting f) => f.hair.add(Part(shapes: <Shape>[Shape(_cap(f), color: color)]));
}

/// Down past the shoulders, behind.
class LongHair extends Garment {
  const LongHair(this.color, {this.length = 1.6});
  final Color color;

  /// Head radii below the middle of the head.
  final double length;

  @override
  void dress(Fitting f) {
    f.headBack.add(Part(shapes: <Shape>[
      Shape(
        f.headPath(<(double, double)>[
          (-0.2, -1.08), (-0.85, -0.88), (-1.12, -0.25), (-1.12, length * 0.5),
          (-0.98, length), (-0.45, length + 0.05), (-0.1, length * 0.55), (0.2, 0.1),
        ]),
        color: _dark(color, 0.12),
      ),
    ]));
    f.hair.add(Part(shapes: <Shape>[
      Shape(_cap(f, back: 0.6), color: color),
    ]));
  }
}

class Bun extends Garment {
  const Bun(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    f.headBack.add(Part(shapes: <Shape>[Shape(Paths.circle(f.h(-0.62, -0.9), f.r * 0.38), color: _dark(color, 0.08))]));
    f.hair.add(Part(shapes: <Shape>[Shape(_cap(f), color: color)]));
  }
}

/// A ponytail that swings: a [Chain] with follow-through.
class Ponytail extends Garment {
  const Ponytail(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    final Chain tail = Chain(
      'ponytail',
      segments: 4,
      length: f.r * 1.25,
      width: f.r * 0.36,
      tipWidth: f.r * 0.12,
      color: _dark(color, 0.08),
      at: f.h(-0.85, -0.55),
      degrees: 118,
    );
    f.headBack.add(tail.part);
    f.jiggles.addAll(tail.jiggles(hertz: 1.7, damping: 0.25, inertia: 1.2, limit: 22));
    f.hair.add(Part(shapes: <Shape>[
      Shape(_cap(f), color: color),
      Shape(Paths.circle(f.h(-0.86, -0.55), f.r * 0.1), color: _dark(color, 0.35)),
    ]));
  }
}

/// A big round cloud of curls.
class Curls extends Garment {
  const Curls(this.color, {this.size = 1.3});
  final Color color;
  final double size;

  @override
  void dress(Fitting f) {
    final Offset c = f.h(-0.18, -0.32);
    final Path cloud = Paths.smooth(<Offset>[
      for (int i = 0; i < 18; i++)
        c + Offset.fromDirection(i * math.pi / 9, f.r * size * (i.isEven ? 1 : 0.9)),
    ]);
    f.headBack.add(Part(shapes: <Shape>[Shape(cloud, color: _dark(color, 0.1))]));
    // Over the head too, but not over the face.
    f.hair.add(Part(shapes: <Shape>[
      Shape(
        Path.combine(
          PathOperation.difference,
          Path.combine(PathOperation.intersect, cloud, Paths.rect(Rect.fromLTRB(c.dx - 999, c.dy - 999, c.dx + 999, f.h(0, -0.45).dy))),
          f.faceWindow,
        ),
        color: color,
      ),
    ]));
  }
}

/// A full beard round the jaw. The mouth is drawn over it.
class Beard extends Garment {
  const Beard(this.color, {this.length = 1});
  final Color color;
  final double length;

  @override
  void dress(Fitting f) {
    final Offset m = f.mouth;
    Offset at(double x, double y) => Offset(m.dx + x * f.r, m.dy + y * f.r);
    final double l = length;
    f.underFace.add(Part(shapes: <Shape>[
      Shape(
        Paths.smooth(<Offset>[
          at(-0.65, -0.42), at(-0.58, 0.1), at(-0.3, 0.45 * l + 0.1), at(0.05, 0.62 * l + 0.12),
          at(0.42, 0.48 * l + 0.08), at(0.56, 0.1), at(0.5, -0.12), at(0.25, -0.08),
          at(0, -0.12), at(-0.25, -0.1), at(-0.45, -0.38),
        ]),
        color: color,
      ),
    ]));
    f.faceFront.add(Part(shapes: <Shape>[Shape(_moustache(f), color: _dark(color, 0.08))]));
  }
}

Path _moustache(Fitting f) {
  final Offset m = f.mouth + Offset(0, -f.r * 0.07);
  Offset at(double x, double y) => Offset(m.dx + x * f.r, m.dy + y * f.r);
  return Paths.smooth(<Offset>[
    at(-0.3, 0.05), at(-0.14, -0.08), at(0, -0.05), at(0.14, -0.08),
    at(0.3, 0.05), at(0.14, 0.0), at(0, 0.03), at(-0.14, 0.0),
  ]);
}

class Moustache extends Garment {
  const Moustache(this.color);
  final Color color;

  @override
  void dress(Fitting f) => f.faceFront.add(Part(shapes: <Shape>[Shape(_moustache(f), color: color)]));
}

// --- on the head ---

class CowboyHat extends Garment {
  const CowboyHat(this.color, {this.band = const Color(0xFF3B2416)});
  final Color color;
  final Color band;

  @override
  void dress(Fitting f) {
    final Path crown = f.headPath(<(double, double)>[
      (-0.66, -0.78), (-0.66, -1.35), (-0.4, -1.62), (-0.05, -1.5), (0.28, -1.64), (0.6, -1.4), (0.62, -0.78),
    ]);
    f.headwear.add(Part(
      at: f.h(0, -0.8),
      degrees: -5,
      children: <Part>[
        Part(at: -f.h(0, -0.8), shapes: <Shape>[
          Shape(Paths.ellipse(f.h(0.02, -0.82), f.r * 1.5, f.r * 0.24), color: _dark(color, 0.12)),
          Shape(crown, color: color),
          Shape(Path.combine(PathOperation.intersect, crown, Paths.rect(Rect.fromLTRB(-999, f.h(0, -1.05).dy, 999, f.h(0, -0.86).dy))),
              color: band),
          Shape(Paths.ellipse(f.h(0.02, -0.8), f.r * 1.5, f.r * 0.1), color: _light(color, 0.1)),
        ]),
      ],
    ));
  }
}

class Cap extends Garment {
  const Cap(this.color);
  final Color color;

  @override
  void dress(Fitting f) => f.headwear.add(Part(shapes: <Shape>[
        Shape(Path.combine(PathOperation.intersect, Paths.circle(f.h(0, 0), f.r * 1.04), Paths.rect(Rect.fromLTRB(-999, -999, 999, f.h(0, -0.5).dy))),
            color: color),
        Shape(f.headPath(<(double, double)>[(0.55, -0.62), (1.05, -0.6), (1.5, -0.5), (1.1, -0.42), (0.6, -0.48)]), color: _dark(color)),
        Shape(Paths.circle(f.h(-0.05, -1.03), f.r * 0.08), color: _dark(color)),
      ]));
}

/// A headcloth: the ghutra or keffiyeh, with or without the agal cord.
class Headcloth extends Garment {
  const Headcloth(this.color, {this.check, this.agal = const Color(0xFF151515)});
  final Color color;

  /// The checked pattern's colour, or null for plain cloth.
  final Color? check;

  /// The cord's colour, or null for none.
  final Color? agal;

  @override
  void dress(Fitting f) {
    final Path drape = f.headPath(<(double, double)>[
      (-0.15, -1.18), (-0.9, -0.95), (-1.22, -0.2), (-1.32, 0.8), (-1.22, 1.75), (-0.6, 1.95),
      (-0.05, 1.7), (0.2, 1.1), (0.55, 0.95), (0.95, 0.2), (1.05, -0.5), (0.7, -1.05),
    ]);
    final Path cloth = Path.combine(PathOperation.difference, drape, f.faceWindow);
    Path grid() {
      final Path p = Path();
      final double s = f.r * 0.16;
      for (double x = -3 * f.r; x < 3 * f.r; x += s * 2) {
        for (double y = -3 * f.r; y < 3 * f.r; y += s * 2) {
          p.addRect(Rect.fromLTWH(x, y, s, s));
          p.addRect(Rect.fromLTWH(x + s, y + s, s * 0.45, s * 0.45));
        }
      }
      return p;
    }

    f.hideHair = true;
    f.hideEars = true;
    f.headwear.add(check == null
        ? Part(shapes: <Shape>[Shape(cloth, color: color), _shade(cloth, drape.getBounds())])
        : _patterned(cloth, color, grid(), check!));
    f.headwear.add(Part(shapes: <Shape>[
      Shape(Path.combine(PathOperation.difference, Paths.ellipse(f.faceWindow.getBounds().center, f.faceWindow.getBounds().width / 2 + f.r * 0.06,
          f.faceWindow.getBounds().height / 2 + f.r * 0.06), f.faceWindow), color: _dark(color, 0.12)),
    ]));
    if (agal != null) {
      for (final double y in <double>[-0.86, -0.7]) {
        f.headwear.add(Part(shapes: <Shape>[
          Shape(Paths.ellipse(f.h(-0.12, y), f.r * 0.98, f.r * 0.2), stroke: agal, strokeWidth: f.r * 0.09),
        ]));
      }
    }
  }
}

/// A headscarf wrapped round the head and neck, the face open.
class Hijab extends Garment {
  const Hijab(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    final Path wrap = Path.combine(
      PathOperation.union,
      Paths.ellipse(f.h(-0.05, -0.08), f.r * 1.14, f.r * 1.16),
      f.headPath(<(double, double)>[
        (-1.08, 0.2), (-1.12, 1.25), (-0.75, 1.95), (0.3, 2.05), (1.0, 1.6), (1.02, 0.9), (0.6, 0.7), (0.0, 0.6),
      ]),
    );
    final Path cloth = Path.combine(PathOperation.difference, wrap, f.faceWindow);
    f.hideHair = true;
    f.hideEars = true;
    f.headwear.add(Part(shapes: <Shape>[
      Shape(cloth, color: color),
      _shade(cloth, wrap.getBounds(), 0.12),
      Shape(
        Path.combine(
          PathOperation.difference,
          Paths.ellipse(f.faceWindow.getBounds().center, f.faceWindow.getBounds().width / 2 + f.r * 0.07,
              f.faceWindow.getBounds().height / 2 + f.r * 0.07),
          f.faceWindow,
        ),
        color: _dark(color, 0.15),
      ),
    ]));
  }
}

/// A Roman legionary's helmet, crest and all.
class LegionHelmet extends Garment {
  const LegionHelmet({this.metal = const Color(0xFFB8BEC6), this.crest = const Color(0xFFC0272D)});
  final Color metal;
  final Color crest;

  @override
  void dress(Fitting f) {
    final Path dome = Path.combine(
      PathOperation.difference,
      Path.combine(
        PathOperation.union,
        Path.combine(PathOperation.intersect, Paths.ellipse(f.h(-0.04, -0.1), f.r * 1.1, f.r * 1.12), Paths.rect(Rect.fromLTRB(-999, -999, 999, f.h(0, 0.35).dy))),
        f.headPath(<(double, double)>[(-1.05, 0.0), (-1.35, 0.55), (-0.85, 0.5), (-0.55, 0.2)]),
      ),
      f.faceWindow,
    );
    f.hideHair = true;
    f.hideEars = true;
    f.headwear.add(Part(shapes: <Shape>[
      Shape(f.headPath(<(double, double)>[
        (0.55, -1.08), (0.25, -1.55), (-0.3, -1.68), (-0.88, -1.45), (-1.08, -1.0), (-0.8, -1.12), (-0.3, -1.25), (0.2, -1.12),
      ]), color: crest),
      Shape(dome, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[_light(metal), _dark(metal, 0.1)])),
      _shade(dome, dome.getBounds(), 0.12),
      // Cheek guard on the near side.
      Shape(f.headPath(<(double, double)>[(-0.35, -0.2), (-0.15, 0.55), (0.05, 0.62), (0.0, -0.1)]), color: _dark(metal, 0.08)),
      Shape(Paths.circle(f.h(-0.6, -0.15), f.r * 0.07), color: const Color(0xFFD4A94A)),
    ]));
  }
}

/// The striped royal headcloth of ancient Egypt.
class Nemes extends Garment {
  const Nemes({this.color = const Color(0xFFE8C24A), this.stripe = const Color(0xFF2F5DA8)});
  final Color color;
  final Color stripe;

  @override
  void dress(Fitting f) {
    final Path shape = Path.combine(
      PathOperation.difference,
      f.headPath(<(double, double)>[
        (0.75, -0.95), (0.0, -1.22), (-0.9, -1.0), (-1.25, -0.2), (-1.4, 0.9), (-1.0, 1.25), (-0.65, 0.9),
        (-0.55, 1.95), (0.05, 2.0), (0.15, 0.95), (0.45, 0.85), (1.0, -0.4),
      ]),
      f.faceWindow,
    );
    final Path stripes = Path();
    for (double y = -2.5 * f.r; y < 3 * f.r; y += f.r * 0.22) {
      stripes.addRect(Rect.fromLTRB(-3 * f.r, y, 3 * f.r, y + f.r * 0.1));
    }
    f.hideHair = true;
    f.hideEars = true;
    f.headwear.add(_patterned(shape.shift(Offset.zero), color, stripes.shift(f.h(0, 0)), stripe));
    f.headwear.add(Part(shapes: <Shape>[
      Shape(
        Path.combine(PathOperation.difference,
            Paths.ellipse(f.faceWindow.getBounds().center, f.faceWindow.getBounds().width / 2 + f.r * 0.08, f.faceWindow.getBounds().height / 2 + f.r * 0.08),
            Path.combine(PathOperation.union, f.faceWindow, Paths.rect(Rect.fromLTRB(-999, f.h(0, -0.35).dy, 999, 999)))),
        color: const Color(0xFFD4A94A),
      ),
      // The cobra at the brow.
      Shape(Paths.ellipse(f.h(0.42, -0.98), f.r * 0.07, f.r * 0.12), color: const Color(0xFFD4A94A)),
    ]));
  }
}

class LaurelWreath extends Garment {
  const LaurelWreath({this.color = const Color(0xFF6E9E3A)});
  final Color color;

  @override
  void dress(Fitting f) {
    final Offset c = f.h(-0.05, -0.5);
    final double rx = f.r * 0.98, ry = f.r * 0.5;
    f.headwear.add(Part(children: <Part>[
      for (int i = 0; i <= 14; i++)
        () {
          final double a = math.pi * (1.1 + 0.85 * i / 14);
          final Offset p = c + Offset(rx * math.cos(a), ry * math.sin(a));
          final double tangent = math.atan2(ry * math.cos(a), -rx * math.sin(a)) * 180 / math.pi;
          return Part(at: p, degrees: tangent + (i.isEven ? 35 : -35), shapes: <Shape>[
            Shape(Paths.ellipse(Offset(f.r * 0.1, 0), f.r * 0.13, f.r * 0.05), color: i.isEven ? color : _dark(color, 0.15)),
          ]);
        }(),
    ]));
  }
}

class Glasses extends Garment {
  const Glasses({this.color = const Color(0xFF2A2A2A), this.lens = const Color(0x33BFE6FF)});
  final Color color;
  final Color lens;

  @override
  void dress(Fitting f) {
    final double rr = f.eyeRadius * 1.45, w = f.r * 0.06;
    f.faceFront.add(Part(shapes: <Shape>[
      Shape(Paths.circle(f.eyeNear, rr), color: lens, stroke: color, strokeWidth: w),
      Shape(Paths.ellipse(f.eyeFar, rr * 0.75, rr), color: lens, stroke: color, strokeWidth: w),
      Shape(
        Path()
          ..moveTo(f.eyeNear.dx + rr, f.eyeNear.dy - rr * 0.2)
          ..lineTo(f.eyeFar.dx - rr * 0.75, f.eyeFar.dy - rr * 0.2)
          ..moveTo(f.eyeNear.dx - rr, f.eyeNear.dy - rr * 0.2)
          ..lineTo(f.h(-0.3, 0.05).dx, f.h(-0.3, 0.05).dy),
        stroke: color,
        strokeWidth: w,
      ),
    ]));
  }
}

// --- the body ---

class Shirt extends Garment {
  const Shirt(this.color, {this.sleeves = 1, this.vNeck = true});
  final Color color;

  /// How far down the arm: 1 to the wrist, about 0.4 for short sleeves, 0
  /// for none.
  final double sleeves;
  final bool vNeck;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    f.torso.add(Shape(b.torsoPath, color: color));
    f.torso.add(_shade(b.torsoPath, b.torsoPath.getBounds()));
    if (vNeck) {
      f.torso.add(Shape(
        Paths.polygon(<Offset>[Offset(b.front - 34, -b.torso - 2), Offset(b.front - 16, -b.torso + b.torso * 0.16), Offset(b.front - 4, -b.torso - 2)]),
        color: Color.lerp(f.skin, const Color(0xFF000000), 0.08),
      ));
    }
    if (sleeves > 0) f.arms.add(Cover(color, to: sleeves));
  }
}

/// Open down the front, no sleeves.
class Vest extends Garment {
  const Vest(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final Path vest = Path.combine(
      PathOperation.difference,
      f.torsoBand(0.08, 1),
      Paths.polygon(<Offset>[
        Offset(b.front - 30, -b.torso - 10), Offset(b.front + 60, -b.torso - 10),
        Offset(b.front + 60, 40), Offset(b.front - 6, 40), Offset(b.front - 12, -b.torso * 0.5),
      ]),
    );
    f.torso.add(Shape(vest, color: color));
    f.torso.add(Shape(Paths.circle(Offset(b.front - 14, -b.torso * 0.62), 3.5), color: _dark(color, 0.4)));
    f.torso.add(Shape(Paths.circle(Offset(b.front - 11, -b.torso * 0.4), 3.5), color: _dark(color, 0.4)));
  }
}

/// A long coat -- a lab coat, a duster -- down to [length] of the legs.
class Coat extends Garment {
  const Coat(this.color, {this.length = 0.5, this.lapel});
  final Color color;
  final double length;
  final Color? lapel;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    f.torso.add(Shape(b.torsoPath, color: color));
    f.arms.add(Cover(color, extra: 3.5));
    f.overLegs.add(Part(shapes: <Shape>[
      Shape.live((w) => f.skirt(w, length: length, flare: 0.3, waist: 0.3), color: _dark(color, 0.05)),
    ]));
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(f.torsoBand(0.15, 1), color: color),
      _shade(b.torsoPath, b.torsoPath.getBounds()),
      Shape(
        Paths.polygon(<Offset>[Offset(b.front - 34, -b.torso), Offset(b.front - 10, -b.torso * 0.45), Offset(b.front - 4, -b.torso)]),
        color: lapel ?? _dark(color, 0.12),
      ),
      Shape(Paths.roundRect(Rect.fromLTWH(b.front - 30, -b.torso * 0.32, 22, 16), 3), color: _dark(color, 0.08)),
    ]));
  }
}

/// A robe to the ankles -- a thobe, an abaya, a priest's robe -- with long
/// sleeves.
class Robe extends Garment {
  const Robe(this.color, {this.length = 0.94, this.sleeves = 1, this.flare = 0.55, this.trim});
  final Color color;
  final double length;
  final double sleeves;
  final double flare;
  final Color? trim;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    f.torso.add(Shape(b.torsoPath, color: color));
    if (sleeves > 0) f.arms.add(Cover(color, to: sleeves, extra: 5));
    f.overLegs.add(Part(shapes: <Shape>[
      Shape.live((w) => f.skirt(w, length: length, flare: flare), color: color),
    ]));
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(f.torsoBand(0.12, 1), color: color),
      _shade(b.torsoPath, b.torsoPath.getBounds(), 0.12),
      if (trim != null)
        Shape(Paths.rect(Rect.fromLTWH(b.front - 16, -b.torso + 6, 4, b.torso * 0.42)), color: trim),
    ]));
  }
}

/// A knee-length tunic, belted.
class Tunic extends Garment {
  const Tunic(this.color, {this.length = 0.38, this.sleeves = 0.32});
  final Color color;
  final double length;
  final double sleeves;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    f.torso.add(Shape(b.torsoPath, color: color));
    if (sleeves > 0) f.arms.add(Cover(color, to: sleeves, extra: 4));
    f.overLegs.add(Part(shapes: <Shape>[
      Shape.live((w) => f.skirt(w, length: length, flare: 0.3), color: color),
    ]));
    f.overTorso.add(Part(shapes: <Shape>[Shape(f.torsoBand(0.12, 1), color: color), _shade(b.torsoPath, b.torsoPath.getBounds())]));
  }
}

/// A robe with a length of cloth over one shoulder.
class Toga extends Garment {
  const Toga(this.color, {this.border});
  final Color color;
  final Color? border;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    const Robe(Color(0x00000000), sleeves: 0.3, length: 0.9).dress(f);
    // Recolour what the robe added: it is the same cloth.
    f.torso.removeLast();
    f.torso.add(Shape(b.torsoPath, color: color));
    f.arms.removeLast();
    f.arms.add(Cover(color, to: 0.3, extra: 5));
    f.overLegs.removeLast();
    f.overLegs.add(Part(shapes: <Shape>[Shape.live((w) => f.skirt(w, length: 0.9, flare: 0.5), color: color)]));
    f.overTorso.removeLast();
    final Path drape = Path.combine(
      PathOperation.intersect,
      Paths.polygon(<Offset>[
        Offset(b.back - 10, -b.torso - 10), Offset(b.back + b.depth * 0.45, -b.torso - 10),
        Offset(b.front + 40, -b.torso * 0.15), Offset(b.front + 40, 30), Offset(b.front - 20, 30),
      ]),
      b.torsoPath,
    );
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(f.torsoBand(0.12, 1), color: color),
      Shape(drape, color: _dark(color, 0.07)),
      if (border != null) Shape(drape, stroke: border, strokeWidth: 4),
      _shade(b.torsoPath, b.torsoPath.getBounds()),
    ]));
  }
}

/// A short wrapped skirt: the shendyt of ancient Egypt.
class Kilt extends Garment {
  const Kilt(this.color, {this.length = 0.36, this.belt = const Color(0xFFD4A94A)});
  final Color color;
  final double length;
  final Color? belt;

  @override
  void dress(Fitting f) {
    f.overLegs.add(Part(shapes: <Shape>[
      Shape.live((w) => f.skirt(w, length: length, flare: 0.25, waist: 0.08), color: color),
    ]));
    if (belt != null) f.overTorso.add(Part(shapes: <Shape>[Shape(f.torsoBand(0.04, 0.13), color: belt)]));
  }
}

class Skirt extends Garment {
  const Skirt(this.color, {this.length = 0.6});
  final Color color;
  final double length;

  @override
  void dress(Fitting f) => f.overLegs.add(Part(shapes: <Shape>[
        Shape.live((w) => f.skirt(w, length: length, flare: 0.45, waist: 0.1), color: color),
      ]));
}

class Trousers extends Garment {
  const Trousers(this.color, {this.length = 1});
  final Color color;

  /// 1 to the ankle, about 0.45 for shorts.
  final double length;

  @override
  void dress(Fitting f) {
    f.legs.add(Cover(color, to: length, extra: 3.5));
    f.torso.add(Shape(f.torsoBand(-1, 0.12), color: color));
  }
}

class Belt extends Garment {
  const Belt(this.color, {this.buckle = const Color(0xFFD4A94A)});
  final Color color;
  final Color? buckle;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(f.torsoBand(0.07, 0.15), color: color),
      if (buckle != null)
        Shape(Paths.roundRect(Rect.fromLTRB(b.front + b.belly * 0.5 - 16, -b.torso * 0.16, b.front + b.belly * 0.5 + 2, -b.torso * 0.06), 3),
            color: buckle),
    ]));
  }
}

/// A scarf knotted at the throat.
class Bandana extends Garment {
  const Bandana(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final Offset n = b.headAt;
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(Paths.smooth(<Offset>[
        n + const Offset(-26, -4), n + const Offset(16, -2), n + const Offset(30, 14),
        n + const Offset(14, 40), n + const Offset(-2, 16), n + const Offset(-24, 14),
      ]), color: color),
    ]));
  }
}

/// The broad jewelled collar of ancient Egypt.
class BroadCollar extends Garment {
  const BroadCollar({this.colors = const <Color>[Color(0xFFD4A94A), Color(0xFF2F8FA8), Color(0xFFD4A94A), Color(0xFFC0392B)]});
  final List<Color> colors;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final Offset c = b.headAt + const Offset(-2, 6);
    final List<Shape> rings = <Shape>[];
    for (int i = 0; i < colors.length; i++) {
      final double t = 1 - i / colors.length;
      rings.add(Shape(
        Path.combine(
          PathOperation.difference,
          Paths.ellipse(c, b.depth * (0.22 + 0.32 * t), b.torso * (0.08 + 0.2 * t)),
          Paths.ellipse(c, b.depth * 0.22, b.torso * 0.08),
        ),
        color: colors[i],
      ));
    }
    f.overTorso.add(Part(shapes: rings));
  }
}

/// A cape hung from the shoulders, swinging on follow-through.
class Cape extends Garment {
  const Cape(this.color, {this.length = 0.9});
  final Color color;

  /// As a fraction of the distance from the shoulders to the feet.
  final double length;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double drop = (b.torso + b.upperLeg + b.lowerLeg) * length;
    final Chain cape = Chain(
      'cape',
      segments: 5,
      length: drop,
      width: b.depth * 0.45,
      tipWidth: b.depth * 0.95,
      color: _dark(color, 0.1),
      at: Offset(b.back + 18, -b.torso + 8),
      degrees: 97,
    );
    f.behind.add(cape.part);
    f.jiggles.addAll(cape.jiggles(hertz: 1.3, damping: 0.35, inertia: 0.9, limit: 14));
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(Paths.smooth(<Offset>[
        Offset(b.back + 6, -b.torso + 4), Offset(b.back + b.depth * 0.5, -b.torso - 6),
        Offset(b.front - 10, -b.torso + 4), Offset(b.back + b.depth * 0.5, -b.torso + 18),
      ]), color: color),
      Shape(Paths.circle(Offset(b.front - 18, -b.torso + 6), 6), color: const Color(0xFFD4A94A)),
    ]));
  }
}

/// A breastplate in bands, with shoulder guards: a legionary's lorica, a
/// knight's plate, a cyborg's casing.
class Armour extends Garment {
  const Armour({this.metal = const Color(0xFFB8BEC6), this.bands = 4});
  final Color metal;
  final int bands;

  @override
  void dress(Fitting f) {
    final List<Shape> plates = <Shape>[];
    for (int i = 0; i < bands; i++) {
      final double from = 0.12 + i * 0.85 / bands, to = from + 0.85 / bands + 0.02;
      plates.add(Shape(f.torsoBand(from, to), color: i.isEven ? metal : _dark(metal, 0.08)));
    }
    plates.add(_shade(f.body.torsoPath, f.body.torsoPath.getBounds(), 0.16));
    f.overTorso.add(Part(shapes: plates));
    f.arms.add(Cover(_light(metal, 0.1), to: 0.24, extra: 7));
  }
}

class Gloves extends Garment {
  const Gloves(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    f.hands['F'] = color;
    f.hands['B'] = color;
    f.arms.add(Cover(color, from: 0.9, extra: 2.5));
  }
}

// --- feet ---

class Boots extends Garment {
  const Boots(this.color, {this.height = 0.28});
  final Color color;
  final double height;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    f.feet = (Color Function(Color) tone) => <Shape>[
          Shape(Paths.roundRect(Rect.fromLTRB(-b.foot * 0.32, -b.ankleRadius * 0.9, b.foot * 0.98, b.sole), b.ankleRadius * 0.85),
              color: tone(color)),
          Shape(Paths.rect(Rect.fromLTRB(-b.foot * 0.32, b.sole - 5, b.foot * 0.98, b.sole)), color: tone(_dark(color, 0.35))),
        ];
    if (height > 0) f.legs.add(Cover(color, from: 1 - height * b.lowerLeg / (b.upperLeg + b.lowerLeg) * 2, extra: 4));
  }
}

/// Pointed toe, a riding heel, a tall shaft.
class CowboyBoots extends Garment {
  const CowboyBoots(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double s = b.sole, r = b.ankleRadius;
    f.feet = (Color Function(Color) tone) => <Shape>[
          Shape(Paths.smooth(<Offset>[
            Offset(-b.foot * 0.3, -r), Offset(b.foot * 0.25, -r * 0.6), Offset(b.foot * 0.75, s - 9),
            Offset(b.foot * 1.08, s - 2), Offset(b.foot * 0.6, s), Offset(-b.foot * 0.1, s - 3), Offset(-b.foot * 0.32, s * 0.3),
          ]), color: tone(color)),
          Shape(Paths.rect(Rect.fromLTRB(-b.foot * 0.3, s - 7, -b.foot * 0.06, s)), color: tone(_dark(color, 0.4))),
        ];
    f.legs.add(Cover(color, from: 0.68, extra: 5.5));
    f.legs.add(Cover(_dark(color, 0.18), from: 0.68, to: 0.71, extra: 6.5));
  }
}

class Sandals extends Garment {
  const Sandals({this.color = const Color(0xFF8A5A2B)});
  final Color color;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final Color skin = f.skin;
    f.feet = (Color Function(Color) tone) => <Shape>[
          Shape(Paths.roundRect(Rect.fromLTRB(-b.foot * 0.3, -b.ankleRadius * 0.7, b.foot * 0.95, b.sole - 3), b.ankleRadius * 0.8),
              color: tone(skin)),
          Shape(Paths.roundRect(Rect.fromLTRB(-b.foot * 0.32, b.sole - 5, b.foot * 0.98, b.sole), 2), color: tone(color)),
          Shape(Paths.rect(Rect.fromLTRB(b.foot * 0.3, -2, b.foot * 0.38, b.sole - 4)), color: tone(color)),
          Shape(Paths.rect(Rect.fromLTRB(-b.foot * 0.05, -b.ankleRadius * 0.5, b.foot * 0.03, b.sole - 4)), color: tone(color)),
        ];
    f.legs.add(Cover(color, from: 0.93, to: 0.96, extra: 1.5));
  }
}

class Sneakers extends Garment {
  const Sneakers(this.color, {this.sole = const Color(0xFFF4F4F4)});
  final Color color;
  final Color sole;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    f.feet = (Color Function(Color) tone) => <Shape>[
          Shape(Paths.roundRect(Rect.fromLTRB(-b.foot * 0.32, -b.ankleRadius * 0.85, b.foot * 1.0, b.sole), b.ankleRadius),
              color: tone(color)),
          Shape(Paths.roundRect(Rect.fromLTRB(-b.foot * 0.34, b.sole - 7, b.foot * 1.02, b.sole), 3), color: tone(sole)),
          Shape(Paths.rect(Rect.fromLTRB(b.foot * 0.2, -b.ankleRadius * 0.55, b.foot * 0.55, -b.ankleRadius * 0.35)), color: tone(sole)),
        ];
  }
}

// --- cyborg ---

/// One arm (or both) replaced by a machine.
class RobotArm extends Garment {
  const RobotArm({this.metal = const Color(0xFF8E9AA8), this.side = 'F', this.glow = const Color(0xFF4DE8FF)});
  final Color metal;
  final String? side;
  final Color glow;

  @override
  void dress(Fitting f) {
    f.arms.add(Cover(metal, extra: 2.5, side: side));
    f.arms.add(Cover(_dark(metal, 0.35), from: 0.47, to: 0.53, extra: 3.5, side: side));
    f.arms.add(Cover(glow, from: 0.7, to: 0.74, extra: 3, side: side));
    for (final String s in side == null ? const <String>['F', 'B'] : <String>[side!]) {
      f.hands[s] = _dark(metal, 0.1);
    }
  }
}

/// A machine eye where the near eye was, glowing.
class EyeImplant extends Garment {
  const EyeImplant({this.metal = const Color(0xFF6B7684), this.glow = const Color(0xFFFF3B3B)});
  final Color metal;
  final Color glow;

  @override
  void dress(Fitting f) {
    final double rr = f.eyeRadius * 1.5;
    f.faceFront.add(Part(shapes: <Shape>[
      Shape(Paths.circle(f.eyeNear, rr), color: metal),
      Shape(Paths.circle(f.eyeNear, rr * 0.62), color: const Color(0xFF15181D)),
      Shape(Paths.circle(f.eyeNear, rr * 0.38), color: glow),
      Shape(Paths.circle(f.eyeNear + Offset(-rr * 0.12, -rr * 0.12), rr * 0.12), color: const Color(0xCCFFFFFF)),
    ]));
  }
}

/// A metal plate over the back of the skull.
class HeadPlate extends Garment {
  const HeadPlate({this.metal = const Color(0xFF8E9AA8)});
  final Color metal;

  @override
  void dress(Fitting f) {
    final Path plate = Path.combine(
      PathOperation.intersect,
      Paths.ellipse(f.h(0, 0), f.r * 1.03, f.r * 1.05),
      Paths.polygon(<Offset>[f.h(-2, -2), f.h(0.2, -2), f.h(-0.2, -0.3), f.h(-0.5, 0.35), f.h(-2, 0.35)]),
    );
    f.headwear.add(Part(shapes: <Shape>[
      Shape(plate, color: metal),
      for (final (double, double) p in <(double, double)>[(-0.65, -0.5), (-0.3, -0.85), (-0.8, 0.0)])
        Shape(Paths.circle(f.h(p.$1, p.$2), f.r * 0.05), color: _dark(metal, 0.35)),
    ]));
  }
}

/// A glowing panel on the chest.
class ChestLights extends Garment {
  const ChestLights({this.panel = const Color(0xFF3A4350), this.glow = const Color(0xFF4DE8FF)});
  final Color panel;
  final Color glow;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final Rect r = Rect.fromLTWH(b.front - 20, -b.torso * 0.74, 18, 40);
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(Paths.roundRect(r, 6), color: panel),
      for (int i = 0; i < 3; i++) Shape(Paths.circle(Offset(r.center.dx, r.top + 8 + i * 12), 4), color: glow),
    ]));
  }
}

// --- things to hold ---

/// Props for [Character.build]'s `hold`, drawn in the hand's space with the
/// hand at the origin and the forearm above it.
abstract final class Props {
  /// A staff, upright when the arm hangs down.
  static Part staff({double length = 300, Color color = const Color(0xFF7A5230)}) => Part(shapes: <Shape>[
        Shape(Paths.capsule(Offset(0, -length * 0.62), Offset(0, length * 0.38), 6), color: color),
        Shape(Paths.circle(Offset(0, -length * 0.62), 10), color: _dark(color, 0.15)),
      ]);

  static Part spear({double length = 340, Color shaft = const Color(0xFF7A5230), Color head = const Color(0xFFB8BEC6)}) =>
      Part(shapes: <Shape>[
        Shape(Paths.capsule(Offset(0, -length * 0.65), Offset(0, length * 0.35), 4.5), color: shaft),
        Shape(Paths.polygon(<Offset>[Offset(0, -length * 0.65 - 46), Offset(10, -length * 0.65), Offset(-10, -length * 0.65)]), color: head),
      ]);

  static Part scroll({Color paper = const Color(0xFFF1E4C3)}) => Part(at: const Offset(0, 6), degrees: -20, shapes: <Shape>[
        Shape(Paths.roundRect(const Rect.fromLTRB(-10, -30, 10, 30), 6), color: paper),
        Shape(Paths.rect(const Rect.fromLTRB(-12, -6, 12, 6)), color: const Color(0xFFC0392B)),
      ]);

  /// A tall curved shield, held on the arm.
  static Part shield({Color color = const Color(0xFFB0262C), Color boss = const Color(0xFFD4A94A)}) => Part(
        at: const Offset(10, -30),
        shapes: <Shape>[
          Shape(Paths.roundRect(const Rect.fromLTRB(-30, -95, 30, 95), 14), color: color),
          Shape(Paths.roundRect(const Rect.fromLTRB(-30, -95, 30, 95), 14), stroke: boss, strokeWidth: 5),
          Shape(Paths.circle(Offset.zero, 14), color: boss),
        ],
      );

  static Part clipboard() => Part(at: const Offset(8, -4), degrees: 12, shapes: <Shape>[
        Shape(Paths.roundRect(const Rect.fromLTRB(-20, -28, 20, 28), 4), color: const Color(0xFF8A5A2B)),
        Shape(Paths.rect(const Rect.fromLTRB(-16, -22, 16, 24)), color: const Color(0xFFFFFFFF)),
        for (int i = 0; i < 4; i++) Shape(Paths.rect(Rect.fromLTWH(-12, -14 + i * 9.0, 22, 2.5)), color: const Color(0xFF8899AA)),
      ]);

  static Part lasso({Color color = const Color(0xFFC9A26B)}) => Part(at: const Offset(4, 10), shapes: <Shape>[
        Shape(Paths.ellipse(Offset.zero, 18, 30), stroke: color, strokeWidth: 5),
        Shape(Paths.ellipse(const Offset(3, 4), 15, 26), stroke: _dark(color, 0.15), strokeWidth: 4),
      ]);
}
