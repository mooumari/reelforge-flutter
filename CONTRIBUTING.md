# Contributing

Thanks for looking. ReelForge is early and the API will change, so the most
useful contributions right now are bug reports from real projects rather than
large patches against a moving target.

## Before a pull request

Contributions require agreeing to the [CLA](CLA.md). It is short: you keep your
copyright, and you grant the Licensor a licence to ship your contribution under
the project's terms. Say so in the pull request and that is enough.

## Running the suite

```bash
for dir in packages/reelforge packages/reelforge_kit \
           packages/reelforge_json packages/reelforge_encoder example; do
  (cd "$dir" && flutter test)
done
for dir in packages/reelforge_schema packages/reelforge_cli; do
  (cd "$dir" && dart test)
done
flutter analyze packages example
```

CI runs exactly this on every push, plus a publish dry run of each package.

There is also `tool/cold_start.sh`, which installs ReelForge into a Flutter app
created seconds earlier and renders an MP4 from it. It is slower than the unit
tests and it is the only thing here that exercises a project it did not build,
which is why it has caught two bugs that every unit test missed. Run it before
touching `init`, the CLI's project handling, or anything about dependencies.

## The one rule

**A frame is a pure function of its frame number.** Frame 900 must produce the
same pixels whether it is reached by playing forward, scrubbed backward, or
rendered alone in another process. Anything that reads a clock, accumulates
state between frames, or depends on what was rendered before it is a bug, even
when it looks right.

That property is what the determinism tests assert and what makes sharding
across processes safe. If a change makes one of them fail, the change is wrong
rather than the test.

## Style

Match the file you are editing. Comments here explain *why* -- what was tried,
what broke, what the constraint actually was -- and skip what the code already
says.
