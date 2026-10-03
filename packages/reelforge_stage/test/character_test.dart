import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

Future<ui.Image> _paint(WidgetTester tester, Widget drawing, {double size = 200}) async {
  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: size, height: size, child: drawing),
        ),
      ),
    ),
  );
  return (await tester.runAsync(() async {
    final RenderRepaintBoundary boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return boundary.toImage();
  }))!;
}

Future<Color> _pixel(WidgetTester tester, ui.Image image, int x, int y) async {
  final ByteData? raw =
      await tester.runAsync<ByteData?>(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
  final int i = (y * image.width + x) * 4;
  return Color.fromARGB(raw!.getUint8(i + 3), raw.getUint8(i), raw.getUint8(i + 1), raw.getUint8(i + 2));
}

void _near(Offset a, Offset b, [double tolerance = 1e-6]) {
  expect((a - b).distance, lessThan(tolerance), reason: '$a is not $b');
}

/// Every garment in the wardrobe, so each is at least fitted and built.
const List<Garment> _everything = <Garment>[
  ShortHair(Color(0xFF000000)),
  LongHair(Color(0xFF000000)),
  Bun(Color(0xFF000000)),
  Ponytail(Color(0xFF000000)),
  Curls(Color(0xFF000000)),
  Beard(Color(0xFF000000)),
  Moustache(Color(0xFF000000)),
  CowboyHat(Color(0xFF000000)),
  Cap(Color(0xFF000000)),
  Headcloth(Color(0xFFFFFFFF), check: Color(0xFFFF0000)),
  Hijab(Color(0xFF000000)),
  LegionHelmet(),
  Nemes(),
  LaurelWreath(),
  Glasses(),
  Shirt(Color(0xFF000000)),
  Vest(Color(0xFF000000)),
  Coat(Color(0xFF000000)),
  Robe(Color(0xFF000000), trim: Color(0xFFFFFFFF)),
  Tunic(Color(0xFF000000)),
  Toga(Color(0xFF000000), border: Color(0xFF0000FF)),
  Kilt(Color(0xFF000000)),
  Skirt(Color(0xFF000000)),
  Trousers(Color(0xFF000000)),
  Belt(Color(0xFF000000)),
  Bandana(Color(0xFF000000)),
  BroadCollar(),
  Cape(Color(0xFF000000)),
  Armour(),
  Gloves(Color(0xFF000000)),
  Boots(Color(0xFF000000)),
  CowboyBoots(Color(0xFF000000)),
  Sandals(),
  Sneakers(Color(0xFF000000)),
  RobotArm(),
  EyeImplant(),
  HeadPlate(),
  ChestLights(),
];

void main() {
  group('Light and Shade', () {
    double lum(Color c) => 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
    const Color grey = Color(0xFF909090);

    testWidgets('a shaded ball is lit on the side towards the light, and turns with it', (WidgetTester tester) async {
      final Part ball = Part(shapes: <Shape>[Shape(Paths.circle(const Offset(100, 100), 60), color: grey, shade: Shade.solid)]);
      final ui.Image fromLeft = await _paint(tester, Drawing(ball, light: const Light(from: Offset(-1, 0))));
      final Color left = await _pixel(tester, fromLeft, 50, 100), right = await _pixel(tester, fromLeft, 152, 100);
      expect(lum(left), greaterThan(lum(grey)));
      expect(lum(right), lessThan(lum(grey)));
      // The same ball turned half round, the light where it was: the lit
      // side is still the side facing the light.
      final ui.Image turned = await _paint(
        tester,
        Drawing(Part(at: const Offset(200, 200), degrees: 180, children: <Part>[ball]), light: const Light(from: Offset(-1, 0))),
      );
      expect(lum(await _pixel(tester, turned, 50, 100)), greaterThan(lum(await _pixel(tester, turned, 152, 100))));
      // Unshaded, it is flat.
      final ui.Image flat = await _paint(
        tester,
        Drawing(Part(shapes: <Shape>[Shape(Paths.circle(const Offset(100, 100), 60), color: grey)]), light: const Light(from: Offset(-1, 0))),
      );
      expect(await _pixel(tester, flat, 50, 100), grey);
      expect(await _pixel(tester, flat, 152, 100), grey);
    });

    testWidgets('a cast shadow lands on what is drawn under it, and nowhere else', (WidgetTester tester) async {
      final Part scene = Part(shapes: <Shape>[
        Shape(Paths.rect(const Rect.fromLTRB(0, 100, 200, 200)), color: grey),
        // Above the floor, casting straight down 40.
        Shape(Paths.rect(const Rect.fromLTRB(60, 40, 140, 80)),
            color: const Color(0xFFFF0000), shade: const Shade(form: 0, core: 0, rim: 0, cast: 40, castStrength: 0.5)),
      ]);
      final ui.Image image = await _paint(tester, Drawing(scene, light: const Light(from: Offset(0, -1))));
      // On the floor under it: darker. Beside it on the floor: not.
      expect(lum(await _pixel(tester, image, 100, 110)), lessThan(lum(grey)));
      expect(await _pixel(tester, image, 20, 110), grey);
      // In the empty air between: nothing.
      expect((await _pixel(tester, image, 100, 90)).a, 0);
    });
  });

  group('Where and Shape.live', () {
    test('Where gives other joints in the asking part\'s own space', () {
      final Part root = Part(
        name: 'root',
        at: const Offset(100, 100),
        children: <Part>[
          Part(name: 'a', at: const Offset(10, 0)),
          Part(name: 'b', at: const Offset(0, 20), degrees: 90, children: <Part>[
            Part(name: 'c', at: const Offset(5, 0)),
          ]),
        ],
      );
      const Pose pose = Pose(<String, Joint>{'a': Joint.move(Offset(0, 7))});
      final Where fromB = Where(root, pose, frameOf(root, pose, 'b'));
      _near(fromB.point('c'), const Offset(5, 0));
      // 'a' is at (10, 7) from the root, (10, -13) from b; b is turned a
      // quarter, so that is (-13, -10) in b's own axes.
      _near(fromB.point('a'), const Offset(-13, -10));
    });

    testWidgets('a live outline follows the pose', (WidgetTester tester) async {
      const Color red = Color(0xFFFF0000);
      final Part rig = Part(
        name: 'root',
        children: <Part>[
          Part(name: 'target', at: const Offset(40, 100)),
          Part(shapes: <Shape>[
            Shape.live((Where w) => Paths.circle(w.point('target'), 12), color: red),
          ]),
        ],
      );
      final ui.Image rest = await _paint(tester, Drawing(rig));
      expect(await _pixel(tester, rest, 40, 100), red);
      final ui.Image moved = await _paint(
        tester,
        Drawing(rig, pose: const Pose(<String, Joint>{'target': Joint.move(Offset(110, 0))})),
      );
      expect(await _pixel(tester, moved, 40, 100), const Color(0x00000000));
      expect(await _pixel(tester, moved, 150, 100), red);
    });
  });

  test('Part.bake folds a pose into the drawing', () {
    final Part arm = Part(name: 'shoulder', at: const Offset(10, 10), children: <Part>[
      Part(name: 'elbow', at: const Offset(0, 50), children: <Part>[Part(name: 'hand', at: const Offset(0, 40))]),
    ]);
    const Pose pose = Pose(<String, Joint>{
      'shoulder': Joint(degrees: -40, move: Offset(3, -2)),
      'elbow': Joint(degrees: -70, scaleX: 1.2),
    });
    final Part baked = arm.bake(pose);
    for (final String name in <String>['shoulder', 'elbow', 'hand']) {
      _near(frameOf(baked, Pose.rest, name).origin, frameOf(arm, pose, name).origin);
    }
    // And animation adds to it.
    const Pose more = Pose(<String, Joint>{'elbow': Joint.rotate(10)});
    _near(frameOf(baked, more, 'hand').origin, frameOf(arm, pose.plus(more), 'hand').origin);
  });

  group('Character', () {
    const Character plain = Character();

    test('has the joints every motion in the package drives', () {
      final Set<String> names = plain.part.names;
      for (final String n in <String>[
        'body', 'chest', 'head', 'shoulderF', 'elbowF', 'handF', 'shoulderB', 'elbowB', 'handB',
        'hipF', 'kneeF', 'footF', 'hipB', 'kneeB', 'footB', ...FaceJoints.eyes, ...FaceJoints.pupils, FaceJoints.mouth,
      ]) {
        expect(names, contains(n));
      }
    });

    test('is built once, and stands its soles on the ground', () {
      expect(identical(plain.part, plain.part), isTrue);
      for (final Body b in <Body>[const Body(), Body.child, Body.stocky, Body.slim, Body.elder]) {
        final Character c = Character(body: b);
        final Part placed = c.part.placed(at: c.standing(300, 900));
        expect(frameOf(placed, Pose.rest, 'footF').origin.dy + b.sole, closeTo(900, 1e-9));
        final double far = frameOf(placed, Pose.rest, 'footB').origin.dy + b.sole;
        expect(far, lessThan(900));
        expect(far, greaterThan(900 - b.legRadius * 0.5));
      }
    });

    test('a walk plans steps for it', () {
      final Walk walk = Walk(
        rig: plain.part,
        route: const <Waypoint>[Waypoint(0, 0), Waypoint(60, 400)],
        groundY: 800,
        fps: 30,
        body: plain.biped,
      );
      expect(walk.steps, isNotEmpty);
      // Stopped, both feet flat where their last steps put them.
      final Posed p = walk.at(90);
      for (final (int, String) foot in <(int, String)>[(0, 'footF'), (1, 'footB')]) {
        final Footstep last = walk.steps.lastWhere((Footstep s) => s.foot == foot.$1);
        final Offset ankle = frameOf(p.part, p.pose, foot.$2).origin;
        expect(ankle.dx, closeTo(last.to, 0.5));
        expect(ankle.dy + plain.body.sole, closeTo(800, 0.5));
      }
    });

    test('every garment fits every body', () {
      for (final Body b in <Body>[const Body(), Body.child, Body.stocky, Body.elder]) {
        for (final Garment g in _everything) {
          final Character c = Character(body: b, outfit: <Garment>[g]);
          expect(c.build().names, contains('head'), reason: '${g.runtimeType} on $b');
        }
      }
    });

    test('headcloths hide the hair; capes and ponytails swing', () {
      final Character hidden = Character(
        outfit: const <Garment>[ShortHair(Color(0xFF123456)), Hijab(Color(0xFF000000))],
      );
      final Character shown = Character(outfit: const <Garment>[ShortHair(Color(0xFF123456))]);
      Iterable<Shape> shapes(Part p) sync* {
        yield* p.shapes;
        for (final Part c in p.children) {
          yield* shapes(c);
        }
      }

      bool hasHair(Character c) => shapes(c.part).any((Shape s) => s.color == const Color(0xFF123456));
      expect(hasHair(shown), isTrue);
      expect(hasHair(hidden), isFalse);
      expect(const Character(outfit: <Garment>[Cape(Color(0xFF000000))]).jiggles, isNotEmpty);
      expect(const Character(outfit: <Garment>[Ponytail(Color(0xFF000000))]).jiggles, isNotEmpty);
      expect(plain.jiggles, isEmpty);
    });

    test('glasses sit on the eyes, wherever the face puts them', () {
      for (final double turn in <double>[0, 0.55, 1]) {
        final Character c = Character(faceTurn: turn, outfit: const <Garment>[Glasses()]);
        final Part head = pathTo(c.part, 'head')!.last;
        final Rect lenses = head.children.last.shapes.first.path!.getBounds();
        final Offset eye = frameOf(c.part, Pose.rest, FaceJoints.eyeL).origin;
        final Offset headAt = frameOf(c.part, Pose.rest, 'head').origin;
        expect(lenses.contains(eye - headAt), isTrue, reason: 'turn $turn');
      }
    });

    test('the stance stoops an elder and nobody else', () {
      expect(const Character().stance, Pose.rest);
      expect(const Character(body: Body.elder).stance['chest'].degrees, greaterThan(0));
    });

    testWidgets('draws its clothes over its skin', (WidgetTester tester) async {
      const Color shirt = Color(0xFF00FF00), skin = Color(0xFFE0A47C);
      const Character c = Character(skin: skin, outfit: <Garment>[Shirt(shirt, vNeck: false)]);
      final Part placed = c.part.placed(at: c.standing(200, 380), scale: 0.8);
      final ui.Image image = await _paint(tester, Drawing(placed), size: 400);
      // Halfway up the torso, in front of the arm: shirt. Low on the head,
      // clear of the face, the ear and the shadow: skin.
      final Offset chest = frameOf(placed, Pose.rest, 'body').apply(Offset(c.body.front - 8, -c.body.torso * 0.5));
      // Lit, so not the flat colour, but the shirt's and not the skin's.
      double far(Color a, Color b) => (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
      final Color atChest = await _pixel(tester, image, chest.dx.round(), chest.dy.round());
      expect(far(atChest, shirt), lessThan(far(atChest, skin)));
      final Offset cheek = frameOf(placed, Pose.rest, 'head').apply(c.body.headCenter + Offset(-c.body.headRadius * 0.35, c.body.headRadius * 0.45));
      final Color atCheek = await _pixel(tester, image, cheek.dx.round(), cheek.dy.round());
      expect(far(atCheek, skin), lessThan(far(atCheek, shirt)));
    });
  });
}
