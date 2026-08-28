import 'package:flutter/widgets.dart';

import '../theme.dart';

/// One number, large, with a quiet label under it.
///
/// [value] is a widget rather than a string so a counting number and a fixed
/// one are the same component: pass a [Counter] and it counts, pass a [Text]
/// and it does not. The statistic style is set as the default for the
/// subtree, so neither has to be told how big to be.
///
/// ```dart
/// BigStat(value: Counter(to: 128), label: 'releases')
/// BigStat.text(value: '99.98%', label: 'uptime')
/// ```
class BigStat extends StatelessWidget {
  const BigStat({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });

  /// A fixed value, for when nothing is counting.
  BigStat.text({
    Key? key,
    required String value,
    required String label,
    Color? color,
  }) : this(key: key, value: Text(value), label: label, color: color);

  final Widget value;
  final String label;

  /// Defaults to the theme's foreground.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final MotionTheme theme = MotionTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DefaultTextStyle(
          style: theme.textStyle(
            size: theme.typography.statisticSize,
            color: color ?? theme.palette.foreground,
            weight: FontWeight.w800,
            letterSpacing: -6,
            height: 1,
          ),
          child: value,
        ),
        Text(
          label,
          style: theme.textStyle(
            size: theme.typography.bodySize,
            color: theme.palette.muted,
          ),
        ),
      ],
    );
  }
}

/// A column of [BigStat]s, spaced and staggered.
///
/// The stagger is on the *content* rather than on an [Enter] wrapper, because
/// what should arrive one after another here is the counting, not the block.
/// Three numbers that fade in together and then all count at once reads as one
/// event; three that count in sequence reads as three facts.
class BigStatList extends StatelessWidget {
  const BigStatList({
    super.key,
    required this.children,
    this.spacing = 60,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final double gap = spacing * MotionTheme.typeOf(context).scale;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: crossAxisAlignment,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}
