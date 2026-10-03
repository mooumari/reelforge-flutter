import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'stage_style.dart' show wyatt;

/// Ten people from one template: a cowboy, a Bedouin and his sister, a
/// legionary, a pharaoh, a philosopher, a cyborg, a scientist, a kid and a
/// grandmother. They walk on in two rows, stop, wave and say hello.
///
/// Each is a [Body], a skin, a [FaceStyle] and a list of [Garment]s. Nothing
/// below is drawn for one character: the hats, robes, beards and boots fit
/// whoever wears them, and every one of them walks, waves and talks on the
/// same joints.
const int _fps = 30;
const int _frames = 450;

final Composition stageCast = Composition(
  id: 'StageCast',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: _frames,
  builder: (BuildContext context) => typeset(const _StageCast()),
);

// --- the ten ---

const Color _black = Color(0xFF2B2220);
const Color _white = Color(0xFFF3EEE4);
const Color _grey = Color(0xFFC9C4BE);

/// Wyatt's face, retuned: bigger or smaller eyes, brows of a colour and a
/// weight, a mouth, blush.
FaceStyle _face({
  double eyes = 1,
  Color brows = const Color(0xFF3B2416),
  double browThickness = 6.5,
  double mouth = 38,
  Color? cheeks = const Color(0x22E0607A),
}) =>
    FaceStyle(
      eyeSpacing: 60,
      eyeWidth: 24 * eyes,
      eyeHeight: 30 * eyes,
      pupilRadius: 9.5 * eyes,
      browGap: 30,
      browLength: 26,
      browThickness: browThickness,
      browColor: brows,
      mouthY: 52,
      mouthWidth: mouth,
      cheeks: cheeks,
    );

/// Who's who: a name, a greeting, the character, anything in its hands --
/// in the far hand, so the near one is free to wave -- and whether it waves
/// or, hands full, nods.
typedef Cast = ({String name, String hello, Character who, Map<String, List<Part>> hold, bool waves});

