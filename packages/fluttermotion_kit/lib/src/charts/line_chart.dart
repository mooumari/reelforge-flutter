import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';

import '../motion/stagger.dart';
import '../theme.dart';

/// One point on a [LineChart].
@immutable
class LineDatum {
  const LineDatum({required this.value, required this.label});

  final num value;
  final String label;
}

/// A line drawn left to right, with an axis of labels underneath.
///
/// The reveal is a clip, not a path measurement: the geometry is identical on
/// every frame and only the visible width changes, so frame 40 drawn on its
/// own is the same picture as frame 40 reached by playing from the start.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.points,
    this.maxValue,
    this.delay = 8,
    this.duration,
    this.curve = Curves.easeInOutCubic,
    this.color,
    this.strokeWidth = 6,
    this.dotRadius = 9,
    this.showLabels = true,
  });

  final List<LineDatum> points;

  /// The value the top of the box represents. Defaults to the largest present.
  final num? maxValue;

  /// Frames before the reveal starts.
  final int delay;

  /// Frames the reveal takes.
  ///
  /// Null means "the rest of the scene": the line finishes drawing as its
  /// [Sequence] ends. A fixed number cannot know how long the scene it was
  /// dropped into is, and a reveal tuned for nine seconds shows an empty box
  /// for the whole of a two-second one.
  final int? duration;

  final Curve curve;

  /// Defaults to the theme's warning colour -- a line chart in these reels is
  /// usually showing something you would rather went down.
  final Color? color;

  final double strokeWidth;
  final double dotRadius;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final MotionTheme theme = MotionTheme.of(context);
    final Color line = color ?? theme.palette.warning;

    final int span =
        (duration ?? Video.durationInFrames(context) - delay).clamp(1, 1 << 30);
    final double reveal = interpolate(
      Video.frame(context) - delay - StaggerDelay.of(context),
      <num>[0, span],
      <num>[0, 1],
      easing: curve,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: CustomPaint(
            painter: _LinePainter(
              points: points,
              maxValue: maxValue,
              reveal: reveal,
              color: line,
              strokeWidth: strokeWidth,
              dotRadius: dotRadius,
            ),
            size: Size.infinite,
          ),
        ),
        if (showLabels) ...<Widget>[
          SizedBox(height: 14 * theme.typography.scale),
          // One equal-width slot per point, which is exactly how the painter
          // above places them.
          Row(
            children: <Widget>[
              for (final LineDatum point in points)
                Expanded(
                  child: Text(
                    point.label,
                    textAlign: TextAlign.center,
                    style: theme.textStyle(
                      size: theme.typography.captionSize,
                      color: theme.palette.muted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.maxValue,
    required this.reveal,
    required this.color,
    required this.strokeWidth,
    required this.dotRadius,
  });

  final List<LineDatum> points;
  final num? maxValue;
  final double reveal;
  final Color color;
  final double strokeWidth;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final num peak = maxValue ??
        points
            .map((LineDatum p) => p.value)
            .reduce((num a, num b) => a > b ? a : b);
    final double divisor = peak.toDouble() == 0 ? 1 : peak.toDouble();

    // Points sit at the centre of a slot per value, not at the edges of the
    // box. Two reasons: a point at x = 0 has half its dot painted outside the
    // canvas, and slot centres are where a Row of equal-width labels puts its
    // text, so the axis underneath lines up without being told anything.
    final double slot = size.width / points.length;
    final double top = dotRadius;
    final double usable = size.height - dotRadius * 2;

    double xFor(int i) => slot * (i + 0.5);
    double yFor(int i) => top + usable * (1 - points[i].value / divisor);

    final Path path = Path()..moveTo(xFor(0), yFor(0));
    for (int i = 1; i < points.length; i++) {
      path.lineTo(xFor(i), yFor(i));
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(
        Offset(xFor(i), yFor(i)),
        dotRadius,
        Paint()..color = color,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.reveal != reveal ||
      old.points != points ||
      old.color != color ||
      old.maxValue != maxValue;
}
