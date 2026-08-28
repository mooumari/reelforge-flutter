import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';

import 'stagger.dart';

/// The value a counter is showing on this frame.
///
/// A pure function of the frame, like everything else -- which is why
/// scrubbing backwards through a counter lands on exactly the number it showed
/// on the way forward. A counter driven by an `AnimationController` would not.
double counted(
  BuildContext context, {
  required num to,
  num from = 0,
  int delay = 0,
  int duration = 45,
  Curve curve = Curves.easeOutExpo,
}) {
  final int frame = Video.frame(context) - delay - StaggerDelay.of(context);
  return interpolate(
    frame,
    <num>[0, duration],
    <num>[from, to],
    easing: curve,
  );
}

/// A number that counts up to [to].
///
/// [format] decides how the running value is written -- rounded, to two
/// decimals, with a currency symbol, as a percentage. It is called every
/// frame with the interpolated value.
///
/// ```dart
/// Counter(to: 99.98, format: (double v) => '${v.toStringAsFixed(2)}%')
/// ```
class Counter extends StatelessWidget {
  const Counter({
    super.key,
    required this.to,
    this.from = 0,
    this.delay = 0,
    this.duration = 45,
    this.curve = Curves.easeOutExpo,
    this.format = _round,
    this.style,
    this.textAlign,
  });

  final num to;
  final num from;
  final int delay;
  final int duration;
  final Curve curve;

  /// Turns the running value into what is drawn.
  final String Function(double value) format;

  final TextStyle? style;
  final TextAlign? textAlign;

  static String _round(double value) => value.round().toString();

  @override
  Widget build(BuildContext context) {
    final double value = counted(
      context,
      to: to,
      from: from,
      delay: delay,
      duration: duration,
      curve: curve,
    );
    return Text(format(value), style: style, textAlign: textAlign);
  }
}
