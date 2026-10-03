import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'character.dart';
import 'part.dart';
import 'shape.dart';
import 'skin.dart';

// A wardrobe of [Garment]s, drawn three-quarters on and facing right, like
// the [Character] that wears them. Each fits any [Body]: head pieces are
// drawn in head radii around the middle of the head (see [Fitting.h]) and
// follow its [HeadShape]; torso pieces from the torso's own outline and its
// front middle ([Body.mid]); limb pieces as [Cover]s along the limb; robes
// and skirts as live outlines spanning both legs as posed. So the cowboy hat
// fits the child, and the robe stays closed over a stride.
//
// Everything is [Shade]d: it takes the drawing's light as the body does.

Color _dark(Color c, [double t = 0.22]) => Color.lerp(c, const Color(0xFF000000), t)!;
Color _light(Color c, [double t = 0.25]) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;

const Shade _cloth = Shade.soft;
const Shade _metal = Shade(form: 0.5, core: 0.35, coreStrength: 0.8, rim: 0.14, rimStrength: 0.75);

/// [shape], with [details] drawn inside it only.
Part _inside(Shape shape, List<Shape> details) => Part(
      clip: true,
      shapes: <Shape>[shape],
      children: <Part>[Part(shapes: details)],
    );

/// A tapering ribbon along [points], [width] wide at the first and [tip]
/// of that at the last: a lock of hair, a fold of cloth.
Path _ribbon(List<Offset> points, double width, {double tip = 0.15}) {
  final int n = points.length;
  final List<Offset> left = <Offset>[], right = <Offset>[];
  for (int i = 0; i < n; i++) {
    final double t = i / (n - 1);
    final Offset tangent = points[math.min(i + 1, n - 1)] - points[math.max(i - 1, 0)];
    final Offset normal = Offset(-tangent.dy, tangent.dx) / tangent.distance;
    final double w = width / 2 * (1 - (1 - tip) * t);
    left.add(points[i] + normal * w);
    right.add(points[i] - normal * w);
  }
  return Paths.smooth(<Offset>[...left, ...right.reversed]);
}

/// A [_ribbon] along points in head radii; [width] in head radii.
Path _lock(Fitting f, List<(double, double)> spine, double width, {double tip = 0.15}) =>
    _ribbon(<Offset>[for (final (double x, double y) in spine) f.h(x, y)], width * f.r, tip: tip);

/// [path] scaled about [center].
Path _scaled(Path path, Offset center, double sx, [double? sy]) {
  final double ky = sy ?? sx;
  return path.transform(Float64List.fromList(<double>[
    sx, 0, 0, 0, //
    0, ky, 0, 0,
    0, 0, 1, 0,
    center.dx * (1 - sx), center.dy * (1 - ky), 0, 1,
  ]));
}

Path _and(Path a, Path b) => Path.combine(PathOperation.intersect, a, b);
Path _or(Path a, Path b) => Path.combine(PathOperation.union, a, b);
Path _minus(Path a, Path b) => Path.combine(PathOperation.difference, a, b);

/// Everything above, or below, a height: for cutting.
Path _above(double y) => Paths.rect(Rect.fromLTRB(-9999, -9999, 9999, y));
Path _below(double y) => Paths.rect(Rect.fromLTRB(-9999, y, 9999, 9999));

// --- hair ---
//
// Hair is a mass, darker locks inside it that say which way it is combed, a
// band of shine where the light catches it, and a small shadow cast on the
// forehead under the fringe. The hairline sweeps back from the forehead to
// the temple and comes down in front of the ear as a sideburn; the ear is
// drawn over whatever hair is behind it.

Part _hair(
  Fitting f,
  Color color,
  Path mass, {
  List<Path> locks = const <Path>[],
  List<Path> shine = const <Path>[],
  double cast = 0.06,
}) =>
    _inside(
      Shape(
        mass,
        color: color,
        shade: Shade(form: 0.35, core: 0.3, coreStrength: 0.65, rim: 0.08, rimStrength: 0.45, cast: f.r * cast, castStrength: 0.3),
      ),
      <Shape>[
        for (final Path l in locks) Shape(l, color: _dark(color, 0.2)),
        for (final Path s in shine) Shape(s, color: _light(color, 0.2)),
      ],
    );

/// The hairline from [front], the tip of the fringe, back over the temple,
/// down the sideburn and round behind the ear to the nape.
List<(double, double)> _hairline({(double, double) front = (0.98, -0.58)}) => <(double, double)>[
      front, (0.82, -0.66), (0.58, -0.7), (0.32, -0.67), (0.08, -0.6), (-0.1, -0.46), (-0.18, -0.24),
      (-0.18, 0.02), (-0.3, -0.04), (-0.5, 0.16), (-0.64, 0.4),
    ];

/// Over the top and round the back, close to the skull, [lift] head radii
/// clear of it; the points before the hairline.
List<(double, double)> _crown({double lift = 0.08, double nape = 0.4}) => <(double, double)>[
      (-0.86, nape), (-1.0 - lift, 0.02), (-1.0 - lift * 0.9, -0.5), (-0.76 - lift * 0.5, -0.92 - lift * 0.5),
      (-0.28, -1.06 - lift), (0.28, -1.05 - lift), (0.68, -0.9 - lift * 0.6), (0.92, -0.68),
    ];

/// Short and combed to the side, a lock swept forward over the forehead.
class ShortHair extends Garment {
  const ShortHair(this.color);
  final Color color;

  @override
  void dress(Fitting f) => f.hair.add(_hair(
        f,
        color,
        f.headPath(<(double, double)>[..._crown(), ..._hairline()]),
        locks: <Path>[
          _lock(f, <(double, double)>[(-0.6, -0.84), (-0.05, -0.98), (0.45, -0.88), (0.9, -0.66)], 0.08),
          _lock(f, <(double, double)>[(-0.82, -0.52), (-0.42, -0.74), (0.05, -0.8), (0.48, -0.74)], 0.06),
          _lock(f, <(double, double)>[(-0.98, -0.2), (-0.96, 0.1), (-0.84, 0.34)], 0.06),
        ],
        shine: <Path>[_lock(f, <(double, double)>[(-0.42, -1.02), (0.08, -1.08), (0.55, -0.96)], 0.07)],
      ));
}

/// Cropped close to the skull.
class Buzz extends Garment {
  const Buzz(this.color);
  final Color color;

  @override
  void dress(Fitting f) => f.hair.add(_hair(
        f,
        color,
        f.headPath(<(double, double)>[..._crown(lift: 0.03, nape: 0.36), ..._hairline(front: (0.86, -0.64))]),
        shine: <Path>[_lock(f, <(double, double)>[(-0.42, -0.96), (0.05, -1.0), (0.45, -0.9)], 0.05)],
        cast: 0.02,
      ));
}

/// Swept up and back from the forehead.
class Quiff extends Garment {
  const Quiff(this.color);
  final Color color;

  @override
  void dress(Fitting f) => f.hair.add(_hair(
        f,
        color,
        f.headPath(<(double, double)>[
          (-0.86, 0.4), (-1.07, 0.02), (-1.06, -0.5), (-0.82, -0.95), (-0.35, -1.18), (0.2, -1.3),
          (0.66, -1.38), (1.02, -1.22), (1.08, -0.92), ..._hairline(front: (0.94, -0.66)),
        ]),
        locks: <Path>[
          _lock(f, <(double, double)>[(0.92, -0.74), (0.82, -1.08), (0.35, -1.2), (-0.3, -1.08)], 0.1),
          _lock(f, <(double, double)>[(0.6, -0.72), (0.45, -0.98), (0.0, -1.06), (-0.5, -0.92)], 0.07),
        ],
        shine: <Path>[_lock(f, <(double, double)>[(0.95, -1.04), (0.6, -1.27), (0.1, -1.24)], 0.07)],
      ));
}

