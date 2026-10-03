import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:reelforge/reelforge.dart' show ExactCurve;

import 'follow.dart';
import 'kinematics.dart';
import 'part.dart';
import 'pose.dart';
import 'walk.dart';

/// One leg of a four-legged animal, by joint name: three bones and a paw.
///
/// An animal stands on its toes. Below the thigh and the shin (or the upper
/// arm and the forearm) there is a third bone -- the hind leg's hock, the
/// foreleg's wrist -- and that is what keeps a walking cat from looking like
/// a table walking: the hind leg zigzags, knee forward and hock back, and
/// the forepaw folds right back at the wrist as it is carried forward.
@immutable
class PawLeg {
  const PawLeg({
    required this.top,
    required this.middle,
    required this.lower,
    required this.paw,
    this.toe = const Offset(14, 13),
  });

  /// The hip or shoulder, the knee or elbow, the hock or wrist, the paw.
  final String top, middle, lower, paw;

  /// The tips of the toes, on the sole, in the paw's own space: what the paw
  /// stands on, and peels up about as it leaves the ground.
  final Offset toe;
}

/// The joints a [Gait] drives on a four-legged rig.
///
/// The rig's root part is the hips: the gait places it, and the hind legs
/// hang from it. The forelegs hang from [chest], somewhere in front of it,
/// so the back can give between them. Near legs are `F`, far legs `B`.
@immutable
class Quadruped {
  const Quadruped({
    this.hindNear = const PawLeg(top: 'hipF', middle: 'kneeF', lower: 'hockF', paw: 'footF'),
    this.hindFar = const PawLeg(top: 'hipB', middle: 'kneeB', lower: 'hockB', paw: 'footB'),
    this.foreNear = const PawLeg(top: 'shoulderF', middle: 'elbowF', lower: 'wristF', paw: 'pawF'),
    this.foreFar = const PawLeg(top: 'shoulderB', middle: 'elbowB', lower: 'wristB', paw: 'pawB'),
    this.chest = 'chest',
    this.head = 'head',
  });

  final PawLeg hindNear, hindFar, foreNear, foreFar;

  /// The part the forelegs hang from. The gait raises and lowers it on the
  /// forelegs, as it does the hips on the hind legs, so the back is never
  /// quite level.
  final String chest;

  /// Kept steadier than the shoulders it rides on, as an animal's head is.
  final String? head;
}

/// A leg's paw at a moment: where its pivot (the bottom of the lower bone)
/// is, how far the lower bone leans, how the paw is pitched, and how much
/// weight the leg is taking.
typedef _Paw = ({Offset pivot, double lean, double pitch, double support});

/// Where the hips and chest would be at a frame, and how far each leg's
/// lower bone would turn to reach.
typedef _Heights = ({double hips, double chest, List<double> turns});

/// An animal walking on four legs, with its paws planted.
///
/// The same idea as a [Walk]: footfalls are planned once from the [route],
/// spaced by distance so a planted paw stays where it landed however the
/// body speeds up or stops. The legs go in the order animals walk in --
/// hind, fore on the same side, then the other hind and fore -- a quarter of
/// a stride apart, so two or three paws are always down. When the route
/// ends each leg takes one last step to stand square.
///
/// Each step is a cat's step, not a piston's. The paw peels off the ground
/// heel first, rolling over its toes; it is lifted by folding the leg --
/// the hock flexes, the forepaw tucks back under the wrist -- carried
/// forward, unfolded and reached out, and put down flat. While it is down
/// the leg leans further over it as the body passes. The hips ride on the
/// hind legs and the shoulders on the forelegs, each at an easy bend of the
/// legs under them, so the back rises and dips with the steps, and the
/// shoulder blades slide with the forelegs. The head is steadier.
///
/// Everything is a pure function of the frame.
class Gait {
  Gait({
    required this.rig,
    required List<Waypoint> route,
    required this.groundY,
    required this.fps,
    this.scale = 1,
    this.body = const Quadruped(),
    double? stepLength,
    this.stepHeight = 0.13,
    this.duty = 0.62,
  }) : assert(route.isNotEmpty, 'A gait needs at least one waypoint.'),
       assert(duty > 0.5 && duty < 1, 'A walk has more than half of each stride on the ground.'),
       _route = List<Waypoint>.unmodifiable(route) {
    _measureRig();
    this.stepLength = stepLength ?? _legLength * scale * 1.25;
    _dir = route.last.x >= route.first.x ? 1 : -1;
    assert(() {
      for (int i = 1; i < route.length; i++) {
        if ((route[i].x - route[i - 1].x) * _dir < 0) return false;
        if (route[i].frame <= route[i - 1].frame) return false;
      }
      return true;
    }(), 'A gait goes one way: waypoints must not turn back, and their frames must increase.');
    _plan();
  }

