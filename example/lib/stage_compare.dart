import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'stage_hero.dart';

/// The same character walking twice, to see what planning footsteps buys.
///
/// Top: the first spike's walk -- a 24-frame cycle of hand-keyed angles, the
/// body slid along at a constant speed. Bottom: [Walk], given only a route.
///
/// Under each, every frame of the last second and a half leaves a dot where a
/// sole touched the ground. A foot that stays planted leaves one dot. A foot
/// that slides leaves a streak.
const int _fps = 30;
const double _scale = 0.8;
const double _topGround = 470;
const double _bottomGround = 1010;

final Composition walkCompare = Composition(
  id: 'WalkCompare',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: 180,
  builder: (BuildContext context) => typeset(const _WalkCompare()),
);

final Part _rig = hero();

// --- before: the hand-keyed cycle from the first spike, unchanged ---

Pose _p(Map<String, double> degrees, [Map<String, Offset> moves = const <String, Offset>{}]) =>
    Pose(<String, Joint>{
      for (final String name in <String>{...degrees.keys, ...moves.keys})
        name: Joint(degrees: degrees[name] ?? 0, move: moves[name] ?? Offset.zero),
    });

final Pose _contactA = _p(<String, double>{
  'hipF': -28, 'kneeF': 4, 'hipB': 24, 'kneeB': 8,
  'shoulderF': 26, 'elbowF': -12, 'shoulderB': -26, 'elbowB': -14, 'head': -1,
}, <String, Offset>{'body': const Offset(0, 7)});

final Take _handKeyed = Take(<Keyframe>[
  Keyframe(0, _contactA, curve: Curves.easeInOutSine),
  Keyframe(6, _p(<String, double>{
    'hipF': -4, 'kneeF': 6, 'hipB': -6, 'kneeB': 64,
    'shoulderF': 4, 'elbowF': -8, 'shoulderB': -4, 'elbowB': -8, 'head': 1,
  }, <String, Offset>{'body': const Offset(0, -5)}), curve: Curves.easeInOutSine),
  Keyframe(12, _p(<String, double>{
    'hipF': 24, 'kneeF': 8, 'hipB': -28, 'kneeB': 4,
    'shoulderF': -26, 'elbowF': -16, 'shoulderB': 26, 'elbowB': -12, 'head': -1,
  }, <String, Offset>{'body': const Offset(0, 7)}), curve: Curves.easeInOutSine),
  Keyframe(18, _p(<String, double>{
    'hipF': -6, 'kneeF': 64, 'hipB': -4, 'kneeB': 6,
    'shoulderF': -4, 'elbowF': -8, 'shoulderB': 4, 'elbowB': -8, 'head': 1,
  }, <String, Offset>{'body': const Offset(0, -5)}), curve: Curves.easeInOutSine),
  Keyframe(24, _contactA),
], loop: true);

const double _oldSpeed = 13.5 * _scale / 1.25; // the first spike's, rescaled
const int _oldStop = 150;

Posed _before(int frame) {
  final int f = frame.clamp(0, _oldStop);
  Pose pose = _handKeyed.at(f);
  if (frame > _oldStop) {
    pose = Pose.lerp(pose, Pose.rest, ((frame - _oldStop) / 12).clamp(0.0, 1.0));
  }
  return Posed(
    _rig.placed(at: Offset(150 + _oldSpeed * f, _topGround - 150 * _scale), scale: _scale),
    pose,
  );
}

// --- after: a route, and nothing else ---

final Walk _walk = Walk(
  rig: _rig,
  route: const <Waypoint>[
    Waypoint(4, 150),
    Waypoint(24, 260, curve: Curves.easeInSine),
    Waypoint(130, 1176, curve: Curves.linear),
    Waypoint(150, 1286, curve: Curves.easeOutSine),
  ],
  groundY: _bottomGround,
  fps: _fps,
  scale: _scale,
  body: heroBody,
);

Posed _after(int frame) => _walk.at(frame);

// --- the trail ---

/// Where each sole touches the ground at [frame], if it does.
List<Offset> _contacts(Posed p, double ground) => <Offset>[
      for (final String foot in <String>['footF', 'footB'])
        for (final Offset local in const <Offset>[Offset(-10, 24), Offset(40, 24)])
          frameOf(p.part, p.pose, foot).apply(local),
    ].where((Offset o) => o.dy >= ground - 3).toList();

Part _trail(Posed Function(int) at, int frame, double ground, Color color) {
  final List<Shape> dots = <Shape>[];
  for (int g = frame - 45; g <= frame; g++) {
    if (g < 0) continue;
    final double alpha = 0.25 + 0.75 * (g - frame + 45) / 45;
    for (final Offset c in _contacts(at(g), ground)) {
      dots.add(Shape(Paths.circle(Offset(c.dx, ground + 14), 3.2),
          color: color.withValues(alpha: alpha)));
    }
  }
  return Part(shapes: dots);
}

class _WalkCompare extends StatelessWidget {
  const _WalkCompare();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final Posed before = _before(frame);
    final Posed after = _after(frame);
    return Stack(
      children: <Widget>[
        const ColoredBox(color: Color(0xFF241245), child: SizedBox.expand()),
        Drawing(Part(shapes: <Shape>[
          Shape(Paths.rect(const Rect.fromLTRB(0, _topGround, 1920, 540)), color: const Color(0xFF3B1F66)),
          Shape(Paths.rect(const Rect.fromLTRB(0, _bottomGround, 1920, 1080)), color: const Color(0xFF3B1F66)),
          Shape(Paths.rect(const Rect.fromLTRB(0, 538, 1920, 542)), color: const Color(0xFF120828)),
        ])),
        Drawing(_trail(_before, frame, _topGround, const Color(0xFFFF8A80))),
        Drawing(_trail(_after, frame, _bottomGround, const Color(0xFF80FFD0))),
        Drawing(before.part, pose: before.pose),
        Drawing(after.part, pose: after.pose),
        const Positioned(left: 40, top: 30, child: _Label('Before', 'hand-keyed angles, body slid along at constant speed')),
        const Positioned(left: 40, top: 570, child: _Label('After', 'planned footsteps, legs solved to reach them')),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.title, this.detail);

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF))),
          Text(detail, style: const TextStyle(fontSize: 24, color: Color(0xBBFFFFFF))),
        ],
      );
}
