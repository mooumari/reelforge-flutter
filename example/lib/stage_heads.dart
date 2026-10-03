import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'stage_style.dart' show wyatt;

/// Every [HeadShape] on the same character, with his hat and without, lit
/// the same way: a sheet to choose from.
const int _fps = 30;

final Composition stageHeads = Composition(
  id: 'StageHeads',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: 120,
  builder: (BuildContext context) => typeset(const _StageHeads()),
);

const Light _light = Light(
  from: Offset(0.62, -0.78),
  shadow: Color(0xFF8A6AC0),
  highlight: Color(0xFFFFD9A8),
  cast: Color(0xFF2A1640),
);

const List<(String, HeadShape)> _shapes = <(String, HeadShape)>[
  ('oval', HeadShape.oval),
  ('square', HeadShape.square),
  ('heart', HeadShape.heart),
  ('long', HeadShape.long),
  ('round', HeadShape.round),
];

Character _with(HeadShape shape, {required bool hat}) => Character(
      body: Body(head: shape),
      skin: wyatt.skin,
      face: wyatt.face,
      outfit: <Garment>[
        for (final Garment g in wyatt.outfit)
          if (hat || g is! CowboyHat) g,
      ],
    );

final List<List<Character>> _rows = <List<Character>>[
  for (final bool hat in <bool>[true, false]) <Character>[for (final (String, HeadShape) s in _shapes) _with(s.$2, hat: hat)],
];

const double _cellW = 384, _cellH = 500, _zoom = 1.55;

class _StageHeads extends StatelessWidget {
  const _StageHeads();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    return Stack(children: <Widget>[
      const ColoredBox(color: Color(0xFF5A3470), child: SizedBox.expand()),
      for (int row = 0; row < 2; row++)
        for (int i = 0; i < _shapes.length; i++)
          Positioned(
            left: i * _cellW,
            top: 40 + row * (_cellH + 20),
            width: _cellW,
            height: _cellH,
            child: ClipRect(
              child: Stack(children: <Widget>[
                ColoredBox(color: Color.lerp(const Color(0xFF7A3E7E), const Color(0xFFE0745A), 0.25 + 0.1 * row)!, child: const SizedBox.expand()),
                Drawing(
                  _rows[row][i].part.placed(
                    at: Offset(_cellW / 2 - 20, _cellH * 0.47) - _rows[row][i].body.headAt * _zoom - _rows[row][i].body.headCenter * _zoom,
                    scale: _zoom,
                  ),
                  pose: _rows[row][i]
                      .life(3 + i)
                      .at(frame, _fps)
                      .plus(_rows[row][i].face.express(Emotion.happy, amount: 0.6))
                      .plus(_rows[row][i].face.look(const Offset(0.5, 0.1))),
                  light: _light,
                ),
                if (row == 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Text(_shapes[i].$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF))),
                  ),
              ]),
            ),
          ),
    ]);
  }
}
