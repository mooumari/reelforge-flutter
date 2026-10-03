import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'follow.dart';
import 'kinematics.dart';
import 'part.dart';
import 'pose.dart';
import 'walk.dart';

/// The joints a [Gait] drives on a four-legged rig, and which way each pair
/// of legs bends.
///
/// The rig's root part is the hips: the gait places it, and the hind legs
/// hang from it. The forelegs hang from [chest], somewhere in front of it,
/// so the back can give a little between them. Near legs are `F`, far legs
/// `B`, as on a [Biped].
@immutable
class Quadruped {
  const Quadruped({
    this.hindNear = const Leg(hip: 'hipF', knee: 'kneeF', ankle: 'footF'),
    this.hindFar = const Leg(hip: 'hipB', knee: 'kneeB', ankle: 'footB'),
    this.foreNear = const Leg(hip: 'shoulderF', knee: 'elbowF', ankle: 'pawF'),
    this.foreFar = const Leg(hip: 'shoulderB', knee: 'elbowB', ankle: 'pawB'),
    this.chest = 'chest',
    this.head = 'head',
    this.hindBend = -1,
    this.foreBend = -1,
  });

  final Leg hindNear, hindFar, foreNear, foreFar;

  /// The part the forelegs hang from. The gait lowers it when a planted
  /// foreleg needs the reach, and rolls it a little with the shoulders.
  final String? chest;

  /// Kept steady against the bob of the body, as an animal's head is.
  final String? head;

  /// [reach]'s `bend` for each pair: -1 puts the middle joint behind -- a
  /// cat's hock and elbow.
  final double hindBend, foreBend;
}

