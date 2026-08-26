import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'composition.dart';
import 'declarations/manifest.dart';
import 'declarations/pass.dart';
import 'media/spawn.dart';
import 'renderer.dart';

/// Entry point for a render host binary.
///
/// A composition is Flutter code, so it can only run inside a Flutter engine.
/// The CLI therefore builds *your* project with an entry point that calls this,
/// then spawns the resulting binary once per shard:
///
/// ```dart
/// // lib/render_main.dart
/// void main(List<String> args) => renderMain(args, <Composition>[myPromo]);
/// ```
///
/// This function never returns -- it exits the process.
Future<void> renderMain(
  List<String> args,
  List<Composition> compositions,
) async {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  final _Args parsed = _Args(args);

  // The implicit view must exist before a RenderView can be built against it.
  binding.addPostFrameCallback((_) async {
    try {
      if (parsed.has('list')) {
        stdout.writeln(jsonEncode(<String, Object?>{
          'event': 'compositions',
          'compositions': <Object?>[
            for (final Composition c in compositions)
              <String, Object?>{
                'id': c.id,
                'width': c.width,
                'height': c.height,
                'fps': c.fps,
                'durationInFrames': c.durationInFrames,
              },
          ],
        }));
        exit(0);
      }
      if (parsed.has('manifest')) {
        await _emitManifest(parsed, compositions);
        exit(0);
      }
      await _renderShard(parsed, compositions);
      exit(0);
    } catch (error, stack) {
      stdout.writeln(jsonEncode(<String, Object?>{
        'event': 'error',
        'message': error.toString(),
        'stack': stack.toString(),
      }));
      exit(1);
    }
  });

  runApp(const _HostSurface());
}

/// The host still needs a real view for the engine to run a raster thread.
/// Nothing is drawn into it.
class _HostSurface extends StatelessWidget {
  const _HostSurface();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFF000000));
}

/// ffprobe lives next to ffmpeg in every distribution, so deriving it beats
/// making every caller pass both.
String _ffprobeFor(_Args args) {
  final String? explicit = args.optional('ffprobe');
  if (explicit != null) return explicit;
  final String ffmpeg = args.optional('ffmpeg') ?? 'ffmpeg';
  final int slash = ffmpeg.lastIndexOf('/');
  if (slash == -1) return 'ffprobe';
  return '${ffmpeg.substring(0, slash)}/ffprobe';
}

Future<void> _emitManifest(_Args args, List<Composition> compositions) async {
  final Composition composition = _select(args, compositions);
  final RenderManifest manifest = DeclarationPass.run(composition);
  stdout.writeln(jsonEncode(<String, Object?>{
    'event': 'manifest',
    'composition': composition.id,
    ...manifest.toJson(),
  }));
}

Composition _select(_Args args, List<Composition> compositions) {
  final String id = args.require('composition');
  final Composition base = compositions.firstWhere(
    (Composition c) => c.id == id,
    orElse: () => throw ArgumentError(
      'No composition with id "$id". Available: '
      '${compositions.map((Composition c) => c.id).join(', ')}',
    ),
  );
  return base.copyWith(
    width: args.optionalInt('width'),
    height: args.optionalInt('height'),
    fps: args.optionalInt('fps'),
    durationInFrames: args.optionalInt('duration-in-frames'),
  );
}

