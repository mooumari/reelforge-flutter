import 'dart:io';

import 'package:reelforge_cli/src/args.dart';
import 'package:reelforge_cli/src/binding_check.dart';
import 'package:reelforge_cli/src/cli_error.dart';
import 'package:reelforge_cli/src/validate_command.dart';
import 'package:reelforge_schema/reelforge_schema.dart';
import 'package:test/test.dart';

/// Validation, which is the one command that needs nothing built.
///
/// Every test here runs in this process against a real document. That is the
/// point of the split: before it, each of these would have needed a macOS
/// release build of a Flutter project first.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('reelforge_val'));
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
          contains('reelforge validate reel.json'),
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

  group('against data', () {
    Future<int> validateWith(String path, String data) =>
        validateCommand(CliArgs(<String>[path, '--data', data]));

    test('data that fills every binding exits zero', () async {
      expect(
        await validateWith(
          write('ok.json', valid),
          write('data.json', '{"title": "Q3"}'),
        ),
        0,
      );
    });

    test('data missing a binding exits one', () async {
      // The failure this whole path exists for: both files are valid, and the
      // pair renders a title card with no title on it.
      expect(
        await validateWith(
          write('ok.json', valid),
          write('data.json', '{"subtitle": "Q3"}'),
        ),
        1,
      );
    });

    test('a document is still valid on its own with no data at all', () async {
      // Without --data there is nothing to check against, and a template
      // waiting on data is not a broken document.
      expect(await validate(write('ok.json', valid)), 0);
    });

    test('a data file that is not there is refused by name', () async {
      expect(
        () => validateWith(write('ok.json', valid), '${dir.path}/gone.json'),
        throwsA(
          isA<CliError>().having(
            (CliError e) => e.message,
            'message',
            contains('gone.json'),
          ),
        ),
      );
    });

    test('a data file that is not JSON says so, rather than throwing', () async {
      expect(
        () => validateWith(
          write('ok.json', valid),
          write('data.json', 'not json at all'),
        ),
        throwsA(isA<CliError>()),
      );
    });

    test('a data file that is not an object is refused', () async {
      // A document reads its data by name, so a list has nothing to offer it.
      expect(
        () => validateWith(
          write('ok.json', valid),
          write('data.json', '[1, 2, 3]'),
        ),
        throwsA(
          isA<CliError>().having(
            (CliError e) => e.message,
            'message',
            contains('JSON object'),
          ),
        ),
      );
    });
  });

  group('the check the render runs', () {
    test('an unparseable document yields no binding check', () {
      // validate reports that far better, with every schema error at once;
      // bindings cannot be checked against a tree that was never built.
      expect(bindingCheck(write('bad.json', '{ not json'), null), isNull);
    });

    test('a document with no data reports what it cannot fill', () {
      final BindingCheck? check = bindingCheck(write('ok.json', valid), null);
      expect(check, isNotNull);
      expect(check!.hasData, isFalse);
      expect(
        check.problems.single.toString(),
        'scenes[0].child.headline: "{{ title }}" has nothing to bind to',
      );
    });

    test('a document whose data fills it reports nothing', () {
      expect(
        bindingCheck(
          write('ok.json', valid),
          write('data.json', '{"title": "Q3"}'),
        )!.isEmpty,
        isTrue,
      );
    });
  });

}
