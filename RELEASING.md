# Releasing

Three packages ship together: `fluttermotion`, `fluttermotion_cli` and
`fluttermotion_encoder`. All three are at 0.1.0 and none has been published.

## What is still gating a first release

Both are decisions, not work.

1. **The licensor.** `LICENSE.md` and the three package copies of it say
   `REPLACE WITH LEGAL ENTITY BEFORE FIRST PUBLIC RELEASE`. The FSL grant is
   made by a named licensor; a placeholder makes the licence unenforceable and
   the release unretractable, which is the wrong order to do those in.

2. **The repository URL.** There is no git remote. `pub publish --dry-run`
   warns about the missing `repository:` field, and without a public URL a
   source-available licence is a promise nobody can check.

Neither blocks development, and everything else is ready: the dry run is clean
on all three but for that one warning.

## Before publishing

```bash
tool/verify_video_mapping.sh              # both probes, several shard counts
(cd packages/fluttermotion         && flutter test)
(cd packages/fluttermotion_cli     && dart test)
(cd packages/fluttermotion_encoder && flutter test)
flutter analyze packages example
```

Then, in each package:

```bash
flutter pub publish --dry-run
```

## Publishing

Publishing is irreversible. A version can be retracted but never removed, and
the package name is claimed permanently.

1. Fill in the licensor in `LICENSE.md` and the three package `LICENSE` files.
2. Add `repository:` to each `pubspec.yaml`.
3. Delete the `publish_to: none` line from each `pubspec.yaml`.
4. Publish **`fluttermotion` first**. `fluttermotion_encoder` depends on
   `^0.1.0` of it, and pub will not accept a package whose dependency does not
   resolve.
5. Then `fluttermotion_encoder`, then `fluttermotion_cli` (which depends on
   neither -- it drives `flutter` as a subprocess).

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
