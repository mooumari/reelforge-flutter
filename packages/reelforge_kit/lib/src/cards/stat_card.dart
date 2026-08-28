import 'package:flutter/widgets.dart';

import '../theme.dart';

/// A panel with a badge, a name and a number whose sign picks its colour.
///
/// The sign-to-colour rule lives in [MotionPalette.forSign] rather than here,
/// so a grid of these and a chart beside them cannot disagree about what green
/// means.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.badge,
    this.signedBy,
    this.color,
    this.padding = const EdgeInsets.all(22),
    this.radius = 20,
  });

  /// The quiet line naming what this is.
  final String title;

  /// The number, drawn large in the sign colour.
  final String value;

  /// A short string in a tinted square at the top -- initials, a rank, an icon
  /// glyph. Omitted when null.
  final String? badge;

  /// The number whose sign chooses accent or warning.
  ///
  /// Separate from [value] because the value is already formatted: `'+3.1%'`
  /// is a string and has no sign to read. Defaults to positive.
  final num? signedBy;

  /// Overrides the sign colour entirely.
  final Color? color;

  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final MotionTheme theme = MotionTheme.of(context);
    final MotionPalette palette = theme.palette;
    final Color tone = color ?? palette.forSign(signedBy ?? 0);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.outline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (badge != null)
            Container(
              width: 52 * theme.typography.scale,
              height: 52 * theme.typography.scale,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                badge!,
                style: theme.textStyle(
                  size: theme.typography.captionSize,
                  color: tone,
                  weight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textStyle(
                  size: theme.typography.captionSize * 1.3,
                  color: palette.muted,
                ),
              ),
              SizedBox(height: 6 * theme.typography.scale),
              Text(
                value,
                style: theme.textStyle(
                  size: theme.typography.titleSize * 0.9,
                  color: tone,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
