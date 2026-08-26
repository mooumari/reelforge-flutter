// Widgets lifted out of a real app animate on their own Ticker and read their
// app's ambient Theme. Neither survives a detached, frame-addressed render
// tree unaided, and both fail *quietly* -- a blank badge, a stock-purple card.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Written the way an app widget is written: owns a controller, knows nothing
/// about frames. Its grey value is the controller's value, so one pixel says
/// exactly where the animation was.
class Spinner extends StatefulWidget {
  const Spinner({super.key});
  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final int grey = (_controller.value * 255).round().clamp(0, 255);
          return ColoredBox(color: Color.fromARGB(255, grey, grey, grey));
        },
      );
}

/// The other ubiquitous idiom: start an implicit animation from a post-frame
/// callback. In a detached tree that callback never fires at all.
class FadeIn extends StatefulWidget {
  const FadeIn({super.key});
  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 1000),
        child: const ColoredBox(color: Color(0xFFFFFFFF)),
      );
}

/// Reads its app's theme, as app widgets do.
class BrandCard extends StatelessWidget {
  const BrandCard({super.key});
  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Theme.of(context).colorScheme.primary);
}

Composition wrap(
  String id,
  Widget child, {
  Widget Function(BuildContext, Widget)? wrapper,
}) =>
    Composition(
      id: id,
      width: 64,
      height: 64,
      fps: 60,
      durationInFrames: 180,
      wrapper: wrapper,
      builder: (BuildContext context) => child,
    );

