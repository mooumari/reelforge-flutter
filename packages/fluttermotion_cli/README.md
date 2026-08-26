# fluttermotion_cli

Command-line renderer for [FlutterMotion](https://pub.dev/packages/fluttermotion)
compositions.

```bash
dart pub global activate fluttermotion_cli

fluttermotion init                          # add compositions to a Flutter app
fluttermotion preview                       # scrub them, with hot reload
fluttermotion render --composition Hello    # write Hello.mp4
```

The renderer splits a composition's frames across several processes, mixes any
declared audio, and encodes with ffmpeg. It builds and runs a headless host from
your own project, so compositions can use your app's widgets, fonts and state.

Requires ffmpeg on `PATH` for encoding. Exporting *without* ffmpeg is what
[`fluttermotion_encoder`](https://pub.dev/packages/fluttermotion_encoder) is for.

Full documentation is in the repository README.
