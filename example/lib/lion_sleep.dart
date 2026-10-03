import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_kit/reelforge_kit.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'lion_sleep_voices.dart';
import 'savanna_set.dart';
import 'stage_savanna.dart' show leo, momo;

/// Why do lions sleep twenty hours a day? A short, narrated explainer.
///
/// Everything is timed to the narration. [LionSleepVoices] are the lines as
/// Azure voiced them, a [Narration] lays them end to end, and the picture is
/// cut in the pauses between them: five shots, holding one, one, one, two
/// and two lines. A graphic lands on the word it is about -- the bar for the
/// giraffe grows as the giraffe is mentioned -- by asking when that word
/// is said, so re-voicing a line moves the picture with it.
const int _fps = 30;

final Narration _voice = Narration(<Line>[
  LionSleepVoices.intro,
  LionSleepVoices.hours,
  LionSleepVoices.compare,
  LionSleepVoices.lazy,
  LionSleepVoices.hunt,
  LionSleepVoices.save,
  LionSleepVoices.close,
]);

/// How many lines each shot holds.
const List<int> _shots = <int>[1, 1, 1, 2, 2];

final List<double> _cuts = _voice.cuts(_shots);

/// Frames each shot lasts: cut to cut, rounded as cumulative frames so that
/// none of the rounding adds up.
final List<int> _lengths = <int>[
  for (int i = 0; i < _shots.length; i++) (_cuts[i + 1] * _fps).round() - (_cuts[i] * _fps).round(),
];

final List<Scene> _scenes = <Scene>[
  Scene(frames: _lengths[0], child: const _Arrival(), transition: const SceneTransition.fade(frames: 5)),
  Scene(frames: _lengths[1], child: const _Hours(), sting: _sfx('swell'), stingFrames: 68, transition: const SceneTransition.fade(frames: 5)),
  Scene(frames: _lengths[2], child: const _Compare(), sting: _sfx('whoosh'), stingFrames: 28, transition: const SceneTransition.fade(frames: 5)),
  Scene(frames: _lengths[3], child: const _Hunting(), sting: _sfx('whoosh'), stingFrames: 28, transition: const SceneTransition.fade(frames: 5)),
  Scene(frames: _lengths[4], child: const _Rest(), sting: _sfx('whoosh'), stingFrames: 28, transition: const SceneTransition.fade(frames: 5)),
];

final Composition lionSleep = Composition(
  id: 'LionSleep',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: Storyboard.totalFrames(_scenes, fps: _fps),
  builder: (BuildContext context) => typeset(
    Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Storyboard(scenes: _scenes, bed: const Audio(src: 'assets/sound/bed.m4a', volume: 0.16)),
        ..._voice.audio(fps: _fps),
        Captions(narration: _voice),
      ],
    ),
  ),
);

// --- timing ---

/// Seconds into [shot] at which line [line] starts to be said.
double _lineAt(int shot, int line) => _voice.starts[line] - _cuts[shot] ;

/// Seconds into [shot] at which word [word] of line [line] starts to be said.
double _saidAt(int shot, int line, int word) =>
    _voice.starts[line] + Captions.wordTimes(_voice.lines[line])[word].$1 - _cuts[shot];

/// How far along something is: 0 at [from] seconds, 1 [over] seconds later.
double _along(double t, double from, double over, [Curve curve = Curves.easeOutCubic]) =>
    curve.transform(((t - from) / over).clamp(0.0, 1.0));

double _seconds(BuildContext context) => Video.frame(context) / Video.fps(context);

/// A sound effect from the start of whatever it is mounted in.
Widget _sfx(String name, {double volume = 0.5}) => Audio(src: 'assets/sound/$name.wav', volume: volume);

/// A sound effect at [at] seconds into the shot.
Widget _sfxAt(String name, double at, {double volume = 0.5, int frames = 12}) =>
    Sequence(from: (at * _fps).round(), durationInFrames: frames, child: _sfx(name, volume: volume));

// --- palette ---

