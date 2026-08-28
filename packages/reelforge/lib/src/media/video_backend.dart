import 'dart:io';
import 'dart:ui' as ui;

import '../declarations/manifest.dart';
import 'ffmpeg_paths.dart';
import 'video_decoder.dart';

/// One clip's pixels, frame by frame.
///
/// The contract is deliberately narrow: given a composition frame inside the
/// clip's window, hand back the image that belongs on it. How that happens --
/// a pipe from ffmpeg, an `AVAssetReader`, a `MediaCodec` -- is the backend's
/// business and nothing above this line knows.
abstract interface class VideoFrameSource {
  /// Composition frame the clip first appears on.
  int get startFrame;

  /// Composition frame the clip last appears on, inclusive.
  int get endFrame;

  /// The source frame index a composition frame maps to.
  ///
  /// Absolute, in source time, which is what makes it independent of where
  /// decoding started -- the property that lets shards render in parallel and
  /// still agree.
  int sourceFrameFor(int compositionFrame);

  /// The decoded image for [compositionFrame], or null if there is none.
  Future<ui.Image?> frameAt(int compositionFrame);

  /// True once the source ran out before the clip's window did.
  bool get exhausted;

  Future<void> dispose();
}

/// Somewhere video can be decoded from.
///
/// The counterpart to [VideoEncoder]: the one platform-specific step on the
/// way *in*, behind an interface, so that a composition containing a
/// [VideoClip] is the same composition whether it is rendered by a CLI that
/// can spawn ffmpeg or exported from inside an app that cannot.
abstract interface class VideoBackend {
  /// Turns a declared `src` into something [probe] and [open] can read.
  ///
  /// The same string means different things in different places: on a laptop
  /// `assets/clip.mp4` is a path relative to the project, inside an app it is
  /// an asset key with no file behind it.
  Future<String> resolve(String src, {String? projectPath});

  /// Reads a source's dimensions and duration without decoding it.
  Future<VideoSourceInfo> probe(String path);

  /// Opens a decoder for one clip.
  VideoFrameSource open({
    required VideoDeclaration declaration,
    required int startFrame,
    required int endFrame,
    required int fps,
    required String path,
    required VideoSourceInfo info,
  });
}

/// Decodes with ffmpeg, in a process of its own.
///
/// What the CLI uses, and what the preview uses when it can find an ffmpeg.
class FfmpegVideoBackend implements VideoBackend {
  const FfmpegVideoBackend({required this.ffmpeg, required this.ffprobe});

  final String ffmpeg;
  final String ffprobe;

  /// A backend built from whatever ffmpeg is installed, or null if none is.
  ///
  /// For callers that have to look rather than being told -- the preview is
  /// just `flutter run` and gets no `--ffmpeg` flag.
  static FfmpegVideoBackend? findOnPath() {
    final String? ffmpeg = FfmpegPaths.find('ffmpeg');
    final String? ffprobe = FfmpegPaths.find('ffprobe');
    if (ffmpeg == null || ffprobe == null) return null;
    return FfmpegVideoBackend(ffmpeg: ffmpeg, ffprobe: ffprobe);
  }

  @override
  Future<String> resolve(String src, {String? projectPath}) async {
    // ffmpeg reads the file directly and knows nothing about the asset bundle,
    // so a clip's src here is a filesystem path relative to the project.
    final String path = src.startsWith('/') || projectPath == null
        ? src
        : '$projectPath/$src';
    if (!File(path).existsSync()) {
      throw StateError(
        'Video clip not found: $path\n'
        'A clip\'s src is a filesystem path relative to the project being '
        'rendered, not a Flutter asset key -- ffmpeg reads the file '
        'directly and knows nothing about the asset bundle.',
      );
    }
    return path;
  }

  @override
  Future<VideoSourceInfo> probe(String path) => probeVideo(ffprobe, path);

  @override
  VideoFrameSource open({
    required VideoDeclaration declaration,
    required int startFrame,
    required int endFrame,
    required int fps,
    required String path,
    required VideoSourceInfo info,
  }) {
    return VideoDecoder(
      declaration: declaration,
      startFrame: startFrame,
      endFrame: endFrame,
      fps: fps,
      path: path,
      ffmpeg: ffmpeg,
      info: info,
    );
  }
}