/// A cloud of tight curls, each one lit.
class Curls extends Garment {
  const Curls(this.color, {this.size = 1});
  final Color color;
  final double size;

  @override
  void dress(Fitting f) {
    final Offset c = f.h(-0.08, -0.2);
    final double reach = f.r * (0.98 + 0.15 * (size - 1));
    final Shade lit = Shade(form: 0.4, core: 0.35, coreStrength: 0.6, rim: 0.12, rimStrength: 0.4, cast: f.r * 0.04, castStrength: 0.25);
    Shape curl(Offset at, double radius) => Shape(Paths.circle(at, f.r * size * radius), color: color, shade: lit);
    final List<Shape> curls = <Shape>[
      // An inner row over the crown, then the outer one round the back and
      // over the top, from the nape to the forehead, then the fringe.
      for (int i = 0; i < 5; i++) curl(c + Offset.fromDirection(math.pi * (1.1 + 0.75 * i / 4), reach * 0.55), 0.24),
      for (int i = 0; i < 14; i++) curl(c + Offset.fromDirection(math.pi * (0.72 + 1.2 * i / 13), reach), i.isEven ? 0.26 : 0.22),
      for (final (double x, double y) in <(double, double)>[(0.12, -0.74), (0.42, -0.76), (0.7, -0.66)]) curl(f.h(x, y), 0.18),
    ];
    f.hair.add(Part(
      shapes: <Shape>[
        Shape(
          f.headPath(<(double, double)>[..._crown(lift: 0.1), ..._hairline(front: (0.8, -0.66))]),
          color: _dark(color, 0.15),
          shade: Shade.gentle,
        ),
      ],
      children: <Part>[Part(shapes: curls)],
    ));
  }
}

/// Long hair, past the shoulders and over the ear on the near side.
/// [length] is in head radii below the middle of the head; [fringe] cuts it
/// straight across the forehead.
class LongHair extends Garment {
  const LongHair(this.color, {this.length = 2.0, this.fringe = false});
  final Color color;
  final double length;
  final bool fringe;

  @override
  void dress(Fitting f) {
    final double l = length;
    // Behind the head, the far side's hair showing past the cheek; and
    // what falls below it, behind the body -- the back of it, and the far
    // side past the far shoulder.
    final Color back = _dark(color, 0.22);
    f.headBack.add(Part(shapes: <Shape>[
      Shape(
        f.headPath(<(double, double)>[
          (-0.3, -1.08), (-0.94, -0.8), (-1.18, -0.2), (-1.2, 0.6), (-0.9, 0.9), (-0.4, 0.75), (0.3, 0.75), (0.9, 0.62),
          (1.07, 0.3), (0.95, -0.6),
        ]),
        color: back,
        shade: _cloth,
      ),
    ]));
    f.behind.add(Part(at: f.body.headAt, shapes: <Shape>[
      Shape(
        f.headPath(<(double, double)>[
          (-0.6, -0.6), (-1.18, -0.2), (-1.22, l * 0.5), (-1.08, l - 0.15), (-0.8, l + 0.02), (-0.2, l),
          (0.4, l * 0.85), (0.98, l * 0.6), (1.07, 0.2), (0.6, -0.4),
        ]),
        color: back,
        shade: _cloth,
      ),
    ]));
    final List<(double, double)> line = fringe
        ? <(double, double)>[(1.0, -0.42), (0.75, -0.5), (0.45, -0.54), (0.15, -0.52), (-0.1, -0.42)]
        : <(double, double)>[(0.97, -0.56), (0.7, -0.66), (0.4, -0.68), (0.1, -0.6), (-0.1, -0.46)];
    f.hideEars = true;
    f.hair.add(_hair(
      f,
      color,
      f.headPath(<(double, double)>[
        (-0.78, l + 0.02), (-1.12, l - 0.1), (-1.14, 0.4), (-1.1, -0.42), (-0.82, -0.95), (-0.3, -1.15),
        (0.25, -1.14), (0.7, -0.96), (1.0, -0.7), ...line, (-0.2, -0.12), (-0.24, 0.4), (-0.32, 1.0),
        (-0.44, l - 0.1),
      ]),
      locks: <Path>[
        _lock(f, <(double, double)>[(-0.45, -0.72), (-0.75, 0.0), (-0.8, 0.8), (-0.72, l - 0.15)], 0.1),
        _lock(f, <(double, double)>[(-0.15, -0.42), (-0.32, 0.3), (-0.42, 1.0), (-0.55, l - 0.12)], 0.07),
        _lock(f, <(double, double)>[(-0.98, -0.3), (-1.04, 0.5), (-0.98, l - 0.3)], 0.07),
        if (fringe) _lock(f, <(double, double)>[(-0.2, -0.86), (0.3, -0.82), (0.7, -0.62), (0.88, -0.46)], 0.07),
      ],
      shine: <Path>[_lock(f, <(double, double)>[(-0.5, -0.98), (0.05, -1.07), (0.55, -0.94)], 0.08)],
    ));
  }
}

/// Pulled back tight into a bun at the back of the head.
class Bun extends Garment {
  const Bun(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    final Offset at = f.h(-0.8, -0.8);
    final double s = f.r;
    f.headBack.add(_inside(
      Shape(Paths.circle(at, s * 0.38), color: _dark(color, 0.04), shade: _cloth),
      <Shape>[
        Shape(_ribbon(<Offset>[at + Offset(-s * 0.28, s * 0.12), at + Offset(-s * 0.05, -s * 0.22), at + Offset(s * 0.26, -s * 0.05)], s * 0.08),
            color: _dark(color, 0.22)),
        Shape(_ribbon(<Offset>[at + Offset(-s * 0.18, -s * 0.24), at + Offset(s * 0.1, -s * 0.3)], s * 0.06), color: _light(color, 0.18)),
      ],
    ));
    f.hair.add(_slicked(f, color));
  }
}

/// Combed straight back from the forehead, for a bun or a ponytail.
Part _slicked(Fitting f, Color color) => _hair(
      f,
      color,
      f.headPath(<(double, double)>[..._crown(lift: 0.05, nape: 0.36), ..._hairline(front: (0.88, -0.64))]),
      locks: <Path>[
        _lock(f, <(double, double)>[(0.78, -0.7), (0.3, -0.9), (-0.3, -0.92), (-0.76, -0.76)], 0.06),
        _lock(f, <(double, double)>[(0.22, -0.64), (-0.2, -0.7), (-0.66, -0.66)], 0.05),
        _lock(f, <(double, double)>[(-0.62, 0.3), (-0.86, 0.0), (-0.84, -0.56)], 0.05),
      ],
      shine: <Path>[_lock(f, <(double, double)>[(-0.35, -0.99), (0.12, -1.01), (0.55, -0.88)], 0.06)],
      cast: 0.03,
    );

/// Pulled back into a tail that swings: a [Chain] with follow-through.
class Ponytail extends Garment {
  const Ponytail(this.color, {this.length = 1.4});
  final Color color;
  final double length;

  @override
  void dress(Fitting f) {
    final Chain tail = Chain(
      'ponytail',
      segments: 4,
      length: f.r * length,
      width: f.r * 0.3,
      tipWidth: f.r * 0.08,
      color: _dark(color, 0.1),
      at: f.h(-0.92, -0.5),
      degrees: 112,
    );
    f.headBack.add(tail.part);
    f.jiggles.addAll(tail.jiggles(hertz: 1.7, damping: 0.25, inertia: 1.2, limit: 22));
    f.hair.add(_slicked(f, color));
    f.hair.add(Part(shapes: <Shape>[Shape(Paths.ellipse(f.h(-0.94, -0.5), f.r * 0.08, f.r * 0.12), color: _dark(color, 0.45), shade: Shade.gentle)]));
  }
}

