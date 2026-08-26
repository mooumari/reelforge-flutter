import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';

import 'harness.dart';

void main() {
  group('MotionPalette', () {
    test('sign picks the colour, and zero counts as positive', () {
      const MotionPalette p = MotionPalette.dark;
      expect(p.forSign(3), p.accent);
      expect(p.forSign(0), p.accent);
      expect(p.forSign(-0.1), p.warning);
    });

    test('copyWith leaves everything it is not given', () {
      final MotionPalette p =
          MotionPalette.dark.copyWith(accent: const Color(0xFF00FFFF));
      expect(p.accent, const Color(0xFF00FFFF));
      expect(p.background, MotionPalette.dark.background);
    });
  });

  group('MotionTheme', () {
    testWidgets('components work with no theme above them',
        (WidgetTester tester) async {
      // A component that needed a theme to exist would make the kit unusable
      // for one-off use inside an app screen.
      await tester.pumpWidget(at(0, const Center(child: SceneLabel('hi'))));
      expect(find.text('HI'), findsOneWidget);
    });

    testWidgets('scale moves every size together', (WidgetTester tester) async {
      Future<double> labelSizeAt(double scale) async {
        await tester.pumpWidget(at(
          0,
          MotionTheme(
            typography: MotionTypography(scale: scale),
            child: const Center(child: SceneLabel('hi')),
          ),
        ));
        return tester.widget<Text>(find.byType(Text)).style!.fontSize!;
      }

      expect(await labelSizeAt(2.0), 2 * await labelSizeAt(1.0));
    });
  });

  group('BarChart', () {
    testWidgets('no bars draws nothing rather than dividing by zero',
        (WidgetTester tester) async {
      await tester.pumpWidget(at(0, const BarChart(bars: <BarDatum>[])));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('all-zero data is an empty chart, not a crash',
        (WidgetTester tester) async {
      // The peak is the divisor, and a week where nothing shipped is a real
      // week.
      await tester.pumpWidget(at(
        60,
        const SizedBox(
          width: 600,
          height: 400,
          child: BarChart(
            bars: <BarDatum>[
              BarDatum(value: 0, label: 'w1'),
              BarDatum(value: 0, label: 'w2'),
            ],
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('w1'), findsOneWidget);
    });

    testWidgets('bars grow, and the last one starts after the first',
        (WidgetTester tester) async {
      Future<List<double>> heightsAt(int frame) async {
        await tester.pumpWidget(at(
          frame,
          const SizedBox(
            width: 600,
            height: 400,
            child: BarChart(
              delay: 0,
              step: 10,
              bars: <BarDatum>[
                BarDatum(value: 10, label: 'a'),
                BarDatum(value: 10, label: 'b'),
              ],
            ),
          ),
        ));
        return tester
            .widgetList<Container>(find.byType(Container))
            .map((Container c) => (c.constraints?.maxHeight ?? 0))
            .toList();
      }

      final List<double> early = await heightsAt(6);
      expect(early.first, greaterThan(0));
      expect(early.last, 0, reason: 'the second bar has not started yet');

      final List<double> settled = await heightsAt(120);
      expect(settled.first, closeTo(settled.last, 0.5));
      expect(settled.first, greaterThan(0));
    });
  });

  group('LineChart', () {
    testWidgets('a single point draws no line and does not throw',
        (WidgetTester tester) async {
      await tester.pumpWidget(at(
        30,
        const SizedBox(
          width: 600,
          height: 400,
          child: LineChart(points: <LineDatum>[LineDatum(value: 3, label: 'a')]),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('one label per point, in order', (WidgetTester tester) async {
      await tester.pumpWidget(at(
        30,
        const SizedBox(
          width: 600,
          height: 400,
          child: LineChart(
            points: <LineDatum>[
              LineDatum(value: 3, label: 'a'),
              LineDatum(value: 9, label: 'b'),
              LineDatum(value: 1, label: 'c'),
            ],
          ),
        ),
      ));
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
    });
  });

  group('SplitScreen', () {
    testWidgets('panels start off screen and meet', (WidgetTester tester) async {
      Future<double> topLeftX(int frame) async {
        await tester.pumpWidget(at(
          frame,
          const SplitScreen(
            slideFrames: 30,
            first: Text('top'),
            second: Text('bottom'),
          ),
          width: 400,
          height: 800,
        ));
        return tester.renderObject<RenderBox>(find.text('top'))
            .localToGlobal(Offset.zero)
            .dx;
      }

      // Travel is the composition's own width, so this works at any size.
      expect(await topLeftX(0), closeTo(await topLeftX(30) - 400, 1));
      expect(await topLeftX(30), closeTo(await topLeftX(60), 1e-9));
    });
  });

  group('BigStat', () {
    testWidgets('a counting value inherits the statistic style',
        (WidgetTester tester) async {
      // The reason value is a Widget rather than a String: a Counter and a
      // literal are the same component, and neither has to be told how big to
      // be.
      await tester.pumpWidget(at(
        45,
        const Center(
          child: BigStat(
            value: Counter(to: 42, duration: 45),
            label: 'releases',
          ),
        ),
      ));
      expect(find.text('42'), findsOneWidget);
      final TextStyle style =
          tester.widget<Text>(find.text('42')).style ?? const TextStyle();
      // The Text itself carries no size; it takes the DefaultTextStyle above.
      expect(style.fontSize, isNull);
      final DefaultTextStyle applied = DefaultTextStyle.of(
        tester.element(find.text('42')),
      );
      expect(
        applied.style.fontSize,
        const MotionTypography().statisticSize,
      );
    });
  });
}
