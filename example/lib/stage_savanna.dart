import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'savanna_voices.dart';

/// Two animals meet: a lion on four legs and a monkey on two.
///
/// The scene is two [Performance]s -- each a list of beats in seconds -- and
/// its dialogue is voiced: `tool/voice.py` gave each line to an Azure voice
/// (Davis for Leo, Ana for Momo) and wrote [SavannaVoices], so every line
/// starts when the one before it has really finished, the mouths move to
/// the voices' own visemes, and the audio plays under the picture.
///
/// Leo walks in from the left with a [Gait] and stops; Momo walks in from
/// the right with a [Walk], because a monkey here is a [Character] in fur.
/// Leo says hello, Momo waves and answers, Leo is pleased to meet him.
const int _fps = 30;

// --- the script ---

const Say _leoHello = Say(SavannaVoices.leoHello, at: 6.0);
final Say _momoHi = Say(SavannaVoices.momoHi, at: _leoHello.end + 0.45);
final Say _leoNice = Say(SavannaVoices.leoNice, at: _momoHi.end + 0.4);

final Performance _leoPart = Performance(
  fps: _fps,
  startX: -560,
  beats: <Beat>[
    const Move(560, at: 0, seconds: 5.4),
    const Look(Offset(0.6, 0.15), at: 5.0),
    _leoHello,
    const Feel(Emotion.happy, at: 5.7, amount: 0.5),
    _leoNice,
    Feel(Emotion.happy, at: _leoNice.at - 0.2, amount: 0.9),
  ],
);

final Performance _momoPart = Performance(
  fps: _fps,
  startX: 2120,
  beats: <Beat>[
    const Move(1370, at: 1.0, seconds: 4.9),
    const Feel(Emotion.happy, at: 6.1, amount: 0.8),
    const Look(Offset(0.5, 0.1), at: 6.1),
    Act(Character.wave, at: _momoHi.at - 0.3),
    _momoHi,
    Feel(Emotion.surprised, at: _leoNice.at + 0.6, amount: 0.3),
    Feel(Emotion.happy, at: _leoNice.end, amount: 0.9),
  ],
);

/// A beat and a half after the last word.
final int _frames = ((math.max(_leoPart.end, _momoPart.end) + 1.5) * _fps).ceil();

final Composition stageSavanna = Composition(
  id: 'StageSavanna',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: _frames,
  builder: (BuildContext context) => typeset(const _StageSavanna()),
);

/// The sun, low behind them on the right.
const Light _sun = Light(
  from: Offset(0.72, -0.62),
  shadow: Color(0xFF7A4A9E),
  highlight: Color(0xFFFFD49A),
  cast: Color(0xFF3A1A46),
);

const double _ground = 940;

// --- the lion ---

const Lion leo = Lion.male;
const double _lionScale = 1.45;

final Gait _lionGait = Gait(
  rig: leo.part,
  route: _leoPart.route,
  groundY: _ground,
  fps: _fps,
  scale: _lionScale,
  body: leo.quadruped,
);

/// When Leo has stopped, and his tail can swish.
final int _leoStops = (_leoPart.route.last.frame + 0.3 * _fps).round();

Posed _lion(int frame) => _lionGait.at(frame, adjust: (Pose pose) {
      final double still = ((frame - _leoStops) / 20).clamp(0.0, 1.0);
      return pose
          .plus(leo.stance)
          .plus(leo.life(7).at(frame, _fps))
          .plus(Pose.lerp(Pose.rest, leo.swish(frame, _fps), still))
          .plus(_leoPart.face(leo.face, frame));
    });

// --- the monkey ---

const Color _fur = Color(0xFF8A5A3A);
const Color _mask = Color(0xFFF0C9A0);

