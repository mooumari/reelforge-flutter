import 'dart:io';

import 'package:fluttermotion_cli/src/args.dart';
import 'package:fluttermotion_cli/src/cli_error.dart';
import 'package:fluttermotion_cli/src/validate_command.dart';
import 'package:fluttermotion_schema/fluttermotion_schema.dart';
import 'package:test/test.dart';

/// Validation, which is the one command that needs nothing built.
///
/// Every test here runs in this process against a real document. That is the
/// point of the split: before it, each of these would have needed a macOS
/// release build of a Flutter project first.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('fluttermotion_val'));
  tearDown(() => dir.deleteSync(recursive: true));

  String write(String name, String contents) {
    final File file = File('${dir.path}/$name')..writeAsStringSync(contents);
    return file.path;
  }

  Future<int> validate(String path) => validateCommand(CliArgs(<String>[path]));

  const String valid = '''
{
  "id": "Reel",
  "width": 1080,
  "height": 1920,
  "fps": 30,
  "scenes": [
    {"seconds": 2, "child": {"type": "titleCard", "headline": "{{ title }}"}}
  ]
}
''';

  test('a valid document exits zero', () async {
    expect(await validate(write('ok.json', valid)), 0);
  });

  test('a document with problems exits one', () async {
    expect(
      await validate(write('bad.json', valid.replaceAll('headline', 'titel'))),
      1,
    );
  });

  test('malformed JSON is a problem, not a crash', () async {
    expect(await validate(write('broken.json', '{not json')), 1);
  });

  test('a missing file says so before anything else', () {
    expect(
      () => validate('${dir.path}/nowhere.json'),
      throwsA(
        isA<CliError>().having(
          (CliError e) => e.message,
          'message',
          contains('No document at'),
        ),
      ),
    );
  });

  test('with nothing to validate it says what to type', () {
    expect(
      () => validateCommand(CliArgs(<String>[])),
      throwsA(
        isA<CliError>().having(
          (CliError e) => e.message,
          'message',
          contains('fluttermotion validate reel.json'),
        ),
      ),
    );
  });

  test('--document is accepted as well as a positional', () async {
    final String path = write('ok.json', valid);
    expect(await validateCommand(CliArgs(<String>['--document', path])), 0);
  });

  test('four mistakes are four problems, in one pass', () async {
    // The property this command exists for. An author fixing one mistake at a
    // time through four builds is what makes a format unpleasant to write.
    final String path = write('four.json', '''
{
  "id": "Reel",
  "width": 1080,
  "height": 1920,
  "fps": 30,
  "scenes": [
    {
      "seconds": 2,
      "child": {
        "type": "column",
        "children": [
          {"type": "titleCard", "headline": "x", "subhed": "typo"},
          {"type": "text", "value": "{{ n | shout }}"},
          {"type": "video", "src": "../outside.mp4"},
          {"type": "nosuchnode"}
        ]
      }
    }
  ]
}
''');
    expect(await validate(path), 1);
    // And the paths point at each one individually.
    final List<String> paths = <String>[
      for (final SchemaProblem problem in DocumentSpec.problemsIn(
        File(path).readAsStringSync(),
      ))
        problem.path,
    ];
    expect(paths, hasLength(4));
    expect(paths, everyElement(startsWith('scenes[0].child.children[')));
  });
}
