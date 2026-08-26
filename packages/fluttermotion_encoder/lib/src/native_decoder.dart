import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fluttermotion/fluttermotion.dart';

/// Decodes video with AVFoundation (iOS and macOS).
///
/// Nothing above this class knows it exists: it implements [VideoBackend], so
/// a composition with a [VideoClip] exports inside an app through exactly the
/// pipeline the CLI runs, with `AVAssetReader` swapped in for ffmpeg.
///
/// ```dart
/// await InAppExporter.export(
///   composition: myPromo,
///   encoder: NativeVideoEncoder(),
///   videoBackend: NativeVideoBackend(),
///   outputPath: '${dir.path}/promo.mp4',
/// );
/// ```
class NativeVideoBackend implements VideoBackend {
  NativeVideoBackend({
    Directory? cacheDir,
    String? projectPath,
    @visibleForTesting MethodChannel? channel,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _files = SourceFiles(
          cacheDir: cacheDir ??
              Directory('${Directory.systemTemp.path}/fluttermotion_video'),
          projectPath: projectPath,
        );

  /// The channel the platform side listens on.
  static const String channelName = 'fluttermotion/decoder';

  final MethodChannel _channel;
  final SourceFiles _files;

  /// Whether this platform has a native decoder at all.
  static bool get isSupported => Platform.isIOS || Platform.isMacOS;

  @override
  Future<String> resolve(String src, {String? projectPath}) {
    // Inside an app a src is usually an asset key with no file behind it, so
    // this may spill bundle bytes to disk. AVAssetReader needs a real file.
    return _files.pathFor(src, kind: 'video');
  }

  @override
  Future<VideoSourceInfo> probe(String path) async {
    _requireSupport();
    final Map<Object?, Object?> info = (await _channel.invokeMethod<Object?>(
      'probe',
      <String, Object?>{'path': path},
    ))! as Map<Object?, Object?>;
    return VideoSourceInfo(
      width: info['width']! as int,
      height: info['height']! as int,
      durationInSeconds: (info['duration']! as num).toDouble(),
    );
  }

  @override
  VideoFrameSource open({
    required VideoDeclaration declaration,
    required int startFrame,
    required int endFrame,
    required int fps,
    required String path,
    required VideoSourceInfo info,
  }) {
    _requireSupport();
    return NativeVideoFrameSource(
      channel: _channel,
      declaration: declaration,
      startFrame: startFrame,
      endFrame: endFrame,
      fps: fps,
      path: path,
      info: info,
    );
  }

  void _requireSupport() {
    if (isSupported) return;
    throw StateError(
      'NativeVideoBackend supports iOS and macOS; this is '
      '${Platform.operatingSystem}. Use FfmpegVideoBackend on a desktop, or '
      'supply your own VideoBackend.',
    );
  }
}

/// One clip, streamed from the platform decoder.
///
/// The shape mirrors the ffmpeg decoder deliberately: rendering walks frames in
/// order, so this streams, and only a backwards or non-adjacent jump pays for a
/// seek. The difference is where the frames come from.
class NativeVideoFrameSource implements VideoFrameSource {
  NativeVideoFrameSource({
    required MethodChannel channel,
    required this.declaration,
    required this.startFrame,
    required this.endFrame,
    required this.fps,
    required this.path,
    required this.info,
  })  : _channel = channel,
        width = declaration.decodeWidth ?? info.width,
        height = declaration.decodeHeight ?? info.height;

  final MethodChannel _channel;
  final VideoDeclaration declaration;

  @override
  final int startFrame;

  @override
  final int endFrame;

  final int fps;
  final String path;
  final VideoSourceInfo info;

  /// Decoded pixel dimensions, which may be smaller than the source.
  final int width;
  final int height;

  int? _handle;

  /// The last *source* frame asked of the open reader.
  ///
  /// Source rather than composition frames, because a looping clip runs the
  /// composition forward while sending the source back to the start. Checking
  /// continuity in source terms makes the wrap seek for the same reason a
  /// backwards scrub does, rather than needing a case of its own.
  ///
  /// Note this counts in the *composition's* frame rate, not the source's: a
  /// source frame here is an instant, and the native side finds whichever of
  /// its own frames is on screen then.
  int? _cursor;

  ui.Image? _current;
  int? _currentFrame;

  @override
  bool get exhausted => _exhausted;
  bool _exhausted = false;

  /// The source frame the file ran dry at, once it has.
  ///
  /// Kept so that holding the last frame stays free: without it every frame
  /// past the end re-seeks and re-reads to get nothing back.
  int? _driedAt;

  /// How many source frames the clip has to play with after its trim.
  int get _loopLength =>
      (info.frameCapacity(fps) - declaration.trimStartInFrames)
          .clamp(1, 1 << 31);

  @override
  int sourceFrameFor(int compositionFrame) {
    final int offset = compositionFrame - startFrame;
    return declaration.trimStartInFrames +
        (declaration.loop ? offset % _loopLength : offset);
  }

  @override
  Future<ui.Image?> frameAt(int compositionFrame) async {
    if (_currentFrame == compositionFrame) return _current;

    final int sourceFrame = sourceFrameFor(compositionFrame);

    // Already known to be past the end. Scrubbing back before that point is
    // still a normal seek.
    if (_driedAt != null && sourceFrame >= _driedAt!) {
      _currentFrame = compositionFrame;
      return _current;
    }

    if (_handle == null) {
      await _open(compositionFrame);
    } else if (_cursor == null || sourceFrame < _cursor!) {
      // Only backwards, or after running dry -- both leave the reader unable
      // to reach the instant by reading on. A reader cannot be rewound, so
      // going back is a new one; going forward is just more reading, and the
      // native side does that itself on the way to the instant asked for.
      await _seekTo(compositionFrame);
    }

    final Uint8List? bytes = await _channel.invokeMethod<Uint8List>(
      'nextFrame',
      <String, Object?>{'handle': _handle, 'sourceFrame': sourceFrame},
    );
    if (bytes == null) {
      // The source is shorter than the window it was mounted for. Hold the
      // last frame rather than flashing to nothing; the declaration pass has
      // already warned about this by name.
      _exhausted = true;
      _driedAt = sourceFrame;
      _cursor = null;
      _currentFrame = compositionFrame;
      return _current;
    }

    _cursor = sourceFrame;
    _currentFrame = compositionFrame;
    final ui.Image decoded = await _decodeRgba(bytes, width, height);
    _current?.dispose();
    _current = decoded;
    return _current;
  }

  Future<void> _open(int compositionFrame) async {
    final Map<Object?, Object?> opened =
        (await _channel.invokeMethod<Object?>('open', <String, Object?>{
      'path': path,
      'fps': fps,
      'startSourceFrame': sourceFrameFor(compositionFrame),
      if (declaration.decodeWidth != null || declaration.decodeHeight != null)
        'width': width,
      if (declaration.decodeWidth != null || declaration.decodeHeight != null)
        'height': height,
    }))! as Map<Object?, Object?>;
    _handle = opened['handle']! as int;
    _cursor = sourceFrameFor(compositionFrame);
    _exhausted = false;
    _driedAt = null;
  }

  Future<void> _seekTo(int compositionFrame) async {
    await _channel.invokeMethod<void>('seek', <String, Object?>{
      'handle': _handle,
      'sourceFrame': sourceFrameFor(compositionFrame),
    });
    _cursor = sourceFrameFor(compositionFrame);
    _exhausted = false;
    _driedAt = null;
  }

  @override
  Future<void> dispose() async {
    final int? handle = _handle;
    _handle = null;
    _cursor = null;
    if (handle != null) {
      await _channel.invokeMethod<void>(
        'close',
        <String, Object?>{'handle': handle},
      );
    }
    _current?.dispose();
    _current = null;
    _currentFrame = null;
  }
}

Future<ui.Image> _decodeRgba(Uint8List bytes, int width, int height) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bytes,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