/// Bald on top, a fringe of hair round the back and over the ears.
class Balding extends Garment {
  const Balding(this.color);
  final Color color;

  @override
  void dress(Fitting f) => f.hair.add(_hair(
        f,
        color,
        f.headPath(<(double, double)>[
          (-0.3, -0.42), (-0.7, -0.62), (-1.06, -0.3), (-1.06, 0.18), (-0.82, 0.44), (-0.58, 0.38),
          (-0.48, 0.14), (-0.3, -0.04), (-0.18, -0.24),
        ]),
        locks: <Path>[_lock(f, <(double, double)>[(-0.45, -0.46), (-0.86, -0.36), (-0.96, 0.05)], 0.06)],
        cast: 0,
      ));
}

// --- on the face ---

/// A beard round whichever jaw the head has; the mouth shows through it
/// and a moustache goes over the lip. [length] grows it below the chin.
class Beard extends Garment {
  const Beard(this.color, {this.length = 0.4, this.moustache = true});
  final Color color;
  final double length;
  final bool moustache;

  @override
  void dress(Fitting f) {
    final double l = length;
    final Path chin = f.headPath(<(double, double)>[
      (-0.6, 0.4), (-0.25, 0.8 + 0.25 * l), (0.25, 0.95 + 0.6 * l), (0.62, 0.86 + 0.3 * l), (0.92, 0.45), (0.4, 0.3),
    ]);
    // Below the cheeks: from the sideburn, under the cheekbone, round to the
    // far side of the face.
    final Path below = Paths.polygon(<Offset>[
      f.h(-0.3, -0.3), f.h(-0.12, 0.1), f.h(0.18, 0.24), f.h(0.6, 0.22), f.h(1.4, 0.14), f.h(1.4, 3), f.h(-1.3, 3), f.h(-0.8, 0.35),
    ]);
    final Path beard = _and(_or(_scaled(f.headOutline, f.h(0, -0.1), 1.05, 1.04), chin), below);
    f.underFace.add(_inside(
      Shape(beard, color: color, shade: _cloth),
      <Shape>[
        Shape(_lock(f, <(double, double)>[(-0.35, 0.3), (-0.15, 0.7 + 0.2 * l), (0.2, 0.9 + 0.45 * l)], 0.06), color: _dark(color, 0.18)),
        Shape(_lock(f, <(double, double)>[(0.55, 0.4), (0.45, 0.75 + 0.2 * l)], 0.05), color: _dark(color, 0.18)),
      ],
    ));
    if (moustache) Moustache(color).dress(f);
  }
}

/// Under the nose, over the lip; the far half shorter, as it turns away.
Path _moustache(Fitting f) {
  final Offset m = f.mouth + Offset(0, -f.r * 0.11);
  Offset at(double x, double y) => Offset(m.dx + x * f.r, m.dy + y * f.r);
  return Paths.smooth(<Offset>[
    at(-0.34, 0.1), at(-0.2, -0.06), at(0, -0.05), at(0.12, -0.07),
    at(0.24, 0.06), at(0.1, 0.03), at(0, 0.05), at(-0.16, 0.03),
  ]);
}

class Moustache extends Garment {
  const Moustache(this.color);
  final Color color;

  @override
  void dress(Fitting f) => f.faceFront.add(Part(shapes: <Shape>[Shape(_moustache(f), color: _dark(color, 0.05), shade: Shade.gentle)]));
}

/// Round lenses on a thin frame, the far lens narrower as it turns away,
/// an arm back to the ear.
class Glasses extends Garment {
  const Glasses({this.color = const Color(0xFF2A2A2A), this.lens = const Color(0x40BFE6FF)});
  final Color color;
  final Color lens;

  @override
  void dress(Fitting f) {
    final double rr = f.eyeRadius * 1.5, w = f.r * 0.055;
    final Offset near = f.eyeNear, far = f.eyeFar;
    f.faceFront.add(Part(shapes: <Shape>[
      Shape(Paths.circle(near, rr), color: lens, stroke: color, strokeWidth: w),
      Shape(Paths.ellipse(far, rr * 0.72, rr), color: lens, stroke: color, strokeWidth: w),
      Shape(
        Path()
          ..moveTo(near.dx + rr, near.dy - rr * 0.15)
          ..quadraticBezierTo((near.dx + far.dx) / 2, near.dy - rr * 0.45, far.dx - rr * 0.72, far.dy - rr * 0.15)
          ..moveTo(near.dx - rr, near.dy - rr * 0.2)
          ..lineTo(f.ear.dx + f.r * 0.08, f.ear.dy - f.r * 0.1),
        stroke: color,
        strokeWidth: w,
      ),
      // A glint on the near lens.
      Shape(Paths.ellipse(near + Offset(rr * 0.35, -rr * 0.45), rr * 0.2, rr * 0.1), color: const Color(0x99FFFFFF)),
    ]));
  }
}

// --- on the head ---

/// A wide-brimmed hat with a pinched crown, pulled down to the brows; the
/// brim throws its shadow across the eyes.
class CowboyHat extends Garment {
  const CowboyHat(this.color, {this.band = const Color(0xFF3B2416)});
  final Color color;
  final Color band;

  @override
  void dress(Fitting f) {
    final Offset c = f.h(0.06, -0.8);
    final Path brim = Paths.smooth(<Offset>[
      for (int i = 0; i < 24; i++)
        () {
          final double a = i * math.pi / 12;
          // The sides curl up a touch.
          final double curl = math.pow(math.cos(a).abs(), 6) * 0.12;
          return c + Offset(math.cos(a) * f.r * 1.5, (math.sin(a) * 0.27 - curl) * f.r);
        }(),
    ]);
    final Path crown = f.headPath(<(double, double)>[
      (-0.62, -0.8), (-0.68, -1.15), (-0.54, -1.46), (-0.22, -1.56), (0.06, -1.44),
      (0.34, -1.56), (0.62, -1.44), (0.74, -1.12), (0.7, -0.8), (0.04, -0.72),
    ]);
    f.headwear.add(Part(
      at: c,
      degrees: -5,
      children: <Part>[
        Part(at: -c, shapes: <Shape>[
          Shape(brim, color: _dark(color, 0.14), shade: Shade(form: 0.3, core: 0.25, rim: 0.12, cast: f.r * 0.2, castStrength: 0.4)),
          Shape(crown, color: color, shade: _cloth),
          Shape(_and(crown, Paths.rect(Rect.fromLTRB(-999, f.h(0, -1.0).dy, 999, f.h(0, -0.82).dy))), color: band),
          // The dent down the middle of the crown.
          Shape(f.headPath(<(double, double)>[(0.02, -1.42), (0.12, -1.32), (0.1, -1.1), (0.04, -1.2)]), color: _dark(color, 0.12)),
          // The front of the brim, over the crown.
          Shape(_and(brim, _below(c.dy - f.r * 0.02)), color: color, shade: _cloth),
        ]),
      ],
    ));
  }
}

/// A baseball cap, the peak forward over the eyes.
class Cap extends Garment {
  const Cap(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    final double rim = math.min(f.h(0, -0.5).dy, f.browTop - f.r * 0.06);
    final Path dome = _and(_scaled(f.headOutline, f.h(0, 0), 1.06, 1.06), _above(rim));
    final double y = (rim - f.headCenter.dy) / f.r;
    f.headwear.add(Part(shapes: <Shape>[
      Shape(dome, color: color, shade: _cloth),
      // A seam over the top, and the button.
      Shape(_lock(f, <(double, double)>[(0.06, -1.04), (0.3, -0.84), (0.44, y + 0.02)], 0.025, tip: 1), color: _dark(color, 0.2)),
      Shape(Paths.ellipse(f.h(0.06, -1.05), f.r * 0.1, f.r * 0.05), color: _dark(color, 0.15)),
      Shape(
        f.headPath(<(double, double)>[(0.45, y - 0.04), (0.95, y - 0.06), (1.45, y + 0.04), (1.3, y + 0.12), (0.6, y + 0.06)]),
        color: _dark(color, 0.08),
        shade: Shade(form: 0.3, core: 0.2, rim: 0.1, cast: f.r * 0.14, castStrength: 0.35),
      ),
    ]));
  }
}

