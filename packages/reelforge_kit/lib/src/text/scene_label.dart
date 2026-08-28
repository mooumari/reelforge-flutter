import 'package:flutter/widgets.dart';

import '../theme.dart';

/// The small, spaced, upper-case line that says what a scene is about.
///
/// Present in every data scene there is. Its whole job is to be legible
/// without competing with the thing it labels, which is why it is muted and
/// small rather than another headline.
class SceneLabel extends StatelessWidget {
  const SceneLabel(this.text, {super.key, this.color});

  final String text;

  /// Defaults to the theme's muted colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final MotionTheme theme = MotionTheme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textStyle(
        size: theme.typography.labelSize,
        color: color ?? theme.palette.muted,
        weight: FontWeight.w700,
        letterSpacing: 3,
      ),
    );
  }
}
