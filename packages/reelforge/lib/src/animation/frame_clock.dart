import 'package:flutter/scheduler.dart';

import 'ticker_gate.dart';

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

  /// Where composition time zero sits on the binding's own timeline.
  ///
  /// A raw timestamp handed to [SchedulerBinding.handleBeginFrame] is not the
  /// timestamp tickers see: the binding subtracts the first raw stamp of the
  /// current epoch from it. In a headless render host our own first frame *is*
  /// that first stamp, so the two agree and composition time is taken
  /// literally. In a live application the engine got there first, and its
  /// stamps are the platform's clock -- on macOS, time since boot. Handing the
  /// binding a bare composition time of 0.75s there means announcing a frame
  /// from several hours before the app started, and every ticker in reach gets
  /// a negative elapsed time.
  ///
  /// So composition zero is pinned to whenever the first frame was drawn, and
  /// the timeline runs forward from there. Nothing about the composition
  /// changes: what a widget's animation depends on is that consecutive frames
  /// are exactly `1/fps` apart, and a constant origin leaves that alone. In
  /// the render host the origin is zero and this is not observable at all.
  Duration? _base;

  /// How much the binding shifts a raw stamp before tickers see it.
  Duration _shift = Duration.zero;
  bool _measured = false;

  /// Advances the animation clock to [frame]'s instant.
  ///
  /// The binding is global, so this frame is delivered to the host
  /// application's tickers as well as the composition's. Composition time
  /// means nothing to those, so they are muted for the duration -- see
  /// [MotionTickerShield].
  void driveTo(int frame) {
    MotionTickerShield.muteHosts();
    try {
      // The shift can only be read from inside a frame, so a change in it is
      // always noticed one frame late. When that happens the frame just drawn
      // landed at the wrong instant, so it is drawn again at the right one --
      // an animation is a pure function of elapsed time, and the second pass
      // overwrites whatever the first computed.
      if (_frame(frame)) _frame(frame);
    } finally {
      MotionTickerShield.unmuteHosts();
    }
  }

  /// Announces one frame. Returns true if the binding moved its epoch since
  /// the last one, which means this frame did not land where it was aimed.
  bool _frame(int frame) {
    final SchedulerBinding binding = SchedulerBinding.instance;
    binding.handleBeginFrame(_rawFor(binding, frame));

    final Duration shift =
        binding.currentSystemFrameTimeStamp - binding.currentFrameTimeStamp;
    final bool moved = _measured && shift != _shift;
    _shift = shift;
    _measured = true;
    _base ??= binding.currentFrameTimeStamp - timeOf(frame);

    binding.handleDrawFrame();
    return moved;
  }

  /// The raw stamp that puts [frame] where [_base] says it belongs.
  Duration _rawFor(SchedulerBinding binding, int frame) {
    final Duration? base = _base;
    if (base == null) {
      // Nothing measured yet, so start from wherever the binding already is
      // and let this frame define composition zero.
      return timeOf(frame) + binding.currentSystemFrameTimeStamp;
    }
    return timeOf(frame) + base + _shift;
  }
}