  /// The animal, unplaced. Its root is the hips.
  final Part rig;

  final double groundY;
  final int fps;
  final double scale;
  final Quadruped body;

  /// World pixels each paw moves at every step: one stride.
  late final double stepLength;

  /// How high a swinging paw is lifted, as a fraction of the leg.
  final double stepHeight;

  /// The share of each stride a paw spends on the ground.
  final double duty;

  final List<Waypoint> _route;
  late final int _dir;

  /// Every footfall, by leg: 0 hind near, 1 fore near, 2 hind far, 3 fore
  /// far -- the order they step in. `from` and `to` are where the toes are.
  late final List<Footstep> steps;

  late final double _legLength;
  late final List<Offset> _tops; // each leg's top joint, in the root's space
  late final List<double> _upper, _middle, _lower; // bone lengths, unscaled

  late final int _first;
  late final List<double> _u;

  List<PawLeg> get _legs => <PawLeg>[body.hindNear, body.foreNear, body.hindFar, body.foreFar];

  static bool _fore(int leg) => leg.isOdd;

  /// Where in the stride each leg lands.
  static const List<double> _phase = <double>[0, 0.25, 0.5, 0.75];

  void _measureRig() {
    _tops = <Offset>[];
    _upper = <double>[];
    _middle = <double>[];
    _lower = <double>[];
    for (final PawLeg leg in _legs) {
      _tops.add(frameOf(rig, Pose.rest, leg.top).origin - rig.at);
      final List<Part> path = pathTo(rig, leg.paw)!;
      _upper.add(path[path.length - 3].at.distance);
      _middle.add(path[path.length - 2].at.distance);
      _lower.add(path.last.at.distance);
    }
    _legLength = math.min(_upper[0] + _middle[0] + _lower[0], _upper[2] + _middle[2] + _lower[2]);
  }

  /// Where the body is along the route at [frame], in world x.
  double xAt(num frame) {
    final Waypoint first = _route.first;
    if (frame <= first.frame || _route.length == 1) return first.x;
    for (int i = 1; i < _route.length; i++) {
      final Waypoint to = _route[i];
      if (frame > to.frame) continue;
      final Waypoint from = _route[i - 1];
      final double t = to.curve.exact((frame - from.frame) / (to.frame - from.frame));
      return from.x + (to.x - from.x) * t;
    }
    return _route.last.x;
  }

  double _uAt(num frame) => (xAt(frame) - _route.first.x) * _dir;
  double _world(double u) => _route.first.x + u * _dir;