/// The head without the face: what a headcloth, a scarf or a helmet leaves
/// open -- the face window, but only where the head is, so the jaw keeps
/// its own line.
Path _faceOpening(Fitting f) => _and(f.faceWindow, f.headOutline);

/// A band round [_faceOpening], for the cloth's edge.
Path _faceEdge(Fitting f, [double by = 1.12]) =>
    _minus(_scaled(_faceOpening(f), f.faceWindow.getBounds().center, by), _faceOpening(f));

/// A headcloth -- the ghutra, the keffiyeh -- with or without the agal's
/// black cord round the crown.
class Headcloth extends Garment {
  const Headcloth(this.color, {this.check, this.agal = const Color(0xFF1A1A1A)});
  final Color color;

  /// The checked pattern's colour, or null for plain cloth.
  final Color? check;

  /// The cord's colour, or null for none.
  final Color? agal;

  @override
  void dress(Fitting f) {
    final Path cap = _scaled(f.headOutline, f.h(0, -0.1), 1.12, 1.1);
    final Path drape = f.headPath(<(double, double)>[
      (-0.5, -0.4), (-1.18, -0.1), (-1.32, 0.9), (-1.25, 1.85), (-0.55, 2.05), (-0.1, 1.6), (0.1, 1.0), (0.7, 0.95),
      (1.08, 0.5), (1.06, -0.2),
    ]);
    final Path cloth = _minus(_or(cap, drape), _faceOpening(f));
    Path grid() {
      final Path p = Path();
      final double s = f.r * 0.09;
      for (double x = -3; x < 3; x += 0.2) {
        for (double y = -3; y < 3; y += 0.2) {
          p.addRect(Rect.fromLTWH(f.h(x, y).dx, f.h(x, y).dy, s, s));
          p.addRect(Rect.fromLTWH(f.h(x, y).dx + s * 1.2, f.h(x, y).dy + s * 1.2, s * 0.5, s * 0.5));
        }
      }
      return p;
    }

    f.hideHair = true;
    f.hideEars = true;
    f.headwear.add(_inside(
      Shape(cloth, color: color, shade: _cloth),
      <Shape>[
        if (check != null) Shape(grid(), color: check!.withValues(alpha: 0.85)),
        // Folds down the drape.
        Shape(_lock(f, <(double, double)>[(-0.8, 0.0), (-0.95, 0.9), (-0.9, 1.8)], 0.1), color: _dark(color, 0.12)),
        Shape(_lock(f, <(double, double)>[(-0.45, 0.4), (-0.5, 1.2), (-0.4, 1.8)], 0.07), color: _dark(color, 0.1)),
        Shape(_faceEdge(f), color: _dark(color, 0.1)),
      ],
    ));
    if (agal != null) {
      // Two cords round the crown; their far halves are behind the head.
      for (final double y in <double>[-0.74, -0.58]) {
        final Rect ring = Rect.fromCenter(center: f.h(0.0, y), width: f.r * 2.2, height: f.r * 0.42);
        f.headwear.add(Part(shapes: <Shape>[
          Shape(Path()..addArc(ring, 0.05, math.pi - 0.1), stroke: agal, strokeWidth: f.r * 0.1),
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
    final Path wrap = _or(
      _scaled(f.headOutline, f.h(0, -0.1), 1.14, 1.12),
      f.headPath(<(double, double)>[
        (-1.1, 0.0), (-1.18, 1.1), (-0.85, 1.85), (0.1, 2.05), (0.95, 1.75), (1.12, 1.0), (1.0, 0.5), (0.5, 0.75), (-0.3, 0.6),
      ]),
    );
    f.hideHair = true;
    f.hideEars = true;
    f.headwear.add(_inside(
      Shape(_minus(wrap, _faceOpening(f)), color: color, shade: _cloth),
      <Shape>[
        Shape(_lock(f, <(double, double)>[(-0.7, 0.2), (-0.75, 1.0), (-0.45, 1.75)], 0.1), color: _dark(color, 0.14)),
        Shape(_lock(f, <(double, double)>[(0.95, 0.9), (0.6, 1.4), (0.2, 1.85)], 0.08), color: _dark(color, 0.12)),
        Shape(_lock(f, <(double, double)>[(-0.6, -0.85), (0.0, -1.02), (0.6, -0.9)], 0.06), color: _light(color, 0.1)),
        Shape(_faceEdge(f), color: _dark(color, 0.12)),
      ],
    ));
  }
}

/// A Roman legionary's helmet: a dome down to the brows, a neck guard, a
/// cheek guard on the near side clear of the eye, a crest front to back.
class LegionHelmet extends Garment {
  const LegionHelmet({this.metal = const Color(0xFFB8BEC6), this.crest = const Color(0xFFC0272D)});
  final Color metal;
  final Color crest;

  @override
  void dress(Fitting f) {
    final double rim = f.browTop - f.r * 0.05;
    final Path shell = _scaled(f.headOutline, f.h(0, -0.05), 1.1, 1.1);
    final Path dome = _and(shell, _above(rim));
    // The cheek guard hangs from the rim behind the near eye, to the jaw.
    final double edge = f.eyeNear.dx - f.eyeRadius * 1.5;
    final Path cheek = Paths.smooth(<Offset>[
      Offset(f.h(-0.5, 0).dx, rim - 2), Offset(edge, rim - 2), Offset(edge + f.r * 0.04, f.h(0, 0.25).dy),
      Offset(edge - f.r * 0.08, f.h(0, 0.6).dy), Offset(f.h(-0.42, 0).dx, f.h(0, 0.5).dy), Offset(f.h(-0.52, 0).dx, f.h(0, 0.05).dy),
    ]);
    f.hideHair = true;
    f.hideEars = true;
    f.headwear.add(Part(shapes: <Shape>[
      Shape(
        f.headPath(<(double, double)>[
          (0.62, -1.0), (0.4, -1.48), (-0.15, -1.66), (-0.72, -1.5), (-1.02, -1.0), (-0.72, -1.08), (-0.2, -1.2), (0.3, -1.1),
        ]),
        color: crest,
        shade: _cloth,
      ),
      Shape(f.headPath(<(double, double)>[(-0.66, -0.55), (-1.08, -0.5), (-1.24, 0.2), (-0.98, 0.3), (-0.7, 0.05)]), color: _dark(metal, 0.16), shade: _metal),
      Shape(dome, color: metal, shade: Shade(form: 0.5, core: 0.35, coreStrength: 0.8, rim: 0.14, rimStrength: 0.75, cast: f.r * 0.1, castStrength: 0.35)),
      // The brow ridge.
      Shape(_and(_scaled(shell, f.h(0, -0.05), 1.02), Paths.rect(Rect.fromLTRB(-999, rim - f.r * 0.13, 999, rim))), color: _dark(metal, 0.12), shade: _metal),
      Shape(cheek, color: _dark(metal, 0.04), shade: _metal),
      for (final Offset rivet in <Offset>[Offset(edge - f.r * 0.12, rim + f.r * 0.14), f.h(-0.86, -0.42)])
        Shape(Paths.circle(rivet, f.r * 0.055), color: const Color(0xFFD4A94A), shade: Shade.gentle),
    ]));
  }
}

/// The striped royal headcloth of ancient Egypt, its lappet falling in
/// front of the shoulder, a cobra at the brow.
class Nemes extends Garment {
  const Nemes({this.color = const Color(0xFFE8C24A), this.stripe = const Color(0xFF2F5DA8)});
  final Color color;
  final Color stripe;

  @override
  void dress(Fitting f) {
    final Path cloth = _minus(
      _or(
        _and(_scaled(f.headOutline, f.h(0, -0.1), 1.1, 1.08), _above(f.h(0, 0.2).dy)),
        f.headPath(<(double, double)>[
          (-0.6, -0.6), (-1.15, -0.4), (-1.38, 0.7), (-1.0, 1.0), (-0.62, 0.95), (-0.55, 2.0), (-0.12, 2.0), (-0.12, 0.6), (-0.3, -0.2),
        ]),
      ),
      _faceOpening(f),
    );
    final Path stripes = Path();
    for (double y = -2.5; y < 3; y += 0.22) {
      stripes.addRect(Rect.fromLTRB(f.h(-3, y).dx, f.h(0, y).dy, f.h(3, y).dx, f.h(0, y + 0.1).dy));
    }
    f.hideHair = true;
    f.hideEars = true;
    f.headwear.add(_inside(Shape(cloth, color: color, shade: _cloth), <Shape>[Shape(stripes, color: stripe)]));
    f.headwear.add(Part(shapes: <Shape>[
      Shape(_and(_faceEdge(f, 1.14), _above(f.h(0, -0.25).dy)), color: const Color(0xFFD4A94A), shade: _metal),
      Shape(Paths.ellipse(f.h(0.44, -0.84), f.r * 0.06, f.r * 0.12), color: const Color(0xFFD4A94A), shade: _metal),
    ]));
  }
}

/// A crown of leaves round the head: the front half, as the back is hidden.
class LaurelWreath extends Garment {
  const LaurelWreath({this.color = const Color(0xFF6E9E3A)});
  final Color color;

  @override
  void dress(Fitting f) {
    final Offset c = f.h(-0.04, -0.58);
    final double rx = f.r * 1.04, ry = f.r * 0.26;
    f.headwear.add(Part(children: <Part>[
      for (int i = 0; i <= 12; i++)
        () {
          final double a = math.pi * (0.04 + 0.92 * i / 12);
          final Offset p = c + Offset(rx * math.cos(a), ry * math.sin(a));
          final double tangent = math.atan2(ry * math.cos(a), -rx * math.sin(a)) * 180 / math.pi;
          return Part(at: p, degrees: tangent + (i.isEven ? 30 : -30), shapes: <Shape>[
            Shape(Paths.ellipse(Offset(f.r * 0.1, 0), f.r * 0.14, f.r * 0.055), color: i.isEven ? color : _dark(color, 0.15), shade: Shade.gentle),
          ]);
        }(),
    ]));
  }
}

// --- the body ---

/// A shirt: long or short sleeves, a collar or a plain neck.
class Shirt extends Garment {
  const Shirt(this.color, {this.sleeves = 1, this.vNeck = false, this.collar = true});
  final Color color;

  /// How far down the arm: 1 to the wrist, about 0.35 for short sleeves, 0
  /// for none.
  final double sleeves;
  final bool vNeck;
  final bool collar;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double m = b.mid(1), t = b.torso;
    f.torso.add(Shape(b.torsoPath, color: color, shade: _cloth));
    if (vNeck) {
      f.torso.add(Shape(Paths.smooth(<Offset>[Offset(m - 16, -t - 2), Offset(m + 1, -t + 26), Offset(m + 12, -t - 2)]), color: _dark(f.skin, 0.08)));
    } else if (!collar) {
      // A round neck, its band.
      final Path neck = Paths.ellipse(Offset(m - 4, -t), b.shoulders * 0.2, 9);
      f.torso.add(Shape(_and(neck, b.torsoPath), color: _dark(f.skin, 0.1)));
      f.torso.add(Shape(_and(_minus(_scaled(neck, Offset(m - 4, -t), 1.18, 1.35), neck), b.torsoPath), color: _dark(color, 0.12)));
    }
    if (collar) {
      f.torso.add(Shape(Paths.polygon(<Offset>[Offset(m - 26, -t - 4), Offset(m - 2, -t + 4), Offset(m - 8, -t + 16)]), color: _light(color, 0.1)));
      f.torso.add(Shape(Paths.polygon(<Offset>[Offset(m + 22, -t - 5), Offset(m + 4, -t + 4), Offset(m + 10, -t + 14)]), color: _light(color, 0.06)));
    }
    if (sleeves > 0) f.arms.add(Cover(color, to: sleeves));
  }
}

/// Open down the front, showing what is under it; no sleeves.
class Vest extends Garment {
  const Vest(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double t = b.torso, m = b.mid(0.6);
    final Path opening = Paths.polygon(<Offset>[
      Offset(m - 16, -t - 20), Offset(m + 18, -t - 20), Offset(m + 9, -t * 0.42), Offset(m + 6, 30), Offset(m - 2, 30), Offset(m - 4, -t * 0.42),
    ]);
    f.torso.add(Shape(_minus(f.torsoBand(0.1, 1), opening), color: color, shade: _cloth));
    // Buttons down the near panel's edge, and a pocket.
    for (int i = 0; i < 3; i++) {
      f.torso.add(Shape(Paths.circle(Offset(m - 8 - i * 0.6, -t * (0.6 - i * 0.16)), 2.8), color: _dark(color, 0.45)));
    }
    f.torso.add(Shape(Paths.roundRect(Rect.fromLTWH(m - 40, -t * 0.62, 20, 3), 1.5), color: _dark(color, 0.3)));
  }
}

/// A long coat open down the front -- a lab coat, a duster -- to [length]
/// of the legs, with lapels and pockets.
class Coat extends Garment {
  const Coat(this.color, {this.length = 0.5});
  final Color color;
  final double length;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double t = b.torso, m = b.mid(0.6);
    f.arms.add(Cover(color, extra: 3.5));
    f.overLegs.add(Part(shapes: <Shape>[
      Shape.live((w) => f.skirt(w, length: length, flare: 0.3, waist: 0.3), color: _dark(color, 0.04), shade: _cloth),
      // Where it opens, down the front.
      Shape.live(
        (w) => _ribbon(<Offset>[w.point('chest', Offset(m + 2, -t * 0.3)), w.point('chest', Offset(m + 4, 0)), f.legPoint(w, 'F', length) + Offset(b.legRadius * 1.6, 0)],
            3, tip: 1),
        color: _dark(color, 0.18),
      ),
    ]));
    final Path opening = Paths.polygon(<Offset>[
      Offset(m - 12, -t - 20), Offset(m + 16, -t - 20), Offset(m + 8, -t * 0.4), Offset(m + 12, 40), Offset(m + 2, 40), Offset(m - 2, -t * 0.4),
    ]);
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(_minus(b.torsoPath, opening), color: color, shade: _cloth),
      // The lapels: the near one wide, the far one turned away.
      Shape(Paths.polygon(<Offset>[Offset(m - 12, -t - 2), Offset(m - 32, -t + 16), Offset(m - 2, -t * 0.4)]), color: _dark(color, 0.08), shade: Shade.gentle),
      Shape(Paths.polygon(<Offset>[Offset(m + 16, -t - 2), Offset(m + 26, -t + 14), Offset(m + 8, -t * 0.4)]), color: _dark(color, 0.12)),
      Shape(Paths.roundRect(Rect.fromLTWH(m - 44, -t * 0.66, 22, 4), 2), color: _dark(color, 0.18)),
      Shape(Paths.roundRect(Rect.fromLTWH(m - 46, -t * 0.22, 28, 22), 4), color: _dark(color, 0.06), shade: Shade.gentle),
    ]));
  }
}