final List<Cast> castOfTen = <Cast>[
  (
    name: 'Wyatt',
    hello: 'Howdy!',
    who: wyatt,
    hold: <String, List<Part>>{'handB': <Part>[Props.lasso()]},
    waves: true,
  ),
  (
    name: 'Khalid',
    hello: 'As-salamu alaykum!',
    who: Character(
      body: Body(
        headRadius: 60, torso: 128, shoulders: 84, hips: 72, upperArm: 56, forearm: 51, armRadius: 10.5, wristRadius: 8.5,
        upperLeg: 66, lowerLeg: 62, legRadius: 15, ankleRadius: 10.5, head: HeadShape.long,
      ),
      skin: const Color(0xFFC68B59),
      face: _face(brows: _black, browThickness: 8, cheeks: null),
      outfit: const <Garment>[
        Beard(Color(0xFF4A3426), length: 0.15, trimmed: true),
        Robe(_white, collar: true),
        Headcloth(_white, check: Color(0xFFC0392B)),
        Sandals(),
      ],
    ),
    hold: const <String, List<Part>>{},
    waves: true,
  ),
  (
    name: 'Layla',
    hello: 'Marhaba!',
    who: Character(
      body: const Body(head: HeadShape.heart),
      skin: const Color(0xFFD9A06E),
      face: _face(eyes: 1.12, brows: _black, browThickness: 5, mouth: 34, cheeks: const Color(0x33E0607A)),
      outfit: const <Garment>[
        Robe(Color(0xFF2A2233), trim: Color(0xFFD4A94A)),
        Hijab(Color(0xFF5B3A6E)),
        Boots(Color(0xFF2A2233), height: 0),
      ],
    ),
    hold: const <String, List<Part>>{},
    waves: true,
  ),
  (
    name: 'Marcus',
    hello: 'Ave!',
    who: Character(
      body: Body(
        torso: 124, shoulders: 118, hips: 104, belly: 8, chest: 6, armRadius: 15, wristRadius: 11.5, hand: 14,
        legRadius: 21, ankleRadius: 14, upperLeg: 54, lowerLeg: 50, head: HeadShape.square.adjusted(jaw: 0.08, width: 1.04),
      ),
      skin: const Color(0xFFD69A6C),
      face: _face(eyes: 0.92, brows: _black, browThickness: 9, mouth: 42, cheeks: null),
      outfit: const <Garment>[
        Cape(Color(0xFFA8262C)),
        Tunic(Color(0xFFB83236)),
        Armour(),
        Belt(Color(0xFF5A3A22)),
        Sandals(),
        LegionHelmet(),
      ],
    ),
    hold: <String, List<Part>>{
      'handF': <Part>[Props.shield()],
      'handB': <Part>[Props.spear(length: 470)],
    },
    waves: false,
  ),
  (
    name: 'Nefer',
    hello: 'Greetings from the Nile!',
    who: Character(
      body: Body(
        headRadius: 60, torso: 128, shoulders: 82, hips: 70, upperArm: 56, forearm: 51, armRadius: 10.5, wristRadius: 8.5,
        upperLeg: 66, lowerLeg: 62, legRadius: 15, ankleRadius: 10.5, head: HeadShape.lerp(HeadShape.long, HeadShape.heart, 0.4),
      ),
      skin: const Color(0xFFB07A4F),
      face: _face(brows: _black, browThickness: 6, cheeks: null),
      outfit: const <Garment>[
        Kilt(_white, length: 0.42),
        BroadCollar(),
        Sandals(color: Color(0xFFD4A94A)),
        Nemes(),
      ],
    ),
    hold: <String, List<Part>>{'handB': <Part>[Props.staff(length: 260, color: const Color(0xFFD4A94A))]},
    waves: true,
  ),
  (
    name: 'Socrates',
    hello: 'I know that I know nothing.',
    who: const Character(
      body: Body(
        headRadius: 62, torso: 108, shoulders: 88, hips: 82, belly: 8, upperArm: 46, forearm: 42,
        upperLeg: 50, lowerLeg: 48, legRadius: 16, hunch: 9, head: HeadShape.long,
      ),
      skin: Color(0xFFE4AE84),
      face: FaceStyle(
        eyeSpacing: 60, eyeWidth: 22, eyeHeight: 27, pupilRadius: 8.5, browGap: 30, browLength: 28, browThickness: 9,
        browColor: Color(0xFFBDBDBD), mouthY: 52, mouthWidth: 36,
      ),
      outfit: <Garment>[
        Balding(_grey),
        Beard(_grey, length: 1.1),
        Toga(_white, border: Color(0xFF2F5DA8)),
        Sandals(),
      ],
    ),
    hold: const <String, List<Part>>{},
    waves: true,
  ),
  (
    name: 'Kai',
    hello: 'Systems online.',
    who: Character(
      body: Body(head: HeadShape.lerp(HeadShape.square, HeadShape.oval, 0.35)),
      skin: const Color(0xFFEFC3A0),
      face: _face(brows: const Color(0xFF222222), cheeks: null),
      outfit: const <Garment>[
        Buzz(Color(0xFF222222)),
        Shirt(Color(0xFF2C3440), sleeves: 0.35, collar: false),
        ChestLights(),
        Trousers(Color(0xFF3A4350)),
        Boots(Color(0xFF1C2128)),
        RobotArm(),
        HeadPlate(),
        EyeImplant(),
      ],
    ),
    hold: const <String, List<Part>>{},
    waves: true,
  ),
  (
    name: 'Dr. Ada',
    hello: 'Fascinating!',
    who: Character(
      body: const Body(head: HeadShape.heart),
      skin: const Color(0xFFF1C9A5),
      face: _face(eyes: 1.06, brows: const Color(0xFF8C3A12), browThickness: 5.5, mouth: 34, cheeks: const Color(0x33FF6B6B)),
      outfit: const <Garment>[
        Ponytail(Color(0xFFC0501F)),
        Shirt(Color(0xFF2EC4B6), collar: false),
        Trousers(Color(0xFF4A5568)),
        Sneakers(Color(0xFF4A5568)),
        Coat(Color(0xFFF7F7F2), length: 0.45),
        Glasses(),
      ],
    ),
    hold: <String, List<Part>>{'handB': <Part>[Props.clipboard()]},
    waves: true,
  ),
  (
    name: 'Milo',
    hello: 'Hi!!',
    who: Character(
      body: Body.child,
      skin: const Color(0xFF8D5A3B),
      face: _face(eyes: 1.2, brows: _black, browThickness: 6, mouth: 40, cheeks: const Color(0x33E0607A)),
      faceSize: 1.12,
      outfit: const <Garment>[
        Curls(_black, size: 0.92),
        Shirt(Color(0xFFFFC233), sleeves: 0.35, collar: false),
        Trousers(Color(0xFF3A6EA5), length: 0.45),
        Sneakers(Color(0xFFE63946)),
      ],
    ),
    hold: const <String, List<Part>>{},
    waves: true,
  ),
  (
    name: 'Rosa',
    hello: 'Hello, dears!',
    who: Character(
      body: Body(
        headRadius: 61, torso: 108, shoulders: 88, hips: 86, belly: 10, chest: 4, upperArm: 46, forearm: 42,
        upperLeg: 50, lowerLeg: 48, legRadius: 16, hunch: 7, head: HeadShape.round.adjusted(width: 1.03),
      ),
      skin: const Color(0xFFE9B994),
      face: _face(eyes: 0.95, brows: const Color(0xFF9A9A9A), browThickness: 5.5, mouth: 34, cheeks: const Color(0x33E0607A)),
      outfit: const <Garment>[
        Bun(Color(0xFFDADADA)),
        Shirt(Color(0xFF8E6BBF), collar: false),
        Skirt(Color(0xFF4F3B6E), length: 0.72),
        Boots(Color(0xFF5A3A22), height: 0),
        Glasses(color: Color(0xFF8C3A12)),
      ],
    ),
    hold: <String, List<Part>>{'handF': <Part>[Props.cane(length: 108)]},
    waves: false,
  ),
];

