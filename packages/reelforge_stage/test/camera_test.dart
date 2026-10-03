import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

const Size _view = Size(1920, 1080);

void main() {
  group('Camera.stateAt', () {
    const List<CameraKeyframe> keys = <CameraKeyframe>[
      CameraKeyframe(0, center: Offset(500, 300), curve: Curves.linear),
      CameraKeyframe(10, center: Offset(1500, 500), zoom: 4, curve: Curves.linear),
    ];

    test('holds at both ends', () {
      expect(Camera.stateAt(keys, -5, _view).center, const Offset(500, 300));
      expect(Camera.stateAt(keys, 99, _view).zoom, 4);
    });

    test('pans linearly between keyframes', () {
      expect(Camera.stateAt(keys, 5, _view).center, const Offset(1000, 400));
    });

    test('zooms by ratio: halfway from 1x to 4x is 2x', () {
      expect(Camera.stateAt(keys, 5, _view).zoom, closeTo(2, 1e-9));
    });

    test('no centre means wherever the middle of the frame is', () {
      const List<CameraKeyframe> zoomOnly = <CameraKeyframe>[
        CameraKeyframe(0),
        CameraKeyframe(10, zoom: 2),
      ];
      expect(Camera.stateAt(zoomOnly, 5, _view).center, const Offset(960, 540));
    });
  });

  group('ParallaxLayer.project', () {
    const CameraState camera = CameraState(Offset(1500, 700), 2);

    test('depth 1 puts the point the camera looks at in the middle', () {
      expect(
        ParallaxLayer.project(camera, _view, 1, camera.center),
        const Offset(960, 540),
      );
    });

    test('depth 0 is on the lens: nothing moves it', () {
      expect(
        ParallaxLayer.project(camera, _view, 0, const Offset(123, 456)),
        const Offset(123, 456),
      );
    });

    test('panning moves a layer by its depth: far less, near more', () {
      // The same world point seen before and after the camera pans 100px.
      // At zoom 1 the screen shift is exactly depth x pan, which is all that
      // parallax is.
      const Offset p = Offset(900, 700);
      double shift(double depth) {
        final Offset before = ParallaxLayer.project(
            const CameraState(Offset(960, 540), 1), _view, depth, p);
        final Offset after = ParallaxLayer.project(
            const CameraState(Offset(1060, 540), 1), _view, depth, p);
        return before.dx - after.dx;
      }

      expect(shift(0), 0);
      expect(shift(0.4), closeTo(40, 1e-9));
      expect(shift(1), closeTo(100, 1e-9));
      expect(shift(1.5), closeTo(150, 1e-9));
    });

    test('a camera at rest leaves every layer where it was drawn', () {
      const CameraState rest = CameraState(Offset(960, 540), 1);
      for (final double depth in <double>[0, 0.3, 1, 1.7]) {
        expect(
          ParallaxLayer.project(rest, _view, depth, const Offset(300, 800)),
          const Offset(300, 800),
        );
      }
    });
  });
}
