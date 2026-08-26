import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fluttermotion/fluttermotion.dart';

/// Encodes frames with AVFoundation (iOS and macOS).
///
/// Nothing above this class knows it exists: it implements [VideoEncoder], so
/// exporting inside an app runs exactly the pipeline the CLI runs, with the
/// hardware encoder swapped in for ffmpeg.
///
/// ```dart
/// final result = await InAppExporter.export(
///   composition: myPromo,
///   encoder: NativeVideoEncoder(),
///   outputPath: '${dir.path}/promo.mp4',
///   onProgress: (p) => setState(() => _progress = p.fraction),
/// );
/// ```
class NativeVideoEncoder implements VideoEncoder {
  NativeVideoEncoder({@visibleForTesting MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  /// The channel the platform side listens on.
  static const String channelName = 'fluttermotion/encoder';

  final MethodChannel _channel;

  bool _started = false;

  /// Whether this platform has a native encoder at all.
  ///
  /// Android is not implemented yet, so callers can fall back rather than
  /// discovering it as a MissingPluginException mid-export.
  static bool get isSupported => Platform.isIOS || Platform.isMacOS;

  @override
  Future<void> start(EncoderSettings settings) async {
    if (!isSupported) {
      throw EncoderException(
        'NativeVideoEncoder supports iOS and macOS; this is '
        '${Platform.operatingSystem}. Use the ffmpeg-backed CLI, or supply '
        'your own VideoEncoder.',
      );
    }
    await _invoke('start', <String, Object?>{
      'path': settings.outputPath,
      'width': settings.width,
      'height': settings.height,
      'fps': settings.fps,
      'bitrate': settings.effectiveBitrate,
    });
    _started = true;
  }

  @override
  Future<void> addFrame(Uint8List rgba, int frameIndex) async {
    // Awaited per frame, which is what keeps memory flat: the encoder only
    // takes the next frame once it has compressed the last one.
    await _invoke('addFrame', <String, Object?>{
      'frame': rgba,
      'index': frameIndex,
    });
  }

  @override
  Future<void> finish() async {
    await _invoke('finish', null);
    _started = false;
  }

  @override
  Future<void> dispose() async {
    if (!_started) {
      // start() never succeeded, so there is nothing native to release and
      // calling through would only produce a confusing second error.
      return;
    }
    _started = false;
    await _invoke('dispose', null);
  }

  Future<void> _invoke(String method, Map<String, Object?>? arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      throw EncoderException('$method failed: ${error.message}');
    } on MissingPluginException {
      throw const EncoderException(
        'The fluttermotion_encoder plugin is not registered. Add it to your '
        'pubspec and rebuild -- a hot restart is not enough for a new native '
        'plugin.',
      );
    }
  }
}