const Character momo = Character(
  body: Body(
    headRadius: 60, neck: 4, torso: 86, shoulders: 76, hips: 66, belly: 6, upperArm: 50, forearm: 48,
    armRadius: 10.5, wristRadius: 8.5, hand: 12, upperLeg: 38, lowerLeg: 36, legRadius: 13,
    ankleRadius: 10, foot: 36, hunch: 7, head: HeadShape.round,
  ),
  skin: _fur,
  face: FaceStyle(
    eyeSpacing: 58,
    eyeWidth: 26,
    eyeHeight: 30,
    pupilRadius: 10.5,
    browGap: 28,
    browLength: 22,
    browThickness: 6,
    browColor: Color(0xFF5A3420),
    mouthY: 56,
    mouthWidth: 40,
  ),
  outfit: <Garment>[
    Fur(Color(0xFFD9AE84), crown: Color(0xFF6E4429)),
    MonkeyFace(_mask, ear: Color(0xFFE0A884)),
    Tail(_fur, length: 2.6),
  ],
);

const double _monkeyScale = 1.25;

final Walk _monkeyWalk = Walk(
  rig: momo.part,
  route: _momoPart.route,
  groundY: _ground,
  fps: _fps,
  scale: _monkeyScale,
  body: momo.biped,
);

Posed _monkey(int frame) => _monkeyWalk.at(frame, adjust: (Pose pose) {
      final Pose body = pose.plus(momo.stance).plus(momo.life(12).at(frame, _fps));
      return _momoPart.acts(frame, body).plus(_momoPart.face(momo.face, frame));
    });

Posed _swinging(Posed Function(int) perform, List<Jiggle> jiggles, int frame) =>
    followThrough(perform, frame, jiggles: jiggles, fps: _fps);

// --- the savanna ---

final Part _sky = Part(shapes: <Shape>[
  Shape(
    Paths.rect(const Rect.fromLTRB(0, 0, 1920, 1080)),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF34245E), Color(0xFF8A3F6E), Color(0xFFE8784E), Color(0xFFFFB45E)],
      stops: <double>[0, 0.35, 0.62, 0.74],
    ),
  ),
  Shape(
    Paths.circle(const Offset(1500, 690), 420),
    gradient: const RadialGradient(colors: <Color>[Color(0x88FFE0A0), Color(0x22FFC880), Color(0x00FFC880)], stops: <double>[0.3, 0.6, 1]),
  ),
  Shape(Paths.circle(const Offset(1500, 690), 150), color: const Color(0xFFFFE6B0)),
]);

/// A flat-topped acacia: a crooked trunk, branches, and a canopy of lit
/// clumps.
Part _acacia(Offset at, double scale, Color color, {bool flip = false}) {
  const Shade shade = Shade(form: 0.45, core: 0.3, coreStrength: 0.6, rim: 0.1, rimStrength: 0.5);
  final Color bark = Color.lerp(color, const Color(0xFF1A1030), 0.2)!;
  return Part(at: at, scaleX: flip ? -scale : scale, scaleY: scale, shapes: <Shape>[
    Shape(
      Paths.smooth(const <Offset>[
        Offset(-14, 0), Offset(-10, -90), Offset(-30, -170), Offset(-90, -230), Offset(-80, -240), Offset(-14, -186),
        Offset(6, -150), Offset(40, -220), Offset(110, -250), Offset(116, -238), Offset(52, -200), Offset(14, -110), Offset(14, 0),
      ]),
      color: bark,
      shade: shade,
    ),
    for (final (double, double, double) c in const <(double, double, double)>[
      (-150, -258, 70), (-60, -282, 90), (50, -290, 96), (150, -268, 78), (230, -252, 50), (-220, -246, 44),
    ])
      Shape(Paths.ellipse(Offset(c.$1, c.$2), c.$3 * 1.25, c.$3 * 0.42), color: color, shade: shade),
  ]);
}

