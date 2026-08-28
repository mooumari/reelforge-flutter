import 'dart:io';

import 'package:fluttermotion_cli/src/cli_error.dart';
import 'package:fluttermotion_cli/src/host.dart';
import 'package:fluttermotion_cli/src/sandbox_check.dart';
import 'package:test/test.dart';

String _plist(String body) =>
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<plist version="1.0">\n<dict>\n$body\n</dict>\n</plist>\n';

void main() {
  group('reading a release entitlements file', () {
    test('a sandboxed app is caught', () {
      expect(
        SandboxCheck.enablesSandbox(
          _plist('<key>com.apple.security.app-sandbox</key>\n<true/>'),
        ),
        isTrue,
      );
    });

    test('an app that has turned the sandbox off is not', () {
      expect(
        SandboxCheck.enablesSandbox(
          _plist('<key>com.apple.security.app-sandbox</key>\n<false/>'),
        ),
        isFalse,
      );
    });

    test('an entitlements file that never mentions it is not', () {
      expect(
        SandboxCheck.enablesSandbox(
          _plist('<key>com.apple.security.network.client</key>\n<true/>'),
        ),
        isFalse,
      );
    });

    test('a comment cannot answer for the key', () {
      // Entitlements files are heavily commented, and a <true/> in prose is
      // exactly the sort of thing that would make a naive scan lie.
      expect(
        SandboxCheck.enablesSandbox(
          _plist(
            '<!-- Was <true/> until the bench needed to write outside the\n'
            '     container. See the note in the game repo. -->\n'
            '<key>com.apple.security.app-sandbox</key>\n<false/>',
          ),
        ),
        isFalse,
      );
    });

    test(
      'the value read is the one after the key, not the first in the file',
      () {
        expect(
          SandboxCheck.enablesSandbox(
            _plist(
              '<key>com.apple.security.network.client</key>\n<true/>\n'
              '<key>com.apple.security.app-sandbox</key>\n<false/>',
            ),
          ),
          isFalse,
        );
      },
    );
  });

  group('complaining about a project', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('fm_sandbox'));
    tearDown(() => dir.deleteSync(recursive: true));

    void writeEntitlements(String body) {
      final File file = SandboxCheck.entitlementsFile(dir);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(_plist(body));
    }

    test('a project with no macOS runner is left alone', () {
      // Not every project the CLI is pointed at has been built for macOS yet,
      // and refusing to build one that might have worked is worse than the
      // error it would have hit.
      expect(SandboxCheck.complain(dir), isNull);
    });

    test('a sandboxed project is told what will happen and what to do', () {
      writeEntitlements('<key>com.apple.security.app-sandbox</key>\n<true/>');
      final String? complaint = SandboxCheck.complain(dir);
      expect(complaint, isNotNull);
      expect(complaint, contains('Operation not permitted'));
      expect(complaint, contains('app-sandbox'));
      expect(complaint, contains('--allow-sandbox'));
      expect(complaint, contains(SandboxCheck.entitlementsFile(dir).path));
    });

    test('an unsandboxed project is silent', () {
      writeEntitlements('<key>com.apple.security.app-sandbox</key>\n<false/>');
      expect(SandboxCheck.complain(dir), isNull);
    });
  });

  _sandboxEditing();

  group('the gate in front of a build', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('fm_gate');
      final File file = SandboxCheck.entitlementsFile(dir);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        _plist('<key>com.apple.security.app-sandbox</key>\n<true/>'),
      );
    });
    tearDown(() => dir.deleteSync(recursive: true));

    RenderHost hostFor({required bool allowSandbox}) => RenderHost(
      projectDir: dir,
      entryPoint: 'lib/render_main.dart',
      flutter: 'flutter',
      allowSandbox: allowSandbox,
    );

    test('stops a sandboxed project before the build starts', () {
      expect(
        () => hostFor(allowSandbox: false).checkSandbox(),
        throwsA(isA<CliError>()),
      );
    });

    test('--allow-sandbox gets past it', () {
      // An escape hatch that does not actually reach the gate is worse than no
      // escape hatch, because it is only found when someone needs it.
      expect(() => hostFor(allowSandbox: true).checkSandbox(), returnsNormally);
    });
  });
}

void _sandboxEditing() {
  group('turning the sandbox off', () {
    test('flips the value and nothing else', () {
      const String before = '<plist><dict>\n'
          '\t<key>com.apple.security.network.client</key>\n\t<true/>\n'
          '\t<key>com.apple.security.app-sandbox</key>\n\t<true/>\n'
          '</dict></plist>\n';
      final String after = SandboxCheck.withSandboxDisabled(before)!;
      expect(SandboxCheck.enablesSandbox(after), isFalse);
      // The other grants are somebody's decisions, not ours to revisit.
      expect(after, contains('network.client</key>\n\t<true/>'));
      expect(after.replaceFirst('<false/>', '<true/>'), before);
    });

    test('a file that is already off is left alone', () {
      const String off = '<plist><dict>\n'
          '<key>com.apple.security.app-sandbox</key>\n<false/>\n'
          '</dict></plist>';
      expect(SandboxCheck.withSandboxDisabled(off), isNull);
    });

    test('a file that never mentions the key is left alone', () {
      expect(
        SandboxCheck.withSandboxDisabled('<plist><dict></dict></plist>'),
        isNull,
      );
    });
  });

  test('the complaint names the command that fixes it', () {
    // A cold install found this: the message spent a paragraph explaining the
    // problem and never mentioned --fix-entitlements, which is the documented
    // one-command fix. Neither did the render that refused for the same
    // reason. The reader had to already know.
    expect(
      SandboxCheck.message('x/Release.entitlements'),
      contains('fluttermotion init --fix-entitlements'),
    );
  });

  test('the path in the complaint has no redundant segments', () {
    // It is printed on its own line for the reader to open, so
    // `<project>/./macos/...` is a needless stumble in the one line that
    // matters. `--project .` and an absolute directory both arrive here.
    final Directory dotted = Directory('${Directory.systemTemp.path}/.');
    expect(SandboxCheck.entitlementsFile(dotted).path, isNot(contains('/./')));
    expect(
      SandboxCheck.entitlementsFile(Directory('.')).path,
      isNot(contains('/./')),
    );
  });

}
