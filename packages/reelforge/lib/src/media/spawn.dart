import 'dart:io';

/// Starting a helper process from inside the render host, with an explanation
/// ready for the two ways it fails.
///
/// The host is a macOS build of the user's own application, so what it is
/// allowed to do is whatever that application is allowed to do. When the app
/// is sandboxed it may not execute anything outside its own bundle, and the
/// only sign of that is `errno 1` on the spawn -- which reaches the user as
/// `ProcessException: Operation not permitted` over a Dart stack trace that
/// says nothing about entitlements. The other failure, ffmpeg simply not being
/// installed, looks almost the same and wants the opposite advice.
abstract final class Spawn {
  /// Sandbox denial. `Process.start` surfaces the raw errno.
  static const int _permissionDenied = 1;
  static const int _notFound = 2;

  static Future<Process> start(
    String executable,
    List<String> arguments,
  ) async {
    try {
      return await Process.start(executable, arguments);
    } on ProcessException catch (error) {
      throw ProcessException(
        error.executable,
        error.arguments,
        explain(executable, error),
        error.errorCode,
      );
    }
  }

  static Future<ProcessResult> run(
    String executable,
    List<String> arguments,
  ) async {
    try {
      return await Process.run(executable, arguments);
    } on ProcessException catch (error) {
      throw ProcessException(
        error.executable,
        error.arguments,
        explain(executable, error),
        error.errorCode,
      );
    }
  }

  /// What to tell the user about a spawn that did not happen.
  static String explain(String executable, ProcessException error) {
    switch (error.errorCode) {
      case _permissionDenied:
        return 'The render host was not allowed to run $executable.\n'
            '\n'
            'The host is a macOS build of your own app, so it is signed with '
            'your app\'s entitlements -- and this app is sandboxed. App Sandbox '
            'forbids running a binary outside the app bundle, which is what '
            'reaching ffmpeg means.\n'
            '\n'
            'The host is a developer tool and is never distributed, so it is '
            'safe to build it without the sandbox: set '
            'com.apple.security.app-sandbox to <false/> in '
            'macos/Runner/Release.entitlements, or give the host its own build '
            'configuration with its own entitlements.';
      case _notFound:
        return 'The render host could not find $executable.\n'
            '\n'
            'Compositions that declare audio or video need ffmpeg and ffprobe. '
            'Install them (`brew install ffmpeg`) or point at them with '
            '--ffmpeg and --ffprobe.';
      default:
        return 'The render host could not run $executable: ${error.message}';
    }
  }
}
