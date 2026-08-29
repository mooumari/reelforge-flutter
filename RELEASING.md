# Releasing

Six packages ship together: `reelforge`, `reelforge_schema`,
`reelforge_kit`, `reelforge_json`, `reelforge_encoder` and
`reelforge_cli`. Five of them are published; `reelforge_encoder` is held back
deliberately, and says why in its own `pubspec.yaml`.

All six carry the same version, and they are bumped together whether or not
each one changed -- a reader who has `reelforge 0.2.0` should not have to work
out which of its siblings moved with it.

## Before publishing

```bash
tool/verify_video_mapping.sh              # both probes, several shard counts
(cd packages/reelforge         && flutter test)
(cd packages/reelforge_kit     && flutter test)
(cd packages/reelforge_json    && flutter test)
(cd packages/reelforge_encoder && flutter test)
(cd packages/reelforge_schema  && dart test)
(cd packages/reelforge_cli     && dart test)
flutter analyze packages example
```

Then, in each package:

```bash
flutter pub publish --dry-run
```

## Publishing

Publishing is irreversible. A version can be retracted but never removed, and
the package name is claimed permanently.

1. Bump `version:` in all six `pubspec.yaml` files, and the constraints the
   siblings put on each other, and `frameworkConstraint` in
   `reelforge_cli/lib/src/init_command.dart` -- that last one is what `init`
   writes into a user's project, and a test fails if it drifts.
2. Add a `CHANGELOG.md` entry to every package, including the ones that only
   moved to keep the versions in step.
3. Publish in dependency order, because pub will not accept a package whose
   dependencies do not resolve:

   ```
   reelforge          (depends on nothing here)
   reelforge_schema   (depends on nothing at all -- pure Dart)
   reelforge_kit      -> reelforge
   reelforge_encoder  -> reelforge
   reelforge_json     -> reelforge, _kit, _schema
   reelforge_cli      -> reelforge_schema
   ```

   `reelforge_cli` used to depend on nothing -- it drove `flutter` as a
   subprocess and nothing else. It now reads the document format directly, so
   that `validate` needs no build.

## Why pubspec_overrides.yaml exists

Every package here depends on its siblings by *version*, which is what makes
them publishable -- pub rejects a `path:` dependency outright. Inside this repo
that would send pub looking on pub.dev instead of at the checkout one directory
away, so each package that has such a dependency carries a
`pubspec_overrides.yaml` pinning it to the local source: `reelforge_kit`,
`reelforge_json`, `reelforge_encoder`, `reelforge_cli` and the
example.

Each of those lists *every* package in its resolution, not only its direct
dependencies. A path-sourced `reelforge` does not satisfy a hosted
constraint on `reelforge`, because pub treats the two sources as unrelated
-- so one package left un-overridden fails to satisfy the constraint some other
package puts on it. That is worth knowing because it is exactly what a user
hits if they depend on one of these by path and another by version.

The overrides are development-only and are kept out of the published archives
by each package's `.pubignore`.

`pub publish` reports the override as a hint. That is expected: it is saying
the resolution you tested locally is not the one your users will get, which is
what the dry run above is for.