/// The skirt of a robe, with a fold down from each knee as it is posed.
Part _robeSkirt(Fitting f, Color color, {required double length, required double flare, Color? trim, double waist = 0.15}) {
  final Body b = f.body;
  return Part(shapes: <Shape>[
    Shape.live((w) => f.skirt(w, length: length, flare: flare, waist: waist), color: color, shade: _cloth),
    for (final String side in <String>['F', 'B'])
      Shape.live(
        (w) => _ribbon(<Offset>[f.legPoint(w, side, 0.3), f.legPoint(w, side, (length + 0.3) / 2), f.legPoint(w, side, length) + const Offset(0, 2)],
            b.legRadius * 0.35, tip: 0.6),
        color: _dark(color, 0.08),
      ),
    if (trim != null)
      Shape.live(
        (w) {
          final Offset top = w.point('chest', Offset(b.mid(0.1), -b.torso * waist));
          final double hem = math.max(f.legPoint(w, 'F', length).dy, f.legPoint(w, 'B', length).dy) + 4;
          return Paths.rect(Rect.fromLTRB(top.dx - 3, top.dy, top.dx + 3, hem));
        },
        color: trim,
      ),
  ]);
}

/// A robe to the ankles -- a thobe, an abaya, a priest's robe -- with long,
/// loose sleeves; [trim] down the front, [collar] a buttoned placket.
class Robe extends Garment {
  const Robe(this.color, {this.length = 0.95, this.sleeves = 1, this.flare = 0.55, this.trim, this.collar = false});
  final Color color;
  final double length;
  final double sleeves;
  final double flare;
  final Color? trim;
  final bool collar;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double t = b.torso, m = b.mid(0.8);
    f.torso.add(Shape(b.torsoPath, color: color, shade: _cloth));
    if (sleeves > 0) f.arms.add(Cover(color, to: sleeves, extra: 5));
    f.overLegs.add(_robeSkirt(f, color, length: length, flare: flare, trim: trim));
    f.overTorso.add(_inside(
      Shape(f.torsoBand(0.12, 1), color: color, shade: _cloth),
      <Shape>[
        if (trim != null) Shape(Paths.rect(Rect.fromLTRB(m - 3, -t - 10, m + 3, 10)), color: trim),
        if (collar) ...<Shape>[
          Shape(_and(Paths.ellipse(Offset(m - 4, -t), b.shoulders * 0.2, 10), b.torsoPath), color: _dark(f.skin, 0.1)),
          Shape(Paths.rect(Rect.fromLTRB(m - 2, -t, m + 2, -t * 0.62)), color: _dark(color, 0.15)),
          for (int i = 0; i < 3; i++) Shape(Paths.circle(Offset(m + 5, -t * (0.92 - i * 0.1)), 2.2), color: _dark(color, 0.2)),
        ],
      ],
    ));
  }
}

