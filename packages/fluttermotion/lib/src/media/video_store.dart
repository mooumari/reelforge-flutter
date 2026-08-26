import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../declarations/manifest.dart';
import 'video_backend.dart';
import 'video_decoder.dart';

/// Owns one decoder per declared clip and keeps them all on the same frame.
///
/// Deliberately mutable and deliberately *not* an immutable map like
/// [ResolvedImages]: images are decoded once up front, but a video's pixels
/// change every frame, and buffering a whole clip would cost gigabytes.
/// [advanceTo] is awaited before the frame is built, so by the time a
/// [VideoClip] paints, its image is already in memory -- the render itself
/// stays synchronous and deterministic.
class VideoFrames {
  VideoFrames(this._decoders);

  /// Every open decoder, grouped by the declaration a [VideoClip] looks up.
  ///
  /// A list rather than one decoder each, because the same file placed in two
  /// scenes is two placements of one declaration -- [VideoDeclaration] has
  /// value equality, so they are the same key. Keeping only the last one is
  /// what made the earlier placement render black.
  ///
  /// The windows within a group are disjoint: the declaration pass builds them
  /// from runs of consecutive frames, and a gap is what splits one run into
  /// two. So at most one of them wants a given frame, and a [VideoClip] never
  /// has to say which placement it is.
  final Map<VideoDeclaration, List<VideoFrameSource>> _decoders;

  final Map<VideoDeclaration, ui.Image?> _current =
      <VideoDeclaration, ui.Image?>{};

  int? _frame;
  bool _advancing = false;

  /// Clips known to be shorter than the window they were mounted for.
  final List<String> warnings = <String>[];

  bool get isEmpty => _decoders.isEmpty;

  /// Decodes [frame] for every clip visible on it.
  ///
  /// Clips outside their window are absent from the map, so a [VideoClip] that
  /// should not be on screen cannot paint a stale image.
  ///
  /// Must not be called concurrently -- a decoder is a single pipe and cannot
  /// serve two reads at once. The exporter walks frames in a loop; the preview
  /// coalesces scrub requests instead of queueing them.
  Future<void> advanceTo(int frame) async {
    if (_frame == frame) return;
    assert(!_advancing, 'Concurrent advanceTo on one VideoFrames.');
    _advancing = true;
    try {
      // Decoded into a separate map and swapped in at the end: a rebuild that
      // lands mid-decode should show the previous frame, not an empty one.
      final Map<VideoDeclaration, ui.Image?> next =
          <VideoDeclaration, ui.Image?>{};
      for (final MapEntry<VideoDeclaration, List<VideoFrameSource>> entry
          in _decoders.entries) {
        for (final VideoFrameSource decoder in entry.value) {
          if (frame < decoder.startFrame || frame > decoder.endFrame) continue;
          next[entry.key] = await decoder.frameAt(frame);
          break;
        }
      }
      _frame = frame;
      _current
        ..clear()
        ..addAll(next);
    } finally {
      _advancing = false;
    }
  }

  ui.Image? operator [](VideoDeclaration declaration) => _current[declaration];

  Future<void> dispose() async {
    for (final List<VideoFrameSource> group in _decoders.values) {
      for (final VideoFrameSource decoder in group) {
        await decoder.dispose();
      }
    }
    _decoders.clear();
    _current.clear();
  }
}

/// Makes the decoded frames available to [VideoClip].
///
/// The store is mutable and its identity never changes, so this cannot drive
/// rebuilds on its own -- [VideoClip] depends on the frame instead, which
/// changes every frame by construction.
class DecodedVideoFrames extends InheritedWidget {
  const DecodedVideoFrames({
    super.key,
    required this.frames,
    required super.child,
  });

  final VideoFrames? frames;

  static VideoFrames? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DecodedVideoFrames>()?.frames;

  @override
  bool updateShouldNotify(DecodedVideoFrames oldWidget) =>
      !identical(frames, oldWidget.frames);
}

/// Probes every declared clip and opens a decoder for it.
abstract final class VideoPreloader {
  static Future<VideoFrames> open(
    List<VideoTimelineEntry> entries, {
    required int fps,
    required VideoBackend backend,
    String? projectPath,
  }) async {
    final Map<VideoDeclaration, List<VideoFrameSource>> decoders =
        <VideoDeclaration, List<VideoFrameSource>>{};
    final List<String> warnings = <String>[];

    for (final VideoTimelineEntry entry in entries) {
      final String path =
          await backend.resolve(entry.declaration.src, projectPath: projectPath);
      final VideoSourceInfo info = await backend.probe(path);
      final VideoFrameSource decoder = backend.open(
        declaration: entry.declaration,
        startFrame: entry.startFrame,
        endFrame: entry.endFrame,
        fps: fps,
        path: path,
        info: info,
      );

      // Catch a source that runs out mid-window now, by name, rather than
      // letting the last frame silently freeze for two seconds in the export.
      // A looping clip is meant to outlast its source, so it is not a warning.
      final int needed =
          entry.declaration.trimStartInFrames + entry.endFrame - entry.startFrame + 1;
      final int available = info.frameCapacity(fps);
      if (!entry.declaration.loop && needed > available) {
        warnings.add(
          '${entry.declaration.src} is mounted for frames '
          '${entry.startFrame}-${entry.endFrame} and needs $needed source '
          'frames at ${fps}fps, but the file only has $available '
          '(${info.durationInSeconds.toStringAsFixed(2)}s). The last frame '
          'will be held for the remaining ${needed - available}.',
        );
      }

      // Appended, not assigned: the same file in two scenes is two entries
      // sharing one key.
      decoders.putIfAbsent(entry.declaration, () => <VideoFrameSource>[])
          .add(decoder);
    }

    return VideoFrames(decoders)..warnings.addAll(warnings);
  }

}
