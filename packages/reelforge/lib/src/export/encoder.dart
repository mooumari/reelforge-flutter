import 'dart:typed_data';

/// Somewhere frames can be written to make a video file.
///
/// The exporter does not know or care whether this is ffmpeg on a laptop or
/// AVAssetWriter on a phone. That is the whole point: the composition, the
/// renderer and the declaration pass are already platform-free, so putting the
/// one platform-specific step behind an interface is what makes exporting from
/// inside a running app the same code path as exporting from the CLI.
abstract interface class VideoEncoder {
  /// Opens the output. Called once, before any frame.
  Future<void> start(EncoderSettings settings);

  /// Appends one frame of raw RGBA, `width * height * 4` bytes, in order.
  Future<void> addFrame(Uint8List rgba, int frameIndex);

  /// Closes the output. The file is only complete once this returns.
  Future<void> finish();

  /// Abandons the output and releases resources. Safe to call at any point,
  /// including after [finish].
  Future<void> dispose();
}

/// Everything an encoder needs to know before the first frame.
class EncoderSettings {
  const EncoderSettings({
    required this.outputPath,
    required this.width,
    required this.height,
    required this.fps,
    this.bitrate,
    this.totalFrames,
  });

  final String outputPath;
  final int width;
  final int height;
  final int fps;

  /// Target bits per second. Null lets the encoder choose from the dimensions.
  final int? bitrate;

  /// How many frames the whole export is, when the caller knows in advance.
  ///
  /// An encoder writing an audio track needs this before the first frame: the
  /// sound is clamped to the video's length, and it cannot wait until the
  /// length is known to find that out.
  final int? totalFrames;

  /// A reasonable H.264 bitrate for these dimensions.
  ///
  /// Roughly 0.1 bits per pixel per frame, which holds up for the busy,
  /// high-contrast content compositions tend to produce. Deliberately not a
  /// fixed number: 12 Mbps is generous for 720p and thin for 4K.
  int get effectiveBitrate =>
      bitrate ?? (width * height * fps * 0.1).round().clamp(1000000, 80000000);

  @override
  String toString() =>
      'EncoderSettings(${width}x$height @${fps}fps -> $outputPath)';
}

/// Thrown when an encoder cannot do what a composition asks of it.
class EncoderException implements Exception {
  const EncoderException(this.message);

  final String message;

  @override
  String toString() => 'EncoderException: $message';
}
