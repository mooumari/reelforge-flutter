import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'stick.dart';

/// The stick figures, standing and walking, on plain ground: for looking at.
const List<StickFigure> stickCast = <StickFigure>[
  StickFigure(hair: StickHair.shaggy, hairColor: Color(0xFF6A4528), fur: Color(0xFF8A6A48), quiver: true),
  StickFigure(hair: StickHair.messy, hairColor: Color(0xFF7A4A2A), fur: Color(0xFF7A6040), quiver: true),
  StickFigure(),
  StickFigure(hair: StickHair.shaggy, hairColor: Color(0xFF3A2A20), fur: Color(0xFF9A7A56)),
];

final Composition stickLab = Composition(
  id: 'StickLab',
  width: 1920,
  height: 1080,
  fps: 30,
  durationInFrames: 120,
  builder: (BuildContext context) => typeset(const _StickLab()),
);

class _StickLab extends StatelessWidget {
  const _StickLab();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < stickCast.length; i++) {
      final StickFigure c = stickCast[i];
      final Pose pose = c.stance.plus(c.life(i + 2).at(frame, 30));
      final Part placed = c.part.placed(at: c.standing(260 + i * 400.0, 900), scale: 1.2);
      out.add(Drawing(placed, pose: pose, ink: const Ink(width: 6)));
    }
    return Stack(children: <Widget>[
      const ColoredBox(color: Color(0xFFD9DCCB), child: SizedBox.expand()),
      ...out,
    ]);
  }
}
