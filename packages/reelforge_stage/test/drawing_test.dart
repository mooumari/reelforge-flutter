import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

const Color _red = Color(0xFFFF0000);
const Color _blue = Color(0xFF0000FF);

/// A 20x20 red square centred on its joint, with a blue 20x20 child 60px to
/// its right. Rotating the joint carries the child round with it.
final Part _rig = Part(
  name: 'root',
  at: const Offset(100, 100),
  shapes: <Shape>[Shape(Paths.rect(const Rect.fromLTWH(-10, -10, 20, 20)), color: _red)],
  children: <Part>[
    Part(
      name: 'arm',
      at: const Offset(60, 0),
      shapes: <Shape>[Shape(Paths.rect(const Rect.fromLTWH(-10, -10, 20, 20)), color: _blue)],
    ),
  ],
);

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
  final ByteData data = raw!;
  final int i = (y * image.width + x) * 4;
  return Color.fromARGB(
      data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

void main() {
  testWidgets('a part draws at its place, and its child at the child\'s', (tester) async {
    final ui.Image image = await _paint(tester, Drawing(_rig));
    expect(await _pixel(tester, image, 100, 100), _red);
    expect(await _pixel(tester, image, 160, 100), _blue);
    expect(await _pixel(tester, image, 130, 100), isNot(_red)); // gap between
  });

  testWidgets('turning a joint carries everything under it', (tester) async {
    // 90 degrees clockwise about the root: the arm, 60px to the right, is now
    // 60px below. Neither the old place nor the root's own square moves.
    final ui.Image image = await _paint(
      tester,
      Drawing(_rig, pose: const Pose(<String, Joint>{'root': Joint.rotate(90)})),
    );
    expect(await _pixel(tester, image, 100, 100), _red);
    expect(await _pixel(tester, image, 100, 160), _blue);
    expect(await _pixel(tester, image, 160, 100), isNot(_blue));
  });

  testWidgets('a pose on the child alone turns it about its own joint', (tester) async {
    final ui.Image image = await _paint(
      tester,
      Drawing(_rig, pose: const Pose(<String, Joint>{'arm': Joint.move(Offset(0, 40))})),
    );
    expect(await _pixel(tester, image, 160, 140), _blue);
    expect(await _pixel(tester, image, 160, 100), isNot(_blue));
  });

  testWidgets('the same part placed twice is two drawings of one object', (tester) async {
    final Part left = _rig.placed(at: const Offset(40, 40));
    final Part right = _rig.placed(at: const Offset(40, 140), scale: 1);
    expect(identical(left.shapes, right.shapes), isTrue);
    expect(identical(left.children, right.children), isTrue);

    final ui.Image image = await _paint(
      tester,
      Stack(children: <Widget>[Drawing(left), Drawing(right)]),
    );
    expect(await _pixel(tester, image, 40, 40), _red);
    expect(await _pixel(tester, image, 40, 140), _red);
  });

  testWidgets('an inked drawing is flat, with a marker line round the edge', (tester) async {
    const Ink pen = Ink(width: 6);
    final ui.Image image = await _paint(tester, Drawing(_rig, ink: pen));
    expect(await _pixel(tester, image, 100, 100), _red); // flat inside
    expect(await _pixel(tester, image, 90, 100), pen.color); // the line, on the edge
    expect(await _pixel(tester, image, 60, 100), isNot(pen.color)); // nothing outside it
  });

  testWidgets('a line too fine to carry an outline is left unoutlined', (tester) async {
    final Part thread = Part(
      at: const Offset(100, 100),
      shapes: <Shape>[Shape(Paths.rect(const Rect.fromLTWH(-30, -1, 60, 2)), color: _blue)],
    );
    final ui.Image image = await _paint(tester, Drawing(thread, ink: const Ink(width: 6)));
    expect(await _pixel(tester, image, 100, 100), _blue);
  });

  testWidgets('a faded part fades as one: no seam where limb meets body', (tester) async {
    final Part overlapping = Part(
      at: const Offset(100, 100),
      opacity: 0.5,
      shapes: <Shape>[
        Shape(Paths.rect(const Rect.fromLTWH(-20, -20, 40, 40)), color: _red),
        Shape(Paths.rect(const Rect.fromLTWH(-10, -10, 40, 20)), color: _red),
      ],
    );
    final ui.Image image = await _paint(tester, Drawing(overlapping));
    final Color body = await _pixel(tester, image, 90, 100);
    final Color overlap = await _pixel(tester, image, 110, 100);
    expect(overlap, body);
  });

  testWidgets('a pose that names a joint nothing has is an error', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Drawing(_rig, pose: const Pose(<String, Joint>{'elbwo': Joint.rotate(30)})),
      ),
    );
    final Object? error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('elbwo'));
    expect(error.toString(), contains('arm')); // names the real ones
  });

  testWidgets('Camera and ParallaxLayer draw through a VideoFrame', (tester) async {
    final Widget scene = Directionality(
      textDirection: TextDirection.ltr,
      child: VideoFrame(
        frame: 10,
        fps: 30,
        durationInFrames: 20,
        width: 200,
        height: 200,
        child: Camera(
          keyframes: const <CameraKeyframe>[
            CameraKeyframe(0),
            CameraKeyframe(10, center: Offset(160, 100), zoom: 2),
          ],
          child: ParallaxLayer(child: Drawing(_rig)),
        ),
      ),
    );
    await tester.pumpWidget(Center(child: SizedBox(width: 200, height: 200, child: scene)));
    expect(tester.takeException(), isNull);
  });
}
