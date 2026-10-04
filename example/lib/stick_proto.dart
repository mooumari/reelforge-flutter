import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_kit/reelforge_kit.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'rain_cast.dart' show stand;
import 'stick.dart';
import 'stick_world.dart';

/// A prototype of the stick-figure look, all in code: a wide shot of a camp
/// in the rain, then a close-up of one of them looking up.
const int _fps = 30;
const Ink _pen = Ink(width: 6);

const StickFigure _tor = StickFigure(hair: StickHair.shaggy, hairColor: Color(0xFF6A4528), fur: Color(0xFF8A6A48), quiver: true);
const StickFigure _ama = StickFigure(hair: StickHair.messy, hairColor: Color(0xFF7A4A2A), fur: Color(0xFF7A6040), quiver: true);
const StickFigure _eda = StickFigure(hair: StickHair.shaggy, hairColor: Color(0xFF3A2A20), fur: Color(0xFF9A7A56));
const StickFigure _kit = StickFigure();

final List<Scene> _scenes = <Scene>[
  const Scene(frames: 150, child: _Camp(), transition: null),
  const Scene(frames: 120, child: _Closeup(), transition: SceneTransition.fade(frames: 10)),
];

final Composition stickProto = Composition(
  id: 'StickProto',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: Storyboard.totalFrames(_scenes, fps: _fps),
  builder: (BuildContext context) => typeset(
    Stack(fit: StackFit.expand, children: <Widget>[
      Storyboard(scenes: _scenes),
      const Audio(src: 'assets/sound/rain.m4a', volume: 0.12, loop: true),
    ]),
  ),
);

// --- the camp ---

/// A flat shadow under a standing figure.
Widget _shadow(double x, double ground, double s) => Positioned.fill(
      child: CustomPaint(painter: _ShadowPainter(x, ground, s)),
    );

class _ShadowPainter extends CustomPainter {
  const _ShadowPainter(this.x, this.ground, this.s);

  final double x, ground, s;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(Rect.fromCenter(center: Offset(x + 10 * s, ground + 4), width: 150 * s, height: 22 * s), Paint()..color = const Color(0x33202418));
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => old.x != x || old.s != s;
}

class _Camp extends StatelessWidget {
  const _Camp();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / _fps;
    final List<Widget> far = <Widget>[], near = <Widget>[];

    // A walker coming home across the front, spear on the shoulder.
    Widget walker(StickFigure c, int seed, double x, double ground, double s, double seconds, double distance) {
      final Walk walk = Walk(
        rig: c.build(hold: <String, List<Part>>{'handF': <Part>[spear()]}),
        route: Performance(fps: _fps, startX: x, beats: <Beat>[Move(x + distance, at: 0, seconds: seconds, curve: Curves.linear)]).route,
        groundY: ground,
        fps: _fps,
        scale: s,
        body: c.biped,
      );
      final Posed p = walk.at(frame, adjust: (Pose pose) => pose.plus(c.stance).plus(c.life(seed).at(frame, _fps)));
      return Stack(fit: StackFit.expand, children: <Widget>[
        _shadow(walk.xAt(frame), ground, s),
        Drawing(p.part, pose: p.pose, ink: _pen),
      ]);
    }

    // Someone crouched at the fire, stirring it.
    Widget stirrer(StickFigure c, double x, double ground, double s) {
      final double stir = math.sin(t * 5.2) * 9;
      final Pose crouch = Pose(<String, Joint>{
        'hipF': const Joint.rotate(-84),
        'kneeF': const Joint.rotate(96),
        'hipB': const Joint.rotate(-70),
        'kneeB': const Joint.rotate(88),
        'chest': const Joint.rotate(24),
        'head': const Joint.rotate(-8),
        'shoulderF': const Joint.rotate(-62),
        'elbowF': Joint.rotate(-24 + stir),
        'shoulderB': const Joint.rotate(-30),
        'elbowB': const Joint.rotate(-40),
      });
      final Part rig = c.build(hold: <String, List<Part>>{'handF': <Part>[stick()]});
      final Part placed = rig.placed(at: Offset(x, ground - (StickFigure.lowerLeg + StickFigure.sole) * s), scale: s);
      final Pose pose = crouch.plus(c.life(7).at(frame, _fps));
      return Stack(fit: StackFit.expand, children: <Widget>[
        _shadow(x + 40 * s, ground, s),
        Drawing(placed, pose: pose, ink: _pen),
      ]);
    }

