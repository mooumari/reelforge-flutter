import 'dart:io';

import 'package:fluttermotion_cli/src/args.dart';
import 'package:fluttermotion_cli/src/cli_error.dart';
import 'package:fluttermotion_cli/src/preview_command.dart';
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fluttermotion_preview');
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('a project with no preview entry says how to get one', () async {
    // The failure a first-time user actually hits. "No such file" from
    // `flutter run` would not tell them `init` writes this.
    await expectLater(
      previewCommand(CliArgs(<String>['--project', project.path])),
      throwsA(
        isA<CliError>()
            .having((CliError e) => e.message, 'message',
                contains('lib/video/preview_main.dart'))
            .having((CliError e) => e.message, 'message',
                contains('fluttermotion init')),
      ),
    );
  });

  test('--entry is named in the complaint, not the default', () async {
    await expectLater(
      previewCommand(CliArgs(<String>[
        '--project',
        project.path,
        '--entry',
        'lib/scrub.dart',
      ])),
      throwsA(isA<CliError>().having(
          (CliError e) => e.message, 'message', contains('lib/scrub.dart'))),
    );
  });

  test('runs the entry point that exists, on this desktop', () async {
    File('${project.path}/lib/video/preview_main.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('void main() {}');

    // A fake `flutter` that records how it was called and exits.
    final File fake = File('${project.path}/fake_flutter')
      ..writeAsStringSync(r'#!/bin/sh' '\n' r'echo "$@" > "$0.args"' '\n');
    Process.runSync('chmod', <String>['+x', fake.path]);

    final int code = await previewCommand(CliArgs(<String>[
      '--project',
      project.path,
      '--flutter',
      fake.path,
    ]));

    expect(code, 0);
    final String called = File('${fake.path}.args').readAsStringSync().trim();
    expect(called, startsWith('run -d '));
    expect(called, endsWith('-t lib/video/preview_main.dart'));
    // A preview wants a window and a keyboard, so it goes to the desktop
    // rather than to whatever phone happens to be plugged in.
    expect(
      called,
      contains(Platform.isMacOS
          ? 'macos'
          : Platform.isWindows
              ? 'windows'
              : 'linux'),
    );
  });

  test('--device overrides the desktop default', () async {
    File('${project.path}/lib/video/preview_main.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('void main() {}');
    final File fake = File('${project.path}/fake_flutter')
      ..writeAsStringSync(r'#!/bin/sh' '\n' r'echo "$@" > "$0.args"' '\n');
    Process.runSync('chmod', <String>['+x', fake.path]);

    await previewCommand(CliArgs(<String>[
      '--project',
      project.path,
      '--flutter',
      fake.path,
      '--device',
      'chrome',
    ]));

    expect(File('${fake.path}.args').readAsStringSync(), contains('-d chrome'));
  });
}
