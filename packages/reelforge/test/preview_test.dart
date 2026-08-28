import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows the frame it is asked to draw, so tests can assert on what the
/// preview actually handed the composition.
Composition probe({
  String id = 'Probe',
  int durationInFrames = 100,
  int fps = 25,
}) {
  return Composition(
    id: id,
    width: 200,
    height: 100,
    fps: fps,
    durationInFrames: durationInFrames,
    builder: (BuildContext context) => ColoredBox(
      color: const Color(0xFF000000),
      child: Center(
        child: Text(
          'F${Video.frame(context)}',
          style: const TextStyle(fontSize: 20, color: Color(0xFFFFFFFF)),
        ),
      ),
    ),
  );
}

Future<void> pumpPlayer(WidgetTester tester, Composition composition) async {
  tester.view.physicalSize = const Size(1000, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1000, 700)),
        child: CompositionPlayer(
          composition: composition,
          // Fake time advances Timers but not a real Stopwatch.
          stopwatchFactory: tester.binding.clock.stopwatch,
        ),
      ),
    ),
  );
}

/// The preview's own frame readout.
///
/// The composition is rasterised into an image now rather than built into the
/// app's tree, so its content is not there to assert on. What the playhead is
/// doing is read from the chrome instead -- which is what these tests were
/// ever really about.
Finder atFrame(int frame, int total) =>
    find.text('${frame.toString().padLeft(4)} / $total');

String readout(WidgetTester tester) {
  final Text text =
      tester.widget(find.textContaining(RegExp(r'^\s*\d+ / \d+$'))) as Text;
  return text.data!;
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Animates on its own Ticker, knowing nothing about frames -- the case that
/// only lands on the right frame because the renderer drives the animation
/// clock. Built live in the app's tree it would follow the wall clock.
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

Uint8List _bytes(ByteData data) => Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));

