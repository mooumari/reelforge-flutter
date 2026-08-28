# Releasing

Six packages ship together: `reelforge`, `reelforge_schema`,
`reelforge_kit`, `reelforge_json`, `reelforge_encoder` and
`reelforge_cli`. All are at 0.1.0 and none has been published.

## What is still gating a first release

One decision, not work.

1. ~~**The licensor.**~~ Settled: Mohammad Oumari, named in `LICENSE.md`, in
   each package's copy of it, and as the Licensor the CLA assigns to. ReelForge
   is the name of the software, not a party that can grant a licence -- the FSL
   grant is made by a legal person, and copyright in the code vests in its
   author. An entity can be formed later and the copyright assigned to it
   without redoing anything already published.

2. **The repository URL.** There is no git remote. `pub publish --dry-run`
   warns about the missing `repository:` field, and without a public URL a
   source-available licence is a promise nobody can check.

It does not block development, and no work is outstanding: every
inter-package dependency is now a version constraint with a
`pubspec_overrides.yaml` pointing back at the local checkout.

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

1. Fill in the licensor in `LICENSE.md` and each package's `LICENSE` file.
2. Add `repository:` to each `pubspec.yaml`.
3. Delete the `publish_to: none` line from each `pubspec.yaml`.
4. Publish in dependency order, because pub will not accept a package whose
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
