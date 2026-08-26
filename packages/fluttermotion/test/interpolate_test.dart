import 'package:flutter/animation.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('interpolate', () {
    test('maps linearly across a single segment', () {
      expect(interpolate(0, <int>[0, 10], <int>[0, 100]), 0);
      expect(interpolate(5, <int>[0, 10], <int>[0, 100]), 50);
      expect(interpolate(10, <int>[0, 10], <int>[0, 100]), 100);
    });

    test('clamps outside the range by default', () {
      expect(interpolate(-5, <int>[0, 10], <int>[0, 100]), 0);
      expect(interpolate(99, <int>[0, 10], <int>[0, 100]), 100);
    });

    test('extends along the adjacent segment when asked', () {
      expect(
        interpolate(
          20,
          <int>[0, 10],
          <int>[0, 100],
          extrapolateRight: Extrapolate.extend,
        ),
        200,
      );
      expect(
        interpolate(
          -10,
          <int>[0, 10],
          <int>[0, 100],
          extrapolateLeft: Extrapolate.extend,
        ),
        -100,
      );
    });

    test('passes the input through under identity extrapolation', () {
      expect(
        interpolate(
          42,
          <int>[0, 10],
          <int>[0, 100],
          extrapolateRight: Extrapolate.identity,
        ),
        42,
      );
    });

    test('handles multi-point ranges', () {
      const List<int> input = <int>[0, 10, 20];
      const List<int> output = <int>[0, 100, 0];
      expect(interpolate(5, input, output), 50);
      expect(interpolate(10, input, output), 100);
      expect(interpolate(15, input, output), 50);
    });

    test('applies easing within a segment', () {
      final double eased =
          interpolate(5, <int>[0, 10], <int>[0, 100], easing: Curves.easeIn);
      expect(eased, lessThan(50));
      // Endpoints are unaffected by easing.
      expect(interpolate(0, <int>[0, 10], <int>[0, 100],
          easing: Curves.easeIn), 0);
      expect(interpolate(10, <int>[0, 10], <int>[0, 100],
          easing: Curves.easeIn), 100);
    });

    test('rejects a non-increasing input range', () {
      expect(
        () => interpolate(1, <int>[0, 10, 5], <int>[0, 1, 2]),
        throwsAssertionError,
      );
    });

    test('rejects mismatched range lengths', () {
      expect(
        () => interpolate(1, <int>[0, 10], <int>[0, 1, 2]),
        throwsAssertionError,
      );
    });
  });

  group('spring', () {
    test('starts at rest and settles at the target', () {
      expect(spring(0), 0);
      expect(spring(600), closeTo(1, 1e-6));
    });

    test('is a pure function of the frame', () {
      expect(spring(17), spring(17));
    });

    test('respects from and to', () {
      expect(spring(0, from: 10, to: 20), 10);
      expect(spring(600, from: 10, to: 20), closeTo(20, 1e-6));
    });
  });
}
