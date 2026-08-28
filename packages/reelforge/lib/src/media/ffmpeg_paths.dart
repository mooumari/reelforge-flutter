import 'dart:io';

/// Finds ffmpeg and ffprobe for the preview.
///
/// The exporter is told where they are by the CLI; the preview has to look,
/// because it is just `flutter run`. A composition with no video never calls
/// this, so a machine without ffmpeg previews everything else fine.
abstract final class FfmpegPaths {
  static const List<String> _searchPath = <String>[
    '/opt/homebrew/bin',
    '/usr/local/bin',
    '/usr/bin',
  ];

  static String? find(String binary) {
    for (final String dir in _searchPath) {
      final String candidate = '$dir/$binary';
      if (File(candidate).existsSync()) return candidate;
    }
    // `flutter run` does not inherit a login shell's PATH, so `which` is a
    // last resort rather than the first thing tried.
    try {
      final ProcessResult which = Process.runSync('which', <String>[binary]);
      if (which.exitCode == 0) {
        final String path = (which.stdout as String).trim();
        if (path.isNotEmpty) return path;
      }
    } on ProcessException {
      // No `which` on this platform; fall through.
    }
    return null;
  }
}
