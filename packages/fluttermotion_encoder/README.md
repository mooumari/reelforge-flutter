# fluttermotion_encoder

On-device video encoding and decoding for
[FlutterMotion](https://pub.dev/packages/fluttermotion), so a Flutter app can
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

Full documentation is in the repository README.
