import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';

import '../motion/enter.dart';
import '../theme.dart';

/// Full-bleed footage with the composition drawing over it.
///
/// The scrim is the part that is easy to leave out and impossible to read
/// without: white text over arbitrary video is legible on the frames where
/// the video happens to be dark and gone on the rest.
///
/// [loop] defaults to true because footage is almost always shorter than the
/// scene it is mounted in, and the alternative is the picture freezing for
/// the remainder.
class FootageOverlay extends StatelessWidget {
  const FootageOverlay({
    super.key,
    required this.src,
    this.caption,
    this.child,
    this.fit = BoxFit.cover,
    this.loop = true,
    this.trimStartInFrames = 0,
    this.scrim = true,
    this.scrimFrom = Alignment.topCenter,
    this.captionDelay = 10,
    this.captionPadding = const EdgeInsets.only(left: 70, right: 70, bottom: 200),
  });

  final String src;

  /// Text laid over the footage, arriving from below.
  final String? caption;

  /// Arbitrary content over the footage, instead of or as well as [caption].
  final Widget? child;

  final BoxFit fit;
  final bool loop;
  final int trimStartInFrames;

  /// A gradient from transparent to the background colour, so overlaid text
  /// stays legible whatever the footage is doing.
  final bool scrim;

  /// Which end of the frame the scrim fades *from*. The opposite end is where
  /// it is darkest, which is where the caption should sit.
  final Alignment scrimFrom;

  final int captionDelay;
  final EdgeInsets captionPadding;

  @override
  Widget build(BuildContext context) {
    final MotionTheme theme = MotionTheme.of(context);
    final Color ground = theme.palette.background;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        VideoClip(
          src: src,
          fit: fit,
          loop: loop,
          trimStartInFrames: trimStartInFrames,
        ),
        if (scrim)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: scrimFrom,
                end: -scrimFrom,
                colors: <Color>[
                  ground.withValues(alpha: 0),
                  ground.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
        if (caption != null)
          Padding(
            padding: captionPadding,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Enter.slideUp(
                delay: captionDelay,
                distance: 50,
                duration: 30,
                child: Text(
                  caption!,
                  style: theme.textStyle(
                    size: theme.typography.headlineSize,
                    color: theme.palette.foreground,
                    weight: FontWeight.w700,
                    letterSpacing: -1,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        if (child != null) child!,
      ],
    );
  }
}
