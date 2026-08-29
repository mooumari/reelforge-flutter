# Checking a document without an engine

A document is data. Deciding whether it is *valid* data is therefore a question
about JSON, not about widgets -- so it should not need a Flutter engine, a
build, or a device to answer. This package is the node vocabulary, the binding
language and every check, in plain Dart.

## Is the document well formed?

```dart
import 'package:reelforge_schema/reelforge_schema.dart';

for (final SchemaProblem problem in DocumentSpec.problemsIn(json)) {
  print('${problem.path}: ${problem.message}');
  // scenes[1].child.subhed: unknown property "subhed"; this node accepts ...
}
```

Every problem at once, each with its JSON path, because a document with four
mistakes should take one round trip to fix rather than four.

## Will the data fill it?

The second question, and the one a schema check alone cannot answer. A valid
document and valid data can still produce nothing at all together:

```dart
final DocumentSpec document = DocumentSpec.parse(json);
final List<SchemaProblem> unbound = dataProblems(document, data);

for (final SchemaProblem problem in unbound) {
  print('${problem.path}: ${problem.message}');
  // scenes[0].child.headline: "{{ headline }}" has nothing to bind to
}
```

`dataProblems` decides by *resolving* each binding through the same `DataScope`
the renderer uses, rather than by guessing statically what keys ought to exist
-- so the two cannot drift apart. Inside a repeat it checks the template
against every item and complains only when it resolves for none of them.

## Bindings on their own

```dart
isBinding('{{ name }}');            // true
bindingPathsIn('{{ user.name }}');  // ['user.name']

const DataScope scope = DataScope(data: <String, Object?>{'name': 'Ada'});
fillString(scope, 'Hello, {{ name | upper }}');  // 'Hello, ADA'
```

Nothing here knows how to build a widget, and that is the point: a server, an
editor or a CI job can check a document without a Flutter toolchain anywhere in
sight. `reelforge_json` turns one into a `Composition`.