const Color _gold = Color(0xFFFFC857);
const Color _orange = Color(0xFFFF8A4C);
const Color _teal = Color(0xFF5BD6C8);
const Color _violet = Color(0xFF9C8CF5);
const Color _red = Color(0xFFFF6B6B);
const Color _ink = Color(0xFFFFF6E8);

const TextStyle _label = TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: _ink);

// --- shot 1: a lion walks in ---

const double _scale = 1.45;

final Performance _walkIn = Performance(
  fps: _fps,
  startX: -560,
  beats: <Beat>[Move(520, at: 0.2, seconds: _lengths[0] / _fps - 0.9)],
);

final Gait _walkInGait = Gait(
  rig: leo.part,
  route: _walkIn.route,
  groundY: savannaGround,
  fps: _fps,
  scale: _scale,
  body: leo.quadruped,
);

/// Leo, alive: breathing, blinking, his tail swinging on follow-through.
Posed _leo(Gait gait, int frame, {Pose Function(int frame)? mood}) => followThrough(
  (int f) => gait.at(f, adjust: (Pose pose) => pose.plus(leo.stance).plus(leo.life(7).at(f, _fps)).plus(mood?.call(f) ?? Pose.rest)),
  frame,
  jiggles: leo.jiggles,
  fps: _fps,
);

/// The savanna as layers at depths, to be looked at by a [Camera].
List<Widget> _savanna(List<Widget> foreground) => <Widget>[
  ParallaxLayer(depth: 0, child: Drawing(savannaSky)),
  ParallaxLayer(depth: 0.25, child: Drawing(savannaDistance, light: savannaSun)),
  ParallaxLayer(depth: 0.6, child: Drawing(savannaPlain, light: savannaSun)),
  ParallaxLayer(depth: 1, child: Stack(fit: StackFit.expand, children: foreground)),
];

