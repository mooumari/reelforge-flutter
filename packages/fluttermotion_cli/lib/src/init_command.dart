import 'dart:io';

import 'args.dart';
import 'cli_error.dart';
import 'sandbox_check.dart';
import 'templates.dart';

/// Adds FlutterMotion to an existing Flutter project.
///
/// Everything this writes was learned by doing it by hand twice: the path
/// dependency, an entry point that calls `renderMain`, somewhere for
/// compositions to live, and the two things that are not obvious until they
/// bite -- that a sandboxed app cannot host a render, and that the entry point
/// has to run whatever bootstrap the app runs before its first frame.
///
/// Nothing here overwrites. A project that has been set up already is told so
/// and left alone, so running this twice is safe and running it on a project
/// you have edited does not cost you the edits.
Future<int> initCommand(CliArgs args) async {
  final Directory projectDir = Directory(args.value('project', '.')).absolute;
  final File pubspec = File('${projectDir.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw CliError(
      'No pubspec.yaml in ${projectDir.path}.\n'
      'Point --project at a Flutter project.',
    );
  }

  final String original = pubspec.readAsStringSync();
  if (!original.contains('sdk: flutter')) {
    throw CliError(
      '${pubspec.path} does not depend on the Flutter SDK.\n'
      'FlutterMotion renders Flutter widgets, so it needs a Flutter project.',
    );
  }

  final List<String> did = <String>[];
  final List<String> skipped = <String>[];

  // 1. The dependency.
  final String packagePath =
      args.optional('fluttermotion') ?? _locateFrameworkPackage();
  final String relative = relativePath(from: projectDir.path, to: packagePath);
  final String? updated = withDependency(original, path: relative);
  if (updated == null) {
    skipped.add('pubspec.yaml already depends on fluttermotion');
  } else {
    pubspec.writeAsStringSync(updated);
    did.add('added fluttermotion (path: $relative) to pubspec.yaml');
  }

  // 2. Somewhere for compositions to live, and 3. the entry point that serves
  // them. Written in that order so the entry point never points at nothing.
  final String appName = packageNameOf(original) ?? 'your app';
  for (final _Template template in <_Template>[
    _Template('lib/video/compositions.dart', compositionsTemplate(appName)),
    _Template('lib/render_main.dart', renderMainTemplate()),
  ]) {
    final File file = File('${projectDir.path}/${template.path}');
    if (file.existsSync()) {
      skipped.add('${template.path} already exists');
      continue;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(template.contents);
    did.add('wrote ${template.path}');
  }

  for (final String line in did) {
    stdout.writeln('  $line');
  }
  for (final String line in skipped) {
    stdout.writeln('  left alone: $line');
  }

  if (args.flag('fix-entitlements')) {
    stdout.writeln('\n${_disableSandbox(projectDir)}');
  } else {
    for (final String warning in warnings(projectDir)) {
      stdout.writeln('\n$warning');
    }
  }

  stdout.writeln(
    '\nNext:\n'
    '  flutter pub get\n'
    '  fluttermotion render --project ${args.value('project', '.')} '
    '--composition Intro --out intro.mp4',
  );
  return 0;
}

/// Turns App Sandbox off, and says plainly what that means.
///
/// Offered because `flutter create` scaffolds a sandboxed macOS target, so
/// every new project hits this -- but never done without being asked. This
/// edits the entitlements the *release* build is signed with, and an app that
/// ships to the Mac App Store must be sandboxed. Whoever runs this has to know
/// they are on the hook for putting it back.
String _disableSandbox(Directory projectDir) {
  final File file = SandboxCheck.entitlementsFile(projectDir);
  if (!file.existsSync()) {
    return 'No ${file.path} to edit.\n'
        'Add a macOS target first: flutter create --platforms=macos .';
  }
  final String? updated = SandboxCheck.withSandboxDisabled(
    file.readAsStringSync(),
  );
  if (updated == null) {
    return 'App Sandbox is already off in ${file.path}.';
  }
  file.writeAsStringSync(updated);
  return 'Set com.apple.security.app-sandbox to <false/> in\n'
      '${file.path}\n'
      '\n'
      'This is the file your *release* build is signed with, not a render-only\n'
      'one. An app distributed through the Mac App Store must be sandboxed, so\n'
      'put this back before you ship. Nothing else in the file was touched.';
}

/// What will stop a render that `init` cannot fix by writing a file.
///
/// Warnings rather than failures: `init` does not build anything, so none of
/// this is wrong *yet*, and a project may be on its way to being fixed.
List<String> warnings(Directory projectDir) {
  final List<String> found = <String>[];
  if (!Directory('${projectDir.path}/macos').existsSync()) {
    found.add(
      'This project has no macOS target, and the render host is a macOS\n'
      'build of it. Add one with:\n'
      '\n'
      '  flutter create --platforms=macos .',
    );
  }
  final String? sandbox = SandboxCheck.complain(projectDir);
  if (sandbox != null) found.add(sandbox);
  return found;
}

/// The `fluttermotion` package, found from wherever this CLI is running.
String _locateFrameworkPackage() {
  // .../packages/fluttermotion_cli/bin/fluttermotion.dart
  final List<String> parts = Platform.script.toFilePath().split('/');
  final int packages = parts.lastIndexOf('packages');
  if (packages < 0) {
    throw const CliError(
      'Could not work out where the fluttermotion package is.\n'
      'Pass --fluttermotion <path> to say.',
    );
  }
  return <String>[...parts.take(packages + 1), 'fluttermotion'].join('/');
}

/// [original] with a path dependency on fluttermotion, or null if it has one.
///
/// Inserted at the top of `dependencies:` rather than appended, because the end
/// of that block is wherever the next top-level key happens to start and a
/// pubspec's comments make that hard to find honestly.
String? withDependency(String original, {required String path}) {
  if (RegExp(r'^\s+fluttermotion:', multiLine: true).hasMatch(original)) {
    return null;
  }
  final Match? anchor =
      RegExp(r'^dependencies:[ \t]*\r?\n', multiLine: true).firstMatch(original);
  if (anchor == null) {
    throw const CliError(
      'No `dependencies:` section in pubspec.yaml. Add one, or add\n'
      'fluttermotion yourself as a path dependency.',
    );
  }
  return original.substring(0, anchor.end) +
      '  fluttermotion:\n'
      '    path: $path\n' +
      original.substring(anchor.end);
}

/// The `name:` a pubspec declares.
String? packageNameOf(String pubspec) =>
    RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1);

/// [to], written relative to [from].
///
/// A path dependency between two checkouts that sit side by side should read
/// as `../fluttermotion/...`, not as somebody's home directory -- that is what
/// survives being cloned somewhere else. When the two share nothing, which
/// happens on different volumes, an absolute path is the honest answer.
String relativePath({required String from, required String to}) {
  final List<String> a = _segments(from);
  final List<String> b = _segments(to);
  int shared = 0;
  while (shared < a.length && shared < b.length && a[shared] == b[shared]) {
    shared++;
  }
  if (shared == 0) return to;
  return <String>[
    ...List<String>.filled(a.length - shared, '..'),
    ...b.skip(shared),
  ].join('/');
}

List<String> _segments(String path) =>
    path.split('/').where((String s) => s.isNotEmpty).toList();

class _Template {
  _Template(this.path, this.contents);
  final String path;
  final String contents;
}
