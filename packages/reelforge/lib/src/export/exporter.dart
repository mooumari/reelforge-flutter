import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/scheduler.dart';

import '../composition.dart';
import '../declarations/manifest.dart';
import '../declarations/pass.dart';
import '../media/video_backend.dart';
import '../renderer.dart';
import 'audio_sources.dart';
import 'audio_track.dart';
import 'encoder.dart';

/// How far along an export is.
class ExportProgress {
  const ExportProgress({
    required this.frame,
    required this.totalFrames,
    required this.elapsed,
  });

  /// Frames written so far.
  final int frame;
  final int totalFrames;
  final Duration elapsed;

  double get fraction => totalFrames == 0 ? 1 : frame / totalFrames;

  /// Estimated time left, or null before there is enough to estimate from.
  Duration? get remaining {
    if (frame < 2) return null;
    final double perFrame = elapsed.inMicroseconds / frame;
    return Duration(microseconds: (perFrame * (totalFrames - frame)).round());
  }
}

/// What an export produced.
class ExportResult {
  const ExportResult({
    required this.outputPath,
    required this.width,
    required this.height,
    required this.frames,
    required this.elapsed,
    required this.warnings,
  });

  final String outputPath;

  /// Pixel dimensions actually written, which may differ from
  /// `composition.size * scale` -- see [InAppExporter.export].
  final int width;
  final int height;

  final int frames;
  final Duration elapsed;

  /// Things that were declared but not honoured. Empty on a clean export.
  final List<String> warnings;

  @override
  String toString() => 'ExportResult($outputPath, ${width}x$height, '
      '$frames frames in ${elapsed.inMilliseconds}ms)';
}

/// Lets a caller stop an export part way through.
class ExportCancellation {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Thrown when an export is cancelled. The partial file is deleted by the
/// encoder's `dispose`, so a cancelled export leaves nothing half-written.
class ExportCancelled implements Exception {
  const ExportCancelled(this.framesWritten);

  final int framesWritten;

  @override
  String toString() => 'ExportCancelled after $framesWritten frames';
}

/// Renders a composition straight into a [VideoEncoder].
///
/// This is the same pipeline the CLI runs -- declaration pass, preloaded
/// assets, a detached render tree pumped one frame at a time -- with the one
/// platform-specific step (the encoder) swapped out. On a laptop that encoder
/// shells out to ffmpeg; inside a shipping app it is the platform's own
/// hardware encoder, and no binary needs to exist on the device.
///
/// Frames are rendered one at a time with an await between them, so the app's
/// UI keeps running and can show progress while it exports.
abstract final class InAppExporter {
  /// Exports [composition] through [encoder].
  ///
  /// [scale] multiplies the output resolution: `0.5` halves it, `2.0` renders
  /// a 4K master from a 1080p composition. Layout is unaffected -- the tree is
  /// still laid out at the composition's declared size, so text and spacing do
  /// not reflow, only the pixel density changes.
  ///
  /// Output dimensions are rounded to even numbers because H.264 requires it;
  /// [ExportResult.width] and [ExportResult.height] report what was actually
  /// written rather than leaving the caller to assume.
  static Future<ExportResult> export({
    required Composition composition,
    required VideoEncoder encoder,
    required String outputPath,
    double scale = 1.0,
    int? bitrate,
    void Function(ExportProgress)? onProgress,
    ExportCancellation? cancellation,
    VideoBackend? videoBackend,
    String? projectPath,
    Directory? audioCacheDir,
  }) async {
    if (scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'must be greater than zero');
    }

    final List<String> warnings = <String>[];

    // Even dimensions: H.264 encodes in 16x16 macroblocks and chroma is
    // subsampled by two, so an odd width has no valid representation.
    int even(num value) {
      final int rounded = value.round();
      return rounded.isEven ? rounded : rounded - 1;
    }

    final int width = even(composition.width * scale);
    final int height = even(composition.height * scale);
    if (width < 2 || height < 2) {
      throw ArgumentError.value(
        scale,
        'scale',
        'produces a ${width}x$height output, which is too small to encode',
      );
    }
    if (width != (composition.width * scale).round() ||
        height != (composition.height * scale).round()) {
      warnings.add(
        'Output rounded to ${width}x$height; H.264 requires even dimensions.',
      );
    }

    final PreparedComposition prepared = await DeclarationPass.prepare(
      composition,
      videoBackend: videoBackend,
      projectPath: projectPath,
    );

    try {
      final RenderManifest manifest = prepared.manifest;

      // Video is structural: a clip that cannot be decoded leaves a rectangle
      // of nothing where the footage should be. Refusing loudly beats
      // shipping that, so unlike audio this one throws.
      if (manifest.video.isNotEmpty && prepared.videoFrames == null) {
        throw EncoderException(
          'This composition uses ${manifest.video.length} video '
          '${manifest.video.length == 1 ? 'clip' : 'clips'}, but no video '
          'backend was given to decode them with. Pass videoBackend: '
          'FfmpegVideoBackend(...) on a desktop, or NativeVideoBackend() to '
          'decode inside the app.',
        );
      }

      // Audio is additive rather than structural: the frames are still right
      // either way, so nothing here refuses an export. An encoder that cannot
      // mix says so by not implementing the interface, and a sound that cannot
      // be found is reported by name rather than going quietly missing.
      if (manifest.audio.isNotEmpty) {
        if (encoder is AudioCapableEncoder) {
          final AudioResolution audio = await AudioSourceResolver(
            cacheDir: audioCacheDir ??
                Directory('${Directory.systemTemp.path}/reelforge_audio'),
            projectPath: projectPath,
          ).resolveAll(manifest.audio);
          warnings.addAll(audio.failures);
          if (audio.tracks.isNotEmpty) {
            await (encoder as AudioCapableEncoder).setAudio(audio.tracks);
          }
        } else {
          warnings.add(
            '${manifest.audio.length} audio '
            '${manifest.audio.length == 1 ? 'clip was' : 'clips were'} '
            'declared, but this encoder writes video only.',
          );
        }
      }

      // Rendering drives the binding's frame loop, which is only legal between
    // frames. An export started from a button tap can begin inside one.
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await SchedulerBinding.instance.endOfFrame;
    }

    await encoder.start(EncoderSettings(
        outputPath: outputPath,
        width: width,
        height: height,
        fps: composition.fps,
        bitrate: bitrate,
        totalFrames: composition.durationInFrames,
      ));

      final CompositionRenderer renderer =
          prepared.createRenderer(scale: scale);
      final Stopwatch stopwatch = Stopwatch()..start();
      int written = 0;

      try {
        for (int frame = 0; frame < composition.durationInFrames; frame++) {
          if (cancellation?.isCancelled ?? false) {
            throw ExportCancelled(written);
          }

          await prepared.videoFrames?.advanceTo(frame);

          final ByteData rgba = await renderer.renderFrameRgba(frame);
          await encoder.addFrame(
            rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
            frame,
          );

          written++;
          onProgress?.call(ExportProgress(
            frame: written,
            totalFrames: composition.durationInFrames,
            elapsed: stopwatch.elapsed,
          ));
        }
      } finally {
        renderer.dispose();
      }

      await encoder.finish();
      stopwatch.stop();

      return ExportResult(
        outputPath: outputPath,
        width: width,
        height: height,
        frames: written,
        elapsed: stopwatch.elapsed,
        warnings: warnings,
      );
    } finally {
      await prepared.dispose();
      await encoder.dispose();
    }
  }
}
