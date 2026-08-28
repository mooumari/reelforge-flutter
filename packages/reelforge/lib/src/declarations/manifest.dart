import 'dart:io';

import 'package:flutter/widgets.dart';

/// A piece of audio a composition asked for.
@immutable
class AudioDeclaration {
  const AudioDeclaration({
    required this.src,
    this.volume = 1.0,
    this.trimStartInFrames = 0,
    this.loop = false,
  });

  final String src;
  final double volume;

  /// How far into the source file playback begins.
  final int trimStartInFrames;

  final bool loop;

  /// Identity for aggregation. Two `Audio` widgets with the same parameters
  /// mounted over adjacent frames are the same clip, not two clips.
  String get key => '$src|$volume|$trimStartInFrames|$loop';

  @override
  bool operator ==(Object other) =>
      other is AudioDeclaration && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'Audio($src)';
}

/// An audio clip placed on the composition's timeline.
///
/// The range is derived from which frames the widget was mounted on, so
/// wrapping `Audio` in a [Sequence] positions it without any extra API.
@immutable
class AudioTimelineEntry {
  const AudioTimelineEntry({
    required this.declaration,
    required this.startFrame,
    required this.endFrame,
  });

  final AudioDeclaration declaration;

  /// First frame the clip is audible on.
  final int startFrame;

  /// Last frame the clip is audible on, inclusive.
  final int endFrame;

  int get durationInFrames => endFrame - startFrame + 1;

  @override
  String toString() =>
      '${declaration.src} @ $startFrame-$endFrame ($durationInFrames frames)';
}

/// A video clip a composition asked for.
@immutable
class VideoDeclaration {
  const VideoDeclaration({
    required this.src,
    this.trimStartInFrames = 0,
    this.decodeWidth,
    this.decodeHeight,
    this.loop = false,
  });

  final String src;

  /// How far into the source file the clip begins.
  final int trimStartInFrames;

  /// Decode size. Null decodes at the source's native resolution.
  ///
  /// Worth setting when a 4K source is being drawn into a 1080p composition:
  /// every frame is decoded, uploaded, and scaled, so decoding at the size you
  /// actually paint at is the single biggest lever on video render cost.
  final int? decodeWidth;
  final int? decodeHeight;

  /// Whether the clip restarts when it reaches the end of the source.
  ///
  /// Off by default, because a clip running out is usually a mistake worth
  /// hearing about. On, it is the normal way two seconds of B-roll sit under a
  /// nine-second scene.
  final bool loop;

  /// Identity for aggregation, and the key the decoder set is keyed by. Two
  /// clips differing only in decode size are two decoders, because they cannot
  /// share a pipe.
  String get key => '$src|$trimStartInFrames|'
      '${decodeWidth ?? '-'}x${decodeHeight ?? '-'}|${loop ? 'loop' : 'once'}';

  @override
  bool operator ==(Object other) =>
      other is VideoDeclaration && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'Video($src)';
}

/// A video clip placed on the composition's timeline.
@immutable
class VideoTimelineEntry {
  const VideoTimelineEntry({
    required this.declaration,
    required this.startFrame,
    required this.endFrame,
  });

  final VideoDeclaration declaration;

  /// First frame the clip is visible on.
  final int startFrame;

  /// Last frame the clip is visible on, inclusive.
  final int endFrame;

  int get durationInFrames => endFrame - startFrame + 1;

  @override
  String toString() =>
      '${declaration.src} @ $startFrame-$endFrame ($durationInFrames frames)';
}

/// An image the composition needs resolved before rendering starts.
@immutable
class ImageDeclaration {
  ImageDeclaration(this.provider) : debugLabel = describeProvider(provider);

  final ImageProvider<Object> provider;

  /// Used in error messages and `reelforge inspect`, so it has to name the
  /// actual file rather than the class.
  final String debugLabel;

  static String describeProvider(ImageProvider<Object> provider) {
    return switch (provider) {
      AssetImage(:final String assetName) => assetName,
      ExactAssetImage(:final String assetName) => assetName,
      NetworkImage(:final String url) => url,
      FileImage(:final File file) => file.path,
      MemoryImage() => 'in-memory image (${provider.hashCode})',
      _ => provider.toString(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ImageDeclaration && other.provider == provider;

  @override
  int get hashCode => provider.hashCode;

  @override
  String toString() => debugLabel;
}

/// Everything a composition declared, gathered before a single frame is
/// rasterised.
@immutable
class RenderManifest {
  const RenderManifest({
    required this.audio,
    required this.video,
    required this.images,
    required this.framesVisited,
    required this.elapsed,
  });

  final List<AudioTimelineEntry> audio;
  final List<VideoTimelineEntry> video;
  final List<ImageDeclaration> images;

  /// How many frames the pass built. Every frame, not a sample.
  final int framesVisited;

  final Duration elapsed;

  bool get isEmpty => audio.isEmpty && video.isEmpty && images.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'framesVisited': framesVisited,
        'elapsedMs': elapsed.inMilliseconds,
        'audio': <Object?>[
          for (final AudioTimelineEntry entry in audio)
            <String, Object?>{
              'src': entry.declaration.src,
              'startFrame': entry.startFrame,
              'endFrame': entry.endFrame,
              'volume': entry.declaration.volume,
              'trimStartInFrames': entry.declaration.trimStartInFrames,
              'loop': entry.declaration.loop,
            },
        ],
        'video': <Object?>[
          for (final VideoTimelineEntry entry in video)
            <String, Object?>{
              'src': entry.declaration.src,
              'startFrame': entry.startFrame,
              'endFrame': entry.endFrame,
              'trimStartInFrames': entry.declaration.trimStartInFrames,
              'decodeWidth': entry.declaration.decodeWidth,
              'decodeHeight': entry.declaration.decodeHeight,
            },
        ],
        'images': <Object?>[
          for (final ImageDeclaration image in images) image.debugLabel,
        ],
      };

  @override
  String toString() {
    if (isEmpty) return 'RenderManifest(nothing declared)';
    return 'RenderManifest(${audio.length} audio, ${video.length} video, '
        '${images.length} images, '
        '$framesVisited frames in ${elapsed.inMilliseconds}ms)';
  }
}
