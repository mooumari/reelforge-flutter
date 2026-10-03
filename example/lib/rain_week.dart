import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_kit/reelforge_kit.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'rain_cast.dart';
import 'rain_set.dart';
import 'rain_timing.dart';
import 'rain_dig.dart';
import 'rain_shelter.dart';

/// What did ancient humans do when it rained all week? A narrated explainer,
/// in the style of a Kurzgesagt video: one continuous world, drawn in flat
/// light, and the numbers shown as things happening in it -- a river rising,
/// a stack of wood shrinking, a tally of days scratched on a stone.
///
/// Timed to the narration like [lionSleep]: the picture is cut in the pauses
/// between lines and a graphic lands on the word it is about.
const int _fps = rainFps;

Widget _with(Widget shot, List<Widget> sounds) => Stack(fit: StackFit.expand, children: <Widget>[shot, ...sounds]);

final List<Scene> _scenes = <Scene>[
  Scene(frames: rainLengths[0], child: const _Storm(), transition: const SceneTransition.fade(frames: 8)),
  Scene(
    frames: rainLengths[1],
    child: _with(const _Week(), <Widget>[sfx('thunder', 0.9, volume: 0.45, seconds: 2.2), sfx('thunder', 2.3, volume: 0.42, seconds: 0.9)]),
    transition: const SceneTransition.fade(frames: 6),
  ),
  Scene(frames: rainLengths[2], child: const _Caught(), transition: const SceneTransition.fade(frames: 6)),
  Scene(
    frames: rainLengths[3],
    child: _with(const DigShot(), <Widget>[
      sfx('pop', saidAt(3, 3, 10) - 0.1, volume: 0.5, seconds: 0.3),
      sfx('pop', saidAt(3, 3, 11) - 0.1, volume: 0.51, seconds: 0.3),
      sfx('pop', saidAt(3, 3, 12) - 0.1, volume: 0.52, seconds: 0.3),
      sfx('pop', saidAt(3, 3, 14) - 0.1, volume: 0.53, seconds: 0.3),
    ]),
    sting: Audio(src: 'assets/sound/whoosh.wav', volume: 0.4),
    stingFrames: 28,
    transition: const SceneTransition.fade(frames: 8),
  ),
  Scene(
    frames: rainLengths[4],
    child: _with(const CaveShot(), <Widget>[sfx('crackle', 1.2, volume: 0.2, seconds: 7, loop: true, ext: 'm4a')]),
    transition: const SceneTransition.fade(frames: 8),
  ),
  Scene(
    frames: rainLengths[5],
    child: _with(const HutsShot(), <Widget>[sfx('crackle', 0.0, volume: 0.21, seconds: 12.2, loop: true, ext: 'm4a')]),
    transition: const SceneTransition.fade(frames: 8),
  ),
];

/// Rain, under everything from the first drop, and a quiet bed.
class _Weather extends StatelessWidget {
  const _Weather();

  @override
  Widget build(BuildContext context) {
    final bool raining = Video.frame(context) >= ((rainCuts[0] + saidAt(0, 0, 10)) * rainFps).round();
    return Stack(children: <Widget>[
      const Audio(src: 'assets/sound/bed.m4a', volume: 0.09),
      if (raining) const Audio(src: 'assets/sound/rain.m4a', volume: 0.24, loop: true),
    ]);
  }
}

final Composition rainWeek = Composition(
  id: 'RainWeek',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: Storyboard.totalFrames(_scenes, fps: _fps),
  builder: (BuildContext context) => typeset(
    Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Storyboard(scenes: _scenes),
        const _Weather(),
        ...rainVoice.audio(fps: _fps),
      ],
    ),
  ),
);

// --- shot 1: the storm comes ---

