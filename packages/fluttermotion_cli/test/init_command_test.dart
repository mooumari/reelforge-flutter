import 'dart:io';

import 'package:fluttermotion_cli/src/cli_error.dart';
import 'package:fluttermotion_cli/src/init_command.dart';
import 'package:fluttermotion_cli/src/sandbox_check.dart';
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
      final int dep = updated.indexOf('  fluttermotion:');
      expect(dep, greaterThan(updated.indexOf('dependencies:')));
      expect(dep, lessThan(updated.indexOf('dev_dependencies:')));
      expect(updated, contains('    path: ../fm\n'));
    });

    test('leaves everything else exactly as it was', () {
      final String updated = withDependency(_pubspec, path: '../fm')!;
      expect(
        updated.replaceFirst('  fluttermotion:\n    path: ../fm\n', ''),
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
        '  fluttermotion: ^0.1.0\n  collection:',
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
          to: '/Users/x/Code/fm/packages/fluttermotion',
        ),
        '../fm/packages/fluttermotion',
      );
    });

    test('a project nested deeper climbs out of it', () {
      expect(
        relativePath(
          from: '/Users/x/Code/editor/app',
          to: '/Users/x/Code/fm/packages/fluttermotion',
        ),
        '../../fm/packages/fluttermotion',
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
}
