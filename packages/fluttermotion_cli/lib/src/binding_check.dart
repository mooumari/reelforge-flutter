import 'dart:convert';
import 'dart:io';

import 'package:fluttermotion_schema/fluttermotion_schema.dart';

import 'cli_error.dart';

/// What a document's bindings find in a data file, or fail to.
///
/// A document and its data are separate files and are checked separately, so
/// both can be perfectly valid while the pair renders nothing. That is not
/// hypothetical: `longform.json` rendered sixty seconds of empty scenes when
/// its data file was left off the command line, exited 0, and said nothing.
///
/// Reading the document is cheap enough to do on the way into a render --
/// `fluttermotion_schema` is plain Dart, and parsing the largest document in
/// the repo takes about as long as opening the file.
class BindingCheck {
  const BindingCheck({required this.problems, required this.hasData});

  /// Every binding with nothing behind it, each with its path in the document.
  final List<SchemaProblem> problems;

  /// Whether a data file was supplied at all.
  ///
  /// Changes the advice rather than the finding: with no data file, the likely
  /// fix is `--data`, not an edit to the document.
  final bool hasData;

  bool get isEmpty => problems.isEmpty;
}

/// Checks [documentPath]'s bindings against [dataPath], or against nothing.
///
/// Returns null when the document does not parse. That is a real problem, but
/// it is `validate`'s to report and it is reported better there -- with every
/// schema error at once. Bindings cannot be checked against a tree that was
/// never built.
BindingCheck? bindingCheck(String documentPath, String? dataPath) {
  final DocumentSpec document;
  try {
    document = DocumentSpec.parse(File(documentPath).readAsStringSync());
  } on SchemaException {
    return null;
  } on FormatException {
    return null;
  }

  return BindingCheck(
    problems: dataProblems(document, readData(dataPath)),
    hasData: dataPath != null,
  );
}

/// Reads a data file, or gives the empty data a document gets without one.
Map<String, Object?> readData(String? path) {
  if (path == null) return const <String, Object?>{};
  final Object? decoded;
  try {
    decoded = jsonDecode(File(path).readAsStringSync());
  } on FormatException catch (error) {
    throw CliError('$path is not valid JSON.\n\n${error.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw CliError(
      '$path must be a JSON object, since a document reads it by name.',
    );
  }
  return decoded;
}

/// How many problems a warning lists before it stops.
const int _shown = 8;

/// Warns that a render is about to draw nothing, on the way in rather than
/// after.
///
/// To stderr, and without stopping: the document may genuinely be a template
/// waiting on data that this run does not have, and refusing to render it
/// would be a worse default than saying so. The exit code stays whatever the
/// render earns.
void warnAboutBindings(BindingCheck check, {required void Function(String) log}) {
  if (check.isEmpty) return;

  final int count = check.problems.length;
  log(
    'warning: $count ${count == 1 ? 'binding has' : 'bindings have'} nothing '
    'to bind to. Whatever they fill will render empty.',
  );
  for (final SchemaProblem problem in check.problems.take(_shown)) {
    log('  ${problem.path}');
    log('    ${problem.message}');
  }
  if (count > _shown) {
    log('  ... and ${count - _shown} more; run validate --data to see them.');
  }
  if (!check.hasData) {
    log('  No data file was given. Pass --data <file> if the document '
        'expects one.');
  }
}