/// A knee-length tunic, short-sleeved.
class Tunic extends Garment {
  const Tunic(this.color, {this.length = 0.4, this.sleeves = 0.3});
  final Color color;
  final double length;
  final double sleeves;

  @override
  void dress(Fitting f) {
    f.torso.add(Shape(f.body.torsoPath, color: color, shade: _cloth));
    if (sleeves > 0) f.arms.add(Cover(color, to: sleeves, extra: 4));
    f.overLegs.add(_robeSkirt(f, color, length: length, flare: 0.3));
    f.overTorso.add(Part(shapes: <Shape>[Shape(f.torsoBand(0.12, 1), color: color, shade: _cloth)]));
  }
}

/// A robe with a length of cloth over the near shoulder and across the
/// chest to the far hip.
class Toga extends Garment {
  const Toga(this.color, {this.border});
  final Color color;
  final Color? border;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double t = b.torso, w = b.shoulders / 2;
    f.torso.add(Shape(b.torsoPath, color: color, shade: _cloth));
    f.arms.add(Cover(color, to: 0.32, extra: 5));
    f.overLegs.add(_robeSkirt(f, color, length: 0.9, flare: 0.5));
    final Path drape = _and(
      Paths.polygon(<Offset>[
        Offset(-w - 10, -t + 4), Offset(-w * 0.35, -t - 10), Offset(w + 30, -t * 0.3), Offset(w + 30, 20), Offset(w * 0.25, 20),
      ]),
      _scaled(b.torsoPath, Offset(0, -t / 2), 1.04),
    );
    f.overTorso.add(Part(shapes: <Shape>[Shape(f.torsoBand(0.12, 1), color: color, shade: _cloth)]));
    f.overTorso.add(_inside(
      Shape(drape, color: _dark(color, 0.05), shade: _cloth),
      <Shape>[
        Shape(_ribbon(<Offset>[Offset(-w * 0.6, -t + 10), Offset(0, -t * 0.55), Offset(w * 0.8, -t * 0.12)], 6, tip: 0.3), color: _dark(color, 0.14)),
        Shape(_ribbon(<Offset>[Offset(-w * 0.2, -t + 2), Offset(w * 0.3, -t * 0.6), Offset(w * 0.9, -t * 0.35)], 5, tip: 0.3), color: _dark(color, 0.12)),
        if (border != null) Shape(drape, stroke: border, strokeWidth: 10),
      ],
    ));
  }
}

/// A short wrapped skirt -- the shendyt of ancient Egypt -- with its
/// pleated front panel.
class Kilt extends Garment {
  const Kilt(this.color, {this.length = 0.38, this.belt = const Color(0xFFD4A94A)});
  final Color color;
  final double length;
  final Color? belt;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    f.overLegs.add(Part(shapes: <Shape>[
      Shape.live((w) => f.skirt(w, length: length, flare: 0.08, waist: 0.06), color: color, shade: _cloth),
      Shape.live(
        (w) {
          final double hem = math.max(f.legPoint(w, 'F', length).dy, f.legPoint(w, 'B', length).dy);
          final Offset a = w.point('chest', Offset(b.mid(0.1) - 6, -b.torso * 0.06)), c = w.point('chest', Offset(b.mid(0.1) + 8, -b.torso * 0.06));
          return Paths.polygon(<Offset>[a, c, Offset(c.dx + 10, hem), Offset(a.dx - 4, hem)]);
        },
        color: _light(color, 0.06),
        shade: Shade.gentle,
      ),
    ]));
    if (belt != null) f.overTorso.add(Part(shapes: <Shape>[Shape(f.torsoBand(0.03, 0.12), color: belt, shade: _metal)]));
  }
}

class Skirt extends Garment {
  const Skirt(this.color, {this.length = 0.6});
  final Color color;
  final double length;

  @override
  void dress(Fitting f) {
    f.torso.add(Shape(f.torsoBand(-1, 0.2), color: color, shade: _cloth));
    f.overLegs.add(_robeSkirt(f, color, length: length, flare: 0.4, waist: 0.2));
  }
}

class Trousers extends Garment {
  const Trousers(this.color, {this.length = 1});
  final Color color;

  /// 1 to the ankle, about 0.45 for shorts.
  final double length;

  @override
  void dress(Fitting f) {
    f.legs.add(Cover(color, to: length, extra: 3));
    f.torso.add(Shape(f.torsoBand(-1, 0.13), color: color, shade: _cloth));
  }
}

class Belt extends Garment {
  const Belt(this.color, {this.buckle = const Color(0xFFD4A94A)});
  final Color color;
  final Color? buckle;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double m = b.mid(0.1), t = b.torso;
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(f.torsoBand(0.07, 0.16), color: color, shade: _cloth),
      if (buckle != null) ...<Shape>[
        Shape(Paths.roundRect(Rect.fromLTRB(m - 11, -t * 0.175, m + 9, -t * 0.055), 3), color: buckle, shade: Shade.gentle),
        Shape(Paths.roundRect(Rect.fromLTRB(m - 6, -t * 0.14, m + 4, -t * 0.09), 1.5), color: _dark(buckle!, 0.3)),
      ],
    ]));
  }
}