Future<void> _renderShard(_Args args, List<Composition> compositions) async {
  final Composition composition = _select(args, compositions);

  final int start = args.optionalInt('start') ?? 0;
  final int end = args.optionalInt('end') ?? composition.durationInFrames;
  final String out = args.require('out');
  final String ffmpegPath = args.optional('ffmpeg') ?? 'ffmpeg';
  final String codec = args.optional('codec') ?? 'h264_videotoolbox';
  final String bitrate = args.optional('bitrate') ?? '12M';

  final Process ffmpeg = await Spawn.start(ffmpegPath, <String>[
    '-y',
    '-hide_banner',
    '-loglevel', 'error',
    '-f', 'rawvideo',
    '-pix_fmt', 'rgba',
    '-s', '${composition.width}x${composition.height}',
    '-r', '${composition.fps}',
    '-i', '-',
    '-c:v', codec,
    '-b:v', bitrate,
    '-pix_fmt', 'yuv420p',
    out,
  ]);

  final StringBuffer ffmpegErrors = StringBuffer();
  ffmpeg.stderr.transform(utf8.decoder).listen(ffmpegErrors.write);
  ffmpeg.stdout.drain<void>();

  // Sweep the timeline and get every declared asset ready before rasterising,
  // so no frame can ever wait on I/O mid-render.
  final PreparedComposition prepared = await DeclarationPass.prepare(
    composition,
    ffmpeg: ffmpegPath,
    ffprobe: _ffprobeFor(args),
    projectPath: Directory(args.optional('project') ?? '.').absolute.path,
  );
  final CompositionRenderer renderer = prepared.createRenderer();

  stdout.writeln(jsonEncode(<String, Object?>{
    'event': 'manifest',
    'composition': composition.id,
    ...prepared.manifest.toJson(),
    'videoWarnings': prepared.videoFrames?.warnings ?? const <String>[],
  }));

  final Stopwatch stopwatch = Stopwatch()..start();

  try {
    for (int frame = start; frame < end; frame++) {
      // Decode this frame's video before building, so the tree can paint it
      // synchronously and the render stays a pure function of frame number.
      await prepared.videoFrames?.advanceTo(frame);

      final ByteData rgba = await renderer.renderFrameRgba(frame);
      ffmpeg.stdin.add(rgba.buffer.asUint8List(
        rgba.offsetInBytes,
        rgba.lengthInBytes,
      ));
      await ffmpeg.stdin.flush();

      // Cheap heartbeat so the CLI can show real progress rather than a spinner.
      stdout.writeln(jsonEncode(<String, Object?>{
        'event': 'frame',
        'frame': frame,
      }));
    }
  } finally {
    renderer.dispose();
    await prepared.dispose();
  }

  await ffmpeg.stdin.close();
  final int code = await ffmpeg.exitCode;
  stopwatch.stop();

  if (code != 0) {
    throw StateError(
      'ffmpeg exited with $code.\n${ffmpegErrors.toString().trim()}',
    );
  }

  stdout.writeln(jsonEncode(<String, Object?>{
    'event': 'shard-done',
    'start': start,
    'end': end,
    'frames': end - start,
    'elapsed_ms': stopwatch.elapsedMilliseconds,
    'out': out,
  }));
}

/// Minimal `--key=value` / `--key value` / `--flag` parser.
///
/// Deliberately dependency-free: this package must stay importable by any
/// Flutter app without dragging in a CLI argument library.
class _Args {
  _Args(List<String> raw) {
    for (int i = 0; i < raw.length; i++) {
      final String token = raw[i];
      if (!token.startsWith('--')) continue;
      final String body = token.substring(2);
      final int eq = body.indexOf('=');
      if (eq >= 0) {
        _values[body.substring(0, eq)] = body.substring(eq + 1);
      } else if (i + 1 < raw.length && !raw[i + 1].startsWith('--')) {
        _values[body] = raw[++i];
      } else {
        _values[body] = 'true';
      }
    }
  }

  final Map<String, String> _values = <String, String>{};

  bool has(String key) => _values.containsKey(key);

  String? optional(String key) => _values[key];

  String require(String key) {
    final String? value = _values[key];
    if (value == null) throw ArgumentError('Missing required --$key');
    return value;
  }

  int? optionalInt(String key) {
    final String? value = _values[key];
    if (value == null) return null;
    final int? parsed = int.tryParse(value);
    if (parsed == null) {
      throw ArgumentError('--$key must be an integer, got "$value"');
    }
    return parsed;
  }
}
