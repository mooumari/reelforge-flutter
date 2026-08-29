## 0.2.0

* `init` writes `^0.2.0` for the framework packages.

## 0.1.1

* Adds `example/`, so the package page has an Example tab.
* `init` adds published version dependencies rather than path dependencies,
  unless `--reelforge <path>` points at a checkout. A CLI installed with
  `dart pub global activate` has no checkout beside it, so `init` failed
  outright for anyone who installed it the documented way -- the one path
  that could not be tested until the packages existed on pub.dev.
* A path install also gets a `pubspec_overrides.yaml`, without which it does
  not resolve at all: the packages constrain each other by version, and pub
  treats a path source and a hosted source as unrelated.

## 0.1.0

First release.

* `reelforge render` -- shards a composition across processes, mixes audio
  and encodes to MP4.
* `reelforge preview` -- runs the scrubber against a project.
* `reelforge init` -- writes a composition, a preview entry point and a
  render entry point into an existing Flutter app; `--json` writes a starter
  document and its data instead.
* `--show-window` lets the render hosts appear on screen; by default they
  render off it.
* The App Sandbox complaint names `init --fix-entitlements`, the command
  that fixes it, in both places it is printed.
* `reelforge validate reel.json --data report.json` -- reports every
  problem in a document, each with its JSON path, without rendering a frame,
  and with `--data` also whether that data fills the document's bindings.
  `render` runs the same check before the build and warns.
* `render` and `preview` accept a document directly
  (`reelforge render reel.json --data report.json`), generating the host
  entry point that loads it. The document is passed to the host on argv as
  well as baked in, so `--no-build` reuses one built host across documents
  honestly.
