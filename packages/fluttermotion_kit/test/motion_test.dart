import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';

import 'harness.dart';

Future<double> opacityOf(WidgetTester tester, Widget widget, int frame) async {
  await tester.pumpWidget(at(frame, Center(child: widget)));
  final Iterable<Opacity> found = tester.widgetList<Opacity>(
    find.byType(Opacity),
  );
  return found.isEmpty ? 1 : found.first.opacity;
}

void main() {
  group('Enter', () {
    testWidgets('holds at nothing until its delay is up',
        (WidgetTester tester) async {
      const Widget child = Text('x');
      expect(
        await opacityOf(tester, const Enter.fade(delay: 20, child: child), 0),
        0,
      );
      expect(
        await opacityOf(tester, const Enter.fade(delay: 20, child: child), 19),
        0,
      );
      expect(
        await opacityOf(tester, const Enter.fade(delay: 20, child: child), 32),
        1,
      );
    });

    testWidgets('a spring overshoots without ever exceeding opacity 1',
        (WidgetTester tester) async {
      // The reason opacity is clamped separately from the offset it shares a
      // driver with: Opacity asserts above 1, and an underdamped spring goes
      // there on purpose.
      for (int frame = 0; frame < 60; frame++) {
        final double opacity = await opacityOf(
          tester,
          const Enter.spring(child: Text('x')),
          frame,
        );
        expect(opacity, inInclusiveRange(0, 1), reason: 'frame $frame');
      }
    });

    testWidgets('slide starts displaced and ends in place',
        (WidgetTester tester) async {
      Future<Offset> offsetAt(int frame) async {
        await tester.pumpWidget(at(
          frame,
          Center(child: Enter.slideUp(distance: 80, duration: 10, child: const Text('x'))),
        ));
        final RenderBox box = tester.renderObject(find.text('x'));
        return box.localToGlobal(Offset.zero);
      }

      final Offset start = await offsetAt(0);
      final Offset landed = await offsetAt(10);
      expect(start.dy - landed.dy, closeTo(80, 0.5));
      // And it stays landed rather than drifting past.
      expect((await offsetAt(40)).dy, closeTo(landed.dy, 1e-9));
    });
  });

  group('Stagger', () {
    testWidgets('each child starts later than the one before',
        (WidgetTester tester) async {
      await tester.pumpWidget(at(
        6,
        Stagger(
          step: 6,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              const Enter.fade(duration: 6, child: SizedBox(width: 10)),
          ],
        ),
      ));

      final List<double> opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((Opacity o) => o.opacity)
          .toList();
      // First child is 6 frames in and done; second is at its own frame 0;
      // third has not started.
      expect(opacities, <double>[1, 0, 0]);
    });

    testWidgets('a nested Enter does not pick up its parent\'s stagger twice',
        (WidgetTester tester) async {
      // Enter re-provides a zero delay for its subtree. Without that, an
      // Enter inside a staggered card would be delayed by the card's stagger
      // as well as its own, and the innermost content of the last card would
      // arrive long after the video had moved on.
      await tester.pumpWidget(at(
        24,
        Stagger(
          step: 12,
          children: <Widget>[
            const Enter.fade(
              duration: 6,
              child: Enter.fade(duration: 6, child: SizedBox(width: 10)),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ));

      final List<double> opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((Opacity o) => o.opacity)
          .toList();
      // Outer is staggered by 0 and long done; inner counts from the same
      // frame, not from 24 + 0 again.
      expect(opacities, <double>[1, 1]);
    });

    test('wrap tags without laying out', () {
      final List<Widget> tagged =
          Stagger.wrap(<Widget>[const Text('a'), const Text('b')], step: 5);
      expect(tagged, hasLength(2));
      expect((tagged.first as StaggerDelay).frames, 0);
      expect((tagged.last as StaggerDelay).frames, 5);
    });
  });

  group('Counter', () {
    testWidgets('counts from nothing to the target and stops there',
        (WidgetTester tester) async {
      Future<String> textAt(int frame) async {
        await tester.pumpWidget(at(
          frame,
          const Center(child: Counter(to: 128, duration: 30)),
        ));
        return tester.widget<Text>(find.byType(Text)).data!;
      }

      expect(await textAt(0), '0');
      expect(await textAt(30), '128');
      // Past the end it holds rather than extrapolating.
      expect(await textAt(300), '128');
    });

    testWidgets('the same frame always gives the same number',
        (WidgetTester tester) async {
      // The property that makes scrubbing backwards work. A counter driven by
      // an AnimationController could not promise it.
      Future<String> textAt(int frame) async {
        await tester.pumpWidget(at(
          frame,
          const Center(child: Counter(to: 999, duration: 45)),
        ));
        return tester.widget<Text>(find.byType(Text)).data!;
      }

      final List<String> forwards = <String>[
        for (int f = 0; f <= 45; f += 5) await textAt(f),
      ];
      final List<String> backwards = <String>[
        for (int f = 45; f >= 0; f -= 5) await textAt(f),
      ];
      expect(backwards.reversed.toList(), forwards);
    });

    testWidgets('format decides what is drawn', (WidgetTester tester) async {
      await tester.pumpWidget(at(
        45,
        Center(
          child: Counter(
            to: 99.98,
            duration: 45,
            format: (double v) => '${v.toStringAsFixed(2)}%',
          ),
        ),
      ));
      expect(find.text('99.98%'), findsOneWidget);
    });
  });
}
