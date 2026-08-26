import 'package:flutter/scheduler.dart';

/// Slaves Flutter's animation clock to the frame being rendered.
///
/// Widgets written for a real app animate against wall-clock time: an
/// [AnimationController] is driven by a [Ticker], and every [Ticker] --
/// including the ones [SingleTickerProviderStateMixin] creates, which is what
/// `AnimatedContainer` and friends use -- schedules itself against
/// [SchedulerBinding]. There is no seam in the widget tree to intercept them,
/// so the only way to make such a widget deterministic is to control the
/// binding's notion of what time it is.
///
/// Driving a frame here does two things a detached tree otherwise never gets:
/// it ticks every active [Ticker] to the composition's time, and it drains
/// post-frame callbacks, which is how a great many widgets start their
/// animation in the first place.
class FrameClock {
  FrameClock({required this.fps});

  final int fps;

  Duration timeOf(int frame) =>
      Duration(microseconds: (frame * 1000000 / fps).round());

  /// Advances the animation clock to [frame]'s instant.
  void driveTo(int frame) {
    final SchedulerBinding binding = SchedulerBinding.instance;
    binding.handleBeginFrame(timeOf(frame));
    binding.handleDrawFrame();
  }
}
