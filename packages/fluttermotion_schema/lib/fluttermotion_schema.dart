/// The FlutterMotion document format: parsing and validation, no Flutter.
///
/// A document is data. Deciding whether it is *valid* data is therefore a
/// question about JSON, not about widgets -- so it should not need a Flutter
/// engine, a build, or a device to answer. That is this package: the node
/// vocabulary, the binding language, and every check, in plain Dart.
///
/// ```dart
/// for (final SchemaProblem problem in DocumentSpec.problemsIn(json)) {
///   print(problem);  // scenes[1].child.subhed: unknown property "subhed"; ...
/// }
/// ```
///
/// `fluttermotion_json` builds one of these into a `Composition`. Nothing here
/// knows how -- and that is what lets a server, an editor or a CLI check a
/// document without either of them.
library;

export 'src/document.dart'
    show
        DocumentSpec,
        SceneSpec,
        ThemeSpec,
        TransitionSpec,
        currentDocumentVersion,
        knownNodeTypes;
export 'src/errors.dart' show Problems, SchemaException, SchemaProblem;
export 'src/names.dart';
export 'src/node.dart'
    show ChildList, MotionNode, NodeType, ScopedNode, ScopedSpec, SpecList;
export 'src/reader.dart'
    show
        Reader,
        checkAnimated,
        checkColour,
        checkFilters,
        checkInsets,
        parseHex;
export 'src/data_check.dart' show dataProblems;
export 'src/scope.dart'
    show
        DataScope,
        bindingPathsIn,
        fillString,
        fillValue,
        filtersIn,
        isBinding,
        isWholeBinding,
        knownFilters;
