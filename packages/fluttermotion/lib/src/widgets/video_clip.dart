import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../declarations/manifest.dart';
import '../declarations/scope.dart';
import '../frame.dart';
import '../media/video_store.dart';

/// Plays a video file inside a composition.
///
/// Position and length come from where it is mounted, exactly like [Audio]:
///
/// ```dart
/// Sequence(
///   from: 60,
///   durationInFrames: 120,
///   child: VideoClip(src: 'assets/clip.mp4', decodeWidth: 1080),
/// )
/// ```
///
/// ## Why this is not `video_player`
///
/// A platform view renders in its own layer, outside Flutter's scene graph.
/// `RenderRepaintBoundary.toImage()` cannot see it, so a `video_player` in a
/// composition would export as a black hole in the frame. This decodes with
/// ffmpeg and paints the pixels through [RawImage], which means the video is a
/// real part of the widget tree: it can be rotated, masked, blurred, or put
/// behind a `BackdropFilter` like anything else.
///
/// It also means playback is a function of frame number rather than of the
/// wall clock, which is what keeps the render deterministic.
class VideoClip extends StatelessWidget {
  const VideoClip({
    super.key,
    required this.src,
    this.trimStartInFrames = 0,
    this.decodeWidth,
    this.decodeHeight,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.opacity = 1.0,
    this.loop = false,
  })  : assert(trimStartInFrames >= 0),
        assert(
          decodeWidth == null || decodeHeight == null || true,
          'decodeWidth and decodeHeight may be set independently.',
        );

  /// Path to the video file, relative to the project being rendered.
  final String src;

  /// How far into the source file the clip starts.
  final int trimStartInFrames;

  /// Decode resolution. Defaults to the source's own.
  ///
  /// Set this when the source is much larger than what you paint. Decoding a
  /// 4K file into a 1080p composition costs four times the pixels on every
  /// single frame, and nothing downstream can recover that.
  final int? decodeWidth;
  final int? decodeHeight;

  /// Layout size. Independent of decode size.
  final double? width;
  final double? height;

  final BoxFit fit;
  final Alignment alignment;
  final double opacity;

  /// Restart the clip when it reaches the end of the source, instead of
  /// holding the last frame.
  ///
  /// Without this, a clip mounted for longer than the file lasts freezes --
  /// warned about by name during the declaration pass, but still a frozen
  /// frame. Two seconds of B-roll under a nine-second scene is the ordinary
  /// case, not the exception.
  final bool loop;

  @override
  Widget build(BuildContext context) {
    // Two jobs at once: the declaration pass infers the clip's window from the
    // frames it was seen on, and rasterisation needs this to rebuild every
    // frame so it picks up the newly decoded image. The store itself never
    // changes identity, so this dependency is what drives both.
    Video.frame(context);

    final VideoDeclaration declaration = VideoDeclaration(
      src: src,
      trimStartInFrames: trimStartInFrames,
      decodeWidth: decodeWidth,
      decodeHeight: decodeHeight,
      loop: loop,
    );

    DeclarationScope.maybeOf(context)?.declareVideo(declaration);

    final VideoFrames? frames = DecodedVideoFrames.maybeOf(context);
    final ui.Image? image = frames?[declaration];

    if (image == null) {
      // Nothing is decoded during the declaration pass -- that is the point of
      // the pass -- so occupy the right space and move on.
      return SizedBox(width: width, height: height);
    }

    return SizedBox(
      width: width,
      height: height,
      child: RawImage(
        image: image,
        fit: fit,
        alignment: alignment,
        opacity: opacity == 1.0 ? null : AlwaysStoppedAnimation<double>(opacity),
      ),
    );
  }
}
