import 'document.dart';
import 'errors.dart';
import 'node.dart';
import 'scope.dart';

/// Every binding in [document] that has nothing in [data] behind it.
///
/// ## Why this is a separate question from validity
///
/// A document and its data are checked apart from each other, and both can be
/// perfectly well formed while the pair renders nothing. `longform.json`
/// validates; run it without `report.json` and it produces sixty seconds of
/// video in which every bound value is empty and every `repeat` draws zero
/// children. Nothing throws, nothing warns, and the file plays.
///
/// That is the worst failure a video tool can have, because a missing binding
/// renders as *absence* -- which is indistinguishable, in the output, from a
/// scene that was meant to be sparse. The only way to notice is to watch the
/// whole video and already know what it should look like.
///
/// So this asks the one question neither half can answer alone: given this
/// data, will this document draw anything?
///
/// ## How it decides
///
/// By resolving, not by guessing. Every binding is looked up through the same
/// [DataScope] the renderer would use, in the same order -- item first, then
/// root -- so the rules cannot drift from the ones that actually apply. A
/// binding that resolves to null is reported, because null is exactly what
/// renders as nothing.
///
/// Inside a `repeat`, the template is checked against *every* item, and a
/// binding is only reported when it resolves for none of them. A field that
/// some rows have and others do not is ordinary data, not a mistake; a field
/// no row has is a typo or a missing key.
List<SchemaProblem> dataProblems(
  DocumentSpec document,
  Map<String, Object?> data,
) {
  final Problems problems = Problems();
  final List<DataScope> root = <DataScope>[DataScope(data: data)];

  final MotionNode? tree = document.root;
  if (tree != null) _checkNode(tree, root, problems);
  final MotionNode? bed = document.bed;
  if (bed != null) _checkNode(bed, root, problems);
  for (final SceneSpec scene in document.scenes) {
    _checkNode(scene.child, root, problems);
    final MotionNode? sting = scene.sting;
    if (sting != null) _checkNode(sting, root, problems);
  }
  return problems.found;
}

/// Checks one node against every scope it could be read in.
///
/// A list of scopes rather than one because a node inside a `repeat` is a
/// single node in the document that renders once per item, and each rendering
/// reads its bindings differently. Checking it once against all of them
/// reports a missing field once, at its own path -- rather than once per row,
/// which for a twelve-week chart would be twelve copies of the same sentence.
void _checkNode(MotionNode node, List<DataScope> scopes, Problems problems) {
  // `props` is the node's raw JSON, so it holds the children, slots and repeat
  // templates as well as the plain properties. Those are walked below, in the
  // scopes that actually apply to them; descending into them here would check
  // a repeat template against the data outside its own repeat, where its
  // fields are genuinely absent and reporting them would be wrong.
  final Set<String> structural = <String>{
    'type',
    ...node.type.slots,
    ...node.type.lists,
    ...node.type.specs.keys,
  };
  node.props.forEach((String key, Object? value) {
    if (structural.contains(key)) return;
    _checkValue(value, scopes, child(node.path, key), problems);
  });

  node.slots.forEach((String _, MotionNode slot) {
    _checkNode(slot, scopes, problems);
  });

  node.lists.forEach((String key, ChildList list) {
    if (!list.repeats) {
      for (final MotionNode each in list.nodes) {
        _checkNode(each, scopes, problems);
      }
      return;
    }
    final List<DataScope> items = _itemScopes(
      list.over!,
      scopes,
      child(node.path, key),
      problems,
    );
    if (items.isEmpty) return;
    _checkNode(list.template!, items, problems);
  });

  node.specs.forEach((String key, SpecList spec) {
    final String path = child(node.path, key);
    if (!spec.repeats) {
      for (int i = 0; i < spec.items.length; i++) {
        _checkValue(spec.items[i], scopes, index(path, i), problems);
      }
      return;
    }
    final List<DataScope> items =
        _itemScopes(spec.over!, scopes, path, problems);
    if (items.isEmpty) return;
    // `as` is where the template actually lives in the file, and a problem
    // has to point at a path the author can find.
    _checkValue(spec.template, items, child(path, 'as'), problems);
  });
}

/// A scope per item of the list [over] names, across every enclosing scope.
///
/// Empty when there is nothing to repeat over, which happens two ways: the
/// key is missing -- reported -- or the list is there and empty, which is not
/// a mistake. A week with no releases is a real week. The template's own
/// bindings then go unchecked rather than being reported as absent, because
/// there is no item to check them against.
List<DataScope> _itemScopes(
  String over,
  List<DataScope> scopes,
  String path,
  Problems problems,
) {
  final List<DataScope> items = <DataScope>[];
  Object? wrongType;
  bool found = false;

  for (final DataScope scope in scopes) {
    final Object? source = scope.resolve(over);
    if (source == null) continue;
    found = true;
    if (source is! List<Object?>) {
      wrongType ??= source;
      continue;
    }
    for (int i = 0; i < source.length; i++) {
      items.add(scope.forItem(source[i], i));
    }
  }

  if (!found) {
    problems.add(path, 'repeats over "$over", which is not in the data');
  } else if (items.isEmpty && wrongType != null) {
    problems.add(
      path,
      'repeats over "$over", which is ${_describe(wrongType)}, not a list',
    );
  }
  return items;
}

/// Checks every binding in [value], which may be nested inside maps and lists.
///
/// Bindings are not only top-level string properties: an animated value keeps
/// them in its keyframes, insets are a list, and a repeat template is a map.
/// Walking the shape is cheaper than knowing which properties are allowed to
/// hold one.
///
/// [scopes] is every scope the value could be read in -- one outside a repeat,
/// one per item inside one. A binding counts as bound if it resolves in any of
/// them.
void _checkValue(
  Object? value,
  List<DataScope> scopes,
  String path,
  Problems problems,
) {
  if (value is Map<String, Object?>) {
    value.forEach((String key, Object? nested) {
      _checkValue(nested, scopes, child(path, key), problems);
    });
    return;
  }
  if (value is List<Object?>) {
    for (int i = 0; i < value.length; i++) {
      _checkValue(value[i], scopes, index(path, i), problems);
    }
    return;
  }
  if (value is! String || !isBinding(value)) return;

  for (final String binding in bindingPathsIn(value)) {
    // These come from the scope rather than the data, and are always there.
    if (binding == '@index' || binding == '@item') continue;
    final bool bound = scopes.any(
      (DataScope scope) => scope.resolve(binding) != null,
    );
    if (!bound) {
      problems.add(path, '"{{ $binding }}" has nothing to bind to');
    }
  }
}

String _describe(Object? value) {
  if (value is Map) return 'an object';
  if (value is String) return 'a string';
  if (value is num) return 'a number';
  if (value is bool) return 'a boolean';
  return 'a ${value.runtimeType}';
}