Future<Uint8List> shot(CompositionRenderer r, int frame) async {
  final ByteData d = await r.renderFrameRgba(frame);
  return Uint8List.fromList(
      d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
}

int _centre(Uint8List px, int channel) => px[((32 * 64) + 32) * 4 + channel];
int red(Uint8List px) => _centre(px, 0);
int green(Uint8List px) => _centre(px, 1);
int blue(Uint8List px) => _centre(px, 2);
int alpha(Uint8List px) => _centre(px, 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a widget animating on its own ticker', () {
    test('advances with the frame, not the wall clock', () async {
      final CompositionRenderer r = CompositionRenderer(
        wrap('Spin', const Spinner()),
      );
      addTearDown(r.dispose);

      // A 1000ms cycle at 60fps: frame f sits (f % 60) / 60 through it.
      for (final int frame in <int>[0, 15, 30, 45, 75, 90]) {
        final int expected = (((frame % 60) / 60) * 255).round();
        expect(
          red(await shot(r, frame)),
          closeTo(expected, 1),
          reason: 'frame $frame of a 1000ms repeat',
        );
      }
    });

    test('seeking to a frame matches playing through to it', () async {
      // This is the shard boundary. A Ticker treats its first tick as elapsed
      // zero, so without priming a renderer entering at frame 45 starts the
      // animation over -- and video one animation out still looks like video.
      final CompositionRenderer seeked =
          CompositionRenderer(wrap('Spin', const Spinner()));
      final Uint8List direct = await shot(seeked, 45);
      seeked.dispose();

      final CompositionRenderer played =
          CompositionRenderer(wrap('Spin', const Spinner()));
      for (int frame = 0; frame <= 45; frame++) {
        await shot(played, frame);
      }
      final Uint8List streamed = await shot(played, 45);
      played.dispose();

      expect(direct, equals(streamed));
    });

    test('mounted mid-timeline, it still anchors where it mounts', () async {
      // Mounting at frame 0 is not enough: a widget inside a Sequence mounts
      // when the sequence says so, and its ticker has to anchor there. A
      // renderer seeking straight to frame 90 has to arrive at the state a
      // play-through would have been in.
      final Composition late = Composition(
        id: 'Late',
        width: 64,
        height: 64,
        fps: 60,
        durationInFrames: 180,
        builder: (BuildContext context) => const Sequence(
          from: 60,
          durationInFrames: 120,
          child: Spinner(),
        ),
      );

      final CompositionRenderer seeked = CompositionRenderer(late);
      final Uint8List direct = await shot(seeked, 90);
      seeked.dispose();

      final CompositionRenderer played = CompositionRenderer(late);
      for (int frame = 0; frame <= 90; frame++) {
        await shot(played, frame);
      }
      final Uint8List streamed = await shot(played, 90);
      played.dispose();

      expect(direct, equals(streamed));
    });

    test('scrubbing backwards returns to the same pixels', () async {
      final CompositionRenderer r =
          CompositionRenderer(wrap('Spin', const Spinner()));
      addTearDown(r.dispose);

      final Uint8List first = await shot(r, 30);
      await shot(r, 120);
      final Uint8List again = await shot(r, 30);
      expect(again, equals(first));
    });
  });

  group('an implicit animation started from a post-frame callback', () {
    test('actually runs, rather than exporting blank', () async {
      final CompositionRenderer r =
          CompositionRenderer(wrap('Fade', const FadeIn()));
      addTearDown(r.dispose);

      // Played through, the way the exporter and every shard drive it.
      //
      // The fade starts on frame 1, not frame 0: the callback runs after frame
      // 0 has been built, so the rebuild it triggers lands a frame later. That
      // is what happens in a real app too, and reproducing it is the point --
      // a 1000ms fade at 60fps is therefore 29/60 done by frame 30, not 30/60.
      final List<int> alphas = <int>[];
      for (int frame = 0; frame <= 60; frame++) {
        alphas.add(alpha(await shot(r, frame)));
      }
      // Frame f is (f - 1) / 60 through the fade, so 255 * 29/60 = 123 at
      // frame 30 and 255 * 59/60 = 251 at frame 60.
      expect(alphas[0], 0);
      expect(alphas[1], 0);
      expect(alphas[30], closeTo(123, 2));
      expect(alphas[60], closeTo(251, 2));
    });

    test('is the same seeked as played through', () async {
      final CompositionRenderer seeked =
          CompositionRenderer(wrap('Fade', const FadeIn()));
      final Uint8List direct = await shot(seeked, 30);
      seeked.dispose();

      final CompositionRenderer played =
          CompositionRenderer(wrap('Fade', const FadeIn()));
      for (int frame = 0; frame <= 30; frame++) {
        await shot(played, frame);
      }
      final Uint8List streamed = await shot(played, 30);
      played.dispose();

      expect(direct, equals(streamed));
    });
  });

  group('ambient state a widget was written against', () {
    test('without a wrapper, Theme.of falls back and says nothing', () async {
      final CompositionRenderer r =
          CompositionRenderer(wrap('Brand', const BrandCard()));
      addTearDown(r.dispose);

      final Uint8List px = await shot(r, 0);
      // Stock Material 3 seed purple, #6750A4 -- not anybody's brand.
      expect(<int>[red(px), green(px), blue(px)], <int>[103, 80, 164]);
    });

    test('a wrapper supplies it, and the render honours it', () async {
      const Color brand = Color(0xFFCC0044);
      final CompositionRenderer r = CompositionRenderer(wrap(
        'Brand',
        const BrandCard(),
        wrapper: (BuildContext context, Widget child) => Theme(
          data: ThemeData(
            colorScheme: const ColorScheme.light(primary: brand),
          ),
          child: child,
        ),
      ));
      addTearDown(r.dispose);

      final Uint8List px = await shot(r, 0);
      expect(<int>[red(px), green(px), blue(px)], <int>[0xCC, 0x00, 0x44]);
    });
  });

  test('the clock can be switched off, and then nothing animates', () async {
    // The escape hatch, and the proof that the clock is what does the work:
    // this is exactly what every one of the cases above used to do.
    final CompositionRenderer r = CompositionRenderer(
      wrap('Spin', const Spinner()),
      driveAnimationClock: false,
    );
    addTearDown(r.dispose);

    expect(red(await shot(r, 0)), 0);
    expect(red(await shot(r, 45)), 0);
  });
}