// --- the lineup ---

/// Two rows, the back one smaller and higher.
class _Spot {
  const _Spot(this.index, this.x, this.groundY, this.scale);

  final int index;
  final double x, groundY, scale;

  Character get who => castOfTen[index].who;

  /// A brisk walk, in pixels a frame: proportional to the legs, so short
  /// legs take as many steps a second as long ones, not longer strides.
  double get speed => (who.body.upperLeg + who.body.lowerLeg) * scale * 0.1;
}

const double _backGround = 640, _frontGround = 1000;
const double _backScale = 0.6, _frontScale = 0.8;

// Back row: Khalid, Nefer, Layla, Marcus, Socrates. Front row: Wyatt, Ada,
// Kai, Rosa, Milo -- the slowest walkers at the front of each row.
const List<int> _backRow = <int>[1, 4, 2, 3, 5];
const List<int> _frontRow = <int>[0, 7, 6, 9, 8];

final List<_Spot> _spots = <_Spot>[
  for (int i = 0; i < 5; i++) _Spot(_backRow[i], 430 + i * 330.0, _backGround, _backScale),
  for (int i = 0; i < 5; i++) _Spot(_frontRow[i], 270 + i * 345.0, _frontGround, _frontScale),
];

const double _offstage = -160;
const int _ease = 18;

/// Frames to walk on: ease up to speed, cruise, ease to a stop. The easing
/// segments are sized so the speed is continuous where they meet the cruise.
double _easeDistance(_Spot s) => s.speed * _ease * 2 / math.pi;
int _cruise(_Spot s) => ((s.x - _offstage - 2 * _easeDistance(s)) / s.speed).round();
int _walkLength(_Spot s) => 2 * _ease + _cruise(s);

/// Everyone stops together. Nobody overtakes anybody either: whoever is
/// behind in a row is never slower than whoever is ahead of them.
final int _arrived = 8 + _spots.map(_walkLength).reduce(math.max);

List<Waypoint> _route(_Spot s) {
  final int start = _arrived - _walkLength(s);
  return <Waypoint>[
    Waypoint(start, _offstage),
    Waypoint(start + _ease, _offstage + _easeDistance(s), curve: Curves.easeInSine),
    Waypoint(start + _ease + _cruise(s), s.x - _easeDistance(s), curve: Curves.linear),
    Waypoint(_arrived, s.x, curve: Curves.easeOutSine),
  ];
}

final List<Walk> _walks = <Walk>[
  for (final _Spot s in _spots)
    Walk(
      rig: s.who.build(hold: castOfTen[s.index].hold),
      route: _route(s),
      groundY: s.groundY,
      fps: _fps,
      scale: s.scale,
      body: s.who.biped,
    ),
];

/// Hellos go along the rows, front and back in turn.
int _helloAt(int spot) => _arrived + 10 + (spot % 5 * 2 + (spot < 5 ? 1 : 0)) * 12;

final List<Speech> _hellos = <Speech>[
  for (int i = 0; i < _spots.length; i++)
    Speech.fromText(castOfTen[_spots[i].index].hello, start: (_helloAt(i) + 8) / _fps),
];

