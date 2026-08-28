import 'dart:io';

import 'package:reelforge_schema/reelforge_schema.dart';

import 'args.dart';
import 'binding_check.dart';
import 'cli_error.dart';
import 'document_entry.dart';

/// Reports everything wrong with a document, without rendering a frame.
///
/// Every problem at once, each with its JSON path, because a document with
/// four mistakes should take one round trip to fix rather than four.
///
/// This runs in this process. A document is data, so whether it is *valid*
/// data is a question about JSON rather than about widgets -- and
/// `reelforge_schema` answers it in plain Dart, with no Flutter engine and
/// nothing to build first. The node vocabulary is still declared exactly once:
/// the schema is what this reads and what the builders in
/// `reelforge_json` are registered against, and neither half can name a
/// node the other has not heard of.
Future<int> validateCommand(CliArgs args) async {
  final String? path = documentPathFrom(args.rest, args.optional('document'));
  if (path == null) {
    throw CliError(
      'Nothing to validate.\n\n'
      'Usage: reelforge validate reel.json',
    );
  }

  final File document = File(path);
  if (!document.existsSync()) throw CliError('No document at $path');

  final List<SchemaProblem> problems = DocumentSpec.problemsIn(
    document.readAsStringSync(),
  );

  if (problems.isNotEmpty) {
    _report(problems, 'in $path');
    return 1;
  }

  // Valid on its own, which is a smaller claim than it sounds. A document is
  // a template: whether it draws anything depends on data it does not
  // contain, and the two are checked separately because they are separate
  // files. Answering only the first question is how a reel renders sixty
  // seconds of empty scenes and exits 0.
  final String? data = args.optional('data');
  if (data != null && !File(data).existsSync()) {
    throw CliError('No data file at $data');
  }

  final DocumentSpec parsed = DocumentSpec.parse(document.readAsStringSync());
  final List<SchemaProblem> unbound = dataProblems(parsed, readData(data));

  if (data != null) {
    if (unbound.isEmpty) {
      stdout.writeln('$path is valid, and $data fills every binding in it.');
      return 0;
    }
    _report(unbound, 'in $path against $data');
    return 1;
  }

  stdout.writeln('$path is a valid composition document.');
  if (unbound.isNotEmpty) {
    // Not a problem -- a document with no data is exactly what a template is.
    // But it is the one thing this command cannot answer without being told
    // where the data lives, so it says so rather than implying otherwise.
    stdout.writeln(
      '${unbound.length} of its bindings need data. '
      'Pass --data <file> to check them.',
    );
  }
  return 0;
}

void _report(List<SchemaProblem> problems, String where) {
  stdout.writeln(
    '${problems.length} ${problems.length == 1 ? 'problem' : 'problems'} '
    '$where:',
  );
  for (final SchemaProblem problem in problems) {
    stdout.writeln('  ${problem.path.isEmpty ? '<document>' : problem.path}');
    stdout.writeln('    ${problem.message}');
  }
}