/// The band, small, walking home across the bank with the day's gatherings.
final List<(Character, double, double, double, double)> _walkers = <(Character, double, double, double, double)>[
  // character, start x, scale, seconds, distance
  (tor, 120, 0.34, 4.0, 310),
  (ama, 20, 0.33, 4.0, 320),
  (bran, -70, 0.35, 4.3, 400),
  (eda, -30, 0.31, 3.2, 190),
  (kito, -90, 0.3, 3.4, 150),
];

final List<Walk> _walks = <Walk>[
  for (final (Character c, double x, double s, double speed, double far) in _walkers)
    Walk(
      rig: c.part,
      route: Performance(fps: _fps, startX: x, beats: <Beat>[Move(x + far, at: 0, seconds: speed, curve: Curves.linear)]).route,
      groundY: 928,
      fps: _fps,
      scale: s,
      body: c.biped,
    ),
];

class _Storm extends StatelessWidget {
  const _Storm();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = secondsOf(context);
    final double len = rainLengths[0] / _fps;
    // Golden hour, closing in: the cloud thickens on the way, and the first
    // drops fall on "rain".
    final double storm = along(t, 0.2, len - 0.6, Curves.easeIn) * 0.88;
    final double rain = along(t, saidAt(0, 0, 10), 2.6, Curves.easeIn);
    final double h = lerpD(0.70, 0.73, t / len);
    final Light light = skyLight(h, storm);
    return Stack(fit: StackFit.expand, children: <Widget>[
      Camera(
        keyframes: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(960, 560)),
          CameraKeyframe(rainLengths[0], center: const Offset(880, 690), zoom: 1.32, curve: Curves.easeInOutSine),
        ],
        child: Stack(fit: StackFit.expand, children: <Widget>[
          ...valleyLayers(
            context,
            h: h,
            storm: storm,
            rain: rain,
            foreground: Stack(fit: StackFit.expand, children: <Widget>[
              RainSplash(left: -100, right: 2020, top: 900, bottom: 1060, intensity: rain, count: 140),
              for (int i = 0; i < _walks.length; i++) _walker(i, frame, light, storm, rain),
            ]),
          ),
        ]),
      ),
      ParallaxLayer0(child: Rain(intensity: rain * 0.9, slant: 12)),
    ]);
  }

  Widget _walker(int i, int frame, Light light, double storm, double rain) {
    final Character c = _walkers[i].$1;
    final Posed p = followThrough(
      (int f) => _walks[i].at(f, adjust: (Pose pose) => pose.plus(c.stance).plus(c.life(i + 3).at(f, _fps))),
      frame,
      jiggles: c.jiggles,
      fps: _fps,
    );
    return Stack(fit: StackFit.expand, children: <Widget>[
      Drawing(groundShadow(_walks[i].xAt(frame), 70 * _walkers[i].$3, y: 932)),
      wet(Drawing(p.part, pose: p.pose, light: light), rain * 0.5),
    ]);
  }
}

/// A layer on the lens: not moved by any camera.
class ParallaxLayer0 extends StatelessWidget {
  const ParallaxLayer0({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}


// --- shot 2: a whole week ---

class _Week extends StatelessWidget {
  const _Week();

  @override
  Widget build(BuildContext context) {
    final double t = secondsOf(context);
    final double len = rainLengths[1] / _fps;
    // Seven days through the sky in the time it takes to say it.
    final double span = len - 0.5;
    final double days = 7 * along(t, 0.15, span, Curves.linear);
    final double h = 0.73 + days;
    final double storm = 0.9;
    final double rise = 70 * along(t, 0.15, span, Curves.easeInOut);
    final Light light = skyLight(h, storm);
    final List<double> strikes = <double>[0.9, 2.3];
    return Stack(fit: StackFit.expand, children: <Widget>[
      Camera(
        keyframes: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(880, 690), zoom: 1.32),
          CameraKeyframe(rainLengths[1], center: const Offset(960, 600), zoom: 1.12, curve: Curves.easeInOutSine),
        ],
        child: Stack(fit: StackFit.expand, children: <Widget>[
          ...valleyLayers(
            context,
            h: h,
            storm: storm,
            riverRise: rise,
            rain: 1,
            foreground: Stack(fit: StackFit.expand, children: <Widget>[
              const RainSplash(left: -100, right: 2020, top: 900, bottom: 1060, count: 160),
              Positioned(left: 250, top: 790, width: 460, height: 260, child: _Tally(days: days, light: light)),
            ]),
          ),
        ]),
      ),
      const Rain(slant: 14),
      Lightning(flashes: strikes),
    ]);
  }
}