class _Arrival extends StatelessWidget {
  const _Arrival();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = _seconds(context);
    final Posed lion = _leo(_walkInGait, frame);
    final double x = _walkInGait.xAt(frame);
    // The title is there as the lion arrives, and gone before he stops.
    final double title = _along(t, 0.15, 0.5) * (1 - _along(t, 3.0, 0.5));
    return Stack(fit: StackFit.expand, children: <Widget>[
      Camera(
        keyframes: <CameraKeyframe>[
          const CameraKeyframe(0, center: Offset(940, 540)),
          CameraKeyframe(_lengths[0], center: const Offset(1010, 520), zoom: 1.1, curve: Curves.easeInOutSine),
        ],
        child: Stack(fit: StackFit.expand, children: _savanna(<Widget>[
          Drawing(savannaShadow(x + leo.length * 0.6 * _scale, leo.length * _scale)),
          Drawing(lion.part, pose: lion.pose, light: savannaSun),
        ])),
      ),
      Positioned(
        left: 110,
        top: 96,
        child: Opacity(
          opacity: title,
          child: Transform.translate(
            offset: Offset(0, (1 - title) * 24),
            child: const Text(
              'WHY DO LIONS\nSLEEP 20 HOURS\nA DAY?',
              style: TextStyle(
                fontSize: 92,
                height: 1.02,
                fontWeight: FontWeight.w900,
                color: _ink,
                letterSpacing: -1,
                shadows: <Shadow>[Shadow(color: Color(0xAA2A1B52), blurRadius: 18, offset: Offset(0, 6))],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// --- the graphic shots share a night-time backdrop ---

class _Dusk extends StatelessWidget {
  const _Dusk({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double t = _seconds(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF241548), Color(0xFF5A2B6E), Color(0xFFB4506A)],
          stops: <double>[0, 0.62, 1],
        ),
      ),
      child: Stack(fit: StackFit.expand, children: <Widget>[
        // Soft discs drifting slowly: depth without detail.
        for (int i = 0; i < 7; i++)
          Positioned(
            left: 140 + i * 270.0 + 28 * math.sin(t * 0.35 + i * 1.7),
            top: 120 + (i * 173) % 700 + 24 * math.cos(t * 0.3 + i),
            child: Container(
              width: 70.0 + (i * 37) % 120,
              height: 70.0 + (i * 37) % 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFB45E).withValues(alpha: 0.05 + 0.02 * (i % 3))),
            ),
          ),
        child,
      ]),
    );
  }
}

// --- shot 2: sixteen to twenty hours ---

class _Hours extends StatelessWidget {
  const _Hours();

  // "Between sixteen and twenty hours a day, ..."
  static final double _sixteen = _saidAt(1, 1, 1), _twenty = _saidAt(1, 1, 3);

  @override
  Widget build(BuildContext context) {
    final double t = _seconds(context);
    final double gold = _along(t, _sixteen - 0.9, 1.4, Curves.easeInOutCubic);
    final double orange = _along(t, _twenty - 0.1, 0.9, Curves.easeInOutCubic);
    final double teal = _along(t, _twenty + 0.7, 0.6, Curves.easeInOutCubic);
    return _Dusk(
      child: Stack(children: <Widget>[
        _sfxAt('tick', _twenty - 0.05, frames: 6),
        Positioned(
          left: 170,
          top: 80,
          width: 690,
          height: 690,
          child: CustomPaint(painter: _RingPainter(gold, orange, teal)),
        ),
        // The middle of the ring.
        Positioned(
          left: 170,
          top: 80,
          width: 690,
          height: 690,
          child: Center(
            child: Opacity(
              opacity: _along(t, _sixteen - 0.3, 0.5),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(
                  orange > 0.5 ? '16–20' : '16',
                  style: const TextStyle(fontSize: 170, fontWeight: FontWeight.w900, color: _ink, letterSpacing: -4, height: 1),
                ),
                const Text('hours a day', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w600, color: _ink)),
              ]),
            ),
          ),
        ),
        Positioned(
          left: 1000,
          top: 260,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _Legend(color: _gold, text: 'Resting: at least 16 hours', shown: _along(t, _sixteen - 0.3, 0.4)),
            const SizedBox(height: 44),
            _Legend(color: _orange, text: 'Resting: up to 20 hours', shown: _along(t, _twenty - 0.1, 0.4)),
            const SizedBox(height: 44),
            _Legend(color: _teal, text: 'Awake: eating, patrolling, hunting', shown: _along(t, _twenty + 0.7, 0.4)),
          ]),
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text, required this.shown});

  final Color color;
  final String text;
  final double shown;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: shown,
    child: Transform.translate(
      offset: Offset((1 - shown) * 40, 0),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12))),
        const SizedBox(width: 26),
        Text(text, style: _label),
      ]),
    ),
  );
}

/// A day as a ring: sixteen hours of gold, four of orange, four of teal,
/// each sweeping round from where the last left off.
class _RingPainter extends CustomPainter {
  const _RingPainter(this.gold, this.orange, this.teal);

  final double gold, orange, teal;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    const double stroke = 78;
    final double r = size.shortestSide / 2 - stroke / 2 - 30;
    final Rect rect = Rect.fromCircle(center: c, radius: r);
    Paint pen(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    const double top = -math.pi / 2, hour = 2 * math.pi / 24;
    canvas.drawCircle(c, r, pen(const Color(0x22FFFFFF)));
    canvas.drawArc(rect, top, hour * 16 * gold, false, pen(_gold));
    canvas.drawArc(rect, top + hour * 16, hour * 4 * orange, false, pen(_orange));
    canvas.drawArc(rect, top + hour * 20, hour * 4 * teal, false, pen(_teal));
    // Hour ticks just outside the ring.
    final Paint tick = Paint()
      ..color = const Color(0x55FFF6E8)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (int h = 0; h < 24; h++) {
      final double a = top + hour * h;
      final double len = h % 6 == 0 ? 22 : 11;
      final Offset dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r + stroke / 2 + 10), c + dir * (r + stroke / 2 + 10 + len), tick);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.gold != gold || old.orange != orange || old.teal != teal;
}

// --- shot 3: against a person and a giraffe ---

class _Compare extends StatelessWidget {
  const _Compare();

  // "A person sleeps about eight hours. A giraffe, about five. The lion ..."
  static final List<double> _at = <double>[_saidAt(2, 2, 1), _saidAt(2, 2, 7), _saidAt(2, 2, 11)];

