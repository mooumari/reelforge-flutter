
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'support/walk_report.dart';

Part _leg(String s, double x) => Part(name: 'hip$s', at: Offset(x, 0), children: <Part>[
      Part(name: 'knee$s', at: const Offset(0, 60), children: <Part>[Part(name: 'foot$s', at: const Offset(0, 50))]),
    ]);

Part _arm(String s) => Part(name: 'shoulder$s', at: const Offset(0, -60), children: <Part>[Part(name: 'elbow$s', at: const Offset(0, 40))]);

final Part _walker = Part(name: 'body', children: <Part>[
  _leg('B', -6),
  _leg('F', 6),
  Part(name: 'chest', children: <Part>[_arm('B'), _arm('F'), Part(name: 'head', at: const Offset(0, -90))]),
]);

const Leg _front = Leg(hip: 'hipF', knee: 'kneeF', ankle: 'footF', toe: Offset(24, 10), heel: Offset(-8, 10));
const Leg _back = Leg(hip: 'hipB', knee: 'kneeB', ankle: 'footB', toe: Offset(24, 10), heel: Offset(-8, 10));

/// Walks [distance] pixels in [seconds], at [scale], optionally as a run.
(Walk, WalkReport) _go(double distance, double seconds, {double scale = 1.0, bool running = false, Curve curve = Curves.easeInOutSine}) {
  final Walk w = Walk(
    rig: _walker,
    route: <Waypoint>[Waypoint(0, 0), Waypoint((seconds * 30).round(), distance, curve: curve)],
    groundY: 500,
    fps: 30,
    scale: scale,
    body: const Biped(front: _front, back: _back),
    running: running,
  );
  final WalkReport r = reportOn(w, from: 0, to: (seconds * 30).round() + 20, hip: 'hipF', standingHipY: 500 - (10 + 110 * 0.985) * scale, legReach: 110, scale: scale);
  return (w, r);
}

void main() {
  pacedTests();
  test('a stroll plants its feet, keeps the hips steady and stops without ringing', () {
    final (_, WalkReport r) = _go(300, 2.4);
    expect(r.slide, lessThan(3));
    expect(r.overreach, lessThan(1));
    expect(r.hipJerk, lessThan(0.1));
    expect(r.stopJerk, lessThan(0.03));
    expect(r.flightFrames, 0);
  });

  test('a route too fast to walk is refused, not drawn with splayed legs', () {
    expect(() => _go(1000, 2.4), throwsA(isA<AssertionError>()));
    expect(() => _go(2400, 2.4, running: true), throwsA(isA<AssertionError>()));
  });

  test('a run leaves the ground between strides, and still lands on its feet', () {
    for (final (double, double) c in <(double, double)>[(1000, 3.0), (1500, 3.8)]) {
      final (_, WalkReport r) = _go(c.$1, c.$2, running: true);
      expect(r.overreach, lessThan(1), reason: '$c');
      expect(r.hipJerk, lessThan(0.25), reason: '$c');
      expect(r.stopJerk, lessThan(0.05), reason: '$c');
      expect(r.flightFrames, greaterThan(5), reason: '$c');
    }
  });

  test('a run starts from standing in a couple of short steps', () {
    final (Walk w, _) = _go(1500, 3.8, running: true);
    final List<Footstep> first = w.steps.take(4).toList();
    // Strides grow as the body speeds up.
    expect(first[1].to - first[1].from, greaterThan(first[0].to - first[0].from));
    expect(first[3].to - first[3].from, greaterThan(first[1].to - first[1].from));
  });
}

void pacedTests() {
  test('Walk.paced goes as fast as asked and no faster', () {
    for (final double pace in <double>[0.6, 1.0, 1.4]) {
      final Walk w = Walk.paced(
        rig: _walker,
        from: 0,
        to: 900,
        groundY: 500,
        fps: 30,
        pace: pace,
        body: const Biped(front: _front, back: _back),
      );
      expect(w.topPace, closeTo(pace, 0.03));
    }
    final Walk r = Walk.paced(rig: _walker, from: 0, to: 900, groundY: 500, fps: 30, pace: 1.2, running: true, body: const Biped(front: _front, back: _back));
    expect(r.topPace, closeTo(1.2, 0.03));
    expect(r.endFrame, greaterThan(20));
  });
}
