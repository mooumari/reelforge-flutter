import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a subtree at a given composition frame and reports what the widget
/// under test saw, without rasterising anything.
Future<void> atFrame(
  WidgetTester tester,
  int frame,
  Widget child, {
  int durationInFrames = 120,
}) {
  return tester.pumpWidget(
    VideoFrame(
      frame: frame,
      fps: 60,
      durationInFrames: durationInFrames,
      width: 100,
      height: 100,
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    ),
  );
}

class _ReportFrame extends StatelessWidget {
  const _ReportFrame();

  @override
  Widget build(BuildContext context) => Text('${Video.frame(context)}');
}

void main() {
  testWidgets('Video.frame reads the enclosing frame', (WidgetTester t) async {
    await atFrame(t, 42, const _ReportFrame());
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('Sequence shifts the frame to a local timeline',
      (WidgetTester t) async {
    const Widget child =
        Sequence(from: 30, durationInFrames: 60, child: _ReportFrame());

    await atFrame(t, 30, child);
    expect(find.text('0'), findsOneWidget);

    await atFrame(t, 45, child);
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('Sequence does not build outside its window',
      (WidgetTester t) async {
    const Widget child =
        Sequence(from: 30, durationInFrames: 60, child: _ReportFrame());

    await atFrame(t, 29, child);
    expect(find.byType(_ReportFrame), findsNothing);

    await atFrame(t, 90, child); // one past the end
    expect(find.byType(_ReportFrame), findsNothing);

    await atFrame(t, 89, child); // last frame in the window
    expect(find.text('59'), findsOneWidget);
  });

  testWidgets('nested Sequences compose their offsets',
      (WidgetTester t) async {
    const Widget child = Sequence(
      from: 10,
      child: Sequence(from: 5, child: _ReportFrame()),
    );
    await atFrame(t, 20, child);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('a Sequence reports its own duration to children',
      (WidgetTester t) async {
    await atFrame(
      t,
      30,
      Sequence(
        from: 30,
        durationInFrames: 60,
        child: Builder(
          builder: (BuildContext context) =>
              Text('${Video.durationInFrames(context)}'),
        ),
      ),
    );
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('an unbounded Sequence runs to the end of the composition',
      (WidgetTester t) async {
    await atFrame(
      t,
      30,
      Sequence(
        from: 20,
        child: Builder(
          builder: (BuildContext context) =>
              Text('${Video.durationInFrames(context)}'),
        ),
      ),
      durationInFrames: 120,
    );
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('Video.progress spans 0 to 1', (WidgetTester t) async {
    await atFrame(
      t,
      0,
      Builder(
        builder: (BuildContext c) => Text('${Video.progress(c)}'),
      ),
      durationInFrames: 101,
    );
    expect(find.text('0.0'), findsOneWidget);

    await atFrame(
      t,
      100,
      Builder(
        builder: (BuildContext c) => Text('${Video.progress(c)}'),
      ),
      durationInFrames: 101,
    );
    expect(find.text('1.0'), findsOneWidget);
  });

  testWidgets('reading the frame outside a composition asserts',
      (WidgetTester t) async {
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: _ReportFrame(),
    ));
    expect(t.takeException(), isAssertionError);
  });
}
