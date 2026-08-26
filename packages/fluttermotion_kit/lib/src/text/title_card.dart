import 'package:flutter/widgets.dart';

import '../motion/enter.dart';
import '../theme.dart';

/// A kicker, a headline and a subhead, arriving in that order.
///
/// The opening and closing beat of most reels. Everything is optional except
/// [headline], so the same component covers a title card, a section break and
/// an outro.
class TitleCard extends StatelessWidget {
  const TitleCard({
    super.key,
    required this.headline,
    this.kicker,
    this.subhead,
    this.padding = const EdgeInsets.all(90),
    this.alignment = CrossAxisAlignment.start,
    this.centred = false,
    this.headlineColor,
    this.kickerColor,
  });

  /// Centred in the frame, with everything centre-aligned. The outro shape.
  const TitleCard.centred({
    Key? key,
    required String headline,
    String? kicker,
    String? subhead,
    EdgeInsets padding = const EdgeInsets.all(90),
    Color? headlineColor,
    Color? kickerColor,
  }) : this(
          key: key,
          headline: headline,
          kicker: kicker,
          subhead: subhead,
          padding: padding,
          alignment: CrossAxisAlignment.center,
          centred: true,
          headlineColor: headlineColor,
          kickerColor: kickerColor,
        );

  final String headline;

  /// The small line above the headline. Drawn in the accent colour.
  final String? kicker;

  /// The muted line below. Arrives last.
  final String? subhead;

  final EdgeInsets padding;
  final CrossAxisAlignment alignment;

  /// Whether the block sits in the middle of the frame rather than filling it.
  final bool centred;

  final Color? headlineColor;
  final Color? kickerColor;

  @override
  Widget build(BuildContext context) {
    final MotionTheme theme = MotionTheme.of(context);
    final MotionPalette palette = theme.palette;
    final TextAlign textAlign =
        alignment == CrossAxisAlignment.center ? TextAlign.center : TextAlign.start;

    final Widget column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: centred ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: alignment,
      children: <Widget>[
        if (kicker != null) ...<Widget>[
          Enter.spring(
            delay: 4,
            from: const Offset(0, 60),
            scale: null,
            stiffness: 110,
            child: Text(
              kicker!,
              textAlign: textAlign,
              style: theme.textStyle(
                size: theme.typography.titleSize,
                color: kickerColor ?? palette.accent,
                weight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
          SizedBox(height: 24 * theme.typography.scale),
        ],
        Enter.spring(
          delay: 4,
          // Further than the kicker, so the two do not move as one block.
          from: const Offset(0, 100),
          scale: null,
          stiffness: 110,
          child: Text(
            headline,
            textAlign: textAlign,
            style: theme.textStyle(
              size: theme.typography.displaySize,
              color: headlineColor ?? palette.foreground,
              weight: FontWeight.w800,
              letterSpacing: -3,
              height: 1.02,
            ),
          ),
        ),
        if (subhead != null) ...<Widget>[
          SizedBox(height: 40 * theme.typography.scale),
          Enter.fade(
            delay: 20,
            duration: 24,
            child: Text(
              subhead!,
              textAlign: textAlign,
              style: theme.textStyle(
                size: theme.typography.bodySize,
                color: palette.muted,
              ),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: centred ? Center(child: column) : column,
    );
  }
}
