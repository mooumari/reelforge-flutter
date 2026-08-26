/// Something wrong with a document, and exactly where.
///
/// JSON that describes a video is going to be written by people, by editors
/// and by models, and all three get it wrong. A `type 'String' is not a
/// subtype of type 'num'` thrown from somewhere inside a chart is useless to
/// every one of them, so nothing in this package reads a value without
/// knowing the path it came from.
class SchemaProblem {
  const SchemaProblem(this.path, this.message);

  /// Where in the document, as a JSON path: `scenes[1].child.bars`.
  final String path;

  final String message;

  @override
  String toString() => '$path: $message';
}

/// Thrown when a document cannot be built.
///
/// Carries *every* problem found rather than the first, because an author
/// fixing one mistake at a time through six round trips is the thing that
/// makes a format unpleasant to write.
class SchemaException implements Exception {
  SchemaException(this.problems);

  final List<SchemaProblem> problems;

  @override
  String toString() => problems.length == 1
      ? 'Invalid composition document -- ${problems.single}'
      : 'Invalid composition document, ${problems.length} problems:\n'
          '${problems.map((SchemaProblem p) => '  $p').join('\n')}';
}

/// Collects problems while walking a document.
///
/// Parsing keeps going after a problem so that one pass reports everything.
/// Where a value is unusable the parser substitutes something harmless and
/// records the problem; the document is refused at the end, so nothing built
/// on a substituted value is ever rendered.
class Problems {
  final List<SchemaProblem> _found = <SchemaProblem>[];

  List<SchemaProblem> get found => List<SchemaProblem>.unmodifiable(_found);

  bool get isEmpty => _found.isEmpty;

  void add(String path, String message) =>
      _found.add(SchemaProblem(path, message));

  void throwIfAny() {
    if (_found.isNotEmpty) throw SchemaException(found);
  }
}

/// Appends a key to a JSON path.
String child(String path, String key) => path.isEmpty ? key : '$path.$key';

/// Appends an index to a JSON path.
String index(String path, int i) => '$path[$i]';
