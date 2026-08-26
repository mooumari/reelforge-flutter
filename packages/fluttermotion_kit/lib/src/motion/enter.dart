import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';

import 'stagger.dart';

/// Brings a subtree on screen: fade, slide, scale, or a spring doing all three.
///
/// One wrapper rather than an entrance baked into every component, because
/// the *how* of arriving is independent of the *what* that arrives. Anything
/// can be wrapped, including widgets from an app that knows nothing about
/// video.
///
/// Timing is in frames and read from the enclosing composition or [Sequence],
/// so an `Enter` inside a scene counts from that scene's own frame zero. A
/// [Stagger] above it adds to [delay].
///
/// ```dart
/// Enter.slideUp(child: Text('Arrives from below'))
/// Enter.spring(delay: 4, child: BigStat(value: '42'))
/// ```
class Enter extends StatelessWidget {
  const Enter({
    super.key,
    this.delay = 0,
    this.duration = 12,
    this.curve = Curves.easeOutCubic,
    this.fade = true,
    this.from = Offset.zero,
    this.scaleFrom,
    this.stiffness,
    this.damping = 15,
    required this.child,
  });

  /// Fades up, with no movement.
  const Enter.fade({
    Key? key,
    int delay = 0,
    int duration = 12,
    Curve curve = Curves.easeOutCubic,
    required Widget child,
  }) : this(
          key: key,
          delay: delay,
          duration: duration,
          curve: curve,
          child: child,
        );

  /// Rises into place from [distance] pixels below.
  Enter.slideUp({
    Key? key,
    double distance = 60,
    int delay = 0,
    int duration = 12,
    Curve curve = Curves.easeOutCubic,
    bool fade = true,
    required Widget child,
  }) : this(
          key: key,
          delay: delay,
          duration: duration,
          curve: curve,
          fade: fade,
          from: Offset(0, distance),
          child: child,
        );

  /// Drops into place from [distance] pixels above.
  Enter.slideDown({
    Key? key,
    double distance = 60,
    int delay = 0,
    int duration = 12,
    Curve curve = Curves.easeOutCubic,
    bool fade = true,
    required Widget child,
  }) : this(
          key: key,
          delay: delay,
          duration: duration,
          curve: curve,
          fade: fade,
          from: Offset(0, -distance),
          child: child,
        );

  /// Slides in from [distance] pixels to the left.
  Enter.slideLeft({
    Key? key,
    double distance = 60,
    int delay = 0,
    int duration = 12,
    Curve curve = Curves.easeOutCubic,
    bool fade = true,
    required Widget child,
  }) : this(
          key: key,
          delay: delay,
          duration: duration,
          curve: curve,
          fade: fade,
          from: Offset(-distance, 0),
          child: child,
        );

  /// Slides in from [distance] pixels to the right.
  Enter.slideRight({
    Key? key,
    double distance = 60,
    int delay = 0,
    int duration = 12,
    Curve curve = Curves.easeOutCubic,
    bool fade = true,
    required Widget child,
  }) : this(
          key: key,
          delay: delay,
          duration: duration,
          curve: curve,
          fade: fade,
          from: Offset(distance, 0),
          child: child,
        );

  /// Grows into place from [scale].
  const Enter.scale({
    Key? key,
    double scale = 0.9,
    int delay = 0,
    int duration = 12,
    Curve curve = Curves.easeOutCubic,
    bool fade = true,
    required Widget child,
  }) : this(
          key: key,
          delay: delay,
          duration: duration,
          curve: curve,
          fade: fade,
          scaleFrom: scale,
          child: child,
        );

  /// Arrives on a spring, overshooting slightly and settling.
  ///
  /// A spring is what makes something *land* rather than stop. The overshoot
  /// applies to offset and scale; opacity is clamped, since 1.03 is not a
  /// legal opacity.
  const Enter.spring({
    Key? key,
    int delay = 0,
    Offset from = const Offset(0, 60),
    double? scale = 0.9,
    double stiffness = 130,
    double damping = 15,
    bool fade = true,
    required Widget child,
  }) : this(
          key: key,
          delay: delay,
          from: from,
          scaleFrom: scale,
          stiffness: stiffness,
          damping: damping,
          fade: fade,
          child: child,
        );

  /// Frames to wait before starting. A [Stagger] above adds to this.
  final int delay;

  /// Frames the entrance takes. Ignored when [stiffness] is set -- a spring
  /// settles when the physics says it does.
  final int duration;

  final Curve curve;

  /// Whether to fade in as well as move.
  final bool fade;

  /// Where the subtree starts, relative to where it belongs.
  final Offset from;

  /// Scale to start at. Null leaves scale alone.
  final double? scaleFrom;

  /// Set to drive the entrance with a spring rather than a curve.
  final double? stiffness;

  final double damping;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context) - delay - StaggerDelay.of(context);

    final double t = stiffness != null
        ? spring(
            frame,
            fps: Video.fps(context),
            stiffness: stiffness!,
            damping: damping,
          )
        : interpolate(frame, <num>[0, duration], <num>[0, 1], easing: curve);

    Widget result = child;

    if (scaleFrom != null) {
      result = Transform.scale(
        scale: scaleFrom! + (1 - scaleFrom!) * t,
        child: result,
      );
    }
    if (from != Offset.zero) {
      result = Transform.translate(offset: from * (1 - t), child: result);
    }
    if (fade) {
      // Clamped: a spring overshoots, and Opacity asserts above 1.
      result = Opacity(opacity: t.clamp(0.0, 1.0), child: result);
    }

    // A nested Enter should honour its own delay, not this one's stagger
    // again. Re-providing zero stops the tag at exactly one consumer.
    return StaggerDelay(frames: 0, child: result);
  }
}
