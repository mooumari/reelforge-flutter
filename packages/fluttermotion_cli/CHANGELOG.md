## 0.1.0

First release.

* `fluttermotion render` -- shards a composition across processes, mixes audio
  and encodes to MP4.
* `fluttermotion preview` -- runs the scrubber against a project.
* `fluttermotion init` -- writes a composition, a preview entry point and a
  render entry point into an existing Flutter app; `--json` writes a starter
  document and its data instead.
* `fluttermotion validate reel.json` -- reports every problem in a document,
  each with its JSON path, without rendering a frame.
* `render` and `preview` accept a document directly
  (`fluttermotion render reel.json --data report.json`), generating the host
  entry point that loads it. The document is passed to the host on argv as
  well as baked in, so `--no-build` reuses one built host across documents
  honestly.
