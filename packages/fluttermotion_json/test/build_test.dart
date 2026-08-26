import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_json/fluttermotion_json.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';

/// Puts one node on screen at one frame, with data behind it.
///
/// Documents are parsed, not hand-built, so these go in as JSON: a test that
/// constructed `MotionNode`s directly would be checking the builders while
/// skipping the parser, which is where half the behaviour lives.
Future<void> pump(
  WidgetTester tester,
  Map<String, Object?> node, {
  int frame = 0,
  Map<String, Object?> data = const <String, Object?>{},
  int width = 400,
  int height = 800,
}) async {
  final MotionDocument document = MotionDocument.parse(<String, Object?>{
    'id': 'T',
    'width': width,
    'height': height,
    'fps': 30,
    'root': node,
    'durationInFrames': 120,
  });
  final Composition composition = document.toComposition(data: data);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: VideoFrame(
        frame: frame,
        fps: composition.fps,
        durationInFrames: composition.durationInFrames,
        width: width,
        height: height,
        child: Builder(
          builder: (BuildContext context) => composition.wrapper!(
            context,
            Builder(builder: composition.builder),
          ),
        ),
      ),
    ),
  );
}

double? _boxWidth(WidgetTester tester) =>
    tester.widget<SizedBox>(find.byType(SizedBox).last).width;

