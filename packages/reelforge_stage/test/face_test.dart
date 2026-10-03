import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

Future<ui.Image> _paint(WidgetTester tester, Widget drawing) async {
  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: 200, height: 200, child: drawing),
        ),
      ),
    ),
  );
  return (await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return boundary.toImage();
  }))!;
}

Future<Color> _pixel(WidgetTester tester, ui.Image image, int x, int y) async {
  final ByteData? raw = await tester.runAsync<ByteData?>(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba));
  final int i = (y * image.width + x) * 4;
  return Color.fromARGB(raw!.getUint8(i + 3), raw.getUint8(i), raw.getUint8(i + 1), raw.getUint8(i + 2));
}

void main() {
  group('Joint.weights', () {
    test('add, blend against zero, and compare', () {
      const Joint a = Joint.weigh(<String, double>{'smile': 1});
      const Joint b = Joint.weigh(<String, double>{'smile': 0.5, 'ah': 1});
      expect(a.plus(b).weights, <String, double>{'smile': 1.5, 'ah': 1});
      expect(Joint.lerp(a, b, 0.5).weights, <String, double>{'smile': 0.75, 'ah': 0.5});
      expect(Joint.lerp(Joint.rest, a, 0.25).weights['smile'], 0.25);
      expect(a, const Joint.weigh(<String, double>{'smile': 1}));
      expect(a, isNot(b));
      expect(a.hashCode, const Joint.weigh(<String, double>{'smile': 1}).hashCode);
    });
  });

  group('Blend', () {
    final Path base = Paths.rect(const Rect.fromLTRB(-50, -10, 50, 10));
    final Blend blend = Blend(
      base,
      <String, Path>{
        'tall': Paths.rect(const Rect.fromLTRB(-50, -40, 50, 40)),
        'wide': Paths.rect(const Rect.fromLTRB(-90, -10, 90, 10)),
        'shut': Paths.rect(const Rect.fromLTRB(-50, -1, 50, 1)),
      },
      overriding: const <String>{'shut'},
    );
    Rect box(Map<String, double> w) {
      final List<Offset> p = blend.outlineFor(w).points;
      return Rect.fromPoints(
        Offset(p.map((Offset o) => o.dx).reduce((a, b) => a < b ? a : b), p.map((Offset o) => o.dy).reduce((a, b) => a < b ? a : b)),
        Offset(p.map((Offset o) => o.dx).reduce((a, b) => a > b ? a : b), p.map((Offset o) => o.dy).reduce((a, b) => a > b ? a : b)),
      );
    }

    test('no weights is the base, a whole key is the key', () {
      expect(box(const <String, double>{}).height, closeTo(20, 0.5));
      expect(box(const <String, double>{'tall': 1}).height, closeTo(80, 0.5));
      expect(box(const <String, double>{'tall': 1}).width, closeTo(100, 0.5));
    });

    test('keys mix: some of each', () {
      final Rect r = box(const <String, double>{'tall': 0.5, 'wide': 1});
      expect(r.height, closeTo(50, 0.5));
      expect(r.width, closeTo(180, 0.5));
    });

    test('an overriding key replaces the others as it comes in', () {
      final Rect shut = box(const <String, double>{'tall': 1, 'wide': 1, 'shut': 1});
      expect(shut.height, closeTo(2, 0.5));
      expect(shut.width, closeTo(100, 0.5));
      final Rect half = box(const <String, double>{'tall': 1, 'shut': 0.5});
      // Half of "tall" left, plus half of "shut": 20 + 30 - 9.
      expect(half.height, closeTo(41, 0.5));
    });

    test('ignores names that are not its keys', () {
      expect(box(const <String, double>{'smile': 1}).height, closeTo(20, 0.5));
    });
  });

  group('Part.clip', () {
    testWidgets('children only show inside the part, as its shapes change', (WidgetTester tester) async {
      const Color white = Color(0xFFFFFFFF), black = Color(0xFF000000);
      final Part eye = Part(
        name: 'eye',
        at: const Offset(100, 100),
        clip: true,
        shapes: <Shape>[
          Shape.blend(
            Blend(Paths.ellipse(Offset.zero, 40, 30), <String, Path>{
              'shut': Paths.ellipse(const Offset(0, 25), 40, 3),
            }),
            color: white,
          ),
        ],
        children: <Part>[
          Part(shapes: <Shape>[Shape(Paths.circle(Offset.zero, 50), color: black)]),
        ],
      );
      final ui.Image open = await _paint(tester, Drawing(eye));
      expect(await _pixel(tester, open, 100, 100), black);
      expect(await _pixel(tester, open, 100, 140), const Color(0x00000000));
      final ui.Image shut = await _paint(
        tester,
        Drawing(eye, pose: const Pose(<String, Joint>{'eye': Joint.weigh(<String, double>{'shut': 1})})),
      );
      // The pupil is still there, posed nowhere -- but the eye has closed
      // over it.
      expect(await _pixel(tester, shut, 100, 100), const Color(0x00000000));
    });
  });

  group('FaceStyle', () {
    const FaceStyle style = FaceStyle();

    test('builds every face joint', () {
      final Set<String> names = style.build().names;
      expect(
        names,
        containsAll(<String>[
          FaceJoints.face, ...FaceJoints.eyes, ...FaceJoints.pupils,
          FaceJoints.browL, FaceJoints.browR, FaceJoints.mouth,
        ]),
      );
      expect(const FaceStyle(browThickness: 0).build().names, isNot(contains(FaceJoints.browL)));
    });

    test('every emotion poses only face joints, and neutral is rest', () {
      final Set<String> names = style.build().names;
      for (final Emotion e in Emotion.values) {
        expect(names, containsAll(style.express(e).joints.keys), reason: e.name);
      }
      expect(style.express(Emotion.neutral), Pose.rest);
      expect(style.express(Emotion.happy)[FaceJoints.mouth].weights['smile'], 1);
      expect(style.express(Emotion.happy, amount: 0.5)[FaceJoints.mouth].weights['smile'], 0.5);
    });

    test('brows mirror: a cross face lowers both inner ends', () {
      final Pose angry = style.express(Emotion.angry);
      expect(angry[FaceJoints.browL].degrees, greaterThan(0));
      expect(angry[FaceJoints.browR].degrees, -angry[FaceJoints.browL].degrees);
    });

    test('moods hold, then change over the transition', () {
      final Take take = style.moods(<(int, Emotion)>[(0, Emotion.neutral), (30, Emotion.happy)], transition: 10);
      expect(take.at(29)[FaceJoints.mouth].weights['smile'] ?? 0, 0);
      expect(take.at(40)[FaceJoints.mouth].weights['smile'], closeTo(1, 1e-9));
      final double mid = take.at(35)[FaceJoints.mouth].weights['smile']!;
      expect(mid, greaterThan(0.1));
      expect(mid, lessThan(0.9));
    });

    test('look keeps the pupils inside the eyes', () {
      final Offset far = style.look(const Offset(5, -5))[FaceJoints.pupilL].move;
      expect(far.dx, lessThan(style.eyeWidth / 2));
      expect(far.dy, greaterThan(-style.eyeHeight / 2));
      expect(far.dx, greaterThan(0));
    });

    test('turning foreshortens the far eye', () {
      final Pose right = style.turn(1);
      expect(right[FaceJoints.eyeR].scaleX, lessThan(1));
      expect(right[FaceJoints.eyeL].scaleX, 1);
      expect(right[FaceJoints.face].move.dx, style.turnRange);
    });
  });

  group('Gaze', () {
    const Gaze gaze = Gaze(<(int, Offset)>[(0, Offset.zero), (20, Offset(1, 0)), (50, Offset(0, 1))]);

    test('holds, then darts in a few frames', () {
      expect(gaze.at(19), Offset.zero);
      expect(gaze.at(24), const Offset(1, 0));
      expect(gaze.at(22).dx, greaterThan(0.5));
      expect(gaze.at(52), isNot(gaze.at(54)));
      expect(gaze.at(60), const Offset(0, 1));
    });

    test('the head follows late and slow', () {
      expect(gaze.follow(24).dx, lessThan(gaze.at(24).dx));
      expect(gaze.follow(45).dx, closeTo(1, 1e-9));
    });
  });

  group('Speech', () {
    test('Azure viseme ids cover 0 to 21', () {
      expect(Viseme.azure, hasLength(22));
      expect(Viseme.azure[0], Viseme.rest);
      expect(Viseme.azure[21], Viseme.closed);
      expect(Viseme.azure[18], Viseme.fv);
    });

    test("reads Azure's events in ticks", () {
      final Speech s = Speech.azureJson('''
        {"visemes": [
          {"audioOffset": 0, "visemeId": 0},
          {"audioOffset": 1000000, "visemeId": 21},
          {"audioOffset": 2000000, "visemeId": 2},
          {"audioOffset": 3500000, "visemeId": 0}
        ],
        "words": [{"audioOffset": 1000000, "duration": 2500000, "text": "Ma"}]}
      ''', start: 1);
      expect(s.visemes.map((VisemeCue c) => c.viseme), <Viseme>[Viseme.rest, Viseme.closed, Viseme.ah, Viseme.rest]);
      expect(s.visemes[1].seconds, closeTo(1.1, 1e-9));
      expect(s.words.single.start, closeTo(1.1, 1e-9));
      expect(s.words.single.end, closeTo(1.35, 1e-9));
      expect(s.wordAt(1.2)!.text, 'Ma');
      expect(s.wordAt(1.4), isNull);
      // Every shape is reached, and the closed "m" really closes.
      expect(s.weightsAt(1.19)['closed'], closeTo(1, 1e-9));
      expect(s.weightsAt(1.29)['ah'], closeTo(1, 1e-9));
      expect(s.weightsAt(1.29)['closed'] ?? 0, closeTo(0, 1e-9));
      expect(s.weightsAt(1.22)['ah']! + s.weightsAt(1.22)['closed']!, closeTo(1, 1e-9));
    });

    test('guesses from text: lips close on m, b and p, rest at the end', () {
      final Speech s = Speech.fromText('Mama, be happy.');
      expect(s.words.map((WordCue w) => w.text), <String>['Mama', 'be', 'happy']);
      final List<Viseme> shapes = s.visemes.map((VisemeCue c) => c.viseme).toList();
      expect(shapes.first, Viseme.rest);
      expect(shapes.last, Viseme.rest);
      expect(shapes.where((Viseme v) => v == Viseme.closed).length, greaterThanOrEqualTo(4));
      expect(shapes, contains(Viseme.ah));
      // The comma is a pause: "be" starts well after "Mama" ends.
      expect(s.words[1].start - s.words[0].end, greaterThan(0.15));
      for (int i = 1; i < s.visemes.length; i++) {
        expect(s.visemes[i].seconds, greaterThanOrEqualTo(s.visemes[i - 1].seconds));
      }
    });

    test('is a pure function of the frame', () {
      final Speech s = Speech.fromText('Every word shapes my mouth.');
      expect(s.at(17, 30), s.at(17, 30));
      expect(s.at(17, 30, amount: 0.5)[FaceJoints.mouth].weights.values.fold<double>(0, (double a, double b) => a + b),
          closeTo(0.5 * s.weightsAt(17 / 30).values.fold<double>(0, (double a, double b) => a + b), 1e-9));
    });
  });

  test('Life can blink by shape key and glance with the pupils', () {
    const Life life = Life(seed: 4, eyes: FaceJoints.eyes, blinkKey: 'closed', pupils: FaceJoints.pupils);
    bool blinked = false;
    for (int f = 0; f < 300; f++) {
      final Pose p = life.at(f, 30);
      expect(p[FaceJoints.eyeL].scaleY, 1);
      expect(p[FaceJoints.eyeL].move, Offset.zero);
      if ((p[FaceJoints.eyeL].weights['closed'] ?? 0) > 0.99) blinked = true;
    }
    expect(blinked, isTrue);
    expect(
      List<Offset>.generate(300, (int f) => life.at(f, 30)[FaceJoints.pupilL].move).toSet().length,
      greaterThan(1),
    );
  });
}