  @override
  Widget build(BuildContext context) {
    final double t = _seconds(context);
    const List<(String, double, Color)> bars = <(String, double, Color)>[
      ('Person', 8, _teal),
      ('Giraffe', 5, _violet),
      ('Lion', 20, _gold),
    ];
    const double base = 700, tallest = 470, width = 250, gap = 130;
    return _Dusk(
      child: Stack(children: <Widget>[
        for (int i = 0; i < bars.length; i++) _sfxAt('pop', _at[i] - 0.05, frames: 9),
        const Positioned(
          left: 0,
          right: 0,
          top: 64,
          child: Center(child: Text('HOURS OF SLEEP PER DAY', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: _ink, letterSpacing: 6))),
        ),
        Positioned(
          left: 960 - (bars.length * width + (bars.length - 1) * gap) / 2,
          top: 0,
          bottom: 0,
          child: Stack(children: <Widget>[
            for (int i = 0; i < bars.length; i++) ...<Widget>[
              Builder(builder: (BuildContext context) {
                final (String name, double hours, Color color) = bars[i];
                final double grow = _along(t, _at[i], 0.7, Curves.easeOutBack);
                final double h = tallest * hours / 20 * grow;
                final double left = i * (width + gap);
                // The lion's bar, once it is up, breathes a little.
                final double glow = i == 2 ? 0.5 + 0.5 * math.sin(t * 3) : 0;
                return Positioned(
                  left: left,
                  top: base - h,
                  width: width,
                  height: h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                      boxShadow: <BoxShadow>[
                        if (i == 2 && grow >= 1) BoxShadow(color: _gold.withValues(alpha: 0.25 + 0.2 * glow), blurRadius: 60, spreadRadius: 6),
                      ],
                    ),
                  ),
                );
              }),
              Positioned(
                left: i * (width + gap),
                width: width,
                top: base - tallest * bars[i].$2 / 20 * _along(t, _at[i], 0.7, Curves.easeOutBack) - 96,
                child: Opacity(
                  opacity: _along(t, _at[i] + 0.25, 0.3),
                  child: Text(
                    '${bars[i].$2.round()} h',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 76, fontWeight: FontWeight.w900, color: bars[i].$3, height: 1),
                  ),
                ),
              ),
              Positioned(
                left: i * (width + gap),
                width: width,
                top: base + 18,
                child: Opacity(
                  opacity: _along(t, _at[i], 0.3),
                  child: Text(bars[i].$1, textAlign: TextAlign.center, style: _label.copyWith(fontSize: 46)),
                ),
              ),
            ],
          ]),
        ),
        Positioned(
          left: 960 - (bars.length * width + (bars.length - 1) * gap) / 2 - 40,
          top: base,
          width: bars.length * width + (bars.length - 1) * gap + 80,
          height: 6,
          child: const DecoratedBox(decoration: BoxDecoration(color: Color(0x66FFF6E8))),
        ),
      ]),
    );
  }
}

// --- shot 4: so is he lazy? ---

class _Hunting extends StatelessWidget {
  const _Hunting();

  // "So is the lion just lazy? Not quite. Hunting is brutal."
  static final double _hard = _saidAt(3, 3, 8);
  // "A few seconds of sprinting burns a huge amount of energy, and only about
  //  one hunt in four ends in a meal."
  static final double _energy = _saidAt(3, 4, 0),
      _sprint = _saidAt(3, 4, 4),
      _spent = _saidAt(3, 4, 10),
      _only = _saidAt(3, 4, 12),
      _four = _saidAt(3, 4, 17),
      _meal = _saidAt(3, 4, 21);

