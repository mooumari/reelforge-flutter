## 0.1.1

* Adds `example/`, so the package page has an Example tab.

## 0.1.0

- Initial release: the ReelForge document format as pure Dart.
- `DocumentSpec.parse` and `DocumentSpec.problemsIn` — the whole document as
  data, or every problem in it with a JSON path, without building anything.
- The node vocabulary (`NodeType`, `knownNodeTypes`) and every closed name set,
  enumerable for editors and validators.
- `dataProblems` — every binding in a document with nothing behind it in a
  given data object, each with its path. A document and its data are valid
  separately and can still render nothing together.
- `DataScope` and the `{{ path | filter }}` binding language.
- Extracted from `reelforge_json` so that validating a document needs
  neither Flutter nor a build: `reelforge validate reel.json` went from a
  macOS release build to about half a second.
