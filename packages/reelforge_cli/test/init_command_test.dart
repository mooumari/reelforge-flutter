import 'dart:convert';
import 'dart:io';

import 'package:reelforge_cli/src/args.dart';
import 'package:reelforge_cli/src/cli_error.dart';
import 'package:reelforge_cli/src/init_command.dart';
import 'package:reelforge_cli/src/sandbox_check.dart';
import 'package:test/test.dart';

const String _pubspec = '''
name: my_app
description: An app.

environment:
  sdk: ^3.9.0

dependencies:
  flutter:
    sdk: flutter
  collection: ^1.18.0

dev_dependencies:
  flutter_test:
    sdk: flutter
''';

void main() {
  group('adding the dependency', () {
    test('lands inside dependencies, not somewhere that looks like it', () {
      final String updated = withDependency(_pubspec, path: '../fm')!;
      final int dep = updated.indexOf('  reelforge:');
      expect(dep, greaterThan(updated.indexOf('dependencies:')));
      expect(dep, lessThan(updated.indexOf('dev_dependencies:')));
      expect(updated, contains('    path: ../fm\n'));
    });

    test('leaves everything else exactly as it was', () {
      final String updated = withDependency(_pubspec, path: '../fm')!;
      expect(
        updated.replaceFirst('  reelforge:\n    path: ../fm\n', ''),
        _pubspec,
      );
    });

    test('a pubspec that already has it is left alone', () {
      final String once = withDependency(_pubspec, path: '../fm')!;
      expect(withDependency(once, path: '../fm'), isNull);
    });

    test('a hosted dependency counts as having it too', () {
      // Whatever form it takes, adding a second one would not resolve.
      final String hosted = _pubspec.replaceFirst(
        '  collection:',
        '  reelforge: ^0.1.0\n  collection:',
      );
      expect(withDependency(hosted, path: '../fm'), isNull);
    });

    test('a pubspec with no dependencies section says so', () {
      expect(
        () => withDependency('name: my_app\n', path: '../fm'),
        throwsA(isA<CliError>()),
      );
    });
  });

  group('writing the path', () {
    test('two checkouts side by side get a relative path', () {
      expect(
        relativePath(
          from: '/Users/x/Code/game',
          to: '/Users/x/Code/fm/packages/reelforge',
        ),
        '../fm/packages/reelforge',
      );
    });

    test('a project nested deeper climbs out of it', () {
      expect(
        relativePath(
          from: '/Users/x/Code/editor/app',
          to: '/Users/x/Code/fm/packages/reelforge',
        ),
        '../../fm/packages/reelforge',
      );
    });

    test('nothing in common falls back to the absolute path', () {
      // Different volumes. A relative path would be a lie dressed as a link.
      expect(
        relativePath(from: '/Users/x/game', to: '/Volumes/work/fm'),
        '/Volumes/work/fm',
      );
    });
  });

  test('the app name comes off the pubspec', () {
    expect(packageNameOf(_pubspec), 'my_app');
    expect(packageNameOf('description: no name here\n'), isNull);
  });

  group('warning about what init cannot write', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('fm_init'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a project with no macOS target is told how to add one', () {
      expect(
        warnings(dir).join('\n'),
        contains('flutter create --platforms=macos .'),
      );
    });

    test('a sandboxed project is warned before it ever builds', () {
      Directory('${dir.path}/macos').createSync();
      final File file = SandboxCheck.entitlementsFile(dir);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '<plist><dict>\n'
        '<key>com.apple.security.app-sandbox</key>\n<true/>\n'
        '</dict></plist>',
      );
      expect(warnings(dir).join('\n'), contains('sandboxed'));
    });

    test('a macOS project with the sandbox off has nothing to say', () {
      Directory('${dir.path}/macos').createSync();
      expect(warnings(dir), isEmpty);
    });
  });

  group('init --json', () {
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('reelforge_init_json');
      File('${project.path}/pubspec.yaml').writeAsStringSync(_pubspec);
    });

    tearDown(() => project.deleteSync(recursive: true));

    Future<void> init(List<String> extra) => initCommand(
      CliArgs(<String>[
        '--project',
        project.path,
        '--reelforge',
        Directory.current.parent.path + '/reelforge',
        ...extra,
      ]),
    );

    String read(String path) =>
        File('${project.path}/$path').readAsStringSync();

    test('overrides every sibling back to the checkout', () async {
      // Without this the install does not resolve at all: reelforge_kit
      // depends on a *version* of reelforge, the project depends on a path,
      // and pub treats the two sources as unrelated rather than as the same
      // package. Found by tool/cold_start.sh, which is the only thing here
      // that installs into a project it did not build.
      await init(<String>['--json']);
      final String overrides = read('pubspec_overrides.yaml');
      expect(overrides, contains('dependency_overrides:'));
      for (final String name in <String>[
        'reelforge',
        'reelforge_kit',
        'reelforge_json',
        'reelforge_schema',
      ]) {
        expect(overrides, contains('  $name:\n    path: '));
      }
    });

    test('an existing pubspec_overrides.yaml is left alone', () async {
      File('${project.path}/pubspec_overrides.yaml').writeAsStringSync('mine\n');
      await init(<String>['--json']);
      expect(read('pubspec_overrides.yaml'), 'mine\n');
    });

    test('writes a document and its data, not three Dart files', () async {
      await init(<String>['--json']);
      expect(File('${project.path}/video/reel.json').existsSync(), isTrue);
      expect(File('${project.path}/video/reel_data.json').existsSync(), isTrue);
      expect(
        File('${project.path}/lib/render_main.dart').existsSync(),
        isFalse,
        reason: 'a document needs no hand-written host; the CLI writes one',
      );
    });

    test(
      'the starter document is a document, and it binds to its data',
      () async {
        await init(<String>['--json']);
        final Map<String, Object?> document =
            jsonDecode(read('video/reel.json')) as Map<String, Object?>;
        final Map<String, Object?> data =
            jsonDecode(read('video/reel_data.json')) as Map<String, Object?>;

        expect(document['fps'], isA<int>());
        expect(document['scenes'], isA<List<Object?>>());

        // Every `{{ name }}` in the document has something to bind to -- at
        // the root, or on an item of a list a `repeat` walks. A starter that
        // renders three blanks is worse than no starter.
        final Set<String> bindable = <String>{
          ...data.keys,
          for (final Object? value in data.values)
            if (value is List<Object?>)
              for (final Object? item in value)
                if (item is Map<String, Object?>) ...item.keys,
        };
        final Iterable<RegExpMatch> bindings = RegExp(
          r'\{\{\s*([a-zA-Z0-9_.@]+)',
        ).allMatches(read('video/reel.json'));
        expect(bindings, isNotEmpty);
        for (final RegExpMatch match in bindings) {
          final String root = match.group(1)!.split('.').first;
          if (root.startsWith('@')) continue; // @item / @index, from a repeat
          expect(
            bindable,
            contains(root),
            reason: '{{ $root }} has nothing to bind to in reel_data.json',
          );
        }
      },
    );

    test('the interpreter and the components come along', () async {
      await init(<String>['--json']);
      final String pubspec = read('pubspec.yaml');
      expect(pubspec, contains('reelforge:'));
      expect(pubspec, contains('reelforge_json:'));
      expect(pubspec, contains('reelforge_kit:'));
    });

    test('without --json none of that is added', () async {
      await init(<String>[]);
      final String pubspec = read('pubspec.yaml');
      expect(pubspec, contains('reelforge:'));
      expect(pubspec, isNot(contains('reelforge_json:')));
      expect(File('${project.path}/lib/render_main.dart').existsSync(), isTrue);
    });

    test('running it twice leaves the document alone', () async {
      await init(<String>['--json']);
      File('${project.path}/video/reel.json').writeAsStringSync('{"mine": 1}');
      await init(<String>['--json']);
      expect(read('video/reel.json'), '{"mine": 1}');
    });
  });
}
