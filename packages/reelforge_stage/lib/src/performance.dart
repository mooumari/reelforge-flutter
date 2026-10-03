import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';

import 'face.dart';
import 'pose.dart';
import 'walk.dart';

/// A voiced line: what is said, the audio of it being said, and the timings
/// the voice reported as it said it.
///
/// Lines are not written by hand: `tool/voice.py` voices a scene's script
/// with Azure and writes each line as one of these, its [visemes] and
/// [words] in Azure's own units -- ticks of 100ns from the start of the
/// audio.
@immutable
class Line {
  const Line({
    required this.text,
    required this.audio,
    required this.seconds,
    this.visemes = const <(int, int)>[],
    this.words = const <(int, int, String)>[],
  });

  final String text;

  /// The audio file, relative to the project: an `Audio` widget's `src`.
  final String audio;

  /// How long the audio is, trailing silence and all.
  final double seconds;

  /// `(ticks, Azure viseme id)`, in order.
  final List<(int, int)> visemes;

  /// `(ticks, duration in ticks, word)`, in order.
  final List<(int, int, String)> words;

  /// When the voice stops, which is before the audio does: the end of the
  /// last word, or the last mouth shape.
  double get spoken {
    double end = 0;
    if (words.isNotEmpty) end = (words.last.$1 + words.last.$2) / 1e7;
    if (visemes.isNotEmpty) end = math.max(end, visemes.last.$1 / 1e7);
    return words.isEmpty && visemes.isEmpty ? seconds : end;
  }

  /// The mouth for this line, said from [start] seconds.
  Speech speech({double start = 0}) => Speech.azure(
    visemes: <Map<String, Object?>>[
      for (final (int, int) v in visemes) <String, Object?>{'audioOffset': v.$1, 'visemeId': v.$2},
    ],
    words: <Map<String, Object?>>[
      for (final (int, int, String) w in words) <String, Object?>{'audioOffset': w.$1, 'duration': w.$2, 'text': w.$3},
    ],
    start: start,
  );
}

/// One thing a performer does, from [at] seconds into the scene.
///
/// Beats are plain values with a start and an [end], so a scene is laid out
/// with arithmetic: `Say(momoHi, at: leoHello.end + 0.4)` answers when Leo
/// has finished, however long his line turned out to be.
@immutable
sealed class Beat {
  const Beat({required this.at});

  /// When it starts, in seconds.
  final double at;

  /// When it is done, in seconds.
  double get end;
}

/// How a walk covers ground: speeding up over the first [ease] of it,
/// steady through the middle, slowing over the last [ease] -- rather than
/// an ease-in-out's rush through the middle, which a walk does not do.
class Stroll extends Curve {
  const Stroll([this.ease = 0.15]) : assert(ease > 0 && ease <= 0.5);

  final double ease;

  @override
  double transformInternal(double t) {
    final double top = 1 / (1 - ease);
    if (t < ease) return top * t * t / (2 * ease);
    if (t > 1 - ease) return 1 - top * (1 - t) * (1 - t) / (2 * ease);
    return top * (t - ease / 2);
  }
}

/// Walk to [x] over [seconds], setting off and arriving gently.
class Move extends Beat {
  const Move(this.x, {required super.at, required this.seconds, this.curve = const Stroll()});

  final double x;
  final double seconds;
  final Curve curve;

  @override
  double get end => at + seconds;
}

/// Say [line].
class Say extends Beat {
  const Say(this.line, {required super.at});

  final Line line;

  @override
  double get end => at + line.spoken;
}

/// Feel [emotion], at [amount], reached over [ease] seconds and held until
/// the next [Feel]. `Feel(Emotion.neutral, ...)` lets the last one go.
class Feel extends Beat {
  const Feel(this.emotion, {required super.at, this.amount = 1, this.ease = 0.4});

  final Emotion emotion;
  final double amount;
  final double ease;

  @override
  double get end => at + ease;
}

/// Look towards [direction] -- (-1..1, -1..1), as [FaceStyle.look] -- the
/// eyes darting there as eyes do.
class Look extends Beat {
  const Look(this.direction, {required super.at});

  final Offset direction;

  @override
  double get end => at;
}

/// A gesture: [gesture] is asked for its pose each frame from its start,
/// given the pose it is played over, until it returns null. [Character.wave]
/// and [Character.nod] are gestures. It is [overlay]ed -- deciding its joints
/// outright, as a wave takes an arm -- unless [add] is set, when it is added
/// on top, as a nod is.
class Act extends Beat {
  const Act(this.gesture, {required super.at, this.add = false, this.seconds = 2});

  final Pose? Function(int frame, int fps, {Pose from}) gesture;
  final bool add;

  /// About how long it takes, for laying out what comes after it.
  final double seconds;