  @override
  Widget build(BuildContext context) {
    final double t = _seconds(context);
    final double lazy = _along(t, _lineAt(3, 3), 0.5) * (1 - _along(t, _hard - 0.25, 0.25));
    final double hard = _along(t, _hard - 0.1, 0.5);
    // The battery empties in a sprint: quickly, and not quite to nothing.
    final double drain = _along(t, _sprint, _spent - _sprint, Curves.easeIn);
    final double charge = 1 - 0.93 * drain;
    return _Dusk(
      child: Stack(children: <Widget>[
        _sfxAt('pop', _only - 0.05, frames: 9),
        _sfxAt('pop', _four + 0.25, frames: 9),
        _sfxAt('tick', _sprint, frames: 6),
        Positioned(
          left: 0,
          right: 0,
          top: 120,
          child: Center(
            child: SizedBox(
              height: 130,
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: <Widget>[
                Opacity(
                  opacity: lazy,
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * lazy,
                    child: const Text('Just lazy?', style: TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: _ink, height: 1)),
                  ),
                ),
                Opacity(
                  opacity: hard,
                  child: Transform.translate(
                    offset: Offset(0, (1 - hard) * 30),
                    child: const Text('Hunting is hard work', style: TextStyle(fontSize: 112, fontWeight: FontWeight.w900, color: _gold, height: 1)),
                  ),
                ),
              ]),
            ),
          ),
        ),
        // The energy a sprint costs.
        Positioned(
          left: 0,
          right: 0,
          top: 330,
          child: Opacity(
            opacity: _along(t, _energy, 0.4),
            child: Center(child: _Battery(charge: charge, urgent: drain)),
          ),
        ),
        // One hunt in four.
        Positioned(
          left: 0,
          right: 0,
          top: 560,
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
              for (int i = 0; i < 4; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 56),
                _Attempt(
                  appear: _along(t, _only + 0.12 * i, 0.4, Curves.easeOutBack),
                  mark: _along(t, i == 2 ? _meal - 0.15 : _four + 0.1 * (i == 3 ? 2 : i), 0.35, Curves.easeOutBack),
                  success: i == 2,
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// How much energy is left, as a battery.
class _Battery extends StatelessWidget {
  const _Battery({required this.charge, required this.urgent});

  final double charge;
  final double urgent;

  @override
  Widget build(BuildContext context) {
    const double w = 760, h = 110;
    final Color fill = Color.lerp(_teal, _red, urgent)!;
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      const Text('Energy', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(width: 44),
      Stack(clipBehavior: Clip.none, children: <Widget>[
        Container(
          width: w,
          height: h,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: _ink, width: 7), borderRadius: BorderRadius.circular(30)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: (w - 20 - 14) * charge.clamp(0.0, 1.0),
              decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
        Positioned(
          right: -26,
          top: h / 2 - 22,
          child: Container(width: 20, height: 44, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(8))),
        ),
      ]),
    ]);
  }
}

/// One hunt: a ring that fills with a cross, or, once, with a gold tick.
class _Attempt extends StatelessWidget {
  const _Attempt({required this.appear, required this.mark, required this.success});

  final double appear;
  final double mark;
  final bool success;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: appear.clamp(0.0, 1.0),
    child: Transform.scale(
      scale: 0.6 + 0.4 * appear + (success ? 0.12 * mark : 0),
      child: SizedBox(width: 190, height: 190, child: CustomPaint(painter: _AttemptPainter(mark, success))),
    ),
  );
}

class _AttemptPainter extends CustomPainter {
  const _AttemptPainter(this.mark, this.success);

  final double mark;
  final bool success;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2 - 8;
    final Color color = success ? _gold : _red;
    final double m = mark.clamp(0.0, 1.0);
    canvas.drawCircle(c, r, Paint()..color = Color.lerp(const Color(0x22FFFFFF), color.withValues(alpha: success ? 1 : 0.28), m)!);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = Color.lerp(const Color(0x66FFF6E8), color, m)!,
    );
    if (m <= 0) return;
    final Paint pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = success ? const Color(0xFF2A1B52) : _red;
    final Path path = Path();
    if (success) {
      path
        ..moveTo(c.dx - 40, c.dy + 2)
        ..lineTo(c.dx - 10, c.dy + 32)
        ..lineTo(c.dx + 42, c.dy - 28);
    } else {
      path
        ..moveTo(c.dx - 32, c.dy - 32)
        ..lineTo(c.dx + 32, c.dy + 32)
        ..moveTo(c.dx + 32, c.dy - 32)
        ..lineTo(c.dx - 32, c.dy + 32);
    }
    for (final m2 in path.computeMetrics()) {
      canvas.drawPath(m2.extractPath(0, m2.length * m), pen);
    }
  }

  @override
  bool shouldRepaint(_AttemptPainter old) => old.mark != mark || old.success != success;
}

