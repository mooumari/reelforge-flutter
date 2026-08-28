import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:flutter_test/flutter_test.dart';

/// A composition whose every visual property depends on the frame, so any
/// leaked state or wall-clock dependency would show up as a pixel difference.
final Composition probe = Composition(
  id: 'Probe',
  width: 240,
  height: 320,
  fps: 60,
  durationInFrames: 120,
  builder: (BuildContext context) {
    final int frame = Video.frame(context);
    return ColoredBox(
      color: const Color(0xFF101018),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: interpolate(frame, <int>[0, 119], <double>[0, 180]),
            top: 40,
            child: Transform.rotate(
              angle: frame / 20,
              child: Container(
                width: 60,
                height: 60,
                color: const Color(0xFF4C7DFF),
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 20,
            child: Opacity(
              opacity: interpolate(frame, <int>[0, 60], <double>[0, 1]),
              child: Transform.scale(
                scale: spring(frame),
                child: const Text(
                  'frame',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 24, color: Color(0xFFFFFFFF)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  },
);

Future<Uint8List> renderOnce(CompositionRenderer renderer, int frame) async {
  final ByteData data = await renderer.renderFrameRgba(frame);
  return Uint8List.fromList(data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the same frame renders identically from a fresh renderer', () async {
    final List<Uint8List> renders = <Uint8List>[];
    for (int run = 0; run < 3; run++) {
      final CompositionRenderer renderer = CompositionRenderer(probe);
      renders.add(await renderOnce(renderer, 37));
      renderer.dispose();
    }
    expect(renders[1], equals(renders[0]));
    expect(renders[2], equals(renders[0]));
  });

  test('scrubbing order does not affect the result', () async {
    final CompositionRenderer renderer = CompositionRenderer(probe);
    addTearDown(renderer.dispose);

    // Reached by playing forward from the start.
    for (int f = 0; f < 37; f++) {
      renderer.pump(f);
    }
    final Uint8List forward = await renderOnce(renderer, 37);

    // Reached by scrubbing backward from later in the timeline.
    for (int f = 119; f > 37; f--) {
      renderer.pump(f);
    }
    final Uint8List backward = await renderOnce(renderer, 37);

    // Reached by jumping straight there.
    final Uint8List jumped = await renderOnce(renderer, 37);

    expect(backward, equals(forward));
    expect(jumped, equals(forward));
  });

  test('different frames actually differ', () async {
    final CompositionRenderer renderer = CompositionRenderer(probe);
    addTearDown(renderer.dispose);
    final Uint8List a = await renderOnce(renderer, 10);
    final Uint8List b = await renderOnce(renderer, 11);
    expect(a, isNot(equals(b)));
  });

  test('renders at the composition size', () async {
    final CompositionRenderer renderer = CompositionRenderer(probe);
    addTearDown(renderer.dispose);
    final ui.Image image = await renderer.renderFrame(0);
    expect(image.width, 240);
    expect(image.height, 320);
    image.dispose();
  });

  test('scale changes output resolution but not composition size', () async {
    final CompositionRenderer renderer = CompositionRenderer(probe, scale: 2.0);
    addTearDown(renderer.dispose);
    final ui.Image image = await renderer.renderFrame(0);
    expect(image.width, 480);
    expect(image.height, 640);
    image.dispose();
  });

  test('using a renderer after dispose is caught', () async {
    final CompositionRenderer renderer = CompositionRenderer(probe);
    renderer.dispose();
    expect(() => renderer.pump(0), throwsAssertionError);
  });
}
