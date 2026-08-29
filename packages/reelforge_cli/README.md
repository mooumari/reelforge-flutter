# reelforge_cli

Command-line renderer for [ReelForge](https://pub.dev/packages/reelforge)
compositions.

```bash
dart pub global activate reelforge_cli

reelforge init                          # add compositions to a Flutter app
reelforge preview                       # scrub them, with hot reload
reelforge render --composition Hello    # write Hello.mp4
```

The renderer splits a composition's frames across several processes, mixes any
declared audio, and encodes with ffmpeg. It builds and runs a headless host from
your own project, so compositions can use your app's widgets, fonts and state.

Requires ffmpeg on `PATH` for encoding. Exporting *without* ffmpeg is what
[`reelforge_encoder`](https://pub.dev/packages/reelforge_encoder) is for.

Full documentation is in the [guide](https://github.com/mooumari/reelforge-flutter/blob/main/docs/guide.md).
