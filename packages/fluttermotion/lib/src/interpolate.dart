import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// What to do outside the input range.
enum Extrapolate {
  /// Hold the nearest output value. The default, and almost always what you
  /// want in a video.
  clamp,

  /// Keep going along the last segment's slope.
  extend,

  /// Pass the input through unchanged.
  identity,
}

/// Maps [input] from [inputRange] onto [outputRange].
///
/// ```dart
/// final opacity = interpolate(Video.frame(context), [0, 20], [0, 1]);
/// ```
///
/// [inputRange] must be strictly increasing and the same length as
/// [outputRange]. [easing] is applied within each segment, so a multi-point
/// range eases between each pair rather than across the whole span.
double interpolate(
  num input,
  List<num> inputRange,
  List<num> outputRange, {
  Curve easing = Curves.linear,
  Extrapolate extrapolateLeft = Extrapolate.clamp,
  Extrapolate extrapolateRight = Extrapolate.clamp,
}) {
  assert(
    inputRange.length == outputRange.length,
    'inputRange (${inputRange.length}) and outputRange '
    '(${outputRange.length}) must be the same length.',
  );
  assert(inputRange.length >= 2, 'Ranges need at least two points.');
  assert(() {
    for (int i = 0; i < inputRange.length - 1; i++) {
      if (inputRange[i + 1] <= inputRange[i]) return false;
    }
    return true;
  }(), 'inputRange must be strictly increasing, got $inputRange.');

  final double x = input.toDouble();

  if (x < inputRange.first) {
    switch (extrapolateLeft) {
      case Extrapolate.clamp:
        return outputRange.first.toDouble();
      case Extrapolate.identity:
        return x;
      case Extrapolate.extend:
        return _segment(x, inputRange, outputRange, 0, easing);
    }
  }
  if (x > inputRange.last) {
    switch (extrapolateRight) {
      case Extrapolate.clamp:
        return outputRange.last.toDouble();
      case Extrapolate.identity:
        return x;
      case Extrapolate.extend:
        return _segment(
            x, inputRange, outputRange, inputRange.length - 2, easing);
    }
  }

  for (int i = 0; i < inputRange.length - 1; i++) {
    if (x >= inputRange[i] && x <= inputRange[i + 1]) {
      return _segment(x, inputRange, outputRange, i, easing);
    }
  }
  return outputRange.last.toDouble();
}

double _segment(
  double x,
  List<num> inputRange,
  List<num> outputRange,
  int i,
  Curve easing,
) {
  final double x0 = inputRange[i].toDouble();
  final double x1 = inputRange[i + 1].toDouble();
  final double y0 = outputRange[i].toDouble();
  final double y1 = outputRange[i + 1].toDouble();
  final double t = (x - x0) / (x1 - x0);
  // Curves are only defined on [0, 1]; extrapolation stays linear.
  final double eased = (t >= 0 && t <= 1) ? easing.transform(t) : t;
  return y0 + (y1 - y0) * eased;
}

/// A damped spring evaluated at [frame], as a pure function.
///
/// Unlike a physics simulation stepped over real time, this is deterministic:
/// the same frame always yields the same value.
///
/// An underdamped spring **overshoots** [to] and settles back, which is the
/// point of using one. It also means the result is not bounded by `from..to`:
/// driving an `Opacity` with it asserts, since 1.03 is not a legal opacity.
/// Use it for offsets and scales, and [interpolate] -- which clamps -- for
/// anything with a range.
double spring(
  int frame, {
  int fps = 60,
  double from = 0,
  double to = 1,
  double mass = 1,
  double stiffness = 100,
  double damping = 10,
  double initialVelocity = 0,
}) {
  final double t = frame / fps;
  if (t <= 0) return from;

  final double delta = to - from;
  final double w0 = math.sqrt(stiffness / mass);
  final double zeta = damping / (2 * math.sqrt(stiffness * mass));

  final double value;
  if (zeta < 1) {
    final double wd = w0 * math.sqrt(1 - zeta * zeta);
    final double a = 1.0;
    final double b = (zeta * w0 + -initialVelocity) / wd;
    value = 1 -
        math.exp(-t * zeta * w0) * (a * math.cos(wd * t) + b * math.sin(wd * t));
  } else {
    final double a = 1.0;
    final double b = -initialVelocity + w0;
    value = 1 - math.exp(-t * w0) * (a + b * t);
  }
  return from + delta * value;
}
