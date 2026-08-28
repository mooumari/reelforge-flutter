import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../declarations/manifest.dart';
import 'frame_reader.dart';
import 'video_backend.dart';
import 'spawn.dart';

/// What ffprobe knows about a video file.
class VideoSourceInfo {
  const VideoSourceInfo({
    required this.width,
    required this.height,
    required this.durationInSeconds,
    this.declaresColour,
  });

  final int width;
  final int height;
  final double durationInSeconds;

  /// Whether the file says which colour matrix its pixels were written with.
  ///
  /// Null when the backend cannot tell, which is not the same as `false` and
  /// must not be reported as one. ffprobe always can; a platform decoder that
  /// does not expose the container's tags leaves this null and stays quiet.
  ///
  /// A file that says nothing is not neutral, it is ambiguous: every decoder
  /// guesses, mostly from the frame height, and they do not all guess the
  /// same. An untagged 720p clip decoded by ffmpeg and by VideoToolbox comes
  /// out visibly different, which is a real defect that only appears when a
  /// composition is exported on two platforms and compared.
  final bool? declaresColour;

  /// How many composition frames the source can cover at [fps].
  int frameCapacity(int fps) => (durationInSeconds * fps).floor();

  @override
  String toString() =>
      '${width}x$height, ${durationInSeconds.toStringAsFixed(2)}s';
}

/// Reads a video file's dimensions and duration without decoding it.
Future<VideoSourceInfo> probeVideo(String ffprobe, String path) async {
  final ProcessResult result = await Spawn.run(ffprobe, <String>[
    '-v', 'error',
    '-select_streams', 'v:0',
    '-show_entries', 'stream=width,height,color_space:format=duration',
    '-of', 'json',
    path,
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'Could not probe $path.\n${(result.stderr as String).trim()}',
    );
  }

  final Map<String, Object?> json =
      jsonDecode(result.stdout as String) as Map<String, Object?>;
  final List<Object?> streams =
      (json['streams'] as List<Object?>?) ?? const <Object?>[];
  if (streams.isEmpty) {
    throw StateError('$path has no video stream.');
  }
  final Map<String, Object?> stream = streams.first! as Map<String, Object?>;
  final Map<String, Object?> format =
      (json['format'] as Map<String, Object?>?) ?? const <String, Object?>{};

  // In JSON output ffprobe drops unknown fields rather than writing them, so
  // an absent key is the untagged case rather than the can't-tell one. (The
  // default text output does print `color_space=unknown`, which is why this
  // reads both ways.)
  final String? colourSpace = stream['color_space'] as String?;

  return VideoSourceInfo(
    width: stream['width']! as int,
    height: stream['height']! as int,
    durationInSeconds:
        double.tryParse((format['duration'] as String?) ?? '') ?? 0,
    declaresColour: colourSpace != null &&
        colourSpace.isNotEmpty &&
        colourSpace != 'unknown',
  );
}

/// Pulls one decoded frame per composition frame out of a video file.
///
/// ## Why this is not a seek-per-frame
///
/// Rendering walks frames in order, so the decoder streams: ffmpeg is started
/// once at the entry point and each composition frame reads the next raw RGBA
/// frame off the pipe. A backwards or non-adjacent jump (preview scrubbing)
/// restarts the process, which is the only expensive path.
///
/// ## Why the mapping is shard-independent
///
/// Frames are rendered by several processes over different ranges, so the
/// decoder must land on the *same* source frame whether it entered the clip at
/// its start or half way through. Naive `-ss` cannot promise that: input
/// seeking rebases timestamps to zero, so the `fps` filter's sampling grid is
/// anchored wherever the seek happened to land, and a seek that falls between
/// two source frames shifts every subsequent frame by one.
///
/// `-copyts` keeps the source's absolute timestamps, and the `fps` filter's
/// grid is anchored at the seek point -- which is itself an exact multiple of
/// `1 / fps`, so the sample times are a suffix of the same absolute grid a
/// full-timeline decode would use. Entering a clip at frame 60 therefore lands
/// on precisely the frame a single-process render puts there.
///
/// Anchoring at absolute zero instead (`start_time=0`) is subtly wrong: the
/// `fps` filter *pads* from its anchor, so seeking an hour in would emit an
/// hour of duplicated first frames before the real content.
class VideoDecoder implements VideoFrameSource {
  VideoDecoder({
    required this.declaration,
    required this.startFrame,
    required this.endFrame,
    required this.fps,
    required this.path,
    required this.ffmpeg,
    required this.info,
  })  : width = declaration.decodeWidth ?? info.width,
        height = declaration.decodeHeight ?? info.height;

  final VideoDeclaration declaration;

  /// Composition frame the clip first appears on.
  @override
  final int startFrame;

  /// Composition frame the clip last appears on, inclusive.
  @override
  final int endFrame;

  final int fps;
  final String path;
  final String ffmpeg;
  final VideoSourceInfo info;

  /// Decoded pixel dimensions, which may be smaller than the source.
  final int width;
  final int height;

  int get _frameBytes => width * height * 4;

