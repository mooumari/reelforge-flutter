import 'dart:io';

import 'args.dart';
import 'cli_error.dart';

/// Runs the preview app: `flutter run` on the project's preview entry point.
///
/// A thin wrapper on purpose. It exists because the alternative is remembering
/// `flutter run -d macos -t lib/video/preview_main.dart`, and the preview is
/// the thing you are in all day -- scrubbing, hot reloading, checking a frame.
/// Everything `flutter run` prints comes straight through, including the
/// hot-reload keys, because this hands over the terminal rather than
/// interpreting it.
Future<int> previewCommand(CliArgs args) async {
  final Directory projectDir = Directory(args.value('project', '.')).absolute;
  final String entry = args.value('entry', 'lib/video/preview_main.dart');
  final File entryFile = File('${projectDir.path}/$entry');

  if (!entryFile.existsSync()) {
    throw CliError(
      'No preview entry point at $entry\n\n'
      'Run `fluttermotion init` to write one, or point --entry at the file '
      'that calls previewMain().',
    );
  }

  final String device = args.value('device', _defaultDevice());
  final Process process = await Process.start(
    args.value('flutter', 'flutter'),
    <String>['run', '-d', device, '-t', entry],
    workingDirectory: projectDir.path,
    // The preview is interactive: `r` hot reloads, `q` quits. Inheriting the
    // terminal is what makes those keys reach flutter rather than this.
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

/// The desktop this machine can actually run a preview on.
///
/// A preview wants a real window and a keyboard, so it defaults to the desktop
/// rather than to whatever device happens to be plugged in.
String _defaultDevice() {
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  return 'linux';
}
