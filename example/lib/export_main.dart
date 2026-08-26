import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_encoder/fluttermotion_encoder.dart';

import 'compositions.dart';

/// Headless in-app export, for verifying that the *app* can make a video.
///
/// This is the same code path the Export button runs, minus the UI: a real
/// Flutter app, the platform's own encoder, and no ffmpeg anywhere. Running it
/// from a script is what makes the claim checkable instead of a screenshot.
///
///     flutter build macos -t lib/export_main.dart
///     .../example.app/Contents/MacOS/example \
///         --composition WeeklyDeals --out /tmp/inapp.mp4
void main(List<String> args) {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> options = <String, String>{};
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i].startsWith('--')) options[args[i].substring(2)] = args[i + 1];
  }

  final List<Composition> compositions = <Composition>[
    helloFlutter,
    weeklyDeals,
    videoShowcase,
    videoProbe,
    audioProbe,
    tickerProbe,
  ];

  // A RenderView needs the implicit view, which only exists once the engine
  // has produced a frame.
  binding.addPostFrameCallback((_) async {
    try {
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
        videoBackend: NativeVideoBackend(projectPath: Directory.current.path),
        // systemTemp so this works unchanged inside an iOS app sandbox,
        // where absolute paths like /tmp are not writable.
        outputPath: options['out'] ??
            '${Directory.systemTemp.path}/${composition.id}_inapp.mp4',
        scale: double.tryParse(options['scale'] ?? '') ?? 1.0,
        projectPath: Directory.current.path,
        onProgress: (ExportProgress p) {
          if (p.frame % 30 == 0 || p.frame == p.totalFrames) {
            stdout.writeln('frame ${p.frame}/${p.totalFrames}');
          }
        },
      );
      stopwatch.stop();

      for (final String warning in result.warnings) {
        stdout.writeln('warning: $warning');
      }
      stdout.writeln('exported ${result.outputPath}');
      stdout.writeln('${result.width}x${result.height}  '
          '${result.frames} frames  '
          '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s');
      exit(0);
    } catch (error, stack) {
      stderr.writeln('export failed: $error\n$stack');
      exit(1);
    }
  });

  runApp(const ColoredBox(color: Color(0xFF000000)));
}
