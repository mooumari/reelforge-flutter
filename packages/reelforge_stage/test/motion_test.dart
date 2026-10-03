import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

/// A minimal walker: pelvis, two legs of 60 + 50, flat feet, a chest with two
/// arms and a head with an antenna. Shapes are irrelevant here -- this is
/// about where joints go.
Part _leg(String s, double x) => Part(
      name: 'hip$s',
      at: Offset(x, 0),
      children: <Part>[
        Part(
          name: 'knee$s',
          at: const Offset(0, 60),
          children: <Part>[Part(name: 'foot$s', at: const Offset(0, 50))],
        ),
      ],
    );

Part _arm(String s) => Part(
      name: 'shoulder$s',
      at: const Offset(0, -60),
      children: <Part>[Part(name: 'elbow$s', at: const Offset(0, 40))],
    );

final Part _walker = Part(name: 'body', children: <Part>[
  _leg('B', -6),
  _leg('F', 6),
  Part(name: 'chest', children: <Part>[
    _arm('B'),
    _arm('F'),
    Part(name: 'head', at: const Offset(0, -90), children: <Part>[
      Part(name: 'antenna', at: const Offset(0, -30)),
    ]),
  ]),
]);

const Leg _front = Leg(hip: 'hipF', knee: 'kneeF', ankle: 'footF', toe: Offset(24, 10), heel: Offset(-8, 10));
const Leg _back = Leg(hip: 'hipB', knee: 'kneeB', ankle: 'footB', toe: Offset(24, 10), heel: Offset(-8, 10));
const Biped _biped = Biped(front: _front, back: _back);

Walk _walk({List<Waypoint>? route, double scale = 1.5}) => Walk(
      rig: _walker,
      route: route ??
          const <Waypoint>[
            Waypoint(5, 100),
            Waypoint(25, 220, curve: Curves.easeInSine),
            Waypoint(85, 820, curve: Curves.linear),
            Waypoint(110, 980, curve: Curves.easeOutSine),
          ],
      groundY: 500,
      fps: 30,
      scale: scale,
      body: _biped,
    );

Offset _ankle(Posed p, String foot) => frameOf(p.part, p.pose, foot).origin;

