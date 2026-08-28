import 'package:flutter/widgets.dart';

/// How many frames later than its siblings this subtree should start.
///
/// Provided by [Stagger] and consumed by [Enter]. Separate from [Stagger]
/// itself so anything can honour a stagger, not just the widgets that happen
/// to be its direct children.
class StaggerDelay extends InheritedWidget {
  const StaggerDelay({super.key, required this.frames, required super.child});

  final int frames;

  /// Zero when nothing above has staggered this subtree.
  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StaggerDelay>()?.frames ?? 0;

  @override
  bool updateShouldNotify(StaggerDelay oldWidget) =>
      frames != oldWidget.frames;
}

/// Starts each child a fixed number of frames after the one before it.
///
/// This is the pattern behind every list that arrives rather than appearing:
/// bars growing left to right, cards landing one after another. It does not
/// animate anything itself -- it says *when*, and an [Enter] inside each child
/// says *how*.
///
/// ```dart
/// Stagger(
///   delay: 10,
///   step: 3,
///   children: <Widget>[
///     for (final Team t in teams) Enter.spring(child: StatCard(team: t)),
///   ],
/// )
/// ```
///
/// It deliberately does not lay its children out. [children] come back in the
/// same order and shape, so a `Stagger` can feed a `Row`, a `GridView` or a
/// `Column` without knowing which -- use [Stagger.wrap] to get the list, or
/// the widget form to place them in a [Flex].
class Stagger extends StatelessWidget {
  const Stagger({
    super.key,
    required this.children,
    this.step = 3,
    this.delay = 0,
    this.direction = Axis.horizontal,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.expandChildren = false,
  });

  final List<Widget> children;

  /// Frames between one child starting and the next.
  final int step;

  /// Frames before the first child starts.
  final int delay;

  final Axis direction;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  /// Wrap each child in [Expanded], so children share the main axis evenly.
  final bool expandChildren;

  /// Tags [children] with their delays without laying them out.
  ///
  /// For when the layout is something a [Flex] cannot do -- a grid, a wrap, a
  /// stack of positioned cards.
  static List<Widget> wrap(
    List<Widget> children, {
    int step = 3,
    int delay = 0,
  }) =>
      <Widget>[
        for (int i = 0; i < children.length; i++)
          StaggerDelay(frames: delay + i * step, child: children[i]),
      ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> tagged = <Widget>[
      for (int i = 0; i < children.length; i++)
        if (expandChildren)
          Expanded(
            child: StaggerDelay(
              frames: delay + i * step,
              child: children[i],
            ),
          )
        else
          StaggerDelay(frames: delay + i * step, child: children[i]),
    ];

    return Flex(
      direction: direction,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: tagged,
    );
  }
}