    // One standing about by a tent, face to the sky.
    Widget lookout(StickFigure c, double x, double ground, double s) {
      final Performance act = Performance(fps: _fps, startX: x, beats: const <Beat>[Look(Offset(0.1, -0.95), at: 0.4)]);
      final Part placed = stand(c, x, ground, s);
      final Pose pose = c.stance.plus(c.life(11).at(frame, _fps)).plus(const Pose(<String, Joint>{'head': Joint.rotate(-16)})).plus(act.face(c.face, frame));
      return Stack(fit: StackFit.expand, children: <Widget>[
        _shadow(x, ground, s),
        Drawing(placed, pose: pose, ink: _pen),
      ]);
    }

    // Back to front: far things first.
    far.add(Drawing(hideTent(250, 700, 0.8), ink: _pen));
    far.add(Drawing(hideTent(1560, 690, 0.7), ink: _pen));
    far.add(Drawing(hideTent(1780, 714, 0.8), ink: _pen));
    far.add(Drawing(rock(1180, 700, 0.5), ink: _pen));
    far.add(lookout(_eda, 1530, 760, 0.62));
    far.add(walker(_ama, 3, 1160, 780, 0.55, 4.8, 260));

    near.add(Drawing(fireStones(1010, 840, 1.0), ink: _pen));
    near.add(stirrer(_kit, 830, 850, 0.78));
    near.add(FireLight(base: Offset(1010, 840), size: 1.05));
    near.add(walker(_tor, 1, 230, 990, 0.95, 5.0, 480));

    return Stack(fit: StackFit.expand, children: <Widget>[
      Camera(
        keyframes: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(960, 650), zoom: 1.22),
          CameraKeyframe(150, center: Offset(950, 660), zoom: 1.3, curve: Curves.easeInOutSine),
        ],
        child: Stack(fit: StackFit.expand, children: <Widget>[
          const StickWorld(gloom: 1),
          ParallaxLayer(depth: 1.0, child: Stack(fit: StackFit.expand, children: far)),
          ParallaxLayer(depth: 1.0, child: Stack(fit: StackFit.expand, children: near)),
        ]),
      ),
      StickRain(intensity: ease(t, 0.0, 1.5), slant: 8),
    ]);
  }
}

double ease(double t, double from, double over, [Curve curve = Curves.easeInOut]) => curve.transform(((t - from) / over).clamp(0.0, 1.0));

// --- the close-up ---

class _Closeup extends StatelessWidget {
  const _Closeup();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / _fps;
    const StickFigure c = _tor;
    const double s = 3.0;
    final Performance act = Performance(fps: _fps, startX: 0, beats: const <Beat>[
      Look(Offset(0.5, 0.0), at: 0.0),
      Look(Offset(0.2, -1.0), at: 0.9),
      Feel(Emotion.worried, at: 1.4, amount: 0.9),
      Look(Offset(-0.1, -1.0), at: 2.2),
    ]);
    // His head tips back to look at the sky, a beat after his eyes do.
    final double tilt = -17 * ease(t, 1.0, 0.5, Curves.easeOut);
    final Pose pose = c.stance
        .plus(c.life(5).at(frame, _fps))
        .plus(Pose(<String, Joint>{'head': Joint.rotate(tilt), 'chest': Joint.rotate(-3 * ease(t, 1.0, 0.5))}))
        .plus(act.face(c.face, frame));
    final Part placed = c.part.placed(at: const Offset(960, 1110), scale: s);
    return Stack(fit: StackFit.expand, children: <Widget>[
      Camera(
        keyframes: const <CameraKeyframe>[CameraKeyframe(0, center: Offset(960, 540)), CameraKeyframe(120, center: Offset(960, 520), zoom: 1.05, curve: Curves.easeInOutSine)],
        child: Stack(fit: StackFit.expand, children: <Widget>[
          const StickWorld(gloom: 1, horizon: 860),
          ParallaxLayer(depth: 1.0, child: Drawing(placed, pose: pose, ink: const Ink(width: 14))),
        ]),
      ),
      const StickRain(intensity: 1, slant: 10),
    ]);
  }
}