  Process? _process;
  FrameReader? _reader;
  StringBuffer? _errors;

  /// The next *source* frame the open pipe will yield.
  ///
  /// Source rather than composition frames, because a looping clip runs the
  /// composition forward while sending the source back to the start. Checking
  /// continuity in source terms makes the wrap restart the pipe for the same
  /// reason a backwards scrub does, rather than needing a case of its own.
  int? _cursor;

  ui.Image? _current;
  int? _currentFrame;

  /// True once the source ran out before the clip's window did.
  @override
  bool get exhausted => _exhausted;
  bool _exhausted = false;

  /// The source frame the file ran dry at, once it has.
  ///
  /// Kept so that holding the last frame stays free. Without it every frame
  /// past the end starts a fresh ffmpeg, decodes the whole file, and gets
  /// nothing -- a clip mounted for seven seconds longer than it lasts cost 210
  /// process spawns and dominated the render.
  int? _driedAt;

  /// How many source frames the clip has to play with after its trim.
  ///
  /// The length a loop wraps at. Clamped to at least one so a source shorter
  /// than its own trim cannot divide by zero.
  int get _loopLength =>
      (info.frameCapacity(fps) - declaration.trimStartInFrames)
          .clamp(1, 1 << 31);

  /// The source frame index this composition frame maps to.
  ///
  /// Absolute, in source time -- which is exactly what makes it independent of
  /// where decoding started. A looping clip wraps here, so every other part of
  /// the decoder can go on believing frames are a straight line.
  @override
  int sourceFrameFor(int compositionFrame) {
    final int offset = compositionFrame - startFrame;
    return declaration.trimStartInFrames +
        (declaration.loop ? offset % _loopLength : offset);
  }

  /// Decodes [compositionFrame], reusing the open pipe when it is the next one.
  @override
  Future<ui.Image?> frameAt(int compositionFrame) async {
    if (_currentFrame == compositionFrame) return _current;

    final int sourceFrame = sourceFrameFor(compositionFrame);

    // Already known to be past the end. Scrubbing back before that point is
    // still a normal restart.
    if (_driedAt != null && sourceFrame >= _driedAt!) {
      _currentFrame = compositionFrame;
      return _current;
    }

    if (_process == null || _cursor != sourceFrame) {
      await _restartAt(compositionFrame);
    }

    final Uint8List? bytes = await _reader!.read(_frameBytes);
    if (bytes == null) {
      // The source is shorter than the window it was mounted for. Hold the
      // last frame rather than flashing to nothing; `prepare` has already
      // warned about this by name.
      _exhausted = true;
      _driedAt = sourceFrame;
      _cursor = null;
      _currentFrame = compositionFrame;
      return _current;
    }

    _cursor = _cursor! + 1;
    _currentFrame = compositionFrame;
    final ui.Image decoded = await _decodeRgba(bytes, width, height);
    _current?.dispose();
    _current = decoded;
    return _current;
  }

  Future<void> _restartAt(int compositionFrame) async {
    await _stop();

    final int sourceFrame = sourceFrameFor(compositionFrame);
    final double seekSeconds = sourceFrame / fps;

    final String seek = seekSeconds.toStringAsFixed(6);

    final String filters = <String>[
      // Anchoring the grid at the seek point rather than at zero avoids the
      // filter padding the gap with duplicates, while staying phase-aligned:
      // seekSeconds is an exact multiple of 1/fps, so these sample times are a
      // suffix of the grid a decode from frame 0 would produce.
      'fps=$fps:start_time=$seek',
      if (declaration.decodeWidth != null || declaration.decodeHeight != null)
        'scale=$width:$height',
      'format=rgba',
    ].join(',');

    final Process process = await Spawn.start(ffmpeg, <String>[
      '-hide_banner',
      '-loglevel', 'error',
      // Seek before -i so ffmpeg skips rather than decodes the skipped part.
      '-ss', seek,
      // Without this, seeking rebases timestamps to zero, and the grid anchor
      // above -- expressed in the source's absolute time -- would not match.
      '-copyts',
      '-i', path,
      '-vf', filters,
      '-f', 'rawvideo',
      '-pix_fmt', 'rgba',
      '-',
    ]);

    final StringBuffer errors = StringBuffer();
    process.stderr.transform(utf8.decoder).listen(errors.write);

    _process = process;
    _errors = errors;
    _reader = FrameReader(process.stdout, maxBufferedBytes: _frameBytes * 4);
    _cursor = sourceFrame;
    _exhausted = false;
    _driedAt = null;
  }

  Future<void> _stop() async {
    final Process? process = _process;
    _process = null;
    _reader?.cancel();
    _reader = null;
    _cursor = null;
    if (process != null) {
      process.kill();
      await process.exitCode;
    }
  }

  @override
  Future<void> dispose() async {
    await _stop();
    _current?.dispose();
    _current = null;
    _currentFrame = null;
  }

  /// Diagnostics from the last ffmpeg process, for error messages.
  String get lastErrors => _errors?.toString().trim() ?? '';
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
