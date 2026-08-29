# Exporting video from inside a running app

The desktop CLI shells out to ffmpeg. An app on someone's phone cannot. This
package is the platform half: it encodes rendered frames with the device's own
hardware encoder -- `AVAssetWriter` on iOS and macOS, `MediaCodec` on Android
-- so a shipping app can export video with no ffmpeg, no server and no upload.

```dart
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_encoder/reelforge_encoder.dart';

Future<void> exportReel(Composition composition, String outputPath) async {
  if (!NativeVideoEncoder.isSupported) {
    // Fall back to whatever your app does when export is unavailable.
    return;
  }

  final ExportResult result = await InAppExporter.export(
    composition: composition,
    encoder: NativeVideoEncoder(),
    outputPath: outputPath,
    onProgress: (ExportProgress progress) {
      debugPrint('${progress.frame}/${progress.totalFrames}');
    },
  );

  debugPrint('wrote ${result.width}x${result.height} to ${result.outputPath}');
}
```

The composition is the same object the CLI renders, built from the same
widgets, producing the same frames. Only the encoder differs.

## Scale, cancellation and audio

```dart
final ExportCancellation cancellation = ExportCancellation();
// cancellation.cancel() from a button; export throws ExportCancelled.

await InAppExporter.export(
  composition: composition,
  encoder: NativeVideoEncoder(),
  outputPath: path,
  scale: 0.5,            // half resolution; layout is unaffected
  cancellation: cancellation,
);
```

`scale` multiplies output resolution without reflowing anything -- the tree is
still laid out at the composition's declared size, so only pixel density
changes. Output dimensions are rounded to even numbers because H.264 requires
it, and `ExportResult` reports what was actually written rather than leaving
you to assume.

Audio declared in the composition is mixed by the platform encoder too; there
is nothing extra to wire up.
