import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../composition.dart';
import '../renderer.dart';
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
        CompositionRenderer(composition, collector: collector);
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

  /// Runs the pass and decodes everything it found.
  static Future<PreparedComposition> prepare(Composition composition) async {
    final RenderManifest manifest = run(composition);
    return PreparedComposition(
      composition: composition,
      manifest: manifest,
      images: await ImagePreloader.resolveAll(manifest.images),
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
  });

  final Composition composition;
  final RenderManifest manifest;
  final Map<ImageProvider<Object>, ui.Image> images;

  CompositionRenderer createRenderer({double scale = 1.0}) {
    return CompositionRenderer(
      composition,
      scale: scale,
      images: images,
    );
  }
}