/// A scarf knotted at the throat, its point down the chest.
class Bandana extends Garment {
  const Bandana(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double t = b.torso, m = b.mid(1);
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(Paths.smooth(<Offset>[
        Offset(m - 34, -t - 6), Offset(m - 4, -t - 1), Offset(m + 26, -t - 7),
        Offset(m + 16, -t + 10), Offset(m + 3, -t + 34), Offset(m - 14, -t + 12),
      ]), color: color, shade: _cloth),
      Shape(Paths.circle(Offset(m - 2, -t + 4), 5.5), color: _dark(color, 0.12)),
    ]));
  }
}

/// The broad jewelled collar of ancient Egypt: bands of colour round the
/// neck and over the chest.
class BroadCollar extends Garment {
  const BroadCollar({this.colors = const <Color>[Color(0xFFD4A94A), Color(0xFF2F8FA8), Color(0xFFD4A94A), Color(0xFFC0392B)]});
  final List<Color> colors;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final Offset c = Offset(b.mid(1) - 6, -b.torso + 2);
    final Path inner = Paths.ellipse(c, b.shoulders * 0.2, b.torso * 0.07);
    f.overTorso.add(Part(shapes: <Shape>[
      for (int i = 0; i < colors.length; i++)
        Shape(
          _and(_minus(Paths.ellipse(c, b.shoulders * (0.2 + 0.36 * (1 - i / colors.length)), b.torso * (0.07 + 0.26 * (1 - i / colors.length))), inner),
              b.torsoPath),
          color: colors[i],
          shade: _metal,
        ),
    ]));
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
      width: b.shoulders * 0.7,
      tipWidth: b.shoulders * 1.1,
      color: _dark(color, 0.14),
      at: Offset(b.back + 14, -b.torso + 10),
      degrees: 96,
    );
    f.behind.add(cape.part);
    f.jiggles.addAll(cape.jiggles(hertz: 1.3, damping: 0.35, inertia: 0.9, limit: 14));
    final double t = b.torso, m = b.mid(1);
    f.overTorso.add(Part(shapes: <Shape>[
      // Over the shoulders, fastened at the throat.
      Shape(
        _and(
          Paths.smooth(<Offset>[
            Offset(b.back - 6, -t + 22), Offset(b.back + 4, -t - 6), Offset(m, -t - 8), Offset(b.front + 4, -t + 4), Offset(m, -t + 14), Offset(b.back + 18, -t + 26),
          ]),
          _scaled(b.torsoPath, Offset(0, -t / 2), 1.06),
        ),
        color: color,
        shade: _cloth,
      ),
      Shape(Paths.circle(Offset(m - 4, -t + 6), 6.5), color: const Color(0xFFD4A94A), shade: _metal),
    ]));
  }
}

/// A breastplate in bands, with shoulder guards: a legionary's lorica, a
/// knight's plate.
class Armour extends Garment {
  const Armour({this.metal = const Color(0xFFB8BEC6), this.bands = 4});
  final Color metal;
  final int bands;

  @override
  void dress(Fitting f) {
    f.overTorso.add(Part(shapes: <Shape>[
      for (int i = 0; i < bands; i++)
        Shape(
          f.torsoBand(0.14 + i * 0.86 / bands, 0.14 + (i + 1) * 0.86 / bands + 0.03),
          color: i.isEven ? metal : _dark(metal, 0.06),
          shade: _metal,
        ),
    ]));
    f.arms.add(Cover(_light(metal, 0.08), to: 0.26, extra: 7));
    f.arms.add(Cover(_dark(metal, 0.1), from: 0.16, to: 0.26, extra: 7.5));
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

/// Plain boots to above the ankle, or up the shin by [height].
class Boots extends Garment {
  const Boots(this.color, {this.height = 0.2});
  final Color color;
  final double height;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final Path boot = Character.shoe(b, top: 1.1);
    f.feet = (Color Function(Color) tone) => <Shape>[
          Shape(boot, color: tone(color), shade: Shade.solid),
          Shape(_and(boot, _below(b.sole - 4)), color: tone(_dark(color, 0.4))),
        ];
    if (height > 0) f.legs.add(Cover(color, from: 1 - height, extra: 3.5));
  }
}

/// Pointed toe, a riding heel, a tall shaft with a stitched top.
class CowboyBoots extends Garment {
  const CowboyBoots(this.color);
  final Color color;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double s = b.sole, r = b.ankleRadius, ft = b.foot;
    f.feet = (Color Function(Color) tone) => <Shape>[
          Shape(Paths.smooth(<Offset>[
            Offset(-r * 1.05, -r * 1.2), Offset(r * 0.9, -r * 1.1), Offset(ft * 0.6, s * 0.15),
            Offset(ft * 1.1, s * 0.62), Offset(ft * 0.95, s - 1), Offset(ft * 0.2, s - 3),
            Offset(-r * 1.0, s - 1), Offset(-r * 1.2, s * 0.4),
          ]), color: tone(color), shade: Shade.solid),
          // The heel, and the sole's edge.
          Shape(Paths.polygon(<Offset>[Offset(-r * 1.1, s - 6), Offset(-r * 0.15, s - 6), Offset(-r * 0.25, s + 1), Offset(-r * 1.0, s + 1)]),
              color: tone(_dark(color, 0.45))),
          Shape(Paths.smooth(<Offset>[Offset(0, s - 3.5), Offset(ft * 0.9, s - 2.5), Offset(ft * 0.95, s - 0.5), Offset(0, s)]),
              color: tone(_dark(color, 0.35))),
        ];
    f.legs.add(Cover(color, from: 0.66, extra: 4.5));
    f.legs.add(Cover(_dark(color, 0.22), from: 0.66, to: 0.7, extra: 5.5));
  }
}

/// Bare feet on a sole, a strap over the toes and one round the ankle.
class Sandals extends Garment {
  const Sandals({this.color = const Color(0xFF8A5A2B)});
  final Color color;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double r = b.ankleRadius, s = b.sole, ft = b.foot;
    final Path foot = Character.shoe(b, top: 0.7);
    f.feet = (Color Function(Color) tone) => <Shape>[
          Shape(foot, color: tone(f.skin), shade: Shade.solid),
          Shape(_and(foot, Paths.rect(Rect.fromLTRB(ft * 0.3, -r, ft * 0.44, s))), color: tone(color)),
          Shape(Paths.roundRect(Rect.fromLTRB(-r * 1.15, -r * 0.55, r * 0.95, -r * 0.2), 2), color: tone(color)),
          Shape(Paths.roundRect(Rect.fromLTRB(-r * 1.2, s - 3.5, ft * 0.95, s + 1), 2), color: tone(_dark(color, 0.15))),
        ];
  }
}

/// Trainers: a white sole, laces, a stripe.
class Sneakers extends Garment {
  const Sneakers(this.color, {this.sole = const Color(0xFFF4F4F4)});
  final Color color;
  final Color sole;

  @override
  void dress(Fitting f) {
    final Body b = f.body;
    final double r = b.ankleRadius, s = b.sole, ft = b.foot;
    final Path shoe = Character.shoe(b, top: 1.0);
    f.feet = (Color Function(Color) tone) => <Shape>[
          Shape(shoe, color: tone(color), shade: Shade.solid),
          Shape(_and(_scaled(shoe, Offset(ft * 0.3, s), 1.04), _below(s - 6)), color: tone(sole), shade: Shade.gentle),
          Shape(_ribbon(<Offset>[Offset(-r * 0.6, s - 9), Offset(ft * 0.25, s - 12), Offset(ft * 0.55, s - 16)], 4, tip: 0.4), color: tone(sole)),
          for (int i = 0; i < 3; i++)
            Shape(Paths.roundRect(Rect.fromCenter(center: Offset(r * (0.5 + i * 0.55), -r * (0.55 - i * 0.28)), width: 7, height: 3), 1.5),
                color: tone(sole)),
        ];
  }
}

// --- cyborg ---

