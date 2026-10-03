import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;

/// The band: a family of Ice Age hunter-gatherers, one template and a
/// wardrobe of hides.
///
/// They are a composite -- nobody knows what any real band looked like --
/// but the details follow the evidence: dark skin and dark hair (ancient
/// DNA from Ice Age Europe says so), skins and fur for clothes, bone and
/// shell for ornament, cords of sinew for belts.

const Color _hair = Color(0xFF1E1410);
const Color _grey = Color(0xFFB9B2AA);

/// The hunter: broad, bearded, a mantle of wolf fur.
const Character tor = Character(
  body: Body(
    torso: 124, shoulders: 112, hips: 98, belly: 6, chest: 6, armRadius: 14.5, wristRadius: 11, hand: 13.5,
    legRadius: 20, ankleRadius: 13.5, upperLeg: 56, lowerLeg: 52, head: HeadShape.square,
  ),
  skin: Color(0xFF7A4B32),
  face: FaceStyle(
    eyeSpacing: 60, eyeWidth: 22, eyeHeight: 27, pupilRadius: 9, pupilColor: Color(0xFF1A100A), browGap: 28, browLength: 28,
    browThickness: 9, browColor: Color(0xFF1E1410), mouthY: 52, mouthWidth: 40,
  ),
  outfit: <Garment>[
    LongHair(_hair, length: 1.5),
    Beard(Color(0xFF241810), length: 0.6),
    HideTunic(Color(0xFF8A5A36), length: 0.34),
    FurMantle(Color(0xFFB9A58A)),
    Cord(Color(0xFFD9C7A0)),
    Boots(Color(0xFF6A4528), height: 0.34),
  ],
);

/// The woman who keeps the fire: slim, hair knotted up, shell beads.
const Character ama = Character(
  body: Body(head: HeadShape.heart, torso: 122, shoulders: 84, hips: 74, upperArm: 52, forearm: 47, upperLeg: 60, lowerLeg: 56, legRadius: 16, ankleRadius: 11),
  skin: Color(0xFF8A5A3C),
  face: FaceStyle(
    eyeSpacing: 60, eyeWidth: 26, eyeHeight: 32, pupilRadius: 10.5, pupilColor: Color(0xFF1A100A), browGap: 30, browLength: 26,
    browThickness: 5, browColor: Color(0xFF1E1410), mouthY: 52, mouthWidth: 36, cheeks: Color(0x22C0503A),
  ),
  outfit: <Garment>[
    Bun(_hair),
    HideTunic(Color(0xFFA06A3E), length: 0.4),
    BeadNecklace(Color(0xFFEFE3C8)),
    Cord(Color(0xFFD9C7A0)),
    Boots(Color(0xFF7A5230), height: 0.3),
  ],
);

/// The grandmother: stooped, grey, wrapped in fur.
const Character eda = Character(
  body: Body(
    headRadius: 61, torso: 106, shoulders: 86, hips: 82, belly: 6, upperArm: 45, forearm: 41, upperLeg: 48, lowerLeg: 46,
    legRadius: 15, hunch: 10, head: HeadShape.long,
  ),
  skin: Color(0xFF6A3F2A),
  face: FaceStyle(
    eyeSpacing: 60, eyeWidth: 21, eyeHeight: 25, pupilRadius: 8.5, pupilColor: Color(0xFF1A100A), browGap: 30, browLength: 28,
    browThickness: 8, browColor: _grey, mouthY: 52, mouthWidth: 34,
  ),
  outfit: <Garment>[
    LongHair(_grey, length: 1.7),
    HideTunic(Color(0xFF7C5B3E), length: 0.46, sleeves: 0.3),
    FurMantle(Color(0xFFCBBBA3), drop: 0.5),
    Boots(Color(0xFF5E4026), height: 0.3),
  ],
);

/// A boy of seven or so.
const Character kito = Character(
  body: Body.child,
  skin: Color(0xFF8D5A3B),
  face: FaceStyle(
    eyeSpacing: 60, eyeWidth: 29, eyeHeight: 36, pupilRadius: 11.5, pupilColor: Color(0xFF1A100A), browGap: 30, browLength: 24,
    browThickness: 5.5, browColor: Color(0xFF1E1410), mouthY: 52, mouthWidth: 40, cheeks: Color(0x33C0503A),
  ),
  faceSize: 1.12,
  outfit: <Garment>[
    Curls(_hair, size: 0.9),
    HideTunic(Color(0xFF9A6840), length: 0.44, trim: null),
    Cord(Color(0xFFD9C7A0), toggle: null),
    Boots(Color(0xFF7A5230), height: 0.3),
  ],
);

