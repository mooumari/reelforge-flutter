import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'savanna_set.dart';
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

// --- the lion ---

const Lion leo = Lion.male;
const double _lionScale = 1.45;

final Gait _lionGait = Gait(
  rig: leo.part,
  route: _leoPart.route,
  groundY: savannaGround,
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
  groundY: savannaGround,
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
      Drawing(savannaSky),
      Drawing(savannaDistance, light: savannaSun),
      Drawing(savannaPlain, light: savannaSun),
      Drawing(savannaShadow(lionX + leo.length * 0.6 * _lionScale, leo.length * 1.0 * _lionScale)),
      Drawing(savannaShadow(monkeyX, 52 * _monkeyScale)),
      Drawing(lion.part, pose: lion.pose, light: savannaSun),
      Drawing(monkey.part, pose: monkey.pose, light: savannaSun),
      if (leoLast) _bubble(leoSays.line.text, Offset(lionX + 330, 330)),
      if (!leoLast && momoSays != null) _bubble(momoSays.line.text, Offset(monkeyX - 40, 470)),
    ]);
  }
}