Posed _perform(int i, int frame) {
  final Cast c = castOfTen[_spots[i].index];
  final Character who = c.who;
  final int hello = _helloAt(i);
  return _walks[i].at(frame, adjust: (Pose pose) {
    Pose out = pose.plus(who.stance).plus(who.life(31 + i).at(frame, _fps));
    if (c.waves) {
      final Pose? arm = Character.wave(frame - hello, _fps, from: pose);
      if (arm != null) out = out.overlay(arm);
    } else {
      final Pose? nod = Character.nod(frame - hello, _fps);
      if (nod != null) out = out.plus(nod);
    }
    // A smile as they wave, kept.
    final double smile = ((frame - hello) / 10).clamp(0.0, 1.0);
    if (smile > 0) out = out.plus(who.face.express(Emotion.happy, amount: 0.75 * smile));
    return out.plus(_hellos[i].at(frame, _fps));
  });
}

Posed _posed(int i, int frame) {
  final List<Jiggle> jiggles = castOfTen[_spots[i].index].who.jiggles;
  if (jiggles.isEmpty) return _perform(i, frame);
  return followThrough((int f) => _perform(i, f), frame, jiggles: jiggles, fps: _fps);
}

// --- the scene ---

/// The setting sun, up to the right.
const Light _light = Light(
  from: Offset(0.62, -0.78),
  shadow: Color(0xFF6A5AB0),
  highlight: Color(0xFFFFD9A8),
  cast: Color(0xFF1F1640),
);

final Part _backdrop = Part(shapes: <Shape>[
  Shape(Paths.rect(const Rect.fromLTRB(0, 0, 1920, 1080)), gradient: verticalGradient(const Color(0xFF1F2A5C), const Color(0xFF5B4B9A))),
  Shape(
    Paths.circle(const Offset(1560, 210), 300),
    gradient: const RadialGradient(colors: <Color>[Color(0x66FFD98A), Color(0x22FFD98A), Color(0x00FFD98A)], stops: <double>[0.35, 0.6, 1]),
  ),
  Shape(Paths.circle(const Offset(1560, 210), 110), color: const Color(0xFFFFE3A3)),
  Shape(Paths.smooth(const <Offset>[
    Offset(-100, 600), Offset(300, 520), Offset(700, 575), Offset(1100, 505), Offset(1500, 560),
    Offset(2020, 520), Offset(2020, 1180), Offset(-100, 1180),
  ]), color: const Color(0xFF3D3577)),
  Shape(Paths.rect(const Rect.fromLTRB(0, _backGround - 14, 1920, 1080)), color: const Color(0xFF4A3F86)),
  Shape(Paths.rect(const Rect.fromLTRB(0, 790, 1920, 1080)), color: const Color(0xFF574A99)),
]);

Part _shadow(_Spot s, double x) => Part(
      at: Offset(x, s.groundY + 4),
      shapes: <Shape>[Shape(Paths.ellipse(Offset.zero, 60 * s.scale, 10 * s.scale), color: const Color(0x44160A30))],
    );

class _StageCast extends StatelessWidget {
  const _StageCast();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double seconds = frame / _fps;
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < _spots.length; i++) {
      final _Spot s = _spots[i];
      final Posed p = _posed(i, frame);
      final double x = _walks[i].xAt(frame);
      final Character who = castOfTen[s.index].who;
      final double top = s.groundY - who.body.height * s.scale;
      final Speech hello = _hellos[i];
      final bool talking = seconds >= hello.words.first.start - 0.15 && seconds <= hello.end + 1.2;
      rows.addAll(<Widget>[
        Drawing(_shadow(s, x)),
        Drawing(p.part, pose: p.pose, light: _light),
        if (frame >= _arrived - 10)
          Positioned(
            left: s.x - 150,
            top: s.groundY + 8,
            width: 300,
            child: Opacity(
              opacity: ((frame - _arrived + 10) / 10).clamp(0.0, 1.0),
              child: Text(castOfTen[s.index].name,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34 * s.scale + 4, fontWeight: FontWeight.w700, color: const Color(0xFFFFFFFF))),
            ),
          ),
        if (talking)
          Positioned(
            left: s.x - 170,
            top: top - 70 * s.scale - 30,
            width: 340,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Text(castOfTen[s.index].hello,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30 * s.scale + 2, fontWeight: FontWeight.w600, color: const Color(0xFF1F2A5C))),
                ),
              ),
            ),
          ),
      ]);
    }
    return Stack(children: <Widget>[Drawing(_backdrop), ...rows]);
  }
}