/// The young hunter: tall, quick, hair tied back.
const Character bran = Character(
  body: Body.slim,
  skin: Color(0xFF6E4430),
  face: FaceStyle(
    eyeSpacing: 60, eyeWidth: 23, eyeHeight: 29, pupilRadius: 9.5, pupilColor: Color(0xFF1A100A), browGap: 30, browLength: 27,
    browThickness: 6.5, browColor: Color(0xFF1E1410), mouthY: 52, mouthWidth: 38,
  ),
  outfit: <Garment>[
    Ponytail(_hair, length: 1.6),
    HideTunic(Color(0xFF7E5636), length: 0.3),
    FurMantle(Color(0xFFA58E72), drop: 0.34),
    Cord(Color(0xFFD9C7A0)),
    Boots(Color(0xFF5E4026), height: 0.36),
  ],
);

/// A hide held up for a roof: scraped skin, ragged at the edge, drooping at
/// the corners and fringed with fur, drawn round the hand when the arm is
/// raised straight up.
Part hideSheet({Color color = const Color(0xFF8A5E3A), double width = 230}) {
  final double w = width / 2;
  final Path sheet = Paths.smooth(<Offset>[
    Offset(-w, 46), Offset(-w * 0.9, 18), Offset(-w * 0.5, 2), Offset(0, -6), Offset(w * 0.5, 0), Offset(w * 0.92, 14), Offset(w, 50),
    Offset(w * 0.78, 38), Offset(w * 0.5, 30), Offset(w * 0.2, 36), Offset(-w * 0.12, 30), Offset(-w * 0.45, 38), Offset(-w * 0.76, 32),
  ]);
  final Color dark = Color.lerp(color, const Color(0xFF000000), 0.2)!;
  return Part(at: const Offset(0, 22), shapes: <Shape>[
    Shape(sheet, color: color, shade: Shade.soft),
    Shape(Paths.ellipse(Offset(-w * 0.35, 12), w * 0.3, 9), color: dark),
    Shape(Paths.ellipse(Offset(w * 0.42, 14), w * 0.22, 7), color: dark),
    // Fur along the lower edge, hanging.
    for (int i = 0; i < 9; i++)
      Shape(
        Paths.polygon(<Offset>[Offset(-w * 0.82 + i * w * 0.2, 31), Offset(-w * 0.76 + i * w * 0.2, 46 + (i % 2) * 9), Offset(-w * 0.7 + i * w * 0.2, 31)]),
        color: const Color(0xFFCDB890),
      ),
  ]);
}

/// Everyone, for lineups: name and character.
const List<(String, Character)> band = <(String, Character)>[
  ('Tor', tor),
  ('Ama', ama),
  ('Eda', eda),
  ('Kito', kito),
  ('Bran', bran),
];

/// A warm light from the left, for lineups.
const Light _fire = Light(
  from: Offset(-0.7, -0.45),
  shadow: Color(0xFF5B3A78),
  highlight: Color(0xFFFFC27A),
  cast: Color(0xFF2A1840),
);

final Composition rainCast = Composition(
  id: 'RainCast',
  width: 1920,
  height: 1080,
  fps: 30,
  durationInFrames: 30,
  builder: (BuildContext context) => typeset(const _RainCast()),
);

class _RainCast extends StatelessWidget {
  const _RainCast();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    return Stack(children: <Widget>[
      const ColoredBox(color: Color(0xFF2B2250), child: SizedBox.expand()),
      for (int i = 0; i < band.length; i++)
        () {
          final Character c = band[i].$2;
          final Pose pose = c.stance.plus(c.life(i + 3).at(frame, 30));
          final Part placed = c.part.placed(at: c.standing(260 + i * 350.0, 960), scale: 1.5);
          final Posed p = followThrough((int f) => Posed(placed, pose), frame, jiggles: c.jiggles, fps: 30);
          return Drawing(p.part, pose: p.pose, light: _fire);
        }(),
    ]);
  }
}

/// [part] stood on [ground] at [x], [scale] times its size, so its feet land
/// there whatever the scale.
Part stand(Character c, double x, double ground, double scale) {
  final Offset at = c.standing(x, ground);
  return c.part.placed(at: Offset(x, ground - (ground - at.dy) * scale), scale: scale);
}

