# Releasing

Six packages ship together: `fluttermotion`, `fluttermotion_schema`,
`fluttermotion_kit`, `fluttermotion_json`, `fluttermotion_encoder` and
`fluttermotion_cli`. All are at 0.1.0 and none has been published.

## What is still gating a first release

One decision, not work.

1. ~~**The licensor.**~~ Settled: Mohammad Oumari, named in `LICENSE.md`, in
   each package's copy of it, and as the Licensor the CLA assigns to. FlutterMotion
   is the name of the software, not a party that can grant a licence -- the FSL
   grant is made by a legal person, and copyright in the code vests in its
   author. An entity can be formed later and the copyright assigned to it
   without redoing anything already published.

2. **The repository URL.** There is no git remote. `pub publish --dry-run`
   warns about the missing `repository:` field, and without a public URL a
   source-available licence is a promise nobody can check.

Neither blocks development. One piece of work does remain: the packages depend
on each other by `path:` inside this repo, and pub will not accept that. Each
inter-package dependency has to become a version constraint with a
`pubspec_overrides.yaml` pointing back at the local checkout, which is the
arrangement `fluttermotion_encoder` already uses and the others do not yet.

## Before publishing

```bash
tool/verify_video_mapping.sh              # both probes, several shard counts
(cd packages/fluttermotion         && flutter test)
(cd packages/fluttermotion_kit     && flutter test)
(cd packages/fluttermotion_json    && flutter test)
(cd packages/fluttermotion_encoder && flutter test)
(cd packages/fluttermotion_schema  && dart test)
(cd packages/fluttermotion_cli     && dart test)
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
   fluttermotion          (depends on nothing here)
   fluttermotion_schema   (depends on nothing at all -- pure Dart)
   fluttermotion_kit      -> fluttermotion
   fluttermotion_encoder  -> fluttermotion
   fluttermotion_json     -> fluttermotion, _kit, _schema
   fluttermotion_cli      -> fluttermotion_schema
   ```

   `fluttermotion_cli` used to depend on nothing -- it drove `flutter` as a
   subprocess and nothing else. It now reads the document format directly, so
   that `validate` needs no build.

## Why pubspec_overrides.yaml exists

`fluttermotion_encoder` depends on a *version* of `fluttermotion`, which is
what makes it publishable. Inside this repo that would send pub looking on
pub.dev instead of at the checkout two directories away, so
`packages/fluttermotion_encoder/pubspec_overrides.yaml` and
`example/pubspec_overrides.yaml` point both back at the local source.

The example needs its own override rather than inheriting one: a path-sourced
`fluttermotion` does not satisfy the encoder's hosted constraint, because pub
treats the two sources as unrelated. That is worth knowing because it is
exactly what a user hits if they depend on one by path and the other by
version.

`pub publish` reports the override as a hint. That is expected: it is saying
the resolution you tested locally is not the one your users will get, which is
what the dry run above is for.