/// One arm (or both) replaced by a machine: plating, a ring at the elbow, a
/// light at the wrist, a metal hand.
class RobotArm extends Garment {
  const RobotArm({this.metal = const Color(0xFF8E9AA8), this.side = 'F', this.glow = const Color(0xFF4DE8FF)});
  final Color metal;
  final String? side;
  final Color glow;

  @override
  void dress(Fitting f) {
    f.arms.add(Cover(metal, extra: 2.5, side: side));
    f.arms.add(Cover(_light(metal, 0.12), to: 0.2, extra: 5, side: side));
    f.arms.add(Cover(_dark(metal, 0.4), from: 0.48, to: 0.54, extra: 3.5, side: side));
    f.arms.add(Cover(glow, from: 0.78, to: 0.82, extra: 3, side: side));
    for (final String s in side == null ? const <String>['F', 'B'] : <String>[side!]) {
      f.hands[s] = _dark(metal, 0.12);
    }
  }
}

/// A machine eye where the near eye was, set in a plate that runs back to
/// the temple, glowing.
class EyeImplant extends Garment {
  const EyeImplant({this.metal = const Color(0xFF6B7684), this.glow = const Color(0xFFFF3B3B)});
  final Color metal;
  final Color glow;

  @override
  void dress(Fitting f) {
    final double rr = f.eyeRadius * 1.45;
    final Offset e = f.eyeNear;
    f.faceFront.add(Part(shapes: <Shape>[
      Shape(
        Paths.smooth(<Offset>[e + Offset(-rr * 2.4, -rr * 1.0), e + Offset(rr * 0.6, -rr * 1.25), e + Offset(rr * 1.2, 0), e + Offset(rr * 0.6, rr * 1.15), e + Offset(-rr * 2.2, rr * 0.9)]),
        color: metal,
        shade: _metal,
      ),
      Shape(Paths.circle(e, rr * 0.9), color: glow.withValues(alpha: 0.2)),
      Shape(Paths.circle(e, rr * 0.78), color: const Color(0xFF15181D)),
      Shape(Paths.circle(e, rr * 0.46), color: glow),
      Shape(Paths.circle(e + Offset(-rr * 0.14, -rr * 0.16), rr * 0.14), color: const Color(0xCCFFFFFF)),
      for (final Offset bolt in <Offset>[Offset(-rr * 1.8, -rr * 0.55), Offset(-rr * 1.7, rr * 0.5)])
        Shape(Paths.circle(e + bolt, rr * 0.12), color: _dark(metal, 0.35)),
    ]));
  }
}

/// A metal plate over the back of the skull.
class HeadPlate extends Garment {
  const HeadPlate({this.metal = const Color(0xFF8E9AA8)});
  final Color metal;

  @override
  void dress(Fitting f) {
    final Path plate = _and(
      _scaled(f.headOutline, f.h(0, 0), 1.04),
      Paths.polygon(<Offset>[f.h(-2, -2), f.h(0.15, -2), f.h(-0.15, -0.6), f.h(-0.5, -0.25), f.h(-0.66, 0.35), f.h(-2, 0.35)]),
    );
    f.headwear.add(Part(shapes: <Shape>[
      Shape(plate, color: metal, shade: _metal),
      for (final (double x, double y) in <(double, double)>[(-0.62, -0.55), (-0.25, -0.88), (-0.86, -0.05)])
        Shape(Paths.circle(f.h(x, y), f.r * 0.05), color: _dark(metal, 0.35)),
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
    final Rect r = Rect.fromCenter(center: Offset(b.mid(0.65) - 14, -b.torso * 0.62), width: 22, height: 44);
    f.overTorso.add(Part(shapes: <Shape>[
      Shape(Paths.roundRect(r, 6), color: panel, shade: _metal),
      for (int i = 0; i < 3; i++) ...<Shape>[
        Shape(Paths.circle(Offset(r.center.dx, r.top + 9 + i * 13), 7), color: glow.withValues(alpha: 0.25)),
        Shape(Paths.circle(Offset(r.center.dx, r.top + 9 + i * 13), 4), color: glow),
      ],
    ]));
  }
}

// --- things to hold ---

/// Props for [Character.build]'s `hold`, drawn in the hand's space with the
/// hand at the origin and the forearm above it.
abstract final class Props {
  /// A staff, upright when the arm hangs down.
  static Part staff({double length = 300, Color color = const Color(0xFF7A5230)}) => Part(shapes: <Shape>[
        Shape(Paths.capsule(Offset(0, -length * 0.62), Offset(0, length * 0.38), 6), color: color, shade: Shade.solid),
        Shape(Paths.circle(Offset(0, -length * 0.62), 10), color: _dark(color, 0.15), shade: Shade.solid),
      ]);

  /// A walking stick, the crook in the hand and the tip [length] below it:
  /// on the ground when the arm hangs down, if [length] is the drop from the
  /// wrist to the ground.
  static Part cane({double length = 110, Color color = const Color(0xFF6B4226)}) => Part(shapes: <Shape>[
        Shape(Paths.capsule(const Offset(2, 4), Offset(2, length), 4), color: color, shade: Shade.solid),
        Shape(
          Path()
            ..moveTo(2, 8)
            ..cubicTo(2, -14, 24, -14, 24, 2),
          stroke: color,
          strokeWidth: 8,
        ),
      ]);

  static Part spear({double length = 340, Color shaft = const Color(0xFF7A5230), Color head = const Color(0xFFB8BEC6)}) => Part(shapes: <Shape>[
        Shape(Paths.capsule(Offset(0, -length * 0.65), Offset(0, length * 0.35), 4.5), color: shaft, shade: Shade.solid),
        Shape(Paths.polygon(<Offset>[Offset(0, -length * 0.65 - 46), Offset(10, -length * 0.65), Offset(-10, -length * 0.65)]), color: head, shade: _metal),
      ]);

  static Part scroll({Color paper = const Color(0xFFF1E4C3)}) => Part(at: const Offset(0, 6), degrees: -20, shapes: <Shape>[
        Shape(Paths.roundRect(const Rect.fromLTRB(-10, -30, 10, 30), 6), color: paper, shade: Shade.solid),
        Shape(Paths.rect(const Rect.fromLTRB(-12, -6, 12, 6)), color: const Color(0xFFC0392B)),
      ]);

  /// A tall curved shield, held on the arm.
  static Part shield({Color color = const Color(0xFFB0262C), Color boss = const Color(0xFFD4A94A)}) => Part(
        at: const Offset(10, -30),
        shapes: <Shape>[
          Shape(Paths.roundRect(const Rect.fromLTRB(-30, -95, 30, 95), 14), color: color, shade: _metal),
          Shape(Paths.roundRect(const Rect.fromLTRB(-30, -95, 30, 95), 14), stroke: boss, strokeWidth: 5),
          Shape(Paths.circle(Offset.zero, 14), color: boss, shade: _metal),
        ],
      );

  static Part clipboard() => Part(at: const Offset(8, -4), degrees: 12, shapes: <Shape>[
        Shape(Paths.roundRect(const Rect.fromLTRB(-20, -28, 20, 28), 4), color: const Color(0xFF8A5A2B), shade: Shade.solid),
        Shape(Paths.rect(const Rect.fromLTRB(-16, -22, 16, 24)), color: const Color(0xFFFFFFFF)),
        for (int i = 0; i < 4; i++) Shape(Paths.rect(Rect.fromLTWH(-12, -14 + i * 9.0, 22, 2.5)), color: const Color(0xFF8899AA)),
      ]);

  static Part lasso({Color color = const Color(0xFFC9A26B)}) => Part(at: const Offset(4, 10), shapes: <Shape>[
        Shape(Paths.ellipse(Offset.zero, 18, 30), stroke: color, strokeWidth: 5),
        Shape(Paths.ellipse(const Offset(3, 4), 15, 26), stroke: _dark(color, 0.15), strokeWidth: 4),
      ]);
}
