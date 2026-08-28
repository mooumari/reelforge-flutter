import 'package:flutter/foundation.dart';

/// One sound placed on the timeline, resolved to a file an encoder can open.
///
/// The declaration pass reports what a composition *asked* for -- an asset key,
/// or a path relative to a project. This is the answer to that: a real file,
/// with the timeline placement already worked out in frames.
@immutable
class AudioTrackRequest {
  const AudioTrackRequest({
    required this.path,
    required this.startFrame,
    required this.endFrame,
    required this.volume,
    required this.trimStartInFrames,
    required this.loop,
  });

  /// An absolute path to a file on disk. Not an asset key: an encoder is
  /// native, and native code cannot read a Flutter asset bundle.
  final String path;

  /// First and last frame the clip sounds on, inclusive at both ends.
  final int startFrame;
  final int endFrame;

  final double volume;

  /// How far into the source file playback begins.
  final int trimStartInFrames;

  /// Whether the source repeats to fill its window rather than falling silent.
  final bool loop;

  int get durationInFrames => endFrame - startFrame + 1;

  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'startFrame': startFrame,
        'endFrame': endFrame,
        'volume': volume,
        'trimStartInFrames': trimStartInFrames,
        'loop': loop,
      };

  @override
  String toString() =>
      'AudioTrackRequest($path, $startFrame-$endFrame, volume $volume)';
}

/// A [VideoEncoder] that can also write an audio track.
///
/// Separate from [VideoEncoder] rather than part of it, because an encoder
/// that cannot mix audio is still a perfectly good encoder and should not have
/// to say so in a stub. The exporter asks, and warns when the answer is no.
abstract interface class AudioCapableEncoder {
  /// Declares the audio to mix. Called before `start`, never after.
  ///
  /// The tracks sum: two clips over the same frames are heard together at
  /// their own volumes, rather than being averaged into each other.
  Future<void> setAudio(List<AudioTrackRequest> tracks);
}
