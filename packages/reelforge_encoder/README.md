# reelforge_encoder

On-device video encoding and decoding for
[ReelForge](https://pub.dev/packages/reelforge), so a Flutter app can
export video itself with no ffmpeg binary anywhere near it.

```dart
final ExportResult result = await InAppExporter.export(
  composition: myComposition,
  encoder: NativeVideoEncoder(),
  videoBackend: NativeVideoBackend(),
  outputPath: '${dir.path}/out.mp4',
);
```

`NativeVideoEncoder` writes H.264 through `AVAssetWriter`, with the
composition's declared sounds mixed in. `NativeVideoBackend` decodes
`VideoClip` sources through `AVAssetReader`, landing on the same source frames
the ffmpeg decoder does.

**iOS and macOS.** Android is not implemented yet.

**Not yet a Swift package.** The plugin ships a podspec and no `Package.swift`,
so Flutter builds it through CocoaPods and prints a warning saying that will
become an error in a future release. It builds and runs today; adopting Swift
Package Manager is outstanding work, and it has to happen before the version of
Flutter that drops the fallback.

Full documentation is in the [guide](https://github.com/mooumari/reelforge-flutter/blob/main/docs/guide.md).