  @override
  double get end => at + seconds;
}

/// A performer's part in a scene: where they walk, what they say, how they
/// feel, where they look and what they do, as a list of [Beat]s.
///
/// It answers the questions a composition asks each frame -- the [route] to
/// walk, the [face] to wear, the [acts] on the body, the line being said --
/// and is a pure function of the frame, as everything here is.
///
/// ```dart
/// const Say hello = Say(Voices.leoHello, at: 5.6);
/// final Performance leo = Performance(fps: 30, startX: -560, beats: <Beat>[
///   const Move(560, at: 0, seconds: 5.3),
///   hello,
///   Feel(Emotion.happy, at: hello.end - 0.4, amount: 0.6),
///   const Look(Offset(0.6, 0.15), at: 5.2),
/// ]);
/// ```
@immutable
class Performance {
  Performance({required this.fps, required this.startX, required List<Beat> beats})
    : beats = List<Beat>.unmodifiable(List<Beat>.of(beats)..sort((Beat a, Beat b) => a.at.compareTo(b.at)));

  final int fps;

  /// Where the performer stands before the first [Move].
  final double startX;

  /// In order of when they start.
  final List<Beat> beats;

  Iterable<T> _of<T extends Beat>() => beats.whereType<T>();

  /// When the last beat is done, in seconds.
  double get end => beats.fold(0, (double e, Beat b) => math.max(e, b.end));

  /// The lines, in order.
  List<Say> get lines => _of<Say>().toList();

  /// The [Move]s as a route, for a [Walk] or a [Gait]: standing at
  /// [startX], then each move from where the last one left off.
  List<Waypoint> get route {
    final List<Waypoint> out = <Waypoint>[Waypoint(0, startX)];
    double x = startX;
    for (final Move m in _of<Move>()) {
      final int from = (m.at * fps).round(), to = ((m.at + m.seconds) * fps).round();
      if (from > out.last.frame) out.add(Waypoint(from, x));
      out.add(Waypoint(to, m.x, curve: m.curve));
      x = m.x;
    }
    return out;
  }

  /// Everything said, as one [Speech].
  late final Speech speech = () {
    final List<Speech> all = <Speech>[for (final Say s in _of<Say>()) s.line.speech(start: s.at)];
    return Speech(
      <VisemeCue>[for (final Speech s in all) ...s.visemes],
      words: <WordCue>[for (final Speech s in all) ...s.words],
    );
  }();

  late final Gaze _gaze = Gaze(<(int, Offset)>[
    (0, Offset.zero),
    for (final Look l in _of<Look>()) ((l.at * fps).round(), l.direction),
  ]);

  /// The line being said at [frame], or for [linger] seconds after it --
  /// as long as a speech bubble should stay up.
  Say? sayingAt(int frame, {double linger = 0.8}) {
    final double t = frame / fps;
    Say? out;
    for (final Say s in _of<Say>()) {
      if (s.at - 0.1 <= t && t <= s.end + linger) out = s;
    }
    return out;
  }

  /// The face at [frame], for [face]: the mouth saying the lines, each
  /// feeling eased in as the one before it eases out, and the eyes looking.
  Pose face(FaceStyle face, int frame, {String mouth = FaceJoints.mouth}) {
    final double t = frame / fps;
    Pose out = speech.at(frame, fps, mouth: mouth);
    final List<Feel> feels = _of<Feel>().toList();
    for (int i = 0; i < feels.length; i++) {
      final Feel f = feels[i];
      double ramp(Feel g) => Curves.easeInOutSine.transform(((t - g.at) / math.max(g.ease, 1e-6)).clamp(0.0, 1.0));
      final double weight = ramp(f) * (i + 1 < feels.length ? 1 - ramp(feels[i + 1]) : 1);
      if (weight > 0 && f.emotion != Emotion.neutral) out = out.plus(face.express(f.emotion, amount: f.amount * weight));
    }
    return out.plus(face.look(_gaze.at(frame)));
  }

  /// [body] with the gestures under way at [frame] played over it.
  Pose acts(int frame, Pose body) {
    Pose out = body;
    for (final Act a in _of<Act>()) {
      final Pose? p = a.gesture(frame - (a.at * fps).round(), fps, from: body);
      if (p != null) out = a.add ? out.plus(p) : out.overlay(p);
    }
    return out;
  }

  /// The voice: each line's audio, from when it is said.
  List<Widget> audio({double volume = 1}) => <Widget>[
    for (final Say s in _of<Say>())
      Sequence(
        from: (s.at * fps).round(),
        durationInFrames: (s.line.seconds * fps).ceil() + 1,
        child: Audio(src: s.line.audio, volume: volume),
      ),
  ];
}