  double _frameAt(double u) {
    if (u <= 0) return _first.toDouble();
    if (u >= _u.last) {
      final int i = _u.indexWhere((double v) => v >= _u.last);
      return (_first + i).toDouble();
    }
    int lo = 0, hi = _u.length - 1;
    while (hi - lo > 1) {
      final int mid = (lo + hi) >> 1;
      if (_u[mid] >= u) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    final double span = _u[hi] - _u[lo];
    return _first + lo + (span <= 0 ? 0 : (u - _u[lo]) / span);
  }

  /// Where a leg's toes stand, relative to the body, when it is still: a
  /// little ahead of the hip, under the shoulder.
  double _neutral(int leg) => (_tops[leg].dx + (_fore(leg) ? 0.06 : 0.12) * _legLength) * scale;

  void _plan() {
    _first = _route.first.frame;
    _u = <double>[for (int f = _first; f <= _route.last.frame; f++) _uAt(f)];
    final double total = _u.last, l = stepLength;
    final double minSwing = 0.2 * fps, maxSwing = 0.36 * fps, minStance = 0.12 * fps;
    final List<double> at = <double>[for (int i = 0; i < 4; i++) _neutral(i)];
    final List<double> landed = List<double>.filled(4, double.negativeInfinity);
    final List<Footstep> out = <Footstep>[];

    double start = _first + 0.05 * fps;
    void add(int leg, double to, double lift, double land) {
      final double swing = math.max(land - lift, minSwing);
      lift = math.max(lift, landed[leg] + minStance);
      // Setting off, the legs go one at a time, a beat apart.
      if (lift < start) {
        lift = start;
        start += 0.08 * fps;
      }
      // Two paws stay down: wait while two others are still in the air.
      for (;;) {
        final List<Footstep> up = <Footstep>[
          for (final Footstep o in out)
            if (o.foot != leg && o.lift < lift + swing && o.land > lift) o,
        ];
        if (up.length < 2) break;
        lift = up.map((Footstep o) => o.land).reduce(math.min);
      }
      out.add(Footstep(leg, lift, lift + swing, _world(at[leg]), _world(to)));
      at[leg] = to;
      landed[leg] = lift + swing;
    }

    // Strides, every leg in its turn: a paw lands a little ahead of where it
    // stands, and leaves when it is as far behind. A leg whose turn comes
    // late in the first stride takes a short step at the start instead of
    // being left trailing.
    final List<({int leg, double u})> landings = <({int leg, double u})>[];
    for (int k = -1; ; k++) {
      bool any = false;
      for (int leg = 0; leg < 4; leg++) {
        final double u = (k + _phase[leg] + 0.35) * l;
        if (u > total - 0.2 * l) continue;
        any = true;
        if (u > -0.2 * l) landings.add((leg: leg, u: u));
      }
      if (!any) break;
    }
    landings.sort((a, b) => a.u.compareTo(b.u));
    for (final ({int leg, double u}) s in landings) {
      final double when = math.max(s.u, 0.12 * l);
      final double land = _frameAt(when);
      final double swing = (land - _frameAt(when - (1 - duty) * l)).clamp(minSwing, maxSwing);
      add(s.leg, s.u + _neutral(s.leg) + duty * l / 2, land - swing, land);
    }

    // Then each leg steps square under the body where it stops -- each when
    // its paw falls due, as it would have in the stride, but no sooner than
    // a beat after the one before.
    final List<int> settling = <int>[
      for (int leg = 0; leg < 4; leg++)
        if ((total + _neutral(leg) - at[leg]).abs() >= 0.05 * l) leg,
    ];
    double due(int leg) => math.min(_frameAt(at[leg] - _neutral(leg) + duty * l / 2), _frameAt(total) - 0.1 * fps);
    settling.sort((int a, int b) => due(a).compareTo(due(b)));
    double next = double.negativeInfinity;
    for (final int leg in settling) {
      final double lift = math.max(due(leg), next);
      add(leg, total + _neutral(leg), lift, lift + 0.32 * fps);
      next = math.max(lift, landed[leg] - 0.32 * fps) + 0.16 * fps;
    }
    out.sort((a, b) => a.lift.compareTo(b.lift));
    steps = List<Footstep>.unmodifiable(out);
  }

  // --- the paws ---

  /// A vector in the rig's own drawing, as it is in the world.
  Offset _toWorld(Offset v) => Offset(v.dx * scale * _dir, v.dy * scale);

  /// [v] turned clockwise by [degrees], as a part's turn is.
  static Offset _turn(Offset v, double degrees) {
    final double a = degrees * math.pi / 180, c = math.cos(a), s = math.sin(a);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  static double _smooth(double t) {
    final double x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  /// How a leg holds its paw while it is down, toes at world [toeX]: the
  /// lower bone leans further over as the body passes the paw, and from
  /// [peel] 0 to 1 the paw rolls up onto its toes to leave.
  _Paw _stance(int leg, double toeX, double frame, double peel) {
    final bool fore = _fore(leg);
    final double topX = xAt(frame) + _tops[leg].dx * scale * _dir;
    final double behind = ((topX - toeX) * _dir / (_legLength * scale)).clamp(-0.6, 0.8);
    // Lean is how far the top of the lower bone -- hock or wrist -- is
    // ahead of the paw, in degrees. A hind leg stands with the hock behind
    // the paw, more upright as the leg trails; a foreleg stands with the
    // wrist over the paw, and rolls forward over it as it leaves.
    final double lean = fore ? 4 + 16 * behind + 26 * peel : -16 + 16 * behind - 6 * peel;
    // Rolling onto its toes, the heel rises: the paw turns toes-down.
    final double pitch = (fore ? 40 : 30) * peel;
    final Offset toe = Offset(toeX, groundY);
    return (pivot: toe - _toWorld(_turn(_legs[leg].toe, pitch)), lean: lean, pitch: pitch, support: 1.0);
  }

  _Paw _paw(int leg, double frame) {
    Footstep? previous, current, next;
    for (final Footstep s in steps) {
      if (s.foot != leg) continue;
      if (s.land <= frame) {
        previous = s;
      } else if (s.lift <= frame) {
        current = s;
        break;
      } else {
        next = s;
        break;
      }
    }

    if (current == null) {
      final double toeX = previous?.to ?? _world(_neutral(leg));
      double peel = 0;
      if (next != null) {
        final double length = math.min(0.18 * fps, (next.lift - (previous?.land ?? -1e9)) * 0.45);
        peel = _smooth((frame - (next.lift - length)) / length);
      }
      return _stance(leg, toeX, frame, peel);
    }

    // In the air: from how it left to how it will land, folded up on the
    // way and reaching out at the end.
    final _Paw from = _stance(leg, current.from, current.lift, 1);
    final _Paw to = _stance(leg, current.to, current.land, 0);
    final double t = ((frame - current.lift) / (current.land - current.lift)).clamp(0.0, 1.0);
    // A short or quick step folds the leg less.
    final double size = ((current.to - current.from).abs() / stepLength).clamp(0.25, 1.0) *
        ((current.land - current.lift) / (0.25 * fps)).clamp(0.6, 1.0);
    final double along = Curves.easeInOut.exact(t);
    final double fold = math.pow(math.sin(math.pi * (t / 0.85).clamp(0.0, 1.0)), 1.5).toDouble();
    final double reach = math.sin(math.pi * ((t - 0.45) / 0.55).clamp(0.0, 1.0));
    // Up quickly and down slowly, easing off the ground and onto it.
    final double lift = math.pow(math.sin(math.pi * t * (1.6 - 0.6 * t)), 1.4).toDouble();
    final bool fore = _fore(leg);

    Offset pivot = Offset.lerp(from.pivot, to.pivot, along)! -
        Offset(0, stepHeight * (fore ? 1.15 : 0.9) * _legLength * scale * size * lift);
    final double lean = from.lean + (to.lean - from.lean) * along + size * (fore ? 75 * fold - 22 * reach : 40 * fold - 16 * reach);
    final double bend = (from.pitch - from.lean) + ((to.pitch - to.lean) - (from.pitch - from.lean)) * along;
    final double pitch = lean + bend + size * (fore ? 28 : 18) * fold;
    // Curling, the toes would scrape the ground; the paw rises clear of it.
    final double below = pivot.dy + _toWorld(_turn(_legs[leg].toe, pitch)).dy - groundY;
    if (below > 0) pivot -= Offset(0, below);
    return (pivot: pivot, lean: lean, pitch: pitch, support: 1 - 0.85 * math.sin(math.pi * t));
  }

  /// Where [leg]'s toes are at [frame], in the drawing's coordinates.
  Offset toeAt(int leg, num frame) {
    final _Paw p = _paw(leg, frame.toDouble());
    return p.pivot + _toWorld(_turn(_legs[leg].toe, p.pitch));
  }

  /// Whether [leg] is on the ground at [frame].
  bool plantedAt(int leg, num frame) => !steps.any((Footstep s) => s.foot == leg && s.lift <= frame && frame < s.land);

  // --- the body ---

  /// The top of [leg]'s lower bone -- hock or wrist -- for paw [p].
  Offset _lowerTop(int leg, _Paw p) => p.pivot - _toWorld(_turn(Offset(0, _lower[leg]), p.lean));

  /// The height [leg]'s top joint would sit at over [p], with the leg bent
  /// to [reach] of its length.
  double _topY(int leg, _Paw p, double topX, double reach) {
    final Offset target = _lowerTop(leg, p);
    final double limit = (_upper[leg] + _middle[leg]) * scale * reach;
    final double dx = math.min((target.dx - topX).abs(), limit);
    return target.dy - math.sqrt(limit * limit - dx * dx);
  }

  /// The highest [leg]'s top joint can be and the whole leg, all three
  /// bones, still reach the bottom of its lower bone.
  double _reachY(int leg, _Paw p, double topX) {
    final double limit = (_upper[leg] + _middle[leg] + _lower[leg]) * scale * 0.97;
    final double dx = math.min((p.pivot.dx - topX).abs(), limit);
    return p.pivot.dy - math.sqrt(limit * limit - dx * dx);
  }

  /// [p]'s lean, turned as little as it takes for the upper two bones to
  /// reach the lower one's top from [top]: a trailing hind leg's hock rises
  /// and the leg straightens out behind, rather than the hips sinking.
  double _reachable(int leg, _Paw p, Offset top) {
    final double limit = (_upper[leg] + _middle[leg]) * scale * 0.995;
    bool fits(double lean) => (_lowerTop(leg, (pivot: p.pivot, lean: lean, pitch: p.pitch, support: p.support)) - top).distance <= limit;
    if (fits(p.lean)) return p.lean;
    final Offset v = top - p.pivot;
    final double toward = math.atan2(v.dx * _dir / scale, -v.dy / scale) * 180 / math.pi;
    if (!fits(toward)) return toward;
    double a = p.lean, b = toward;
    for (int i = 0; i < 24; i++) {
      final double mid = (a + b) / 2;
      if (fits(mid)) {
        b = mid;
      } else {
        a = mid;
      }
    }
    return b;
  }

  static double _smoothMax(double a, double b, double k) {
    final double h = (0.5 + 0.5 * (b - a) / k).clamp(0.0, 1.0);
    return a * (1 - h) + b * h + k * h * (1 - h);
  }

  /// How high [leg]'s top joint is when the animal stands square.
  late final List<double> _standing = <double>[
    for (int leg = 0; leg < 4; leg++)
      groundY -
          _topY(leg, _stance(leg, _world(_neutral(leg)), _first.toDouble(), 0), _route.first.x + _tops[leg].dx * scale * _dir,
              // A foreleg stands as a column under the shoulder; a hind leg
              // keeps a spring in its knee and hock.
              _fore(leg) ? 0.95 : 0.88),
  ];

  /// How far into its stride the body is, 0 to 1, and how near walking pace
  /// it is going.
  double _cycle(double frame) => (_uAt(frame) / stepLength) % 1;
  double _pace(double frame) => ((_uAt(frame + 1) - _uAt(frame - 1)) / 2 / (stepLength / fps)).clamp(0.0, 1.0);

  /// Where the legs in [legs] hold the part they hang from: at their
  /// standing height, dipping twice a stride as each leg in turn takes the
  /// weight, and lowered wherever a paw needs the reach. [top] is where
  /// each leg's top joint is, across and below that part's own height.
  double _ride(List<int> legs, List<_Paw> paws, Offset Function(int) top, double frame, double phase) {
    double y = 0;
    for (final int leg in legs) {
      y += (groundY - _standing[leg] - top(leg).dy) / legs.length;
    }
    y += 0.03 * _legLength * scale * _pace(frame) * (0.5 - 0.5 * math.cos(4 * math.pi * (_cycle(frame) - phase)));
    for (final int leg in legs) {
      y = _smoothMax(y, _reachY(leg, paws[leg], top(leg).dx) - top(leg).dy, 0.03 * _legLength * scale);
    }
    return y;
  }

  /// How many frames either side the hips and chest look, to ease.
  static const int _ease = 16;

  /// Where each leg's top joint is across, and how far below the root.
  Offset _top(int leg, double x) => Offset(x + _tops[leg].dx * scale * _dir, _tops[leg].dy * scale);

  /// The shoulder blades slide forward and back with the forelegs, and rise
  /// a little as a leg takes the weight.
  Map<String, Offset> _blades(double f, List<_Paw> paws) => <String, Offset>{
        for (final int leg in const <int>[1, 3])
          _legs[leg].top: Offset(
            0.08 * _legLength * ((toeAt(leg, f).dx - _top(leg, xAt(f)).dx) * _dir / (_legLength * scale)).clamp(-0.6, 0.6),
            -0.03 * _legLength * paws[leg].support,
          ),
      };

  /// Where the hips would be at [f], riding the hind legs, and where the
  /// chest would be, riding the forelegs as the hips do the hind ones, both
  /// as the root's height; and how far each leg's lower bone must turn from
  /// its lean for the leg to reach, from there.
  _Heights _heights(double f) {
    final double x = xAt(f);
    final List<_Paw> paws = <_Paw>[for (int leg = 0; leg < 4; leg++) _paw(leg, f)];
    final Map<String, Offset> blades = _blades(f, paws);
    Offset shoulder(int leg) {
      final Offset blade = blades[_legs[leg].top]!;
      return Offset(_top(leg, x).dx + blade.dx * scale * _dir, (_tops[leg].dy + blade.dy) * scale);
    }

    final double hips = _ride(const <int>[0, 2], paws, (int leg) => _top(leg, x), f, 0);
    final double chest = _ride(const <int>[1, 3], paws, shoulder, f, 0.25);
    return (
      hips: hips,
      chest: chest,
      turns: <double>[
        for (int leg = 0; leg < 4; leg++)
          _reachable(leg, paws[leg], _fore(leg) ? shoulder(leg) + Offset(0, chest) : _top(leg, x) + Offset(0, hips)) -
              paws[leg].lean,
      ],
    );
  }

  /// The gait at [frame]: the rig placed on the route, and its pose.
  ///
  /// [adjust] gets the body's pose before the legs are solved -- add a tail
  /// swish, breathing, a roar -- and the paws still land where they land.
  Posed at(int frame, {Pose Function(Pose pose)? adjust}) {
    final double f = frame.toDouble();
    final double x = xAt(f);
    final List<_Paw> paws = <_Paw>[for (int leg = 0; leg < 4; leg++) _paw(leg, f)];

    // The hips ride the hind legs and the chest the forelegs, each eased so
    // it never rises or sinks faster than a body does: lower than the legs
    // need, never higher, so every paw stays in reach.
    final List<_Heights> near = <_Heights>[for (int d = -_ease; d <= _ease; d++) _heights(f + d)];
    final double rate = 0.02 * _legLength * scale;
    double held(double Function(_Heights) of) {
      double y = -double.infinity;
      for (int d = -_ease; d <= _ease; d++) {
        y = math.max(y, of(near[d + _ease]) - rate * d.abs());
      }
      return y;
    }

    final double y = held((_Heights h) => h.hips);
    final Part placed = rig.placed(at: Offset(x, y), scaleX: scale * _dir, scaleY: scale);
    final Map<String, Offset> blades = _blades(f, paws);
    final double lift = (held((_Heights h) => h.chest) - y) / scale;

    // A trailing leg straightens to reach, and bends again as it lifts --
    // eased in and out the same way, a few degrees a frame.
    final List<double> turns = <double>[
      for (int leg = 0; leg < 4; leg++)
        () {
          double turn = 0;
          for (int d = -_ease; d <= _ease; d++) {
            final double t = near[d + _ease].turns[leg];
            final double eased = math.max(t.abs() - 6 * d.abs(), 0);
            if (eased > turn.abs()) turn = eased * t.sign;
          }
          return turn;
        }(),
    ];
    final Map<String, Joint> joints = <String, Joint>{
      body.chest: Joint(move: Offset(0, lift)),
      // The head holds its line, nodding a little as each foreleg takes the
      // weight.
      if (body.head != null)
        body.head!: Joint(
          move: Offset(0, -lift * 0.5),
          degrees: 2.5 * _pace(f) * math.sin(4 * math.pi * (_cycle(f) - 0.4)),
        ),
      for (final MapEntry<String, Offset> b in blades.entries) b.key: Joint(move: b.value),
    };

    Pose pose = Pose(joints);
    if (adjust != null) pose = adjust(pose);

    for (int leg = 0; leg < 4; leg++) {
      final PawLeg l = _legs[leg];
      final _Paw given = (pivot: paws[leg].pivot, lean: paws[leg].lean + turns[leg], pitch: paws[leg].pitch, support: paws[leg].support);
      final double lean = _reachable(leg, given, frameOf(placed, pose, l.top).origin);
      final _Paw p = (pivot: given.pivot, lean: lean, pitch: given.pitch, support: given.support);
      pose = reach(
        placed,
        pose,
        upper: l.top,
        lower: l.middle,
        end: l.lower,
        target: _lowerTop(leg, p),
        // A hind leg's knee points forward and its hock back; a foreleg's
        // elbow points back.
        bend: _fore(leg) ? -1 : 1,
        endDegrees: p.lean,
      );
      pose = Pose(<String, Joint>{...pose.joints, l.paw: Joint.rotate(p.pitch - p.lean)});
    }
    return Posed(placed, pose);
  }
}