void main() {
  testWidgets('starts parked on frame 0', (WidgetTester tester) async {
    await pumpPlayer(tester, probe());
    expect(atFrame(0, 100), findsOneWidget);
  });

  testWidgets('the canvas shows a rasterised frame at composition size',
      (WidgetTester tester) async {
    // Rasterising is asynchronous and needs a real raster thread, so this is
    // the one test that has to leave fake time behind. Without it the whole
    // suite could pass with the canvasblank forever.
    await pumpPlayer(tester, probe());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final RawImage raw = tester.widget(find.byType(RawImage));
    expect(raw.image, isNotNull, reason: 'the canvas never got a frame');
    expect(raw.image!.width, 200);
    expect(raw.image!.height, 100);
  });

  testWidgets('the preview shows exactly what the exporter would write',
      (WidgetTester tester) async {
    // The whole reason the preview draws through the renderer. This composition
    // animates on its own Ticker, so built live in the app's tree it would
    // follow the wall clock and disagree with the export.
    final Composition spinner = Composition(
      id: 'Spinner',
      width: 64,
      height: 64,
      fps: 60,
      durationInFrames: 46, // so `end` parks on frame 45
      builder: (BuildContext context) => const Spinner(),
    );

    await pumpPlayer(tester, spinner);
    await press(tester, LogicalKeyboardKey.end);
    expect(atFrame(45, 46), findsOneWidget);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final RawImage raw = tester.widget(find.byType(RawImage));
    expect(raw.image, isNotNull, reason: 'the canvas never got a frame');

    late Uint8List shown;
    late Uint8List exported;
    await tester.runAsync(() async {
      shown = _bytes((await raw.image!.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!);
      final CompositionRenderer renderer = CompositionRenderer(spinner);
      exported = _bytes(await renderer.renderFrameRgba(45));
      renderer.dispose();
    });

    expect(shown, equals(exported));
  });

  testWidgets('arrow keys step one frame', (WidgetTester tester) async {
    await pumpPlayer(tester, probe());
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(atFrame(1, 100), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(atFrame(2, 100), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(atFrame(1, 100), findsOneWidget);
  });

  testWidgets('stepping is clamped at both ends', (WidgetTester tester) async {
    await pumpPlayer(tester, probe(durationInFrames: 10));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(atFrame(0, 10), findsOneWidget);

    await press(tester, LogicalKeyboardKey.end);
    expect(atFrame(9, 10), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(atFrame(9, 10), findsOneWidget);

    await press(tester, LogicalKeyboardKey.home);
    expect(atFrame(0, 10), findsOneWidget);
  });

  testWidgets('space plays and advances by wall time',
      (WidgetTester tester) async {
    await pumpPlayer(tester, probe(fps: 25, durationInFrames: 100));
    await press(tester, LogicalKeyboardKey.space);

    // 400 ms at 25fps is 10 frames.
    await tester.pump(const Duration(milliseconds: 400));
    expect(atFrame(10, 100), findsOneWidget);

    await press(tester, LogicalKeyboardKey.space); // pause
    await tester.pump(const Duration(milliseconds: 400));
    expect(atFrame(10, 100), findsOneWidget);
  });

  testWidgets('playback loops back to the start', (WidgetTester tester) async {
    await pumpPlayer(tester, probe(fps: 10, durationInFrames: 10));
    await press(tester, LogicalKeyboardKey.space);
    // 1.2 s at 10fps over a 10-frame composition wraps to frame 2.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(atFrame(2, 10), findsOneWidget);
    await press(tester, LogicalKeyboardKey.space);
  });

  testWidgets('the last frame is shown once, then wraps',
      (WidgetTester tester) async {
    // 4 frames at 4fps: one frame per 250ms, so the pass is exactly 1s.
    await pumpPlayer(tester, probe(fps: 4, durationInFrames: 4));
    await press(tester, LogicalKeyboardKey.space);

    for (final (int ms, int expected) in <(int, int)>[
      (250, 1),
      (250, 2),
      (250, 3),
      (250, 0), // wraps exactly at the duration, not a frame late
      (250, 1),
    ]) {
      await tester.pump(Duration(milliseconds: ms));
      expect(atFrame(expected, 4), findsOneWidget);
    }
    await press(tester, LogicalKeyboardKey.space);
  });

  testWidgets('replaying from the end starts at frame 0',
      (WidgetTester tester) async {
    await pumpPlayer(tester, probe(durationInFrames: 10));
    await press(tester, LogicalKeyboardKey.keyL); // loop off
    await press(tester, LogicalKeyboardKey.end);
    expect(atFrame(9, 10), findsOneWidget);

    await press(tester, LogicalKeyboardKey.space); // replay
    expect(atFrame(0, 10), findsOneWidget,
        reason: 'the canvas still showed the last frame after replaying');
    await press(tester, LogicalKeyboardKey.space);
  });

  testWidgets('tapping the scrubber seeks', (WidgetTester tester) async {
    await pumpPlayer(tester, probe(durationInFrames: 101));
    final Finder scrubber = find.byType(Scrubber);
    expect(scrubber, findsOneWidget);

    final Rect box = tester.getRect(scrubber);
    await tester.tapAt(Offset(box.left + box.width / 2, box.center.dy));
    await tester.pump();
    expect(atFrame(50, 101), findsOneWidget);

    await tester.tapAt(Offset(box.right - 1, box.center.dy));
    await tester.pump();
    expect(atFrame(100, 101), findsOneWidget);
  });

  testWidgets('dragging the scrubber pauses, then resumes if it was playing',
      (WidgetTester tester) async {
    await pumpPlayer(tester, probe(fps: 25, durationInFrames: 100));
    await press(tester, LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 200));
    expect(atFrame(5, 100), findsOneWidget);

    final Rect box = tester.getRect(find.byType(Scrubber));
    final TestGesture gesture =
        await tester.startGesture(Offset(box.left + 5, box.center.dy));
    await tester.pump();
    // Held still mid-drag: time passes but the playhead must not advance.
    await tester.pump(const Duration(milliseconds: 400));
    final String held = readout(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      readout(tester),
      held,
      reason: 'the playhead moved while scrubbing',
    );

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(atFrame(0, 100), findsNothing, reason: 'playback did not resume');
    await press(tester, LogicalKeyboardKey.space);
  });

  testWidgets('the sidebar lists compositions and switches between them',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ReelForgePreview(
        compositions: <Composition>[
          probe(id: 'First'),
          probe(id: 'Second', durationInFrames: 30),
        ],
      ),
    );
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('   0 / 100'), findsOneWidget);

    await tester.tap(find.text('Second'));
    await tester.pump();
    expect(find.text('   0 / 30'), findsOneWidget);
  });

  testWidgets('a single composition hides the sidebar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ReelForgePreview(compositions: <Composition>[probe(id: 'Only')]),
    );
    expect(find.text('Only'), findsNothing);
    expect(atFrame(0, 100), findsOneWidget);
  });

  testWidgets('an empty composition list explains itself',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ReelForgePreview(compositions: <Composition>[]),
    );
    expect(find.textContaining('No compositions'), findsOneWidget);
  });
}
