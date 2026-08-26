# fluttermotion

Build videos with Flutter. A composition is a pure function of frame number,
rendered frame by frame into a video file -- `data -> Flutter widgets -> frames
-> MP4`. Not screen recording.

```dart
final Composition hello = Composition(
  id: 'Hello',
  width: 1080,
  height: 1920,
  fps: 30,
  durationInFrames: 90,
  builder: (BuildContext context) => const _Hello(),
);

class _Hello extends StatelessWidget {
  const _Hello();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double fade = interpolate(frame, <double>[0, 20], <double>[0, 1]);
    return Opacity(opacity: fade, child: const Text('Hello'));
  }
}
```

Render it with [`fluttermotion_cli`](https://pub.dev/packages/fluttermotion_cli),
or export from inside a running app with
[`fluttermotion_encoder`](https://pub.dev/packages/fluttermotion_encoder).

Full documentation, including video clips, audio, sharding and the on-device
export path, is in the repository README.
