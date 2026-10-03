import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'rain_cast.dart';

/// Where walking gets judged: the same band member walking, jogging and
/// running the same ground, then stopping, with a mark where each sole lands.
/// Look at frame strips of it rather than at stills; it is the stopping, the
/// first step and the hips that give a walk away.
const int _fps = 30;

final List<(String, Character, Walk)> _lab = <(String, Character, Walk)>[
  ('walk 1.2', tor, _walk(tor, 1.2, 520, 200, 1000)),
  ('run 1.0', ama, _walk(ama, 1.0, 1020, 200, 1500, running: true)),
];

Walk _walk(Character c, double pace, double ground, double from, double to, {bool running = false}) => Walk.paced(
      rig: c.part,
      from: from,
      to: to,
      groundY: ground,
      fps: _fps,
      start: 6,
      pace: pace,
      running: running,
      scale: 1.0,
      body: c.biped,
    );

final Composition walkLab = Composition(
  id: 'WalkLab',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: 240,
  builder: (BuildContext context) => typeset(const _WalkLab()),
);

class _WalkLab extends StatelessWidget {
  const _WalkLab();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    return Stack(children: <Widget>[
      const ColoredBox(color: Color(0xFF2B2250), child: SizedBox.expand()),
      for (int i = 0; i < _lab.length; i++) ...<Widget>[
        Positioned(left: 20, top: _lab[i].$3.groundY - 400, child: Text(_lab[i].$1, style: const TextStyle(fontFamily: 'Roboto', fontSize: 28, color: Color(0xFFFFFFFF)))),
        Positioned(left: 0, right: 0, top: _lab[i].$3.groundY, height: 3, child: const ColoredBox(color: Color(0x55FFFFFF))),
      ],
      for (int i = 0; i < _lab.length; i++) _walker(i, frame),
    ]);
  }

  Widget _walker(int i, int frame) {
    final Walk walk = _lab[i].$3;
    final Character c = _lab[i].$2;
    final Posed p = followThrough(
      (int f) => walk.at(f, adjust: (Pose pose) => pose.plus(c.stance)),
      frame,
      jiggles: c.jiggles,
      fps: _fps,
    );
    return Drawing(p.part, pose: p.pose);
  }
}

/// When each walker stops, for picking frames to look at.
List<int> get walkLabEnds => <int>[for (final (String _, Character _, Walk w) in _lab) w.endFrame];

/// Where row [i]'s walker is at [frame], and its ground: for tools that crop
/// around it.
double walkLabX(int i, int frame) => _lab[i].$3.xAt(frame);
double walkLabGround(int i) => _lab[i].$3.groundY;
