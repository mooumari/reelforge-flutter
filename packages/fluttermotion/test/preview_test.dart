import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
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
        child: CompositionPlayer(composition: composition),
      ),
    ),
  );
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  testWidgets('starts parked on frame 0', (WidgetTester tester) async {
    await pumpPlayer(tester, probe());
    expect(find.text('F0'), findsOneWidget);
    expect(find.text('   0 / 100'), findsOneWidget);
  });

  testWidgets('arrow keys step one frame', (WidgetTester tester) async {
    await pumpPlayer(tester, probe());
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('F1'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('F2'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.text('F1'), findsOneWidget);
  });

  testWidgets('stepping is clamped at both ends', (WidgetTester tester) async {
    await pumpPlayer(tester, probe(durationInFrames: 10));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.text('F0'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.end);
    expect(find.text('F9'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('F9'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.home);
    expect(find.text('F0'), findsOneWidget);
  });

  testWidgets('space plays and advances by wall time',
      (WidgetTester tester) async {
    await pumpPlayer(tester, probe(fps: 25, durationInFrames: 100));
    await press(tester, LogicalKeyboardKey.space);

    // 400 ms at 25fps is 10 frames.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('F10'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.space); // pause
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('F10'), findsOneWidget);
  });

  testWidgets('playback loops back to the start', (WidgetTester tester) async {
    await pumpPlayer(tester, probe(fps: 10, durationInFrames: 10));
    await press(tester, LogicalKeyboardKey.space);
    // 1.2 s at 10fps over a 10-frame composition wraps to frame 2.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('F2'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.space);
  });

  testWidgets('the last frame is shown once, then wraps',
      (WidgetTester tester) async {
    // 4 frames at 4fps: one frame per 250ms, so the pass is exactly 1s.
    await pumpPlayer(tester, probe(fps: 4, durationInFrames: 4));
    await press(tester, LogicalKeyboardKey.space);

    for (final (int ms, String expected) in <(int, String)>[
      (250, 'F1'),
      (250, 'F2'),
      (250, 'F3'),
      (250, 'F0'), // wraps exactly at the duration, not a frame late
      (250, 'F1'),
    ]) {
      await tester.pump(Duration(milliseconds: ms));
      expect(find.text(expected), findsOneWidget);
    }
    await press(tester, LogicalKeyboardKey.space);
  });

  testWidgets('replaying from the end starts at frame 0',
      (WidgetTester tester) async {
    await pumpPlayer(tester, probe(durationInFrames: 10));
    await press(tester, LogicalKeyboardKey.keyL); // loop off
    await press(tester, LogicalKeyboardKey.end);
    expect(find.text('F9'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.space); // replay
    expect(find.text('F0'), findsOneWidget,
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
    expect(find.text('F50'), findsOneWidget);

    await tester.tapAt(Offset(box.right - 1, box.center.dy));
    await tester.pump();
    expect(find.text('F100'), findsOneWidget);
  });

  testWidgets('dragging the scrubber pauses, then resumes if it was playing',
      (WidgetTester tester) async {
    await pumpPlayer(tester, probe(fps: 25, durationInFrames: 100));
    await press(tester, LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('F5'), findsOneWidget);

    final Rect box = tester.getRect(find.byType(Scrubber));
    final TestGesture gesture =
        await tester.startGesture(Offset(box.left + 5, box.center.dy));
    await tester.pump();
    // Held still mid-drag: time passes but the playhead must not advance.
    await tester.pump(const Duration(milliseconds: 400));
    final String held =
        (tester.widget(find.byType(Text).first) as Text).data ?? '';
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      (tester.widget(find.byType(Text).first) as Text).data,
      held,
      reason: 'the playhead moved while scrubbing',
    );

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('F0'), findsNothing, reason: 'playback did not resume');
    await press(tester, LogicalKeyboardKey.space);
  });

  testWidgets('the sidebar lists compositions and switches between them',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      FlutterMotionPreview(
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
      FlutterMotionPreview(compositions: <Composition>[probe(id: 'Only')]),
    );
    expect(find.text('Only'), findsNothing);
    expect(find.text('F0'), findsOneWidget);
  });

  testWidgets('an empty composition list explains itself',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const FlutterMotionPreview(compositions: <Composition>[]),
    );
    expect(find.textContaining('No compositions'), findsOneWidget);
  });
}
