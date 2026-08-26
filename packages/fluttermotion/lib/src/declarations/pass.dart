import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../composition.dart';
import '../renderer.dart';
import '../media/video_store.dart';
import 'assets.dart';
import 'manifest.dart';
import 'scope.dart';

/// Walks a composition's whole timeline before anything is rasterised, and
/// reports what it needs.
///
/// Every frame is visited rather than sampled. That is affordable because
/// build and layout cost roughly 0.5 ms per frame while rasterising costs
/// ~17 ms -- a five second composition sweeps in about 150 ms. Sampling would
/// be marginally faster and would silently miss a sound or an image that only
/// appears for a few frames inside a [Sequence], which is exactly the bug
/// class this pass exists to prevent.
abstract final class DeclarationPass {
  static RenderManifest run(Composition composition) {
    final DeclarationCollector collector = DeclarationCollector();
    final CompositionRenderer renderer =
        CompositionRenderer(
      composition,
      collector: collector,
      // The pass only needs to know which widgets mount, never what their
      // animations look like -- and driving the animation clock means driving
      // the binding's frame loop, which is illegal from inside a frame. The
      // pass runs from wherever the caller happens to be.
      driveAnimationClock: false,
    );
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      for (int frame = 0; frame < composition.durationInFrames; frame++) {
        // Set before building: widgets read this to place themselves.
        collector.frame = frame;
        renderer.pumpWithoutPaint(frame);
      }
    } finally {
      renderer.dispose();
    }

    stopwatch.stop();
    return collector.build(
      framesVisited: composition.durationInFrames,
      elapsed: stopwatch.elapsed,
    );
  }

  /// Runs the pass and gets everything it found ready to paint.
  ///
  /// Images are decoded in full; video clips get an open decoder each, since
  /// buffering a whole clip's pixels would cost gigabytes. Both are ready
  /// before the first frame is rasterised, which is what lets a frame be
  /// painted synchronously.
  ///
  /// Video needs [ffmpeg], [ffprobe] and [projectPath]; without them a
  /// composition containing a [VideoClip] still renders, just without its
  /// video. That is the preview's position before it has a decoder, not a
  /// silent failure in the exporter -- `renderMain` always supplies them.
  static Future<PreparedComposition> prepare(
    Composition composition, {
    String? ffmpeg,
    String? ffprobe,
    String? projectPath,
  }) async {
    final RenderManifest manifest = run(composition);

    VideoFrames? video;
    if (manifest.video.isNotEmpty &&
        ffmpeg != null &&
        ffprobe != null &&
        projectPath != null) {
      video = await VideoPreloader.open(
        manifest.video,
        fps: composition.fps,
        ffmpeg: ffmpeg,
        ffprobe: ffprobe,
        projectPath: projectPath,
      );
    }

    return PreparedComposition(
      composition: composition,
      manifest: manifest,
      images: await ImagePreloader.resolveAll(manifest.images),
      videoFrames: video,
    );
  }
}

/// A composition together with everything it needs, ready to render.
@immutable
class PreparedComposition {
  const PreparedComposition({
    required this.composition,
    required this.manifest,
    required this.images,
    this.videoFrames,
  });

  final Composition composition;
  final RenderManifest manifest;
  final Map<ImageProvider<Object>, ui.Image> images;

  /// Open decoders, or null if the composition has no video (or no ffmpeg to
  /// decode it with).
  final VideoFrames? videoFrames;

  CompositionRenderer createRenderer({double scale = 1.0}) {
    return CompositionRenderer(
      composition,
      scale: scale,
      images: images,
      videoFrames: videoFrames,
    );
  }

  Future<void> dispose() async {
    await videoFrames?.dispose();
  }
}
