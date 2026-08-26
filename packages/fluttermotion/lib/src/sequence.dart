import 'package:flutter/widgets.dart';

import 'frame.dart';

/// Shifts time for its subtree.
///
/// The child sees frame `0` when the composition reaches [from], and is not
/// built at all outside its window. Nesting composes: a [Sequence] inside a
/// [Sequence] offsets from its parent's local frame.
class Sequence extends StatelessWidget {
  const Sequence({
    super.key,
    required this.from,
    this.durationInFrames,
    this.layout = SequenceLayout.none,
    required this.child,
  });

  /// Frame (in the enclosing timeline) at which this sequence starts.
  final int from;

  /// How long the sequence lasts. Null means "until the end".
  final int? durationInFrames;

  final SequenceLayout layout;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final VideoFrame parent = VideoFrame.of(context);
    final int local = parent.frame - from;
    final int duration = durationInFrames ?? (parent.durationInFrames - from);

    // Outside its window the subtree is not built, so off-screen sequences
    // cost nothing per frame.
    if (local < 0 || local >= duration) {
      return const SizedBox.shrink();
    }

    final Widget shifted = VideoFrame(
      frame: local,
      fps: parent.fps,
      durationInFrames: duration,
      width: parent.width,
      height: parent.height,
      child: child,
    );

    return switch (layout) {
      SequenceLayout.none => shifted,
      SequenceLayout.fill => Positioned.fill(child: shifted),
    };
  }
}

enum SequenceLayout {
  /// Lay the child out normally.
  none,

  /// Wrap in [Positioned.fill]. Only valid directly inside a [Stack].
  fill,
}
