import 'package:flutter/widgets.dart';

import '../theme.dart';
import 'scene_label.dart';

/// A [SceneLabel] over content that fills the rest of the frame.
///
/// Three of the eight scenes in the example reel are exactly this -- a label,
/// a gap, and a chart taking the remaining height -- which is the only reason
/// it is a component. The padding defaults are generous because video is
/// watched at arm's length on a phone, not read at a desk.
class LabelledScene extends StatelessWidget {
  const LabelledScene({
    super.key,
    required this.label,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(70, 150, 70, 150),
    this.gap = 50,
  });

  final String label;

  /// Fills whatever the label leaves.
  final Widget child;

  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SceneLabel(label),
          SizedBox(height: gap * MotionTheme.typeOf(context).scale),
          Expanded(child: child),
        ],
      ),
    );
  }
}