/// An animal walking on four legs, with its feet planted.
///
/// The same idea as a [Walk]: footfalls are planned once from the [route],
/// spaced by distance so a planted foot stays where it landed however the
/// body speeds up or stops, and the legs are solved to reach them. The legs
/// go in the order animals walk in -- hind, fore on the same side, then the
/// other hind and fore -- each a quarter of a stride after the last, so
/// there are always two or three feet on the ground. When the route ends
/// each leg takes one last step to stand square under the body.
///
/// Around that: the hips and shoulders rise and fall twice a stride, the
/// head stays level while they do, and the shoulders roll with the
/// forelegs.
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
    this.stepHeight = 0.18,
    this.duty = 0.65,
    this.bob = 0.025,
  }) : assert(route.isNotEmpty, 'A gait needs at least one waypoint.'),
       assert(duty > 0.5 && duty < 1, 'A walk has more than half of each stride on the ground.'),
       _route = List<Waypoint>.unmodifiable(route) {
    _measureRig();
    this.stepLength = stepLength ?? _legLength * scale * 0.95;
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

  /// World pixels each foot moves at every step: one stride.
  late final double stepLength;

  /// How high a swinging foot lifts, as a fraction of the leg.
  final double stepHeight;

  /// The share of each stride a foot spends on the ground.
  final double duty;

  /// How far the body rises and falls, as a fraction of the leg.
  final double bob;

  final List<Waypoint> _route;
  late final int _dir;

  /// Every footfall, by leg: 0 hind near, 1 fore near, 2 hind far, 3 fore
  /// far -- the order they step in.
  late final List<Footstep> steps;

  late final double _legLength;
  late final List<Offset> _hips; // each leg's top joint, in the root's space
  late final List<double> _lengths;

  late final int _first;
  late final List<double> _u;

  List<Leg> get _legs => <Leg>[body.hindNear, body.foreNear, body.hindFar, body.foreFar];

  static bool _fore(int leg) => leg.isOdd;

  /// Where in the stride each leg lands.
  static const List<double> _phase = <double>[0, 0.25, 0.5, 0.75];

  void _measureRig() {
    _hips = <Offset>[];
    _lengths = <double>[];
    for (final Leg leg in _legs) {
      _hips.add(frameOf(rig, Pose.rest, leg.hip).origin - rig.at);
      final List<Part> path = pathTo(rig, leg.ankle)!;
      _lengths.add(path[path.length - 2].at.distance + path.last.at.distance);
    }
    _legLength = math.min(_lengths[0], _lengths[2]);
  }

  /// Where the body is along the route at [frame], in world x.
  double xAt(num frame) {
    final Waypoint first = _route.first;
    if (frame <= first.frame || _route.length == 1) return first.x;
    for (int i = 1; i < _route.length; i++) {
      final Waypoint to = _route[i];
      if (frame > to.frame) continue;
      final Waypoint from = _route[i - 1];
      final double t = to.curve.transform((frame - from.frame) / (to.frame - from.frame));
      return from.x + (to.x - from.x) * t;
    }
    return _route.last.x;
  }

  double _uAt(num frame) => (xAt(frame) - _route.first.x) * _dir;
  double _world(double u) => _route.first.x + u * _dir;
  double _speed(num frame) => (_uAt(frame + 1) - _uAt(frame - 1)) / 2;

  /// The pace a stride is drawn for: one a second.
  double get _pace => stepLength / fps;

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

  /// Where a leg's foot stands, relative to the body, when it is still.
  double _neutral(int leg) => _hips[leg].dx * scale;

  void _plan() {
    _first = _route.first.frame;
    _u = <double>[for (int f = _first; f <= _route.last.frame; f++) _uAt(f)];
    final double total = _u.last, l = stepLength;
    final double minSwing = 0.18 * fps, maxSwing = 0.45 * fps, minStance = 0.1 * fps;
    final List<double> at = <double>[for (int i = 0; i < 4; i++) _neutral(i)];
    final List<double> landed = List<double>.filled(4, double.negativeInfinity);
    final List<Footstep> out = <Footstep>[];

    void add(int leg, double to, double lift, double land) {
      lift = math.max(lift, landed[leg] + minStance);
      land = math.max(land, lift + minSwing);
      out.add(Footstep(leg, lift, land, _world(at[leg]), _world(to)));
      at[leg] = to;
      landed[leg] = land;
    }

    // Strides, every leg in its turn: a foot lands a little ahead of its
    // hip, and leaves when it is as far behind.
    final List<({int leg, double u})> landings = <({int leg, double u})>[];
    for (int k = 0; ; k++) {
      bool any = false;
      for (int leg = 0; leg < 4; leg++) {
        final double u = (k + _phase[leg] + 0.35) * l;
        if (u > total - 0.2 * l) continue;
        any = true;
        landings.add((leg: leg, u: u));
      }
      if (!any) break;
    }
    landings.sort((a, b) => a.u.compareTo(b.u));
    for (final ({int leg, double u}) s in landings) {
      final double land = _frameAt(s.u);
      final double swing = (_frameAt(s.u) - _frameAt(s.u - (1 - duty) * l)).clamp(minSwing, maxSwing);
      add(s.leg, s.u + _neutral(s.leg) + duty * l / 2, land - swing, land);
    }

    // Then each leg, in order, steps square under the body where it stops.
    double next = _frameAt(total) - 0.15 * fps;
    final int startLeg = landings.isEmpty ? 0 : (landings.last.leg + 1) % 4;
    for (int i = 0; i < 4; i++) {
      final int leg = (startLeg + i) % 4;
      final double to = total + _neutral(leg);
      if ((to - at[leg]).abs() < 0.05 * l) continue;
      final double swing = 0.3 * fps;
      double lift = math.max(next, landed[leg] + minStance);
      // Two paws stay down: wait while two others are still in the air.
      for (;;) {
        final List<Footstep> up = <Footstep>[
          for (final Footstep o in out)
            if (o.foot != leg && o.lift < lift + swing && o.land > lift) o,
        ];
        if (up.length < 2) break;
        lift = up.map((Footstep o) => o.land).reduce(math.min);
      }
      add(leg, to, lift, lift + swing);
      next = lift + 0.16 * fps;
    }
    out.sort((a, b) => a.lift.compareTo(b.lift));
    steps = List<Footstep>.unmodifiable(out);
  }

  // --- where each foot is ---

  /// The ankle's world position and the foot's angle, for [leg] at [frame].
  (Offset, double) _foot(int leg, double frame) {
    Footstep? previous, current;
    for (final Footstep s in steps) {
      if (s.foot != leg) continue;
      if (s.land <= frame) {
        previous = s;
      } else if (s.lift <= frame) {
        current = s;
        break;
      }
    }
    final double sole = _legs[leg].toe.dy * scale;
    if (current != null) {
      final double t = ((frame - current.lift) / (current.land - current.lift)).clamp(0.0, 1.0);
      final double size = ((current.to - current.from).abs() / stepLength).clamp(0.2, 1.0);
      final double along = Curves.easeInOutSine.transform(t);
      final double arc = math.sin(math.pi * math.pow(t, 0.75)) * stepHeight * _lengths[leg] * scale * size;
      final double x = current.from + (current.to - current.from) * along;
      // The paw hangs, toes down, as it is carried forward.
      return (Offset(x, groundY - sole - arc), 30 * size * math.sin(math.pi * t) * (_fore(leg) ? 1 : 0.6));
    }
    final double plant = previous?.to ?? _world(_neutral(leg));
    return (Offset(plant, groundY - sole), 0);
  }

  /// Where [leg] has its ankle at [frame], in the drawing's coordinates.
  Offset ankleAt(int leg, num frame) => _foot(leg, frame.toDouble()).$1;

  /// Whether [leg] is on the ground at [frame].
  bool plantedAt(int leg, num frame) => !steps.any((Footstep s) => s.foot == leg && s.lift <= frame && frame < s.land);

  // --- the body ---

  double _paceAt(num frame) => (_speed(frame) / _pace).clamp(0.0, 1.6);

  /// How far into its stride the body is, 0 to 1.
  double _cycle(double frame) => (_uAt(frame) / stepLength) % 1;

  /// How much higher a top joint sits than it needs to for [leg]'s foot,
  /// as the gait has it: the lowest it can be with that foot still reached.
  double _lowest(int leg, double frame, double x, double topY) {
    final Offset ankle = _foot(leg, frame).$1;
    final double hipX = x + _hips[leg].dx * scale * _dir;
    final double limit = _lengths[leg] * scale * 0.995;
    final double dx = (ankle.dx - hipX).abs();
    final double rise = dx >= limit ? 0 : math.sqrt(limit * limit - dx * dx);
    return ankle.dy - rise - topY;
  }

  double _rootY(double frame, double x) {
    final double pace = math.min(_paceAt(frame), 1);
    final double sole = body.hindNear.toe.dy;
    final double bend = 0.97 - 0.03 * pace;
    final double drop = bob * _legLength * scale * pace * (0.5 - 0.5 * math.cos(4 * math.pi * _cycle(frame)));
    double y = groundY - (sole + _legLength * bend) * scale - _hips[0].dy * scale + drop;
    for (final int leg in <int>[0, 2]) {
      y = _smoothMax(y, _lowest(leg, frame, x, _hips[leg].dy * scale), 0.025 * _legLength * scale);
    }
    return y;
  }

  static double _smoothMax(double a, double b, double k) {
    final double h = (0.5 + 0.5 * (b - a) / k).clamp(0.0, 1.0);
    return a * (1 - h) + b * h + k * h * (1 - h);
  }

  /// The gait at [frame]: the rig placed on the route, and its pose.
  ///
  /// [adjust] gets the body's pose before the legs are solved -- add a tail
  /// wave, breathing, a roar -- and the feet still land where they land.
  Posed at(int frame, {Pose Function(Pose pose)? adjust}) {
    final double f = frame.toDouble();
    final double x = xAt(f);
    final double y = _rootY(f, x);
    final Part placed = rig.placed(at: Offset(x, y), scaleX: scale * _dir, scaleY: scale);
    final double pace = math.min(_paceAt(f), 1);
    final Map<String, Joint> joints = <String, Joint>{};

    if (body.chest != null) {
      // The shoulders ride the forelegs: lowered when a planted foreleg
      // needs the reach, bobbing a beat after the hips, rolling a little
      // towards whichever foreleg is carrying them.
      double need = 0;
      for (final int leg in <int>[1, 3]) {
        need = math.max(need, _lowest(leg, f, x, y + _hips[leg].dy * scale));
      }
      final double drop = bob * _legLength * scale * pace * (0.5 - 0.5 * math.cos(4 * math.pi * (_cycle(f) - 0.12)));
      final double roll = 2.5 * pace * math.sin(2 * math.pi * (_cycle(f) - _phase[1]));
      joints[body.chest!] = Joint(degrees: roll, move: Offset(0, (math.max(need, 0) + drop) / scale));
      if (body.head != null) {
        // The head holds its line while the shoulders bob and roll.
        joints[body.head!] = Joint(degrees: -roll * 0.8, move: Offset(0, -drop * 0.6 / scale));
      }
    }

    Pose pose = Pose(joints);
    if (adjust != null) pose = adjust(pose);

    for (int leg = 0; leg < 4; leg++) {
      final Leg l = _legs[leg];
      final (Offset ankle, double angle) = _foot(leg, f);
      pose = reach(
        placed,
        pose,
        upper: l.hip,
        lower: l.knee,
        end: l.ankle,
        target: ankle,
        bend: _fore(leg) ? body.foreBend : body.hindBend,
        endDegrees: angle,
      );
    }
    return Posed(placed, pose);
  }
}
