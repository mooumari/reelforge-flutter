import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_encoder/fluttermotion_encoder.dart';
import 'package:path_provider/path_provider.dart';

import 'compositions.dart';
import 'longform.dart';
import 'report_data.dart';

/// Headless in-app export, for verifying that the *app* can make a video.
///
/// This is the same code path the Export button runs, minus the UI: a real
/// Flutter app, the platform's own encoder, and no ffmpeg anywhere. Running it
/// from a script is what makes the claim checkable instead of a screenshot.
///
///     flutter build macos -t lib/export_main.dart
///     .../example.app/Contents/MacOS/example \
///         --composition WeeklyDeals --out /tmp/inapp.mp4
///
/// On Android and iOS there is no argv -- an app is launched, not a process
/// invoked, and `--dart-entrypoint-args` arrives empty. See [_optionsFor].

/// Says something everywhere it might be read.
///
/// `stdout` is a desktop idea: on Android nothing is attached to it, so a
/// headless export there reports nothing at all, success or failure -- which
/// is exactly the case where you most want to know. `print` reaches logcat as
/// well as a terminal. Not `debugPrint`: it throttles and queues, and the
/// `exit` at the end of an export would drop whatever is still in the queue.
// ignore: avoid_print
void _say(String message) => print(message);

/// Where a headless run reads its options and writes its output.
///
/// On a desktop that is the command line and the current directory. A phone
/// has neither: an app is launched rather than a process invoked, so
/// `--dart-entrypoint-args` arrives empty, and the working directory is `/`,
/// which is not writable. Both platforms read the same options from
/// `export_args.txt` in a directory the app owns -- one token per line,
/// exactly the argv the desktop build would have been given -- and write the
/// result beside it. `adb push`/`adb pull` reach Android's; the simulator's
/// container path reaches iOS's.
class _Options {
  const _Options(this.values, this.workingDir);

  final Map<String, String> values;
  final Directory workingDir;

  String? operator [](String key) => values[key];
}

Future<_Options> _optionsFor(List<String> args) async {
  Directory dir = Directory.current;
  List<String> tokens = args;

  if (Platform.isAndroid || Platform.isIOS) {
    dir = Platform.isAndroid
        ? (await getExternalStorageDirectory()) ?? await getTemporaryDirectory()
        : await getApplicationDocumentsDirectory();
    final File argsFile = File('${dir.path}/export_args.txt');
    if (argsFile.existsSync()) {
      tokens = argsFile
          .readAsLinesSync()
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty)
          .toList();
    }
  }

  final Map<String, String> values = <String, String>{};
  for (int i = 0; i < tokens.length - 1; i++) {
    if (tokens[i].startsWith('--')) {
      values[tokens[i].substring(2)] = tokens[i + 1];
    }
  }
  return _Options(values, dir);
}

void main(List<String> args) {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

  final List<Composition> compositions = <Composition>[
    longform,
    helloFlutter,
    weeklyDeals,
    videoShowcase,
    videoProbe,
    videoProbeHalf,
    encoderProbe,
    audioProbe,
    tickerProbe,
  ];

  // A RenderView needs the implicit view, which only exists once the engine
  // has produced a frame.
  binding.addPostFrameCallback((_) async {
    try {
      final _Options options = await _optionsFor(args);
      _say('export_main options: ${options.values} in ${options.workingDir.path}');

      // Same bootstrap the render host runs: data first, then compositions.
      await loadReport();
      final String id = options['composition'] ?? 'WeeklyDeals';
      final Composition composition = compositions.firstWhere(
        (Composition c) => c.id == id,
        orElse: () => throw ArgumentError('No composition "$id"'),
      );

      final Stopwatch stopwatch = Stopwatch()..start();
      final ExportResult result = await InAppExporter.export(
        composition: composition,
        encoder: NativeVideoEncoder(),
        // The one platform-specific step on the way *in*. Without it a
        // composition with a VideoClip refuses to export rather than writing
        // a rectangle of nothing.
        videoBackend:
            NativeVideoBackend(projectPath: options.workingDir.path),
        outputPath: options['out'] ??
            '${options.workingDir.path}/${composition.id}_inapp.mp4',
        scale: double.tryParse(options['scale'] ?? '') ?? 1.0,
        bitrate: int.tryParse(options['bitrate'] ?? ''),
        projectPath: options.workingDir.path,
        onProgress: (ExportProgress p) {
          if (p.frame % 30 == 0 || p.frame == p.totalFrames) {
            _say('frame ${p.frame}/${p.totalFrames}');
          }
        },
      );
      stopwatch.stop();

      for (final String warning in result.warnings) {
        _say('warning: $warning');
      }
      _say('exported ${result.outputPath}');
      _say('${result.width}x${result.height}  '
          '${result.frames} frames  '
          '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s');
      exit(0);
    } catch (error, stack) {
      _say('export failed: $error\n$stack');
      exit(1);
    }
  });

  runApp(const ColoredBox(color: Color(0xFF000000)));
}
