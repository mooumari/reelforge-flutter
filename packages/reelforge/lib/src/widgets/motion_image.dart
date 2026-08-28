import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../declarations/assets.dart';
import '../declarations/manifest.dart';
import '../declarations/scope.dart';

/// An image that is guaranteed to be decoded before the frame is drawn.
///
/// Use this instead of [Image] inside a composition. [Image] resolves
/// asynchronously, so frame 12 could show a placeholder on one run and the
/// photo on the next -- which is exactly the class of bug that makes a
/// renderer untrustworthy. `MotionImage` declares itself during the
/// declaration pass, and by the time frames are rasterised the bytes are
/// already decoded.
///
/// If an image somehow was not preloaded, this throws rather than quietly
/// drawing nothing. A loud failure is worth more than a silently wrong video.
class MotionImage extends StatelessWidget {
  const MotionImage({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.opacity = 1.0,
  });

  /// Convenience for the common case.
  MotionImage.asset(
    String name, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.opacity = 1.0,
  }) : image = AssetImage(name);

  final ImageProvider<Object> image;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    DeclarationScope.maybeOf(context)?.declareImage(ImageDeclaration(image));

    final ResolvedImages? store = ResolvedImages.maybeOf(context);
    final ui.Image? resolved = store?[image];

    if (resolved == null) {
      // During the declaration pass nothing is resolved yet -- that is the
      // point of the pass -- so take up the right amount of space and move on.
      if (DeclarationScope.maybeOf(context) != null || store == null) {
        return SizedBox(width: width, height: height);
      }
      throw StateError(
        'MotionImage was asked to paint '
        '${ImageDeclaration.describeProvider(image)}, but it was not '
        'preloaded.\n'
        'This usually means the image was created inside a build that the '
        'declaration pass never reached -- for example behind a condition '
        'that is only true on some frames but constructs a *different* '
        'ImageProvider each build. Hoist the provider to a field or a '
        'top-level final so it compares equal across frames.',
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: RawImage(
        image: resolved,
        fit: fit,
        alignment: alignment,
        opacity: opacity == 1.0 ? null : AlwaysStoppedAnimation<double>(opacity),
      ),
    );
  }
}
