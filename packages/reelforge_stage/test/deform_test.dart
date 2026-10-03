import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

const Color _red = Color(0xFFFF0000);

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

Future<int> _alpha(WidgetTester tester, ui.Image image, int x, int y) async {
  final ByteData? raw = await tester.runAsync<ByteData?>(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba));
  return raw!.getUint8((y * image.width + x) * 4 + 3);
}

double _maxGap(List<Offset> points, {bool closed = true}) {
  double gap = 0;
  final int n = closed ? points.length : points.length - 1;
  for (int i = 0; i < n; i++) {
    gap = math.max(gap, (points[(i + 1) % points.length] - points[i]).distance);
  }
  return gap;
}

List<Offset> pointsOf(Path p) => Outline.of(p, samples: 96).points;

void main() {
  test('a taper is round at both ends and straight between', () {
    final Path p = Paths.taper(const Offset(0, 0), const Offset(0, 100), 20, 10);
    for (final (Offset inside, Offset outside) in <(Offset, Offset)>[
      (const Offset(0, -19.5), const Offset(0, -20.5)),
      (const Offset(0, 109.5), const Offset(0, 110.5)),
      (const Offset(-19.5, 1), const Offset(-20.5, 1)),
    ]) {
      expect(p.contains(inside), isTrue, reason: '$inside');
      expect(p.contains(outside), isFalse, reason: '$outside');
    }
    // Halfway down, the side is halfway between the two radii -- give or take
    // the small tilt of the tangent.
    expect(p.contains(const Offset(14.5, 50)), isTrue);
    expect(p.contains(const Offset(15.6, 50)), isFalse);
    expect(p.contains(const Offset(0, 108)), isTrue);
  });

  group('Outline', () {
    test('samples a contour at even spacing round its length', () {
      final Outline o = Outline.of(Paths.circle(Offset.zero, 50), samples: 64);
      expect(o.points, hasLength(64));
      expect(o.closed, isTrue);
      final double chord = 2 * 50 * math.sin(math.pi / 64);
      for (int i = 0; i < 64; i++) {
        expect(o.points[i].distance, closeTo(50, 0.5));
        expect((o.points[(i + 1) % 64] - o.points[i]).distance, closeTo(chord, 0.3));
      }
    });

    test('an open line keeps both ends', () {
      final Outline o = Outline.of(
        Path()
          ..moveTo(0, 0)
          ..lineTo(90, 0),
        samples: 10,
      );
      expect(o.closed, isFalse);
      expect(o.points.first, const Offset(0, 0));
      expect(o.points.last.dx, closeTo(90, 1e-6));
      expect(o.points[1].dx, closeTo(10, 1e-6));
    });

    test('aligning undoes a different start and the other winding', () {
      final Outline a = Outline.of(Paths.circle(Offset.zero, 50), samples: 48);
      // The same circle, numbered backwards from a quarter turn round.
      final Outline b = Outline(
        <Offset>[
          for (int i = 0; i < 48; i++) a.points[(60 - i) % 48],
        ],
      );
      final Outline aligned = b.alignedTo(a);
      for (int i = 0; i < 48; i++) {
        expect((aligned.points[i] - a.points[i]).distance, lessThan(1e-9));
      }
    });
  });

  group('Morph', () {
    final Morph morph = Morph(<Path>[
      Paths.circle(Offset.zero, 40),
      Paths.rect(const Rect.fromLTRB(-60, -20, 60, 20)),
      Paths.polygon(const <Offset>[Offset(0, -70), Offset(50, 40), Offset(-50, 40)]),
    ]);

    test('passes through each key and blends between them', () {
      expect(morph.at(0).getBounds().width, closeTo(80, 1.5));
      expect(morph.at(1).getBounds().width, closeTo(120, 1.5));
      expect(morph.at(1).getBounds().height, closeTo(40, 1.5));
      final double halfway = morph.at(0.5).getBounds().width;
      expect(halfway, greaterThan(85));
      expect(halfway, lessThan(115));
      expect(morph.at(2).getBounds().top, closeTo(-70, 2));
    });

    test('clamps outside its keys', () {
      expect(morph.at(-3).getBounds(), morph.at(0).getBounds());
      expect(morph.at(9).getBounds(), morph.at(2).getBounds());
    });

    test('moves every point a short way rather than spinning the shape', () {
      // A circle into a square of about its size: aligned, no point needs to
      // go further than the corner pokes out.
      final Morph m = Morph(<Path>[
        Paths.circle(Offset.zero, 50),
        // Drawn from the bottom and the other way round, deliberately.
        Path()
          ..moveTo(0, 45)
          ..lineTo(45, 45)
          ..lineTo(45, -45)
          ..lineTo(-45, -45)
          ..lineTo(-45, 45)
          ..close(),
      ]);
      final List<Offset> a = m.outlines[0].points, b = m.outlines[1].points;
      for (int i = 0; i < a.length; i++) {
        expect((a[i] - b[i]).distance, lessThan(18));
      }
    });

    test('is the same at a frame however often it is asked', () {
      final List<Offset> first = morph.outlineAt(1.37).points;
      morph.at(0.2);
      morph.at(2);
      expect(morph.outlineAt(1.37).points, first);
    });

    testWidgets('is posed by Joint.morph', (WidgetTester tester) async {
      final Part rig = Part(
        name: 'blob',
        at: const Offset(100, 100),
        shapes: <Shape>[
          Shape.morph(
            Morph(<Path>[
              Paths.circle(Offset.zero, 20),
              Paths.rect(const Rect.fromLTRB(-90, -10, 90, 10)),
            ]),
            color: _red,
          ),
        ],
      );
      final ui.Image round = await _paint(tester, Drawing(rig));
      expect(await _alpha(tester, round, 100, 100), 255);
      expect(await _alpha(tester, round, 180, 100), 0);
      final ui.Image long = await _paint(
        tester,
        Drawing(rig, pose: const Pose(<String, Joint>{'blob': Joint.morphTo(1)})),
      );
      expect(await _alpha(tester, long, 180, 100), 255);
      expect(await _alpha(tester, long, 100, 85), 0);
    });
  });

  group('Joint.morph', () {
    test('adds, blends and compares like the other channels', () {
      expect(const Joint.morphTo(1).plus(const Joint.morphTo(0.5)).morph, 1.5);
      expect(Joint.lerp(Joint.rest, const Joint.morphTo(2), 0.25).morph, 0.5);
      expect(const Joint.morphTo(1), isNot(Joint.rest));
      final Take take = const Take(<Keyframe>[
        Keyframe(0, Pose(<String, Joint>{'mouth': Joint.rest})),
        Keyframe(10, Pose(<String, Joint>{'mouth': Joint.morphTo(2)}),
            curve: Curves.linear),
      ]);
      expect(take.at(5)['mouth'].morph, closeTo(1, 1e-9));
    });
  });

  group('Skin', () {
    final Path bar = Paths.roundRect(const Rect.fromLTRB(-10, -10, 10, 130), 10);
    final Skin skin = Skin(bar, bones: const <String>['shoulder', 'elbow'], tip: const Offset(0, 60));
    final Part rig = Part(
      name: 'body',
      at: const Offset(100, 20),
      children: <Part>[
        Part(
          name: 'shoulder',
          shapes: <Shape>[Shape.skin(skin, color: _red)],
          children: const <Part>[Part(name: 'elbow', at: Offset(0, 60))],
        ),
      ],
    );
    final List<Offset> rest = Outline.of(bar, samples: skin.samples).points;

    test('at rest is the outline as drawn', () {
      final Rect drawn = bar.getBounds();
      final Rect posed = skin.deformed(rig, Pose.rest).getBounds();
      expect(posed.left, closeTo(drawn.left, 0.5));
      expect(posed.right, closeTo(drawn.right, 0.5));
      expect(posed.top, closeTo(drawn.top, 0.5));
      expect(posed.bottom, closeTo(drawn.bottom, 0.5));
    });

    test('carries the far end rigidly with the lower bone', () {
      const Pose bent = Pose(<String, Joint>{'elbow': Joint.rotate(-90)});
      final Rect r = skin.deformed(rig, bent).getBounds();
      // Turned -90 at the elbow (0, 60): the forearm now lies along +x.
      expect(r.right, closeTo(70, 3));
      expect(r.bottom, lessThan(80));
    });

    test('bends as one unbroken curve', () {
      final double restGap = _maxGap(rest);
      for (final double degrees in <double>[-30, -60, -100, 45, 90]) {
        final Pose bent = Pose(<String, Joint>{'elbow': Joint.rotate(degrees)});
        final List<Offset> p = pointsOf(skin.deformed(rig, bent));
        expect(_maxGap(p), lessThan(restGap * 3), reason: '$degrees');
      }
    });

    test('the inside of a sharp bend does not fold over itself', () {
      bool crosses(Offset a, Offset b, Offset c, Offset d) {
        double side(Offset p, Offset q, Offset r) =>
            (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
        return side(a, b, c) * side(a, b, d) < 0 && side(c, d, a) * side(c, d, b) < 0;
      }

      for (final double degrees in <double>[-60, -90, -120, 90, 120]) {
        final List<Offset> p = pointsOf(skin.deformed(
          rig,
          Pose(<String, Joint>{'elbow': Joint.rotate(degrees)}),
        ));
        final int n = p.length;
        for (int i = 0; i < n; i++) {
          for (int j = i + 2; j < n; j++) {
            if (i == 0 && j == n - 1) continue;
            expect(crosses(p[i], p[(i + 1) % n], p[j], p[(j + 1) % n]), isFalse,
                reason: 'edges $i and $j cross at $degrees degrees');
          }
        }
      }
    });

    test('ignores what moves the whole limb', () {
      final Path still = skin.deformed(rig, Pose.rest);
      final Path carried = skin.deformed(
        rig,
        const Pose(<String, Joint>{
          'body': Joint(move: Offset(40, -15), degrees: 30),
          'shoulder': Joint.rotate(-50),
        }),
      );
      expect(carried.getBounds().topLeft.dx, closeTo(still.getBounds().topLeft.dx, 1e-6));
      expect(carried.getBounds().bottomRight.dy, closeTo(still.getBounds().bottomRight.dy, 1e-6));
    });

    testWidgets('draws the bend', (WidgetTester tester) async {
      final ui.Image image = await _paint(
        tester,
        Drawing(rig, pose: const Pose(<String, Joint>{'elbow': Joint.rotate(-90)})),
      );
      // Shoulder at (100, 20); elbow at (100, 80); forearm out to the right.
      expect(await _alpha(tester, image, 100, 50), 255);
      expect(await _alpha(tester, image, 140, 80), 255);
      expect(await _alpha(tester, image, 100, 130), 0);
    });
  });

  group('Chain', () {
    const Chain tail = Chain('tail', segments: 5, length: 150, width: 24);

    test('names one joint per segment and nests them', () {
      expect(tail.names, <String>['tail0', 'tail1', 'tail2', 'tail3', 'tail4']);
      expect(tail.part.names, containsAll(tail.names));
      final Affine tip = frameOf(tail.part, Pose.rest, 'tail4');
      expect(tip.origin.dx, closeTo(120, 1e-9));
    });

    test('a curl turns the whole chain by the angle asked', () {
      final Pose curl = tail.curl(180);
      final double total = tail.names
          .map((String n) => curl[n].degrees)
          .fold(0, (double s, double d) => s + d);
      expect(total, closeTo(180, 1e-9));
      expect(curl['tail4'].degrees, greaterThan(curl['tail0'].degrees));
    });

    test('a wave travels from the root to the tip', () {
      // The tip reaches the root's angle a little later.
      final Pose now = tail.wave(10, 30, taper: 0);
      final Pose later = tail.wave(10 + 30 * (1 / 5) / 0.8, 30, taper: 0);
      expect(later['tail1'].degrees, closeTo(now['tail0'].degrees, 1e-9));
      expect(tail.wave(10, 30), tail.wave(10, 30));
    });

    test('its skin covers the chain when it whips', () {
      final Part part = tail.part;
      final Pose pose = tail.wave(17, 30, amplitude: 25);
      final Path skin = part.shapes.single.skin!.deformed(part, pose);
      final Offset tipJoint = frameOf(part, pose, 'tail4').apply(const Offset(30, 0));
      expect((skin.getBounds().inflate(1)).contains(tipJoint), isTrue);
      expect(_maxGap(pointsOf(skin)), lessThan(20));
    });

    test('jiggles root first, one per joint', () {
      expect(tail.jiggles().map((Jiggle j) => j.joint), tail.names);
    });
  });
}
