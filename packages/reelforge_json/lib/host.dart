/// Entry points for running a JSON document as a host binary.
///
/// Kept out of the main library because these touch `dart:io`: a document can
/// be parsed anywhere, but only a desktop host reads one off the filesystem.
///
/// A generated entry point is two lines:
///
/// ```dart
/// import 'package:reelforge_json/host.dart';
/// void main(List<String> args) =>
///     documentRenderMain(args, documentPath: 'reel.json', dataPath: 'data.json');
/// ```
///
/// which is what `reelforge render reel.json` writes for you.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';

import 'reelforge_json.dart';

/// Reads a document and its data off disk and builds the composition.
///
/// Paths are resolved against the working directory, which for a render host
/// is the project root -- the same root a video clip's `src` resolves against.
Composition compositionFromFiles({
  required String documentPath,
  String? dataPath,
}) {
  final File document = File(documentPath);
  if (!document.existsSync()) {
    throw StateError('No document at $documentPath');
  }
  Map<String, Object?> data = const <String, Object?>{};
  if (dataPath != null) {
    final File file = File(dataPath);
    if (!file.existsSync()) {
      throw StateError('No data file at $dataPath');
    }
    final Object? decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw StateError(
        '$dataPath must contain a JSON object; a document reads its bindings '
        'by name, so a list or a bare value has nothing to bind to.',
      );
    }
    data = decoded;
  }
  return MotionDocument.parse(document.readAsStringSync())
      .toComposition(data: data);
}

/// Render-host entry point for a document.
///
/// Behaves exactly as a hand-written `renderMain` host does -- the CLI cannot
/// tell the difference, and does not need to -- with one addition: `--validate`
/// reports the document's problems and exits without rendering anything.
///
/// [documentPath] and [dataPath] are defaults. `--document` and `--data` on
/// the command line win, which is what lets one built host serve every
/// document in a project: the binary is expensive, the JSON is not, and a
/// reused binary must never quietly render the document it was born with.
Future<void> documentRenderMain(
  List<String> args, {
  required String documentPath,
  String? dataPath,
}) async {
  final String document = _option(args, 'document') ?? documentPath;
  final String? data = _option(args, 'data') ?? dataPath;

  if (args.contains('--validate')) {
    exit(_validate(document));
  }

  final Composition composition;
  try {
    composition = compositionFromFiles(
      documentPath: document,
      dataPath: data,
    );
  } catch (error) {
    // The same shape `renderMain` reports failures in, so the CLI surfaces a
    // schema problem the way it surfaces any other host error rather than as
    // an unexplained non-zero exit.
    stdout.writeln(jsonEncode(<String, Object?>{
      'event': 'error',
      'message': error.toString(),
      'stack': '',
    }));
    exit(1);
  }

  await renderMain(args, <Composition>[composition]);
}

/// Preview entry point for a document.
///
/// Hot reload applies to the *interpreter*, not to the document: the JSON is
/// read once, in `main`. Editing the document and pressing `R` -- hot restart
/// -- picks it up; `r` will not.
void documentPreviewMain({
  required String documentPath,
  String? dataPath,
  String? projectPath,
}) {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    previewMain(
      <Composition>[
        compositionFromFiles(documentPath: documentPath, dataPath: dataPath),
      ],
      projectPath: projectPath,
    );
  } on SchemaException catch (error) {
    // A preview that dies on a typo is a bad preview. Showing the problems on
    // the surface you are already looking at means a fix is one `R` away.
    runApp(_ProblemScreen(error.problems));
  }
}

/// Reads `--name value` or `--name=value` out of argv.
///
/// Deliberately the same shape `renderMain` accepts, so a host's arguments
/// mean one thing whoever reads them.
String? _option(List<String> args, String name) {
  for (int i = 0; i < args.length; i++) {
    final String token = args[i];
    if (token == '--$name' && i + 1 < args.length) return args[i + 1];
    if (token.startsWith('--$name=')) return token.substring(name.length + 3);
  }
  return null;
}

int _validate(String documentPath) {
  final File file = File(documentPath);
  if (!file.existsSync()) {
    stdout.writeln('No document at $documentPath');
    return 1;
  }
  final List<SchemaProblem> problems =
      MotionDocument.problemsIn(file.readAsStringSync());
  if (problems.isEmpty) {
    stdout.writeln('$documentPath is a valid composition document.');
    return 0;
  }
  stdout.writeln(
    '${problems.length} ${problems.length == 1 ? 'problem' : 'problems'} '
    'in $documentPath:',
  );
  for (final SchemaProblem problem in problems) {
    stdout.writeln('  ${problem.path.isEmpty ? '<document>' : problem.path}');
    stdout.writeln('    ${problem.message}');
  }
  return 1;
}

class _ProblemScreen extends StatelessWidget {
  const _ProblemScreen(this.problems);

  final List<SchemaProblem> problems;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFF140C0C),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${problems.length} '
                  '${problems.length == 1 ? 'problem' : 'problems'} '
                  'in the document',
                  style: const TextStyle(
                    color: Color(0xFFF97066),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      for (final SchemaProblem problem in problems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                problem.path.isEmpty
                                    ? '<document>'
                                    : problem.path,
                                style: const TextStyle(
                                  color: Color(0xFFF2F4F8),
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                problem.message,
                                style: const TextStyle(
                                  color: Color(0xFF9AA3B2),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'Fix the document and hot restart (R).',
                  style: TextStyle(color: Color(0xFF7C8596), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
}