// --- shot 5: so he rests ---

final Gait _restGait = Gait(
  rig: leo.part,
  route: <Waypoint>[const Waypoint(0, 520)],
  groundY: savannaGround,
  fps: _fps,
  scale: _scale,
  body: leo.quadruped,
);

const double _monkeyScale = 1.25;

final Performance _visit = Performance(
  fps: _fps,
  startX: 2120,
  beats: <Beat>[
    const Move(1380, at: 0.6, seconds: 4.2),
    const Feel(Emotion.happy, at: 4.4, amount: 0.7),
    // "Rest isn't laziness." Momo nods, as if he sees it.
    Act(Character.nod, at: _lineAt(4, 6) + 1.7, add: true),
  ],
);

final Walk _visitWalk = Walk(
  rig: momo.part,
  route: _visit.route,
  groundY: savannaGround,
  fps: _fps,
  scale: _monkeyScale,
  body: momo.biped,
);

class _Rest extends StatelessWidget {
  const _Rest();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = _seconds(context);
    // Leo's eyes close as the line begins, and stay closed: he is dozing.
    final double drowsy = _along(t, 0.3, 1.4, Curves.easeInOutSine);
    final Posed lion = _leo(
      _restGait,
      frame,
      mood: (int f) => Pose(<String, Joint>{
        for (final String eye in FaceJoints.eyes) eye: Joint(scaleY: 1 - 0.93 * drowsy),
      }).plus(const Pose(<String, Joint>{'head': Joint(degrees: 4)})),
    );
    final Posed monkey = followThrough(
      (int f) => _visitWalk.at(f, adjust: (Pose pose) => _visit.acts(f, pose.plus(momo.stance).plus(momo.life(12).at(f, _fps))).plus(_visit.face(momo.face, f))),
      frame,
      jiggles: momo.jiggles,
      fps: _fps,
    );
    final double mx = _visitWalk.xAt(frame);
    return Camera(
      keyframes: <CameraKeyframe>[
        const CameraKeyframe(0, center: Offset(1000, 530)),
        CameraKeyframe(_lengths[4], center: const Offset(1080, 500), zoom: 1.12, curve: Curves.easeInOutSine),
      ],
      child: Stack(fit: StackFit.expand, children: <Widget>[
        ..._savanna(<Widget>[
          Drawing(savannaShadow(520 + leo.length * 0.6 * _scale, leo.length * _scale)),
          Drawing(savannaShadow(mx, 52 * _monkeyScale)),
          Drawing(lion.part, pose: lion.pose, light: savannaSun),
          Drawing(monkey.part, pose: monkey.pose, light: savannaSun),
          // His sleep, rising.
          for (int i = 0; i < 3; i++) _Zzz(t: t - 0.4 - i * 0.9, at: const Offset(1050, 575), size: 62 - i * 6.0),
        ]),
      ]),
    );
  }
}

/// A "z" that floats up and to the right of a sleeper, and fades, every
/// couple of seconds.
class _Zzz extends StatelessWidget {
  const _Zzz({required this.t, required this.at, required this.size});

  final double t;
  final Offset at;
  final double size;

  @override
  Widget build(BuildContext context) {
    const double period = 2.7;
    if (t < 0) return const SizedBox.shrink();
    final double u = (t % period) / period;
    final double fade = math.sin(math.pi * u).clamp(0.0, 1.0);
    return Positioned(
      left: at.dx + 120 * u + 14 * math.sin(u * 6),
      top: at.dy - 190 * u,
      child: Opacity(
        opacity: fade,
        child: Transform.scale(
          scale: 0.7 + 0.5 * u,
          child: Text(
            'Z',
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              color: _ink,
              shadows: const <Shadow>[Shadow(color: Color(0x882A1B52), blurRadius: 8, offset: Offset(0, 3))],
            ),
          ),
        ),
      ),
    );
  }
}
