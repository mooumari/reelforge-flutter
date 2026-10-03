import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:reelforge/reelforge.dart' show ExactCurve;

import 'follow.dart';
import 'kinematics.dart';
import 'part.dart';
import 'pose.dart';

/// Where the body should be, along the ground, at [frame].
///
/// [curve] shapes the stretch arriving here, as for every other keyframe in
/// this package: ease in and out of a walk, and the legs ease with it.
@immutable
class Waypoint {
  const Waypoint(this.frame, this.x, {this.curve = Curves.easeInOutSine});

  final int frame;
  final double x;
  final Curve curve;
}

/// One leg, by joint name, and the shape of its foot.
@immutable
class Leg {
  const Leg({
    required this.hip,
    required this.knee,
    required this.ankle,
    this.toe = const Offset(40, 22),
    this.heel = const Offset(-14, 22),
  });

  final String hip;
  final String knee;

  /// The foot's own joint. Its origin is the ankle.
  final String ankle;

  /// The ball of the foot and the back of the heel, in the foot part's own
  /// coordinates. A foot rolls about the heel as it lands and about the toe as
  /// it leaves, and their height below the ankle is how far the ankle is off
  /// the ground when the foot is flat.
  final Offset toe;
  final Offset heel;
}

/// The joints a [Walk] drives on a two-legged rig.
///
/// The rig's root part is the pelvis: the walk places it, and both hips hang
/// from it. Upper-body joints are optional -- leave one null and the walk
/// leaves it alone.
@immutable
class Biped {
  const Biped({
    this.front = const Leg(hip: 'hipF', knee: 'kneeF', ankle: 'footF'),
    this.back = const Leg(hip: 'hipB', knee: 'kneeB', ankle: 'footB'),
    this.chest = 'chest',
    this.head = 'head',
    this.frontArm = ('shoulderF', 'elbowF'),
    this.backArm = ('shoulderB', 'elbowB'),
  });

  final Leg front;
  final Leg back;
  final String? chest;
  final String? head;
  final (String, String)? frontArm;
  final (String, String)? backArm;
}

/// One footfall: a foot leaving the ground and where it lands.
@immutable
class Footstep {
  const Footstep(this.foot, this.lift, this.land, this.from, this.to);

  /// 0 the front leg, 1 the back.
  final int foot;

  /// Frames, fractional: steps are placed by distance, and distance does not
  /// fall on whole frames.
  final double lift;
  final double land;

  /// Where the ankle is when the foot is flat, in world x.
  final double from;
  final double to;
}

/// A character walking along the ground, with its feet planted.
///
/// The walk is planned once, as a list of [steps], from the [route] the body
/// takes. Footfalls are spaced by *distance*, not by time, so however the body
/// speeds up, slows or stops, a foot on the ground stays exactly where it
/// landed: the legs are solved to reach it ([reach]), rather than swung
/// through angles and hoped to match the ground. A swing takes a time that
/// follows the pace, so a slow walk has slow steps instead of feet that hang
/// in the air.
///
/// Around that: the heel strikes and the toe pushes off; the hips drop when
/// both feet are down, because that is as high as two planted legs can hold
/// them; the chest leans into the pace and lags the hips; arms swing against
/// the legs. Starting and stopping are steps like any other -- the first one
/// is short, and the last two bring the feet together under the body.
///
/// Everything is a pure function of the frame. The plan is arithmetic on the
/// route, done in the constructor, and the same route plans the same steps in
/// every process.
class Walk {
  Walk({
    required this.rig,
    required List<Waypoint> route,
    required this.groundY,
    required this.fps,
    this.scale = 1,
    this.body = const Biped(),
    double? stepLength,
    double? stepHeight,
    double? armSwing,
    double? lean,
    this.running = false,
  })  : stepHeight = stepHeight ?? (running ? 0.34 : 0.16),
        armSwing = armSwing ?? (running ? 42 : 24),
        lean = lean ?? (running ? 13 : 5),
        assert(route.isNotEmpty, 'A walk needs at least one waypoint.'),
        _route = List<Waypoint>.unmodifiable(route) {
    _measureRig();
    this.stepLength = stepLength ?? _legLength * scale * (running ? 1.5 : 0.68);
    _dir = route.last.x >= route.first.x ? 1 : -1;
    assert(() {
      for (int i = 1; i < route.length; i++) {
        if ((route[i].x - route[i - 1].x) * _dir < 0) return false;
        if (route[i].frame <= route[i - 1].frame) return false;
      }
      return true;
    }(), 'A walk goes one way: waypoints must not turn back, and their frames must increase.');
    _plan();
    assert(
      topPace < (running ? 2.0 : 1.6),
      'This route reaches ${topPace.toStringAsFixed(2)}x the pace a walk is drawn for: the legs cannot keep up. Slow it down, or set running: true.',
    );
  }

