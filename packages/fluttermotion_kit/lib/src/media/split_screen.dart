import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';

/// Two panels arriving from opposite sides and meeting.
///
/// Takes widgets rather than clip paths, so it splits footage against
/// footage, footage against a chart, or two app screens -- the motion is the
/// component, not what is behind it.
///
/// The travel distance comes from the composition's own size, so the panels
/// start off screen at any resolution without being told how wide the frame
/// is.
class SplitScreen extends StatelessWidget {
  const SplitScreen({
    super.key,
    required this.first,
    required this.second,
    this.direction = Axis.vertical,
    this.gap = 8,
    this.slideFrames = 30,
    this.curve = Curves.easeInOutCubic,
    this.delay = 0,
  });

  final Widget first;
  final Widget second;

  /// [Axis.vertical] stacks the panels and slides them in horizontally;
  /// [Axis.horizontal] puts them side by side and slides them vertically.
  final Axis direction;

  final double gap;
  final int slideFrames;
  final Curve curve;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final Size size = Video.size(context);
    final double travel =
        direction == Axis.vertical ? size.width : size.height;

    final double split = interpolate(
      Video.frame(context) - delay,
      <num>[0, slideFrames],
      <num>[0, 1],
      easing: curve,
    );

    Offset offsetFor(int sign) => direction == Axis.vertical
        ? Offset((1 - split) * travel * sign, 0)
        : Offset(0, (1 - split) * travel * sign);

    return Flex(
      direction: direction,
      // Stretch, not the default centre: a panel is meant to fill the frame
      // across the split. Loose cross-axis constraints let a childless
      // ColoredBox -- or any widget with no intrinsic size, which is most of
      // what goes in here -- collapse to nothing and render an empty frame.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Transform.translate(offset: offsetFor(-1), child: first),
        ),
        SizedBox(
          width: direction == Axis.vertical ? null : gap,
          height: direction == Axis.vertical ? gap : null,
        ),
        Expanded(
          child: Transform.translate(offset: offsetFor(1), child: second),
        ),
      ],
    );
  }
}