final Part _distance = Part(children: <Part>[
  Part(shapes: <Shape>[
    Shape(
      Paths.smooth(const <Offset>[
        Offset(-100, 760), Offset(240, 690), Offset(560, 720), Offset(820, 664), Offset(1180, 712), Offset(1600, 676),
        Offset(2020, 724), Offset(2020, 1180), Offset(-100, 1180),
      ]),
      color: const Color(0xFFB0587A),
      shade: const Shade(form: 0.35, core: 0.2, coreStrength: 0.4, rim: 0.03),
    ),
  ]),
  _acacia(const Offset(300, 718), 0.42, const Color(0xFF8C4570)),
  _acacia(const Offset(1760, 700), 0.36, const Color(0xFF8C4570), flip: true),
  _acacia(const Offset(1040, 706), 0.28, const Color(0xFF8C4570)),
]);

final Part _plain = Part(children: <Part>[
  Part(shapes: <Shape>[
    Shape(
      Paths.smooth(const <Offset>[
        Offset(-100, 820), Offset(500, 800), Offset(1100, 816), Offset(1700, 796), Offset(2020, 812),
        Offset(2020, 1180), Offset(-100, 1180),
      ]),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFE29A58), Color(0xFFC0684E), Color(0xFF9A4E52)],
        stops: <double>[0, 0.5, 1],
      ),
    ),
  ]),
  _acacia(const Offset(150, 836), 0.95, const Color(0xFF6E3A5E)),
  for (int i = 0; i < 26; i++) _tuft(Offset(40 + i * 73.0 + (i * 37 % 29), 850 + (i * 53 % 70)), 0.6 + (i % 4) * 0.15),
]);

/// A clump of dry grass.
Part _tuft(Offset at, double scale) {
  final math.Random r = math.Random(at.dx.round());
  return Part(at: at, scaleX: scale, scaleY: scale, shapes: <Shape>[
    for (int i = 0; i < 6; i++)
      Shape(
        Paths.smooth(<Offset>[
          Offset(-6 + i * 2.5, 0), Offset(-20 + i * 8 + r.nextDouble() * 6, -30 - r.nextDouble() * 24), Offset(-2 + i * 2.5, 0),
        ]),
        color: Color.lerp(const Color(0xFFC07848), const Color(0xFFF0B064), r.nextDouble())!,
      ),
  ]);
}

Part _shadow(double x, double rx) => Part(at: Offset(x, _ground + 4), shapes: <Shape>[
      Shape(Paths.ellipse(Offset.zero, rx, rx * 0.12), color: const Color(0x553A1A46)),
    ]);

Widget _bubble(String text, Offset at) => Positioned(
      left: at.dx - 260,
      top: at.dy,
      width: 520,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(color: const Color(0xFFFFF6E8), borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(text, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: Color(0xFF34245E))),
          ),
        ),
      ),
    );

class _StageSavanna extends StatelessWidget {
  const _StageSavanna();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final Posed lion = _swinging(_lion, leo.jiggles, frame);
    final Posed monkey = _swinging(_monkey, momo.jiggles, frame);
    final double lionX = _lionGait.xAt(frame), monkeyX = _monkeyWalk.xAt(frame);
    // One bubble at a time: whoever spoke last.
    final Say? leoSays = _leoPart.sayingAt(frame), momoSays = _momoPart.sayingAt(frame);
    final bool leoLast = leoSays != null && (momoSays == null || leoSays.at > momoSays.at);
    return Stack(children: <Widget>[
      ..._leoPart.audio(),
      ..._momoPart.audio(),
      Drawing(_sky),
      Drawing(_distance, light: _sun),
      Drawing(_plain, light: _sun),
      Drawing(_shadow(lionX + leo.length * 0.6 * _lionScale, leo.length * 1.0 * _lionScale)),
      Drawing(_shadow(monkeyX, 52 * _monkeyScale)),
      Drawing(lion.part, pose: lion.pose, light: _sun),
      Drawing(monkey.part, pose: monkey.pose, light: _sun),
      if (leoLast) _bubble(leoSays.line.text, Offset(lionX + 330, 330)),
      if (!leoLast && momoSays != null) _bubble(momoSays.line.text, Offset(monkeyX - 40, 470)),
    ]);
  }
}
