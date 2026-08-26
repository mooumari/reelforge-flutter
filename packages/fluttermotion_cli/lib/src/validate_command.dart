import 'dart:io';

import 'package:fluttermotion_schema/fluttermotion_schema.dart';

import 'args.dart';
import 'cli_error.dart';
import 'document_entry.dart';

/// Reports everything wrong with a document, without rendering a frame.
///
/// Every problem at once, each with its JSON path, because a document with
/// four mistakes should take one round trip to fix rather than four.
///
/// This runs in this process. A document is data, so whether it is *valid*
/// data is a question about JSON rather than about widgets -- and
/// `fluttermotion_schema` answers it in plain Dart, with no Flutter engine and
/// nothing to build first. The node vocabulary is still declared exactly once:
/// the schema is what this reads and what the builders in
/// `fluttermotion_json` are registered against, and neither half can name a
/// node the other has not heard of.
Future<int> validateCommand(CliArgs args) async {
  final String? path = documentPathFrom(args.rest, args.optional('document'));
  if (path == null) {
    throw CliError(
      'Nothing to validate.\n\n'
      'Usage: fluttermotion validate reel.json',
    );
  }

  final File document = File(path);
  if (!document.existsSync()) throw CliError('No document at $path');

  final List<SchemaProblem> problems = DocumentSpec.problemsIn(
    document.readAsStringSync(),
  );

  if (problems.isEmpty) {
    stdout.writeln('$path is a valid composition document.');
    return 0;
  }

  stdout.writeln(
    '${problems.length} ${problems.length == 1 ? 'problem' : 'problems'} '
    'in $path:',
  );
  for (final SchemaProblem problem in problems) {
    stdout.writeln('  ${problem.path.isEmpty ? '<document>' : problem.path}');
    stdout.writeln('    ${problem.message}');
  }
  return 1;
}
