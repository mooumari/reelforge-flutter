# reelforge_schema

The ReelForge document format: parsing, validation, and the node
vocabulary — with no Flutter dependency.

A document is data. Whether it is *valid* data is therefore a question about
JSON, not about widgets, and answering it should not need a Flutter engine, a
build, or a device. That is this package.

```dart
for (final SchemaProblem problem in DocumentSpec.problemsIn(json)) {
  print(problem);
  // scenes[1].child.subhed: unknown property "subhed"; this node accepts
  //   alignment, centred, headline, headlineColor, kicker, kickerColor, ...
}
```

`DocumentSpec.parse` gives the whole document as data — scenes, nodes,
bindings, theme, transitions — with every problem reported at once rather than
the first. `reelforge_json` takes one of those and builds a `Composition`;
nothing here knows how, which is what lets a server, an editor or a CLI check a
document without either of them.

## What is here and what is not

| Here | In `reelforge_json` |
|---|---|
| `curveNames` — `easeOutCubic` is a curve | `namedCurves` — which `Curve` it is |
| `NodeType` — a `titleCard` accepts a `headline` | the builder that draws one |
| `ThemeSpec` — `accent` is `0xFF4ADE80` | the `MotionPalette` it becomes |
| `DataScope` — what `{{ weeks.0.label }}` resolves to | reading it on a frame |

The split is the reason both halves have to agree, and they are made to: a
builder cannot be registered for a name this package has never heard of, and
`reelforge_json/test/vocabulary_test.dart` fails if any name set here has
no value behind it there. A curve the validator accepts with nothing to build
from it would render as `linear` and look like the document was wrong.

See the JSON section of the [repository README](../../README.md) for the
document shape and the binding language.