void main() {
  group('bindings', () {
    testWidgets('a string binding is filled from the data', (WidgetTester t) async {
      await pump(
        t,
        <String, Object?>{'type': 'text', 'value': 'Q{{ quarter }} report'},
        data: <String, Object?>{'quarter': 3},
      );
      expect(find.text('Q3 report'), findsOneWidget);
    });

    test('a path walks maps and lists alike', () {
      const DataScope scope = DataScope(data: <String, Object?>{
        'weeks': <Object?>[
          <String, Object?>{'label': 'W27'},
          <String, Object?>{'label': 'W28'},
        ],
      });
      expect(scope.resolve('weeks.1.label'), 'W28');
      expect(scope.resolve('weeks.9.label'), isNull);
      expect(scope.resolve('nothing.at.all'), isNull);
    });

    testWidgets('a missing field renders empty rather than throwing',
        (WidgetTester t) async {
      await pump(t, <String, Object?>{'type': 'text', 'value': 'x{{ nope }}y'});
      expect(find.text('xy'), findsOneWidget);
    });

    testWidgets('filters format the value they are given', (WidgetTester t) async {
      await pump(
        t,
        <String, Object?>{
          'type': 'text',
          'value': '{{ delta | fixed(1) | sign }}% and {{ name | upper }}',
        },
        data: <String, Object?>{'delta': 18.42, 'name': 'growth'},
      );
      expect(find.text('+18.4% and GROWTH'), findsOneWidget);
    });

    testWidgets('a negative number keeps its own sign', (WidgetTester t) async {
      await pump(
        t,
        <String, Object?>{'type': 'text', 'value': '{{ d | fixed(1) | sign }}'},
        data: <String, Object?>{'d': -2.34},
      );
      expect(find.text('-2.3'), findsOneWidget);
    });

    testWidgets('a whole-string binding keeps its type where a number is wanted',
        (WidgetTester t) async {
      await pump(
        t,
        <String, Object?>{
          'type': 'sizedBox',
          'width': '{{ w }}',
          'height': 10,
          'child': <String, Object?>{'type': 'box', 'color': '#FF0000'},
        },
        data: <String, Object?>{'w': 123.0},
      );
      expect(_boxWidth(t), 123);
    });
  });

  group('repeat', () {
    testWidgets('children repeat over a list, item scope first',
        (WidgetTester t) async {
      await pump(
        t,
        <String, Object?>{
          'type': 'column',
          'children': <String, Object?>{
            'repeat': 'teams',
            'as': <String, Object?>{
              'type': 'text',
              'value': '{{ @index }}:{{ name }} of {{ period }}',
            },
          },
        },
        data: <String, Object?>{
          'period': 'Q3',
          'teams': <Object?>[
            <String, Object?>{'name': 'Platform'},
            <String, Object?>{'name': 'Growth'},
          ],
        },
      );
      expect(find.text('0:Platform of Q3'), findsOneWidget);
      expect(find.text('1:Growth of Q3'), findsOneWidget);
    });

    testWidgets('data repeats too, for things that are not widgets',
        (WidgetTester t) async {
      await pump(
        t,
        <String, Object?>{
          'type': 'barChart',
          'bars': <String, Object?>{
            'repeat': 'weeks',
            'as': <String, Object?>{
              'value': '{{ shipped }}',
              'label': '{{ label }}',
            },
          },
        },
        frame: 60,
        data: <String, Object?>{
          'weeks': <Object?>[
            <String, Object?>{'label': 'W27', 'shipped': 12},
            <String, Object?>{'label': 'W28', 'shipped': 31},
          ],
        },
      );
      expect(find.text('W27'), findsOneWidget);
      expect(find.text('W28'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
    });

    testWidgets('repeating over something that is not a list draws nothing',
        (WidgetTester t) async {
      await pump(
        t,
        <String, Object?>{
          'type': 'column',
          'children': <String, Object?>{
            'repeat': 'teams',
            'as': <String, Object?>{'type': 'text', 'value': 'x'},
          },
        },
        data: <String, Object?>{'teams': 'not a list'},
      );
      expect(find.text('x'), findsNothing);
    });
  });

  group('animated values', () {
    testWidgets('keyframes move a property between frames',
        (WidgetTester t) async {
      Map<String, Object?> tree(int _) => <String, Object?>{
            'type': 'sizedBox',
            'width': <String, Object?>{
              'keyframes': <Object?>[
                <Object?>[0, 100],
                <Object?>[10, 200],
              ],
            },
            'height': 10,
          };

      await pump(t, tree(0), frame: 0);
      expect(_boxWidth(t), 100);
      await pump(t, tree(5), frame: 5);
      expect(_boxWidth(t), 150);
      // Clamped past the end, not extrapolated off the screen.
      await pump(t, tree(90), frame: 90);
      expect(_boxWidth(t), 200);
    });

    testWidgets('a spring settles on its target', (WidgetTester t) async {
      Map<String, Object?> tree() => <String, Object?>{
            'type': 'sizedBox',
            'width': <String, Object?>{
              'spring': <String, Object?>{'from': 0, 'to': 200},
            },
            'height': 10,
          };
      await pump(t, tree(), frame: 0);
      expect(_boxWidth(t), 0);
      await pump(t, tree(), frame: 90);
      expect(_boxWidth(t), closeTo(200, 0.5));
    });

    testWidgets('an opacity driven by a spring stays legal',
        (WidgetTester t) async {
      // A spring overshoots. An Opacity above 1 is an assertion in debug and
      // undefined in release, so the node clamps rather than trusting the
      // document to know that.
      await pump(
        t,
        <String, Object?>{
          'type': 'opacity',
          'value': <String, Object?>{
            'spring': <String, Object?>{'from': 0, 'to': 1, 'damping': 6},
          },
          'child': <String, Object?>{'type': 'text', 'value': 'x'},
        },
        frame: 14,
      );
      final Opacity opacity = t.widget(find.byType(Opacity).first);
      expect(opacity.opacity, lessThanOrEqualTo(1.0));
      expect(opacity.opacity, greaterThanOrEqualTo(0.0));
    });

    testWidgets('a stagger offsets the frame each child animates on',
        (WidgetTester t) async {
      await pump(
        t,
        <String, Object?>{
          'type': 'stagger',
          'step': 10,
          'children': <Object?>[
            <String, Object?>{
              'type': 'opacity',
              'value': <String, Object?>{
                'keyframes': <Object?>[
                  <Object?>[0, 0],
                  <Object?>[10, 1],
                ],
              },
              'child': <String, Object?>{'type': 'text', 'value': 'a'},
            },
            <String, Object?>{
              'type': 'opacity',
              'value': <String, Object?>{
                'keyframes': <Object?>[
                  <Object?>[0, 0],
                  <Object?>[10, 1],
                ],
              },
              'child': <String, Object?>{'type': 'text', 'value': 'b'},
            },
          ],
        },
        frame: 10,
      );
      final List<Opacity> found =
          t.widgetList<Opacity>(find.byType(Opacity)).toList();
      expect(found.first.opacity, 1.0);
      expect(found.last.opacity, 0.0);
    });
  });

  group('colour', () {
    testWidgets('a role follows the theme, a hex does not',
        (WidgetTester t) async {
      await pump(
        t,
        <String, Object?>{
          'type': 'column',
          'children': <Object?>[
            <String, Object?>{
              'type': 'box',
              'color': 'accent',
              'width': 10,
              'height': 10,
            },
            <String, Object?>{
              'type': 'box',
              'color': '#FF102030',
              'width': 10,
              'height': 10,
            },
          ],
        },
      );
      final List<Container> boxes =
          t.widgetList<Container>(find.byType(Container)).toList();
      expect(
        (boxes.first.decoration! as BoxDecoration).color,
        MotionPalette.dark.accent,
      );
      expect(
        (boxes.last.decoration! as BoxDecoration).color,
        const Color(0xFF102030),
      );
    });
  });

  group('sequences', () {
    testWidgets('a sequence rebases the frame its children animate on',
        (WidgetTester t) async {
      await pump(
        t,
        <String, Object?>{
          'type': 'sequence',
          'from': 30,
          'durationInFrames': 30,
          'child': <String, Object?>{
            'type': 'opacity',
            'value': <String, Object?>{
              'keyframes': <Object?>[
                <Object?>[0, 0],
                <Object?>[10, 1],
              ],
            },
            'child': <String, Object?>{'type': 'text', 'value': 'x'},
          },
        },
        frame: 35,
      );
      expect(t.widget<Opacity>(find.byType(Opacity).first).opacity, 0.5);
    });
  });
}