void main() {
  group('reach', () {
    test('puts the end of the limb on the target', () {
      final Part placed = _walker.placed(at: const Offset(300, 200), scale: 2);
      for (final Offset target in const <Offset>[
        Offset(330, 400),
        Offset(250, 380),
        Offset(310, 300),
      ]) {
        final Pose pose = reach(placed, Pose.rest,
            upper: 'hipF', lower: 'kneeF', end: 'footF', target: target);
        expect((frameOf(placed, pose, 'footF').origin - target).distance, lessThan(1e-6),
            reason: 'missed $target');
      }
    });

    test('works the same through a mirrored, turned parent', () {
      final Part placed = _walker.placed(at: const Offset(300, 200), scaleX: -1.5, scaleY: 1.5);
      const Pose leaning = Pose(<String, Joint>{'body': Joint(degrees: 12, move: Offset(4, -3))});
      const Offset target = Offset(270, 330); // within the 165px a leg reaches
      final Pose pose = reach(placed, leaning,
          upper: 'hipF', lower: 'kneeF', end: 'footF', target: target);
      expect((frameOf(placed, pose, 'footF').origin - target).distance, lessThan(1e-6));
    });

    test('bend picks which side the middle joint goes', () {
      final Part placed = _walker.placed(at: const Offset(0, 0));
      const Offset target = Offset(6, 90); // closer than full length: it must bend
      final double kneeA = frameOf(placed,
              reach(placed, Pose.rest, upper: 'hipF', lower: 'kneeF', end: 'footF', target: target),
              'kneeF')
          .origin
          .dx;
      final double kneeB = frameOf(placed,
              reach(placed, Pose.rest,
                  upper: 'hipF', lower: 'kneeF', end: 'footF', target: target, bend: -1),
              'kneeF')
          .origin
          .dx;
      expect(kneeA, greaterThan(6)); // forward, for a figure facing right
      expect(kneeB, lessThan(6));
    });

    test('out of reach, the limb straightens towards the target', () {
      final Part placed = _walker.placed(at: Offset.zero);
      final Pose pose = reach(placed, Pose.rest,
          upper: 'hipF', lower: 'kneeF', end: 'footF', target: const Offset(6, 1000));
      final Offset ankle = frameOf(placed, pose, 'footF').origin;
      // Clamped a hair short of dead straight, so it never folds the wrong way.
      expect(ankle.dy, closeTo(110, 1e-3));
      expect(ankle.dx, closeTo(6, 0.2));
    });

    test('endDegrees holds the foot at an angle however the leg bends', () {
      final Part placed = _walker.placed(at: Offset.zero);
      for (final Offset target in const <Offset>[Offset(30, 95), Offset(-20, 100)]) {
        final Pose pose = reach(placed, Pose.rest,
            upper: 'hipF', lower: 'kneeF', end: 'footF', target: target, endDegrees: 0);
        final Affine foot = frameOf(placed, pose, 'footF');
        expect(math.atan2(foot.b, foot.a), closeTo(0, 1e-9));
      }
    });
  });

  group('Walk', () {
    test('a planted foot does not slide, at any speed, starting or stopping', () {
      // Not sliding means the point the foot pivots on holds still. From the
      // moment the heel has come down until the foot leaves, that is the toe:
      // flat, the whole foot is still; peeling off, it turns about the toe.
      final Walk walk = _walk();
      for (final int foot in <int>[0, 1]) {
        final String name = foot == 0 ? 'footF' : 'footB';
        final Leg leg = foot == 0 ? _front : _back;
        int checked = 0;
        for (final Footstep step in walk.steps.where((Footstep s) => s.foot == foot)) {
          final List<Offset> toe = <Offset>[];
          for (int f = (step.land + 0.12 * 30).ceil(); walk.plantedAt(foot, f) && f < 400; f++) {
            final Posed p = walk.at(f);
            toe.add(frameOf(p.part, p.pose, name).apply(leg.toe));
          }
          for (final Offset t in toe) {
            expect((t - toe.first).distance, lessThan(0.01),
                reason: 'foot $foot slid after landing at ${step.land}');
          }
          checked += toe.length;
        }
        expect(checked, greaterThan(20), reason: 'the test looked at too little');
      }
    });

    test('the legs reach every target, every frame', () {
      // If a target is ever out of reach the leg straightens short of it and
      // the foot floats off the ground. The hips are meant to drop instead.
      final Walk walk = _walk();
      for (int f = 0; f <= 140; f++) {
        final Posed p = walk.at(f);
        expect((_ankle(p, 'footF') - walk.ankleAt(0, f)).distance, lessThan(0.01), reason: 'front, frame $f');
        expect((_ankle(p, 'footB') - walk.ankleAt(1, f)).distance, lessThan(0.01), reason: 'back, frame $f');
      }
    });

    test('feet stand under the body before it starts and after it stops', () {
      final Walk walk = _walk();
      for (final int f in <int>[0, 200]) {
        final double x = walk.xAt(f);
        expect(walk.plantedAt(0, f) && walk.plantedAt(1, f), isTrue);
        expect((walk.ankleAt(0, f).dx - x).abs(), lessThan(20), reason: 'frame $f');
        expect((walk.ankleAt(1, f).dx - x).abs(), lessThan(20), reason: 'frame $f');
      }
    });

    test('never both feet off the ground', () {
      final Walk walk = _walk();
      for (double f = 0; f < 140; f += 0.25) {
        expect(walk.plantedAt(0, f) || walk.plantedAt(1, f), isTrue, reason: 'frame $f');
      }
    });

    test('feet alternate and only move forward', () {
      final Walk walk = _walk();
      expect(walk.steps.length, greaterThan(6));
      for (int i = 1; i < walk.steps.length - 2; i++) {
        expect(walk.steps[i].foot, isNot(walk.steps[i - 1].foot));
      }
      for (final Footstep s in walk.steps) {
        expect(s.to, greaterThanOrEqualTo(s.from - 1));
      }
    });

    test('walking left mirrors the character and still plants its feet', () {
      final Walk walk = _walk(route: const <Waypoint>[
        Waypoint(0, 900),
        Waypoint(60, 400),
      ]);
      expect(walk.at(30).part.scaleX, lessThan(0));
      for (int f = 0; f <= 90; f++) {
        expect((_ankle(walk.at(f), 'footF') - walk.ankleAt(0, f)).distance, lessThan(0.01));
      }
      for (final Footstep s in walk.steps) {
        expect(s.to, lessThanOrEqualTo(s.from + 1));
      }
    });

    test('the same route plans the same steps', () {
      final List<Footstep> a = _walk().steps;
      final List<Footstep> b = _walk().steps;
      expect(a.length, b.length);
      for (int i = 0; i < a.length; i++) {
        expect(<double>[a[i].lift, a[i].land, a[i].from, a[i].to],
            <double>[b[i].lift, b[i].land, b[i].from, b[i].to]);
      }
    });
  });

  group('followThrough', () {
    Posed turning(int f) => Posed(
          _walker.placed(at: const Offset(200, 200)),
          Pose(<String, Joint>{'head': Joint.rotate(f < 20 ? 0 : 30)}),
        );
    const List<Jiggle> antenna = <Jiggle>[Jiggle('antenna', bone: Offset(0, -30))];

    test('a carried part lags a sudden turn, then settles', () {
      final double during = followThrough(turning, 21, jiggles: antenna, fps: 30).pose['antenna'].degrees;
      final double after = followThrough(turning, 90, jiggles: antenna, fps: 30).pose['antenna'].degrees;
      expect(during, lessThan(-5)); // left behind, the opposite way to the turn
      expect(after.abs(), lessThan(0.5)); // long since settled
    });

    test('is a function of the frame: same answer however it is reached', () {
      final double a = followThrough(turning, 27, jiggles: antenna, fps: 30).pose['antenna'].degrees;
      followThrough(turning, 80, jiggles: antenna, fps: 30);
      final double b = followThrough(turning, 27, jiggles: antenna, fps: 30).pose['antenna'].degrees;
      expect(a, b);
    });

    test('nothing moving, nothing swinging', () {
      Posed still(int f) => Posed(_walker, Pose.rest);
      expect(followThrough(still, 50, jiggles: antenna, fps: 30).pose['antenna'].degrees, 0);
    });
  });

  group('Gesture', () {
    const Pose to = Pose(<String, Joint>{'arm': Joint.rotate(100), 'hand': Joint.rotate(50)});
    const Gesture g = Gesture(to: to, anticipation: 5, action: 8, settle: 10, windUp: 0.2, overshoot: 0.1);

    test('winds up the wrong way, overshoots, and settles on the pose', () {
      expect(g.at(0)['arm'].degrees, 0);
      expect(g.at(5)['arm'].degrees, closeTo(-20, 1e-9));
      expect(g.at(13)['arm'].degrees, closeTo(110, 1e-9));
      expect(g.at(23)['arm'].degrees, closeTo(100, 1e-9));
      expect(g.at(99)['arm'].degrees, 100);
    });

    test('lag holds a joint back by its frames', () {
      const Gesture lagged = Gesture(
          to: to, anticipation: 5, action: 8, settle: 10, windUp: 0.2, overshoot: 0.1,
          lag: <String, int>{'hand': 3});
      expect(lagged.at(16)['hand'].degrees, g.at(13)['hand'].degrees);
      expect(lagged.length, g.length + 3);
    });
  });

  group('Life', () {
    const Life life = Life(seed: 3, head: 'head', chest: 'chest', eyes: <String>['eye']);

    test('the same frame is the same pose', () {
      expect(life.at(417, 30), life.at(417, 30));
    });

    test('blinks: the eyes close at some point, and are open most of the time', () {
      int shut = 0, open = 0;
      for (int f = 0; f < 30 * 30; f++) {
        final double y = life.at(f, 30)['eye'].scaleY;
        if (y < 0.2) shut++;
        if (y > 0.99) open++;
      }
      expect(shut, greaterThan(5));
      expect(open, greaterThan(30 * 30 * 0.8));
    });

    test('two seeds are two different people', () {
      bool differ = false;
      for (int f = 0; f < 300 && !differ; f += 10) {
        differ = const Life(seed: 1, head: 'head').at(f, 30) != const Life(seed: 2, head: 'head').at(f, 30);
      }
      expect(differ, isTrue);
    });

    test('noise is smooth and bounded', () {
      for (double t = 0; t < 50; t += 0.01) {
        final double a = noise(9, t), b = noise(9, t + 0.01);
        expect(a.abs(), lessThanOrEqualTo(1));
        expect((a - b).abs(), lessThan(0.05));
      }
    });
  });

  test('Joint.squash keeps the area', () {
    const Joint j = Joint.squash(1.25);
    expect(j.scaleX * j.scaleY, closeTo(1, 1e-12));
  });
}
