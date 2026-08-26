import 'dart:io';

import 'package:fluttermotion_cli/src/args.dart';
import 'package:fluttermotion_cli/src/cli_error.dart';
import 'package:fluttermotion_cli/src/document_entry.dart';
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fluttermotion_doc');
    File('${project.path}/pubspec.yaml').writeAsStringSync(
      'name: demo\ndependencies:\n  fluttermotion_json: ^0.1.0\n',
    );
    File('${project.path}/reel.json').writeAsStringSync('{}');
    File('${project.path}/data.json').writeAsStringSync('{}');
  });

  tearDown(() => project.deleteSync(recursive: true));

  // Paths are typed at a shell, so they resolve against the working
  // directory rather than the project -- these tests use absolute ones.
  String inProject(String name) => '${project.path}/$name';

  CliArgs argsWith(List<String> tokens) =>
      CliArgs(<String>['--project', project.path, ...tokens]);

  group('finding the document', () {
    test('a positional .json is the document', () {
      expect(documentPathFrom(<String>['reel.json'], null), 'reel.json');
    });

    test('--document wins over a positional', () {
      expect(
        documentPathFrom(<String>['reel.json'], 'other.json'),
        'other.json',
      );
    });

    test('no .json anywhere means no document', () {
      expect(documentPathFrom(<String>['WeeklyDeals'], null), isNull);
    });
  });

  group('resolving the host', () {
    test('without a document the project entry point is used untouched', () {
      final HostTarget target = hostTargetFor(argsWith(<String>[]), project);
      expect(target.entryPoint, 'lib/render_main.dart');
      expect(target.hostArgs, isEmpty);
      expect(
        Directory('${project.path}/.dart_tool/fluttermotion').existsSync(),
        isFalse,
        reason: 'a project with a hand-written host generates nothing',
      );
    });

    test('--entry is honoured when there is no document', () {
      expect(
        hostTargetFor(
          argsWith(<String>['--entry', 'lib/x.dart']),
          project,
        ).entryPoint,
        'lib/x.dart',
      );
    });

    test('a document generates an entry point under .dart_tool', () {
      final HostTarget target = hostTargetFor(
        argsWith(<String>[inProject('reel.json')]),
        project,
      );
      expect(
        target.entryPoint,
        '.dart_tool/fluttermotion/document_render.dart',
      );
      final String source = File(
        '${project.path}/${target.entryPoint}',
      ).readAsStringSync();
      expect(source, contains('documentRenderMain'));
      expect(source, contains('${project.path}/reel.json'));
    });

    test('the document reaches the binary on argv too, absolute', () {
      // The generated entry bakes a path in, which `--no-build` would happily
      // reuse for a different document. argv is what keeps that honest.
      final HostTarget target = hostTargetFor(
        argsWith(<String>[
          inProject('reel.json'),
          '--data',
          inProject('data.json'),
        ]),
        project,
      );
      expect(target.hostArgs, <String>[
        '--document',
        '${project.path}/reel.json',
        '--data',
        '${project.path}/data.json',
      ]);
    });

    test('without --data the host is told nothing about data', () {
      final HostTarget target = hostTargetFor(
        argsWith(<String>[inProject('reel.json')]),
        project,
      );
      expect(target.hostArgs, isNot(contains('--data')));
    });

    test('a missing document is caught before a build starts', () {
      expect(
        () =>
            hostTargetFor(argsWith(<String>[inProject('nope.json')]), project),
        throwsA(
          isA<CliError>().having(
            (CliError e) => e.message,
            'message',
            contains('nope.json'),
          ),
        ),
      );
    });

    test('a missing data file is caught too', () {
      expect(
        () => hostTargetFor(
          argsWith(<String>[
            inProject('reel.json'),
            '--data',
            inProject('nope.json'),
          ]),
          project,
        ),
        throwsA(
          isA<CliError>().having(
            (CliError e) => e.message,
            'message',
            contains('No data file'),
          ),
        ),
      );
    });

    test('a project without the json package is told what to add', () {
      File(
        '${project.path}/pubspec.yaml',
      ).writeAsStringSync('name: demo\ndependencies:\n  flutter:\n');
      expect(
        () =>
            hostTargetFor(argsWith(<String>[inProject('reel.json')]), project),
        throwsA(
          isA<CliError>().having(
            (CliError e) => e.message,
            'message',
            contains('fluttermotion_json'),
          ),
        ),
      );
    });
  });

  test('a preview entry carries the project root as well', () {
    final String entry = DocumentEntry(
      project,
    ).writePreviewEntry(documentPath: '${project.path}/reel.json');
    final String source = File('${project.path}/$entry').readAsStringSync();
    expect(source, contains('documentPreviewMain'));
    expect(source, contains("projectPath: r'${project.path}'"));
  });
}
