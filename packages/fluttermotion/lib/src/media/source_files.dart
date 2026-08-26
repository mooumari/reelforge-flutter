import 'dart:io';

import 'package:flutter/services.dart';

/// How a declared `src` is turned into bytes.
typedef AssetLoader = Future<ByteData> Function(String key);

/// Thrown when a declared source cannot be found anywhere.
class SourceFileException implements Exception {
  const SourceFileException(this.src, this.kind, this.reason);

  final String src;

  /// What the source was for, so the message names it: `audio`, `video`.
  final String kind;

  final String reason;

  @override
  String toString() => 'Could not resolve $kind "$src": $reason';
}

/// Finds the real file behind a declared `src`.
///
/// The same string means two different things depending on where the render is
/// happening. On a laptop `assets/clip.mp4` is a path relative to the project
/// being rendered, and ffmpeg opens it directly. Inside a running app that same
/// string is an asset key, and the bytes live inside the application bundle --
/// compressed, on iOS not even a file. `AVAssetReader` cannot open either.
///
/// So an asset is spilled to a real file once and reused. The extension is
/// kept, because AVFoundation decides what a file is by looking at it.
class SourceFiles {
  SourceFiles({
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

  /// An absolute path to [src]'s bytes on disk.
  Future<String> pathFor(String src, {String kind = 'source'}) async {
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
      throw SourceFileException(
        src,
        kind,
        'not a file, and not a loadable asset either ($error). Declare it in '
        'your pubspec under `assets:`, or give an absolute path.',
      );
    }

    final File spilled = File('${cacheDir.path}/${cacheName(src)}');
    spilled.parent.createSync(recursive: true);
    spilled.writeAsBytesSync(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    return _resolved[src] = spilled.path;
  }

  /// A file name that keeps [src]'s extension and cannot collide with another
  /// key's, since `a/b.mp3` and `a_b.mp3` are different assets.
  static String cacheName(String src) {
    final int dot = src.lastIndexOf('.');
    final int slash = src.lastIndexOf('/');
    final String extension = dot > slash ? src.substring(dot) : '';
    final String stem = dot > slash ? src.substring(0, dot) : src;
    return '${stem.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}'
        '_${src.hashCode.toUnsigned(32).toRadixString(16)}$extension';
  }
}
