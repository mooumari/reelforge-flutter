import 'dart:io';

import 'package:flutter/services.dart';

import '../declarations/manifest.dart';
import 'audio_track.dart';

/// How a declared audio `src` is turned into a file a native encoder can open.
typedef AssetLoader = Future<ByteData> Function(String key);

/// Thrown when a declared sound cannot be found anywhere.
class AudioSourceException implements Exception {
  const AudioSourceException(this.src, this.reason);

  final String src;
  final String reason;

  @override
  String toString() => 'Could not resolve audio "$src": $reason';
}

/// Finds the file behind an [Audio] declaration.
///
/// The same `src` means two different things depending on where the render is
/// happening. On a laptop `assets/music.mp3` is a path relative to the project
/// being rendered, and ffmpeg opens it directly. Inside a running app that same
/// string is an asset key, and the bytes live inside the application bundle --
/// compressed, on iOS not even a file. A native encoder cannot open either.
///
/// So an asset is spilled to a real file once and reused. The extension is
/// kept, because `AVURLAsset` decides what a file is by looking at it.
class AudioSourceResolver {
  AudioSourceResolver({
    required this.cacheDir,
    this.projectPath,
    AssetLoader? loadAsset,
  }) : _loadAsset = loadAsset ?? rootBundle.load;

  /// Where spilled assets are written. Anything already in here is reused.
  final Directory cacheDir;

  /// The project a relative `src` is relative to, when there is one. Null in
  /// an app, where there is no project directory to speak of.
  final String? projectPath;

  final AssetLoader _loadAsset;
  final Map<String, String> _resolved = <String, String>{};

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
      } on AudioSourceException catch (error) {
        failures.add(error.toString());
      }
    }
    return AudioResolution(tracks: tracks, failures: failures);
  }

  /// An absolute path to [src]'s bytes on disk.
  Future<String> pathFor(String src) async {
    final String? already = _resolved[src];
    if (already != null) return already;

    for (final String candidate in <String>[
      src,
      if (projectPath != null && !src.startsWith('/')) '$projectPath/$src',
    ]) {
      final File file = File(candidate);
      if (file.existsSync()) {
        return _resolved[src] = file.absolute.path;
      }
    }

    final ByteData bytes;
    try {
      bytes = await _loadAsset(src);
    } catch (error) {
      throw AudioSourceException(
        src,
        'not a file, and not a loadable asset either ($error). Declare it in '
        'your pubspec under `assets:`, or give an absolute path.',
      );
    }

    final File spilled = File('${cacheDir.path}/${_cacheName(src)}');
    spilled.parent.createSync(recursive: true);
    spilled.writeAsBytesSync(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    return _resolved[src] = spilled.path;
  }

  /// A file name that keeps [src]'s extension and cannot collide with another
  /// key's, since `a/b.mp3` and `a_b.mp3` are different assets.
  static String _cacheName(String src) {
    final int dot = src.lastIndexOf('.');
    final int slash = src.lastIndexOf('/');
    final String extension = dot > slash ? src.substring(dot) : '';
    final String stem = dot > slash ? src.substring(0, dot) : src;
    return '${stem.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}'
        '_${src.hashCode.toUnsigned(32).toRadixString(16)}$extension';
  }
}

/// What [AudioSourceResolver.resolveAll] found, and what it did not.
class AudioResolution {
  const AudioResolution({required this.tracks, required this.failures});

  final List<AudioTrackRequest> tracks;

  /// One message per clip that could not be resolved. Audio is additive, so
  /// these are worth reporting without failing an otherwise correct export.
  final List<String> failures;
}