  /// A walk from [from] to [to] starting at frame [start], as long as it takes
  /// to go at [pace]: 1 is the pace a walk is drawn for (a step every 0.45s;
  /// every 0.3s running), and the route's own fastest moment, with its easing,
  /// is what is held to it. So a character is never asked to go faster than
  /// its legs can show: pass a pace, get the duration.
  factory Walk.paced({
    required Part rig,
    required double from,
    required double to,
    required double groundY,
    required int fps,
    int start = 0,
    double pace = 1.0,
    bool running = false,
    double scale = 1,
    Biped body = const Biped(),
    Curve curve = Curves.easeInOutSine,
    double? stepLength,
  }) {
    Walk trial(int frames) => Walk(
          rig: rig,
          route: <Waypoint>[Waypoint(start, from), Waypoint(start + frames, to, curve: curve)],
          groundY: groundY,
          fps: fps,
          scale: scale,
          body: body,
          running: running,
          stepLength: stepLength,
        );
    // Pace is inversely proportional to duration, so one slow trial says how
    // long the real thing takes.
    const int probe = 3000;
    final double probed = trial(probe).topPace;
    final int frames = math.max(12, (probe * probed / pace).ceil());
    return trial(frames);
  }

  /// The frame the body stops on.
  int get endFrame => _route.last.frame;

  /// The character, unplaced. Its root is the pelvis.
  final Part rig;

  final double groundY;
  final int fps;
  final double scale;
  final Biped body;

  /// World pixels from one footfall to the next.
  late final double stepLength;

  /// How high a swinging foot lifts, as a fraction of the leg.
  final double stepHeight;

  /// Degrees an arm swings either way at a full pace.
  final double armSwing;

  /// Degrees the chest leans forward at a full pace.
  final double lean;

  /// A run: longer, quicker strides, a moment in the air between them, the
  /// arms bent and pumping, the body leaning in. A walk planned for a speed
  /// that is really a run is what makes legs splay and hips sink.
  final bool running;

  final List<Waypoint> _route;
  late final int _dir;
  late final List<Footstep> steps;

  // Measured off the rig, in its own units.
  late final double _legLength;
  late final List<Offset> _hips; // hip joints in the root's space
  late final List<double> _thigh;

  // The route sampled at whole frames, as distance travelled.
  late final int _first;
  late final List<double> _u;

  List<Leg> get _legs => <Leg>[body.front, body.back];

