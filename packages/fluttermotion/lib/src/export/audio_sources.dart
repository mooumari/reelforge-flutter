import 'dart:io';

import '../declarations/manifest.dart';
import '../media/source_files.dart';
import 'audio_track.dart';

/// Finds the file behind an [Audio] declaration.
///
/// A thin layer over [SourceFiles], which does the actual looking: a path
/// relative to the project on a laptop, an asset key spilled to a file inside
/// an app.
class AudioSourceResolver {
  AudioSourceResolver({
    required Directory cacheDir,
    String? projectPath,
    AssetLoader? loadAsset,
  }) : _files = SourceFiles(
          cacheDir: cacheDir,
          projectPath: projectPath,
          loadAsset: loadAsset,
        );

  final SourceFiles _files;

  /// The declared clips, as files, in the order they were declared.
  ///
  /// One clip failing does not lose the others: the failures come back
  /// separately so the caller can report them and mix what it has.
  Future<AudioResolution> resolveAll(List<AudioTimelineEntry> entries) async {
    final List<AudioTrackRequest> tracks = <AudioTrackRequest>[];
    final List<String> failures = <String>[];
    for (final AudioTimelineEntry entry in entries) {
      try {
        tracks.add(
          AudioTrackRequest(
            path: await pathFor(entry.declaration.src),
            startFrame: entry.startFrame,
            endFrame: entry.endFrame,
            volume: entry.declaration.volume,
            trimStartInFrames: entry.declaration.trimStartInFrames,
            loop: entry.declaration.loop,
          ),
        );
      } on SourceFileException catch (error) {
        failures.add(error.toString());
      }
    }
    return AudioResolution(tracks: tracks, failures: failures);
  }

  /// An absolute path to [src]'s bytes on disk.
  Future<String> pathFor(String src) => _files.pathFor(src, kind: 'audio');
}

/// What [AudioSourceResolver.resolveAll] found, and what it did not.
class AudioResolution {
  const AudioResolution({required this.tracks, required this.failures});

  final List<AudioTrackRequest> tracks;

  /// One message per clip that could not be resolved. Audio is additive, so
  /// these are worth reporting without failing an otherwise correct export.
  final List<String> failures;
}
