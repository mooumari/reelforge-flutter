import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'compositions.dart' show typeset;
import 'stage_people.dart';

/// Faces: one person talking, feeling and looking about; six more showing
/// every emotion on the same rig.
///
/// The speech is guessed from the script's spelling -- [Speech.fromText] --
/// which is the stand-in until Azure's visemes arrive with the audio. Every
/// mouth shape, feeling, blink and glance is a pose on [FaceJoints].
const int _fps = 30;
const int _frames = 540;

final Composition stageFaces = Composition(
  id: 'StageFaces',
  width: 1920,
  height: 1080,
  fps: _fps,
  durationInFrames: _frames,
  builder: (BuildContext context) => typeset(const _StageFaces()),
);

// --- the presenter ---

const List<String> _lines = <String>[
  "Hi! I'm Ana, and now I can talk.",
  'Every word shapes my mouth, and every feeling moves my eyes.',
  'I can be happy, sad, angry, or surprised!',
];

/// The lines one after another, each with its own words, half a second
/// apart.
final List<Speech> _said = () {
  final List<Speech> out = <Speech>[];
  double start = 0.5;
  for (final String line in _lines) {
    final Speech s = Speech.fromText(line, start: start);
    out.add(s);
    start = s.end + 0.5;
  }
  return out;
}();

final Speech _speech = Speech(
  <VisemeCue>[for (final Speech s in _said) ...s.visemes],
  words: <WordCue>[for (final Speech s in _said) ...s.words],
);

final (String, Part, FaceStyle) _ana = cast.first;
final Part _presenter = _ana.$2.placed(at: const Offset(430, 770), scale: 1.7);
final FaceStyle _face = _ana.$3;
final Life _life = personLife(11);

int _frameOf(double seconds) => (seconds * _fps).round();

/// Feelings on cue words.
final Take _mood = () {
  const Map<String, Emotion> cueWords = <String, Emotion>{
    'Hi': Emotion.happy,
    'Every': Emotion.neutral,
    'feeling': Emotion.happy,
    'happy': Emotion.happy,
    'sad': Emotion.sad,
    'angry': Emotion.angry,
    'surprised': Emotion.surprised,
  };
  final List<(int, Emotion)> cues = <(int, Emotion)>[(0, Emotion.neutral)];
  for (final WordCue w in _speech.words) {
    final Emotion? e = cueWords[w.text];
    if (e != null) cues.add((_frameOf(w.start) - 3, e));
  }
  cues.add((_frameOf(_speech.end) + 20, Emotion.happy));
  return _face.moods(cues, transition: 6);
}();

final double _speechEnd = _speech.end;
final int _flyFrom = _frameOf(_speechEnd) + 10;

/// A firefly that turns up when Ana stops talking.
Offset _fly(int frame) {
  final double t = (frame - _flyFrom) / _fps;
  return Offset(430 + 330 * math.sin(1.25 * t + 0.4), 330 + 140 * math.sin(2.05 * t));
}

const Offset _eyes = Offset(430, 539);

/// Eyes on the viewer, a glance at the others on "eyes", then the firefly.
final Gaze _gaze = () {
  final WordCue eyes = _speech.words.firstWhere((WordCue w) => w.text == 'eyes');
  return Gaze(<(int, Offset)>[
    (0, Offset.zero),
    (_frameOf(eyes.start), const Offset(0.9, -0.2)),
    (_frameOf(eyes.end) + 12, Offset.zero),
  ]);
}();

Offset _lookAt(int frame) {
  final Offset toFly = _fly(frame) - _eyes;
  return Offset(toFly.dx / 360, toFly.dy / 260);
}

Pose _presenterPose(int frame) {
  final Pose mood = _mood.at(frame);
  final double flyIn = ((frame - _flyFrom) / 12).clamp(0.0, 1.0);
  // Eyes jump to the firefly; the head turns after them, a few frames late.
  final Offset eyes = Offset.lerp(_gaze.at(frame), _lookAt(frame), flyIn)!;
  final Offset head = Offset.lerp(_gaze.follow(frame), _lookAt(math.max(frame - 6, 0)), flyIn)!;
  return mood
      .plus(_life.at(frame, _fps))
      .plus(_speech.at(frame, _fps))
      .plus(_face.look(eyes))
      .plus(personTurn(_face, head.dx * 0.75));
}

// --- the cast ---

const int _cycleFrom = 30;
const int _each = 45;

Emotion _castEmotion(int frame) =>
    Emotion.values[((frame - _cycleFrom) ~/ _each).clamp(0, Emotion.values.length - 1)];

Pose _castPose(FaceStyle face, int i, int frame) {
  final int k = ((frame - _cycleFrom) ~/ _each).clamp(0, Emotion.values.length - 1);
  final int into = frame - _cycleFrom - k * _each;
  final Emotion now = Emotion.values[k];
  final Emotion before = Emotion.values[math.max(k - 1, 0)];
  final double t = Curves.easeInOutCubic.transform((into / 8).clamp(0.0, 1.0));
  return Pose.lerp(face.express(before), face.express(now), t).plus(personLife(20 + i).at(frame, _fps));
}

Offset _cellAt(int i) => Offset(1060 + (i % 3) * 330.0, 430 + (i ~/ 3) * 470.0);

class _StageFaces extends StatelessWidget {
  const _StageFaces();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double seconds = frame / _fps;
    return Stack(
      children: <Widget>[
        const ColoredBox(color: Color(0xFF1D2B53), child: SizedBox.expand()),
        Drawing(Part(shapes: <Shape>[
          Shape(Paths.circle(const Offset(430, 520), 330), color: const Color(0xFF26386A)),
          Shape(Paths.rect(const Rect.fromLTRB(870, 0, 1920, 1080)), color: const Color(0xFF16213F)),
        ])),
        Drawing(_presenter, pose: _presenterPose(frame)),
        if (frame >= _flyFrom) ...<Widget>[
          Drawing(Part(shapes: <Shape>[
            Shape(Paths.circle(_fly(frame), 22), color: const Color(0x33FFE066)),
            Shape(Paths.circle(_fly(frame), 8), color: const Color(0xFFFFE066)),
          ])),
        ],
        Positioned(left: 40, right: 1090, bottom: 40, child: _Caption(seconds)),
        for (int i = 0; i < cast.length; i++) ...<Widget>[
          Drawing(
            cast[i].$2.placed(at: _cellAt(i), scale: 0.85),
            pose: _castPose(cast[i].$3, i, frame),
          ),
          Positioned(
            left: _cellAt(i).dx - 150,
            top: _cellAt(i).dy + 40,
            width: 300,
            child: Text(cast[i].$1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))),
          ),
        ],
        Positioned(
          left: 870,
          right: 0,
          top: 24,
          child: Text(
            frame < _cycleFrom ? 'one face rig, six faces' : _castEmotion(frame).name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: Color(0xFFFFD166)),
          ),
        ),
      ],
    );
  }
}

/// The line being said, with the words already spoken lit.
class _Caption extends StatelessWidget {
  const _Caption(this.seconds);

  final double seconds;

  @override
  Widget build(BuildContext context) {
    final Speech? line = _said.where((Speech s) => s.words.first.start - 0.3 <= seconds).lastOrNull;
    if (line == null || seconds > line.end + 0.8) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(children: <InlineSpan>[
        for (final WordCue w in line.words)
          TextSpan(
            text: '${w.text} ',
            style: TextStyle(color: w.start <= seconds ? const Color(0xFFFFFFFF) : const Color(0x55FFFFFF)),
          ),
      ]),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w600),
    );
  }
}