  void _measureRig() {
    _hips = <Offset>[];
    _thigh = <double>[];
    double length = double.infinity;
    for (final Leg leg in _legs) {
      _hips.add(frameOf(rig, Pose.rest, leg.hip).origin - rig.at);
      final List<Part> path = pathTo(rig, leg.ankle)!;
      final double l1 = path[path.length - 2].at.distance;
      final double l2 = path.last.at.distance;
      _thigh.add(l1);
      length = math.min(length, l1 + l2);
    }
    _legLength = length;
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

  /// Distance per frame at [frame].
  double _speed(num frame) => (_uAt(frame + 1) - _uAt(frame - 1)) / 2;

  /// The pace a stride is drawn for: a step every 0.45s walking, every 0.3s
  /// running.
  double get _pace => stepLength / ((running ? 0.3 : 0.45) * fps);

  /// The fastest the route goes, as a multiple of [_pace]: 1 is a walk drawn
  /// at its own stride, 1.7 and over is not a walk any more.
  double get topPace {
    double top = 0;
    for (int f = _first; f <= _route.last.frame; f++) {
      top = math.max(top, _speed(f) / _pace);
    }
    return top;
  }

  /// How far along the route the body is at [frame], fractional.
  double _uInterp(double frame) {
    final double i = (frame - _first).clamp(0.0, (_u.length - 1).toDouble());
    final int lo = i.floor();
    final int hi = math.min(lo + 1, _u.length - 1);
    return _u[lo] + (_u[hi] - _u[lo]) * (i - lo);
  }

  double _standOffset(int foot) =>
      (_hips[foot].dx * scale) + (foot == 0 ? 1 : -1) * 0.04 * _legLength * scale;

  void _plan() {
    _first = _route.first.frame;
    final int lastFrame = _route.last.frame;
    _u = <double>[for (int f = _first; f <= lastFrame; f++) _uAt(f)];
    final double total = _u.last;
    final double length = stepLength;
    // Footfalls come on a beat, one foot then the other, and a step is as long
    // as the body travels in one beat: short while setting off and coming to
    // a stop, long at speed. Placing them by distance instead -- one fixed
    // stride -- is what makes a walk that eases in and out shuffle, rush and
    // lurch.
    final double period = (running ? 0.30 : 0.45) * fps;
    final double swingTime = period * (running ? 1.3 : 0.8);
    final double minStance = (running ? 0.05 : 0.08) * fps;

    final List<double> at = <double>[_standOffset(0), _standOffset(1)];
    final List<double> landed = <double>[double.negativeInfinity, double.negativeInfinity];
    final List<Footstep> out = <Footstep>[];

    // [swing] is how long the foot is in the air, in frames. Planned steps
    // give [share] and [beat] instead: a share of a foot's whole cycle (the
    // time since it last landed), so that when the beat quickens the foot is
    // not left planted for the old, longer one.
    void add(int foot, double to, double land, {double? swing, double share = 0, double beat = 0}) {
      swing ??= landed[foot].isFinite ? (land - landed[foot]) * share / 2 : beat * share;
      double lift = land - swing;
      if (!running) lift = math.max(lift, landed[1 - foot]);
      lift = math.max(lift, landed[foot] + minStance);
      land = math.max(land, lift + 0.1 * fps);
      out.add(Footstep(foot, lift, land, _world(at[foot]), _world(to)));
      at[foot] = to;
      landed[foot] = land;
    }

    // Nothing steps until the body moves.
    double start = _first.toDouble();
    while (start < lastFrame && _speed(start) < 0.03 * _pace) {
      start++;
    }
    // However fast the body goes, a leg only spans so much: past that the
    // steps come quicker instead of longer.
    final double maxStride = length * (running ? 1.1 : 1.3);
    double land = start + swingTime;
    double lastLand = start;
    int foot = 1; // the back foot moves first
    while (land < lastFrame) {
      final double v = _speed(land);
      final double beat = v * period > maxStride ? math.max(0.6 * period, maxStride / v) : period;
      final double stride = (_uInterp(land + beat / 2) - _uInterp(land - beat / 2)).clamp(0.0, maxStride);
      // A foot is planted for 1.2 strides of body travel walking, 0.7 running:
      // it lands half of that ahead, and leaves half of it behind.
      // A foot never lands past where it will stand when the body stops.
      final double to = math.min(_uInterp(land) + (running ? 0.35 : 0.6) * stride, total + _standOffset(foot));
      if (_uInterp(land) > total - 0.3 * length) break;
      if ((to - at[foot]).abs() > 0.06 * length) {
        add(foot, to, land, share: running ? 1.3 : 0.8, beat: beat);
        lastLand = land;
      }
      foot = 1 - foot;
      land += beat;
    }
    // Two last steps, bringing each foot under the body where it stops.
    double settle = math.max(lastLand + 0.5 * period, math.min(land, lastFrame.toDouble()));
    for (int i = 0; i < 2; i++) {
      final double to = total + _standOffset(foot);
      if ((to - at[foot]).abs() > 0.03 * length) {
        add(foot, to, settle, swing: 0.36 * fps);
        settle += 0.42 * period;
      }
      foot = 1 - foot;
    }
    steps = List<Footstep>.unmodifiable(out);
    // The moments neither foot is down, in a run: the body is thrown between
    // them, up and over.
    final List<(double, double)> air = <(double, double)>[];
    for (int i = 0; i < out.length; i++) {
      for (int j = i + 1; j < out.length && j <= i + 2; j++) {
        if (out[j].foot == out[i].foot) continue;
        final double a = math.max(out[i].lift, out[j].lift), b = math.min(out[i].land, out[j].land);
        if (b - a > 0.5) air.add((a, b));
      }
    }
    _air = air;
  }

  late final List<(double, double)> _air;

  // --- where each foot is ---

  /// The ankle's world position and the foot's angle, for [foot] at [frame].
  (Offset, double) _foot(int foot, double frame) {
    final Leg leg = _legs[foot];
    Footstep? previous, current, next;
    for (final Footstep s in steps) {
      if (s.foot != foot) continue;
      if (s.land <= frame) {
        previous = s;
      } else if (s.lift <= frame) {
        current = s;
      } else {
        next ??= s;
      }
    }

    if (current != null) {
      final double t = ((frame - current.lift) / (current.land - current.lift)).clamp(0.0, 1.0);
      final double size = _size(current);
      final (Offset liftAt, double liftAngle) = _pivot(leg, current.from, _toeOff * size, toe: true);
      final (Offset landAt, double landAngle) = _pivot(leg, current.to, -_heelStrike * size, toe: false);
      final double along = Curves.easeInOutSine.exact(t);
      // Up quickly, down a little slower: the peak comes early in the swing.
      final double arc = math.sin(math.pi * math.pow(t, 0.8)) * stepHeight * _legLength * scale * size;
      final Offset ankle = Offset.lerp(liftAt, landAt, along)! - Offset(0, arc);
      final double angle = liftAngle + (landAngle - liftAngle) * Curves.easeInOut.exact(t);
      return (ankle, angle);
    }

    final double plant = previous?.to ?? _world(_standOffset(foot));
    double angle = 0;
    bool aboutToe = false;
    if (previous != null) {
      // Heel strike: the foot slaps down flat over a few frames.
      final double strike = 0.12 * fps;
      final double since = frame - previous.land;
      if (since < strike) {
        angle = -_heelStrike * _size(previous) * (1 - Curves.easeOut.exact(since / strike));
      }
    }
    if (next != null) {
      // Toe-off: the heel peels up before the foot leaves.
      final double roll = math.min(0.22 * fps, (next.lift - (previous?.land ?? next.lift - 0.22 * fps)) * 0.45);
      final double until = next.lift - frame;
      if (until < roll && roll > 0) {
        angle = _toeOff * _size(next) * Curves.easeIn.exact(1 - until / roll);
        aboutToe = true;
      }
    }
    return _pivot(leg, plant, angle, toe: aboutToe);
  }

  static const double _toeOff = 28;
  static const double _heelStrike = 14;

  /// A big step rolls the foot fully; a shuffle barely does.
  double _size(Footstep s) => ((s.to - s.from).abs() / (2 * stepLength)).clamp(0.15, 1.0);

  /// The ankle of a foot planted with its flat-ankle at [plant], turned by
  /// [angle] about its toe (or heel) -- which stays on the ground.
  (Offset, double) _pivot(Leg leg, double plant, double angle, {required bool toe}) {
    final Offset local = toe ? leg.toe : leg.heel;
    final Offset flatAnkle = Offset(plant, groundY - leg.toe.dy * scale);
    final Offset contact = flatAnkle + _toWorld(local);
    final double r = angle * math.pi / 180;
    final Offset turned = Offset(
      local.dx * math.cos(r) - local.dy * math.sin(r),
      local.dx * math.sin(r) + local.dy * math.cos(r),
    );
    return (contact - _toWorld(turned), angle);
  }

  Offset _toWorld(Offset local) => Offset(local.dx * scale * _dir, local.dy * scale);

  /// Where [foot] (0 front, 1 back) has its ankle at [frame], in the drawing's
  /// coordinates. What the legs are solved to reach.
  Offset ankleAt(int foot, num frame) => _foot(foot, frame.toDouble()).$1;

  /// Whether [foot] is on the ground at [frame].
  bool plantedAt(int foot, num frame) =>
      !steps.any((Footstep s) => s.foot == foot && s.lift <= frame && frame < s.land);

  // --- the body ---

  /// 0 standing, 1 at the pace the stride is drawn for.
  double _paceAt(num frame) => (_speed(frame) / _pace).clamp(0.0, 1.6);

  /// The hips' height, smoothed over three frames so that a foot landing is a
  /// settling and not a knock.
  double _rootY(double frame) =>
      math.max((_rawRootY(frame - 1) + 2 * _rawRootY(frame) + _rawRootY(frame + 1)) / 4, _floor(frame));

  /// The lowest the hips may be -- as a y, so the largest -- with every foot
  /// that holds them up still within reach of its hip.
  double _floor(double frame) {
    final double x = xAt(frame);
    final double reachLimit = _legLength * scale * 0.997;
    double floor = double.negativeInfinity;
    for (int i = 0; i < 2; i++) {
      // Walking, both feet hold the hips up. Running, only a foot on the
      // ground does; a swinging one is reached for, not stood on.
      if (running && !plantedAt(i, frame)) continue;
      final Offset ankle = _foot(i, frame).$1;
      final double hipX = x + _hips[i].dx * scale * _dir;
      final double dx = (ankle.dx - hipX).abs();
      final double rise = dx >= reachLimit ? 0 : math.sqrt(reachLimit * reachLimit - dx * dx);
      floor = math.max(floor, ankle.dy - rise - _hips[i].dy * scale);
    }
    return floor;
  }

  double _rawRootY(double frame) {
    final double pace = math.min(_paceAt(frame), 1);
    final double sole = body.front.toe.dy;
    // A standing leg is not quite straight; a walking one is a little more
    // bent, which is what leaves room for the hips to rise and fall.
    final double bend = 0.985 - (running ? 0.09 : 0.035) * pace;
    double y = groundY - (sole + _legLength * bend) * scale - _hips[0].dy * scale;
    final double floor = _floor(frame);
    if (floor.isFinite) y = _smoothMax(y, floor, 0.025 * _legLength * scale);
    if (running) {
      for (final (double a, double b) in _air) {
        if (frame > a && frame < b) y -= 0.1 * _legLength * scale * math.sin(math.pi * (frame - a) / (b - a));
      }
    }
    return y;
  }

  static double _smoothMax(double a, double b, double k) {
    final double h = (0.5 + 0.5 * (b - a) / k).clamp(0.0, 1.0);
    return a * (1 - h) + b * h + k * h * (1 - h);
  }

  /// The walk at [frame]: the rig placed on the route, and its pose.
  ///
  /// [adjust] gets the walk's upper-body pose before the legs are solved, so
  /// whatever it changes -- a wave, breathing, a bigger lean -- the feet still
  /// land where they land. Change the hips in it and the legs follow.
  Posed at(int frame, {Pose Function(Pose pose)? adjust}) {
    final double f = frame.toDouble();
    final double x = xAt(f);
    final double y = _rootY(f);
    final Part placed = rig.placed(
      at: Offset(x, y),
      scaleX: scale * _dir,
      scaleY: scale,
    );

    final double pace = _paceAt(f);
    final Map<String, Joint> joints = <String, Joint>{};

    if (body.chest != null) {
      // Lean into the pace, and further into speeding up; rock back when
      // slowing. The chest also trails the hips' rise and fall by a couple of
      // frames, which is what stops the upper body moving as one block.
      final double accel = ((_speed(f + 3) - _speed(f - 3)) / 6) / _pace * 0.3 * fps;
      final double tilt = lean * math.min(pace, 1.2) + 6 * accel.clamp(-1.0, 1.0);
      final double trail = (_rootY(f - 2) - y) / scale * 0.45;
      joints[body.chest!] = Joint(degrees: tilt, move: Offset(0, trail));
      if (body.head != null) {
        joints[body.head!] = Joint.rotate(-0.55 * tilt);
      }
    }

    for (int i = 0; i < 2; i++) {
      final (String, String)? arm = i == 0 ? body.frontArm : body.backArm;
      if (arm == null) continue;
      // Each arm against its own side's leg, a beat late.
      final double late = f - 0.07 * fps;
      final double ahead = ((ankleAt(i, late).dx - xAt(late)) * _dir / stepLength).clamp(-1.2, 1.2);
      final double swing = armSwing * math.min(_paceAt(late), 1.2) * ahead;
      joints[arm.$1] = Joint.rotate(swing);
      joints[arm.$2] = Joint.rotate(running ? -78 - 14 * ahead : -6 - 16 * math.min(_paceAt(late), 1) * math.max(0, -ahead));
    }

    Pose pose = Pose(joints);
    if (adjust != null) pose = adjust(pose);

    for (int i = 0; i < 2; i++) {
      final Leg leg = _legs[i];
      final (Offset footAt, double angle) = _foot(i, f);
      Offset ankle = footAt;
      if (running && !plantedAt(i, f)) {
        // A swinging foot that the leg cannot reach is brought in to where it
        // can, rather than stretching the leg after it.
        final Offset hip = frameOf(placed, pose, leg.hip).origin;
        final double limit = _legLength * scale * 0.9995;
        final Offset d = ankle - hip;
        if (d.distance > limit) ankle = hip + d / d.distance * limit;
      }
      pose = reach(
        placed,
        pose,
        upper: leg.hip,
        lower: leg.knee,
        end: leg.ankle,
        target: ankle,
        endDegrees: angle,
      );
    }
    return Posed(placed, pose);
  }
}
