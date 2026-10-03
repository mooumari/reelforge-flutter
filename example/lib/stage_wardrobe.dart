import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'stage_style.dart' show wyatt;

/// Every hairstyle, and every hat, scarf, helmet and face piece, on the same
/// head under the same light: a sheet to choose from.
const int _fps = 30;

final Composition stageWardrobe = Composition(
  id: 'StageWardrobe',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: 90,
  builder: (BuildContext context) => typeset(const _StageWardrobe()),
);

const Light _light = Light(
  from: Offset(0.62, -0.78),
  shadow: Color(0xFF8A6AC0),
  highlight: Color(0xFFFFD9A8),
  cast: Color(0xFF2A1640),
);

const Color _brown = Color(0xFF5A3A22);
const Color _black = Color(0xFF2B2220);
const Color _blond = Color(0xFFD9A85A);
const Color _grey = Color(0xFFB9B4AE);

const List<(String, HeadShape, List<Garment>)> _looks = <(String, HeadShape, List<Garment>)>[
  ('short', HeadShape.square, <Garment>[ShortHair(_brown)]),
  ('buzz', HeadShape.square, <Garment>[Buzz(_black)]),
  ('quiff', HeadShape.oval, <Garment>[Quiff(_blond)]),
  ('curls', HeadShape.round, <Garment>[Curls(_black)]),
  ('long', HeadShape.heart, <Garment>[LongHair(_brown)]),
  ('fringe', HeadShape.heart, <Garment>[LongHair(_black, fringe: true, length: 1.4)]),
  ('bun', HeadShape.heart, <Garment>[Bun(_brown)]),
  ('ponytail', HeadShape.oval, <Garment>[Ponytail(_blond)]),
  ('balding', HeadShape.long, <Garment>[Balding(_grey), Beard(_grey)]),
  ('cap', HeadShape.round, <Garment>[ShortHair(_brown), Cap(Color(0xFF2E7DD1))]),
  ('ghutra', HeadShape.long, <Garment>[Beard(Color(0xFF4A3426), length: 0.15, trimmed: true), Headcloth(Color(0xFFF4F1EA), check: Color(0xFFC0272D))]),
  ('hijab', HeadShape.heart, <Garment>[Hijab(Color(0xFF3E6E8E))]),
  ('legion', HeadShape.square, <Garment>[LegionHelmet()]),
  ('nemes', HeadShape.long, <Garment>[Nemes()]),
  ('laurel', HeadShape.long, <Garment>[Curls(_grey, size: 0.8), LaurelWreath(), Beard(_grey, length: 0.8)]),
  ('glasses', HeadShape.oval, <Garment>[Bun(_black), Glasses()]),
  ('cowboy', HeadShape.square, <Garment>[ShortHair(_brown), Moustache(_brown), CowboyHat(Color(0xFFB07A45))]),
  ('cyborg', HeadShape.square, <Garment>[Buzz(_black), HeadPlate(), EyeImplant()]),
];

final List<Character> _cast = <Character>[
  for (final (String, HeadShape, List<Garment>) look in _looks)
    Character(
      body: Body(head: look.$2),
      skin: wyatt.skin,
      face: wyatt.face,
      outfit: <Garment>[const Shirt(Color(0xFF6E8FA8), collar: false), ...look.$3],
    ),
];

const int _perRow = 9;
const double _cellW = 1920 / _perRow, _cellH = 520, _zoom = 1.05;

class _StageWardrobe extends StatelessWidget {
  const _StageWardrobe();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    return Stack(children: <Widget>[
      const ColoredBox(color: Color(0xFF5A3470), child: SizedBox.expand()),
      for (int i = 0; i < _cast.length; i++)
        Positioned(
          left: (i % _perRow) * _cellW,
          top: 14 + (i ~/ _perRow) * (_cellH + 12),
          width: _cellW - 4,
          height: _cellH,
          child: ClipRect(
            child: Stack(children: <Widget>[
              ColoredBox(color: Color.lerp(const Color(0xFF7A3E7E), const Color(0xFFE0745A), 0.3)!, child: const SizedBox.expand()),
              Drawing(
                _cast[i].part.placed(
                  at: Offset(_cellW / 2 - 12, _cellH * 0.42) - _cast[i].body.headAt * _zoom - _cast[i].body.headCenter * _zoom,
                  scale: _zoom,
                ),
                pose: _cast[i]
                    .life(3 + i)
                    .at(frame, _fps)
                    .plus(_cast[i].face.express(Emotion.happy, amount: 0.5))
                    .plus(_cast[i].face.look(const Offset(0.5, 0.1))),
                light: _light,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Text(_looks[i].$1,
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF))),
              ),
            ]),
          ),
        ),
    ]);
  }
}
