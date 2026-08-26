import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';

import '../motion/stagger.dart';
import '../theme.dart';

/// One bar: how tall, what it is called, and optionally what colour.
@immutable
class BarDatum {
  const BarDatum({required this.value, required this.label, this.color});

  final num value;
  final String label;

  /// Overrides the chart's colour for this bar alone.
  final Color? color;
}

/// Bars that grow, one after another, on a spring.
///
/// Heights come from the data and nothing else; the only animated quantity is
/// how far along each bar is. A spring **overshoots**, which is what makes a
/// bar land rather than stop -- height can take that, which is why the growth
/// drives height and the value label's opacity is clamped separately.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.bars,
    this.maxValue,
    this.delay = 10,
    this.step = 3,
    this.stiffness = 140,
    this.damping = 16,
    this.color,
    this.gradient,
    this.showValues = true,
    this.barRadius = 10,
    this.barSpacing = 6,
    this.valueHeadroom = 44,
  });

  final List<BarDatum> bars;

  /// The value a full-height bar represents. Defaults to the largest present.
  final num? maxValue;

  /// Frames before the first bar starts growing.
  final int delay;

  /// Frames between one bar starting and the next.
  final int step;

  final double stiffness;
  final double damping;

  /// Flat colour for the bars. Ignored when [gradient] is set.
  final Color? color;

  /// Defaults to a vertical ramp into the theme's accent.
  final Gradient? gradient;

  /// Draw each bar's value above it, riding up as the bar grows.
  final bool showValues;

  final double barRadius;
  final double barSpacing;

  /// Space kept above the tallest bar for its value label.
  final double valueHeadroom;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();

    final num peak = maxValue ??
        bars.map((BarDatum b) => b.value).reduce((num a, num b) => a > b ? a : b);
    // A chart where everything is zero should be empty, not a division by it.
    final double divisor = peak.toDouble() == 0 ? 1 : peak.toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < bars.length; i++)
          Expanded(
            child: StaggerDelay(
              frames: delay + i * step,
              child: _Bar(
                datum: bars[i],
                fraction: bars[i].value / divisor,
                stiffness: stiffness,
                damping: damping,
                color: color,
                gradient: gradient,
                showValue: showValues,
                radius: barRadius,
                spacing: barSpacing,
                headroom: valueHeadroom,
              ),
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.datum,
    required this.fraction,
    required this.stiffness,
    required this.damping,
    required this.color,
    required this.gradient,
    required this.showValue,
    required this.radius,
    required this.spacing,
    required this.headroom,
  });

  final BarDatum datum;
  final double fraction;
  final double stiffness;
  final double damping;
  final Color? color;
  final Gradient? gradient;
  final bool showValue;
  final double radius;
  final double spacing;
  final double headroom;

  @override
  Widget build(BuildContext context) {
    final MotionTheme theme = MotionTheme.of(context);
    final MotionPalette palette = theme.palette;
    final Color barColor = datum.color ?? color ?? palette.accent;

    final double grow = spring(
      Video.frame(context) - StaggerDelay.of(context),
      fps: Video.fps(context),
      stiffness: stiffness,
      damping: damping,
    );
    final double scale = (grow * fraction).clamp(0.0, 1.0);
    final double settled = grow.clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing),
      child: Column(
        children: <Widget>[
          // Expanded first, then a height read off the constraints. A
          // FractionallySizedBox here would have nothing to be a fraction of:
          // a Column hands its children unbounded height on the main axis.
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double available = (constraints.maxHeight -
                        (showValue ? headroom : 0))
                    .clamp(0.0, double.infinity);
                final double height = available * scale;
                return Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: height,
                        decoration: BoxDecoration(
                          gradient: datum.color == null
                              ? (gradient ?? _rampInto(barColor))
                              : null,
                          color: datum.color,
                          borderRadius: BorderRadius.circular(radius),
                        ),
                      ),
                    ),
                    // Rides on top of its own bar rather than sitting in a row
                    // of numbers at the top, where nothing says which bar a
                    // number belongs to.
                    if (showValue)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: height + 8,
                        child: Text(
                          _format(datum.value),
                          textAlign: TextAlign.center,
                          style: theme.textStyle(
                            size: theme.typography.captionSize * 1.2,
                            color: palette.foreground
                                .withValues(alpha: settled),
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 14 * theme.typography.scale),
          Text(
            datum.label,
            style: theme.textStyle(
              size: theme.typography.captionSize,
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }

  /// A darker foot fading up into [top], so a flat bar still reads as solid.
  static Gradient _rampInto(Color top) => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          Color.lerp(top, const Color(0xFF000000), 0.55)!,
          top,
        ],
      );

  static String _format(num value) =>
      value is int || value == value.roundToDouble()
          ? value.round().toString()
          : value.toStringAsFixed(1);
}
