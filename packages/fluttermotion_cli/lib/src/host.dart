import 'dart:convert';
import 'dart:io';

import 'cli_error.dart';
import 'sandbox_check.dart';

/// Builds and talks to the render host: the user's own Flutter project, built
/// with an entry point that calls `renderMain`.
class RenderHost {
  RenderHost({
    required this.projectDir,
    required this.entryPoint,
    required this.flutter,
    this.allowSandbox = false,
  });

  final Directory projectDir;
  final String entryPoint;
  final String flutter;

  /// Build even though the app is sandboxed. See [SandboxCheck].
  final bool allowSandbox;

  /// Builds the host binary. This is a normal `flutter build`, so the user's
  /// pubspec, assets, fonts, and plugins all come along.
  Future<File> build({void Function(String)? log}) async {
    checkSandbox();
    log?.call('Building render host ($entryPoint)...');
    final ProcessResult result = await Process.run(
      flutter,
      <String>['build', 'macos', '--release', '-t', entryPoint],
      workingDirectory: projectDir.path,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'flutter build failed (${result.exitCode}):\n'
        '${result.stdout}\n${result.stderr}',
      );
    }
    return locateBinary();
  }

  /// Refuses a build that is going to fail at the encode step.
  ///
  /// Checked before the build rather than after, because the build is
  /// minutes long and the failure it leads to says only
  /// `Operation not permitted`.
  void checkSandbox() {
    if (allowSandbox) return;
    final String? complaint = SandboxCheck.complain(projectDir);
    if (complaint != null) throw CliError(complaint);
  }

  /// Finds the built executable inside the `.app` bundle.
  File locateBinary() {
    final Directory releaseDir = Directory(
      '${projectDir.path}/build/macos/Build/Products/Release',
    );
    if (!releaseDir.existsSync()) {
      throw StateError(
        'No release build found at ${releaseDir.path}. '
        'Run without --no-build, or build the host first.',
      );
    }
    final List<Directory> bundles = releaseDir
        .listSync()
        .whereType<Directory>()
        .where((Directory d) => d.path.endsWith('.app'))
        .toList();
    if (bundles.isEmpty) {
      throw StateError('No .app bundle in ${releaseDir.path}.');
    }
    if (bundles.length > 1) {
      throw StateError(
        'Ambiguous build products in ${releaseDir.path}: '
        '${bundles.map((Directory d) => d.path.split('/').last).join(', ')}',
      );
    }
    final String bundle = bundles.single.path;
    final String name = bundle.split('/').last.replaceAll('.app', '');
    final File binary = File('$bundle/Contents/MacOS/$name');
    if (!binary.existsSync()) {
      throw StateError('Expected host binary at ${binary.path}.');
    }
    return binary;
  }

  /// Asks the host what compositions it defines.
  Future<List<CompositionInfo>> list(File binary) async {
    final ProcessResult result =
        await Process.run(binary.path, <String>['--list']);
    if (result.exitCode != 0) {
      throw StateError('Host --list failed:\n${result.stdout}${result.stderr}');
    }
    for (final String line in const LineSplitter().convert('${result.stdout}')) {
      final Map<String, Object?>? decoded = _tryDecode(line);
      if (decoded == null) continue;
      if (decoded['event'] == 'compositions') {
        return <CompositionInfo>[
          for (final Object? entry in decoded['compositions'] as List<Object?>)
            CompositionInfo.fromJson(entry! as Map<String, Object?>),
        ];
      }
      if (decoded['event'] == 'error') {
        throw StateError('Host error: ${decoded['message']}');
      }
    }
    throw StateError('Host produced no composition list.');
  }
}

Map<String, Object?>? _tryDecode(String line) {
  final String trimmed = line.trim();
  if (!trimmed.startsWith('{')) return null;
  try {
    return jsonDecode(trimmed) as Map<String, Object?>;
  } on FormatException {
    return null;
  }
}

/// Decodes newline-delimited JSON events from a host process.
Map<String, Object?>? decodeHostEvent(String line) => _tryDecode(line);

class CompositionInfo {
  const CompositionInfo({
    required this.id,
    required this.width,
    required this.height,
    required this.fps,
    required this.durationInFrames,
  });

  factory CompositionInfo.fromJson(Map<String, Object?> json) {
    return CompositionInfo(
      id: json['id']! as String,
      width: json['width']! as int,
      height: json['height']! as int,
      fps: json['fps']! as int,
      durationInFrames: json['durationInFrames']! as int,
    );
  }

  final String id;
  final int width;
  final int height;
  final int fps;
  final int durationInFrames;

  @override
  String toString() =>
      '$id  ${width}x$height  ${fps}fps  $durationInFrames frames  '
      '(${(durationInFrames / fps).toStringAsFixed(2)}s)';
}
