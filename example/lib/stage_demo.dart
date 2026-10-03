import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'stage_hero.dart';
import 'stage_world.dart';

/// The spike: two characters walk in, one waves, the other waves back, and the
/// camera pushes in. Everything on screen is drawn in code -- no image, no
/// vector file, no animation export -- and every pixel is a function of the
/// frame.
///
/// Nothing here keys a leg. Each character is given a route, the walk plans
/// its footsteps from it, and the legs are solved to reach them; breathing,
/// blinks and the antenna's swing are layered on top.
const int stageFps = 30;

const int _heroWaveAt = 160;
const int _pipWaveAt = 192;

// Start from standing, ease up to pace, cruise, ease to a stop. The cruise
// speeds are each character's stride at a brisk walk; the easing segments are
// sized so the speed is continuous where they meet the cruise.
const List<Waypoint> _heroRoute = <Waypoint>[
  Waypoint(6, 300),
  Waypoint(30, 468, curve: Curves.easeInSine),
  Waypoint(117, 1425, curve: Curves.linear),
  Waypoint(141, 1593, curve: Curves.easeOutSine),
];

const List<Waypoint> _pipRoute = <Waypoint>[
  Waypoint(0, -60),
  Waypoint(24, 87, curve: Curves.easeInSine),
  Waypoint(120, 1009, curve: Curves.linear),
  Waypoint(144, 1156, curve: Curves.easeOutSine),
];

final Walk _heroWalk = Walk(
  rig: hero(),
  route: _heroRoute,
  groundY: groundY,
  fps: stageFps,
  scale: 1.25,
  body: heroBody,
);

// The second character is the first one's skeleton in other colours, smaller,
// with a shorter stride -- so the same distance takes quicker steps.
final Walk _pipWalk = Walk(
  rig: hero(
    suit: const Color(0xFF3FC6B7),
    boot: const Color(0xFF2B2150),
    visor: const Color(0xFF1B2A5A),
  ),
  route: _pipRoute,
  groundY: groundY,
  fps: stageFps,
  scale: 0.9,
  body: heroBody,
);

final Composition stageDemo = Composition(
  id: 'StageDemo',
  width: 1920,
  height: 1080,
  fps: stageFps,
  durationInFrames: 300,
  builder: (BuildContext context) => const _StageDemo(),
);

/// One character's performance: walk, life, an optional wave and speech.
Posed _perform(
  Walk walk,
  int frame, {
  required int seed,
  required int waveAt,
  (int, int)? talking,
}) =>
    walk.at(frame, adjust: (Pose pose) {
      Pose out = pose.plus(heroLife(seed).at(frame, stageFps));
      final Pose? arm = wave(
        frame - waveAt,
        stageFps,
        from: Pose(<String, Joint>{
          'shoulderF': pose['shoulderF'],
          'elbowF': pose['elbowF'],
          'handF': pose['handF'],
        }),
      );
      if (arm != null) out = out.overlay(arm);
      if (talking != null && frame >= talking.$1 && frame < talking.$2) {
        out = out.plus(talk(frame, stageFps));
      }
      return out;
    });

Posed _hero(int frame) => followThrough(
      (int f) => _perform(_heroWalk, f, seed: 1, waveAt: _heroWaveAt, talking: (232, 290)),
      frame,
      jiggles: heroJiggles,
      fps: stageFps,
    );

Posed _pip(int frame) => followThrough(
      (int f) => _perform(_pipWalk, f, seed: 7, waveAt: _pipWaveAt),
      frame,
      jiggles: heroJiggles,
      fps: stageFps,
    );

final Part _sky = sky();
final Part _planet = planet();
final Part _farRidge = ridge(
  color: const Color(0xFF8A4A8F),
  haze: const Color(0xFFC0618A),
  baseY: 700,
  amplitude: 230,
  seed: 3,
);
final Part _midRidge = ridge(
  color: const Color(0xFF5C2F86),
  haze: const Color(0xFF8C4696),
  baseY: 790,
  amplitude: 150,
  seed: 8,
  step: 190,
);
final Part _farForest = forest(leaf: const Color(0xFF7B4AA6), seed: 5, baseY: 840, scale: 0.55);
final Part _nearForest = forest(leaf: const Color(0xFF8D3F8C), seed: 21, baseY: 870, scale: 0.95);
final Part _ground = ground();
final Part _plants = plants(4);

// The camera rides the hero's route, offset to keep room ahead of the walk;
// the same keyframes and curves, so it tracks without lag or drift.
const List<CameraKeyframe> _camera = <CameraKeyframe>[
  CameraKeyframe(6, center: Offset(470, 540)),
  CameraKeyframe(30, center: Offset(638, 540), curve: Curves.easeInSine),
  CameraKeyframe(117, center: Offset(1595, 540), curve: Curves.linear),
  CameraKeyframe(141, center: Offset(1763, 540), curve: Curves.easeOutSine),
  CameraKeyframe(165, center: Offset(1763, 540)),
  CameraKeyframe(240, center: Offset(1450, 500), zoom: 2.1),
  CameraKeyframe(300, center: Offset(1470, 505), zoom: 2.3, curve: Curves.easeOut),
];

class _StageDemo extends StatelessWidget {
  const _StageDemo();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final Posed hero = _hero(frame);
    final Posed pip = _pip(frame);

    return Camera(
      keyframes: _camera,
      child: Stack(
        children: <Widget>[
          ParallaxLayer(depth: 0, child: Drawing(_sky)),
          ParallaxLayer(depth: 0.12, child: Drawing(_planet)),
          ParallaxLayer(depth: 0.28, child: Drawing(_farRidge)),
          ParallaxLayer(depth: 0.45, child: Drawing(_farForest)),
          ParallaxLayer(depth: 0.6, child: Drawing(_midRidge)),
          ParallaxLayer(depth: 0.78, child: Drawing(_nearForest)),
          ParallaxLayer(
            child: Stack(
              children: <Widget>[
                Drawing(_ground),
                Drawing(_shadow(_pipWalk.xAt(frame), 0.9)),
                Drawing(_shadow(_heroWalk.xAt(frame), 1.25)),
                Drawing(pip.part, pose: pip.pose),
                Drawing(hero.part, pose: hero.pose),
              ],
            ),
          ),
          ParallaxLayer(depth: 1.5, child: Drawing(_plants)),
        ],
      ),
    );
  }
}

Part _shadow(double x, double scale) => Part(
      at: Offset(x, groundY + 6),
      shapes: <Shape>[
        Shape(Paths.ellipse(Offset.zero, 74 * scale, 12 * scale), color: const Color(0x44160A30)),
      ],
    );