/// A boulder with the days scratched on it: a stroke for each, the fifth
/// across the four before it.
class _Tally extends StatelessWidget {
  const _Tally({required this.days, required this.light});

  final double days;
  final Light light;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _TallyPainter(days));
}

class _TallyPainter extends CustomPainter {
  const _TallyPainter(this.days);

  final double days;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    final Path rock = Paths.smooth(<Offset>[
      Offset(0, h), Offset(w * 0.02, h * 0.55), Offset(w * 0.12, h * 0.2), Offset(w * 0.4, h * 0.02), Offset(w * 0.72, h * 0.06),
      Offset(w * 0.95, h * 0.38), Offset(w, h * 0.8), Offset(w * 0.97, h),
    ]);
    canvas.drawPath(
      rock,
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFF8A96A8), Color(0xFF4A5468)]).createShader(Offset.zero & size),
    );
    // A shadowed face down the right, and a pale top where the sky lights it.
    canvas.save();
    canvas.clipPath(rock);
    canvas.drawPath(Paths.polygon(<Offset>[Offset(w * 0.7, 0), Offset(w * 1.1, h * 0.3), Offset(w * 1.1, h), Offset(w * 0.62, h), Offset(w * 0.74, h * 0.5)]), Paint()..color = const Color(0x55141C34));
    canvas.drawPath(Paths.polygon(<Offset>[Offset(w * 0.1, h * 0.3), Offset(w * 0.4, 0), Offset(w * 0.75, 0), Offset(w * 0.5, h * 0.2)]), Paint()..color = const Color(0x33DCE8FF));
    canvas.restore();
    canvas.drawPath(rock, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0x44D8E4F4));
    final Paint scratch = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..color = const Color(0xFFF2EAD2);
    for (int i = 0; i < 7; i++) {
      final double u = (days - i).clamp(0.0, 1.0);
      // A mark is cut in the last fifth of its day.
      final double cut = ((u - 0.8) / 0.2).clamp(0.0, 1.0);
      if (cut <= 0) continue;
      final int group = i ~/ 5, k = i % 5;
      final double x0 = size.width * 0.14 + group * size.width * 0.5;
      if (k < 4) {
        final double x = x0 + k * 40;
        canvas.drawLine(Offset(x, size.height * 0.34), Offset(x + 4, size.height * 0.34 + size.height * 0.4 * cut), scratch);
      } else {
        canvas.drawLine(Offset(x0 - 10, size.height * 0.72), Offset(x0 - 10 + 180 * cut, size.height * 0.4), scratch);
      }
    }
  }

  @override
  bool shouldRepaint(_TallyPainter old) => old.days != days;
}

// --- shot 3: caught in the open ---

/// Twenty people: the five, and fifteen more.
List<Character> _crowd() {
  const List<Color> skins = <Color>[Color(0xFF7A4B32), Color(0xFF8A5A3C), Color(0xFF6A3F2A), Color(0xFF946348), Color(0xFF5E3A28)];
  const List<Color> hides = <Color>[Color(0xFF8A5A36), Color(0xFFA06A3E), Color(0xFF7C5B3E), Color(0xFF9A6840), Color(0xFF7E5636)];
  const List<Body> bodies = <Body>[Body.stocky, Body.slim, Body(), Body.child, Body.elder];
  const List<Color> hair = <Color>[Color(0xFF1E1410), Color(0xFF2A1C14), Color(0xFF3A2A20), Color(0xFFB9B2AA)];
  return <Character>[
    for (int i = 0; i < 15; i++)
      Character(
        body: bodies[i % bodies.length],
        skin: skins[(i * 3) % skins.length],
        face: ama.face,
        outfit: <Garment>[
          if (i % 3 == 0) Bun(hair[i % hair.length]) else if (i % 3 == 1) LongHair(hair[i % hair.length], length: 1.4) else ShortHair(hair[i % hair.length]),
          HideTunic(hides[(i * 2) % hides.length], length: 0.34 + (i % 3) * 0.04),
          if (i % 2 == 0) FurMantle(const Color(0xFFB9A58A), drop: 0.34),
          const Cord(Color(0xFFD9C7A0)),
          Boots(hides[(i + 1) % hides.length], height: 0.3),
        ],
      ),
  ];
}

