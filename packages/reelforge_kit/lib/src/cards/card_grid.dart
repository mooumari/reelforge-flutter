import 'package:flutter/widgets.dart';

import '../motion/stagger.dart';

/// A fixed grid of cards, each tagged with its own stagger delay.
///
/// Deliberately not scrollable and not lazy: a composition renders every
/// frame off screen, and a `GridView` that builds only what is visible would
/// build nothing at all. [NeverScrollableScrollPhysics] and `shrinkWrap` are
/// not optional here.
class CardGrid extends StatelessWidget {
  const CardGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 3,
    this.spacing = 20,
    this.aspectRatio = 0.92,
    this.delay = 8,
    this.step = 4,
  });

  final List<Widget> children;
  final int crossAxisCount;
  final double spacing;
  final double aspectRatio;

  /// Frames before the first card arrives.
  final int delay;

  /// Frames between one card arriving and the next.
  final int step;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: aspectRatio,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: Stagger.wrap(children, delay: delay, step: step),
    );
  }
}