final List<Character> _extras = _crowd();

class _Caught extends StatelessWidget {
  const _Caught();

  // Where the five stand, and how big; the rest are behind them.
  static const double _ground = 940;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = secondsOf(context);
    final double h = 0.8, storm = 0.9;
    final Light light = skyLight(h, storm);
    // "Just twenty people": the camera draws back and the rest are there.
    final double twenty = saidAt(2, 2, 12), pull = along(t, twenty - 0.5, 1.6, Curves.easeInOutCubic);
    final double look = along(t, saidAt(2, 2, 18) - 0.2, 1.2);
    final double title = along(t, saidTo(2, 2, 20) + 0.15, 0.7, Curves.easeOutCubic);
    return Stack(fit: StackFit.expand, children: <Widget>[
      Camera(
        keyframes: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(780, 700), zoom: 1.55),
          CameraKeyframe((twenty * _fps).round() - 15, center: const Offset(1000, 690), zoom: 1.5, curve: Curves.easeInOutSine),
          CameraKeyframe((twenty * _fps).round() + 40, center: const Offset(960, 560), zoom: 1.0),
          CameraKeyframe(rainLengths[2] - 50, center: const Offset(960, 560), zoom: 1.0, curve: Curves.linear),
          CameraKeyframe(rainLengths[2], center: const Offset(930, 660), zoom: 1.25, curve: Curves.easeInOutCubic),
        ],
        child: Stack(fit: StackFit.expand, children: <Widget>[
          ...valleyLayers(
            context,
            h: h,
            storm: storm,
            riverRise: 20,
            rain: 1,
            foreground: Stack(fit: StackFit.expand, children: <Widget>[
              const RainSplash(left: -100, right: 2020, top: 900, bottom: 1060, count: 160),
              ..._people(frame, t, light, pull, look),
            ]),
          ),
        ]),
      ),
      const Rain(slant: 14),
      Opacity(
        opacity: title,
        child: ColoredBox(color: const Color(0x88101830), child: Center(child: _Title(progress: title))),
      ),
    ]);
  }

  List<Widget> _people(int frame, double t, Light light, double pull, double look) {
    final List<Widget> out = <Widget>[];
    // The fifteen behind, huddled in a loose crowd, small.
    for (int i = 0; i < _extras.length; i++) {
      final Character c = _extras[i];
      final double row = (i % 3) / 2.0;
      final double x = 330 + (i * 211 % 1300) + row * 40, ground = 886 + row * 40;
      final double s = 0.62 + row * 0.12;
      final Pose pose = _hunch(c, i + 10, frame, 0.6);
      final Posed p = followThrough((int f) => Posed(stand(c, x, ground, s), pose), frame, jiggles: c.jiggles, fps: _fps);
      out.add(Drawing(groundShadow(x, 80 * s, y: ground + 3)));
      out.add(wet(Drawing(p.part, pose: p.pose, light: light), 1));
    }
    // The five at the front, the hunter looking up on the last line.
    const List<(Character, double, double, double)> front = <(Character, double, double, double)>[
      (eda, 470, 1.18, 0.0),
      (kito, 640, 1.05, 0.0),
      (ama, 840, 1.28, 1.0),
      (tor, 1090, 1.34, 1.0),
      (bran, 1330, 1.3, 1.0),
    ];
    for (int i = 0; i < front.length; i++) {
      final (Character c, double x, double s, double hideUp) = front[i];
      final bool hero = c == tor;
      final Part rig = c.build(hold: hideUp > 0 ? <String, List<Part>>{'handF': <Part>[hideSheet(color: Color.lerp(const Color(0xFF8A5E3A), const Color(0xFF5E4026), (i % 2) * 0.5)!)]} : const <String, List<Part>>{});
      final Offset at = c.standing(x, _ground);
      final Part placed = rig.placed(at: Offset(x, _ground - (_ground - at.dy) * s), scale: s);
      Pose pose = _hunch(c, i + 2, frame, 1).plus(hideUp > 0 ? _hideOverhead : Pose.rest);
      if (hero) {
        // He lowers the hide and tips his face to the rain: one last look
        // up at the sky.
        pose = _hunch(c, i + 2, frame, 1 - look * 0.8).plus(Pose.lerp(Pose.rest, _hideOverhead, 1 - look)).plus(Pose(<String, Joint>{'head': Joint.rotate(-20 * look)}));
      }
      final FaceStyle face = c.face;
      final Performance act = Performance(fps: _fps, startX: x, beats: <Beat>[
        const Feel(Emotion.worried, at: 0.2, amount: 0.7),
        Feel(Emotion.neutral, at: saidAt(2, 2, 18), amount: 0.5, ease: 0.8),
        Look(Offset(0.2 + i * 0.1, -0.2), at: 0.8 + i * 0.35),
        Look(const Offset(0.4, -0.95), at: saidAt(2, 2, 18) - 0.1),
      ]);
      final Posed p = followThrough((int f) => Posed(placed, pose.plus(act.face(face, f))), frame, jiggles: c.jiggles, fps: _fps);
      out.add(Drawing(groundShadow(x, 90 * s, y: _ground + 3)));
      out.add(wet(Drawing(p.part, pose: p.pose, light: light), 1));
    }
    return out;
  }

  /// A figure hunched against the rain: forward at the chest, the head
  /// down, a shiver.
  static Pose _hunch(Character c, int seed, int frame, double amount) {
    final double shiver = math.sin(frame * 1.9 + seed * 2.7) * 0.7 + math.sin(frame * 0.8 + seed) * 0.4;
    return c.stance
        .plus(c.life(seed).at(frame, _fps))
        .plus(Pose(<String, Joint>{
          'chest': Joint.rotate(9 * amount + shiver * amount),
          'head': Joint.rotate(6 * amount - shiver * 0.5 * amount),
        }));
  }

  /// The near arm straight up, holding a hide over the head.
  static const Pose _hideOverhead = Pose(<String, Joint>{
    'shoulderF': Joint.rotate(168),
    'elbowF': Joint.rotate(-16),
    'handF': Joint.rotate(-6),
  });
}

class _Title extends StatelessWidget {
  const _Title({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    const TextStyle big = TextStyle(
      fontSize: 126,
      height: 1.0,
      fontWeight: FontWeight.w900,
      color: Color(0xFFFFF6E8),
      letterSpacing: -1,
      shadows: <Shadow>[Shadow(color: Color(0xCC0A1020), blurRadius: 26, offset: Offset(0, 8))],
    );
    const List<String> words = <String>['WHAT DID', 'ANCIENT HUMANS', 'DO WHEN IT RAINED', 'ALL WEEK?'];
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      for (int i = 0; i < words.length; i++)
        Opacity(
          opacity: ((progress * 4 - i * 0.6) / 1.2).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - ((progress * 4 - i * 0.6) / 1.2).clamp(0.0, 1.0)) * 34),
            child: Text(
              words[i],
              style: i == 3 ? big.copyWith(color: const Color(0xFFFFC857), fontSize: 150) : big,
            ),
          ),
        ),
    ]);
  }
}
