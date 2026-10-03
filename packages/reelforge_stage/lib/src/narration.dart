import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';

import 'performance.dart';

/// A voice-over: [Line]s said one after another, and the video cut to them.
///
/// The narration is what a video is timed to. Lines follow each other by how
/// long they really take, so [starts] and [ends] are the voice's own, and
/// the picture is cut at the pauses between them -- [cuts] says where, and
/// [lengths] how long each shot is -- rather than at frame numbers that go
/// stale the moment a line is re-voiced.
///
/// ```dart
/// final Narration voice = Narration(<Line>[Voices.intro, Voices.hours, Voices.why]);
/// final List<double> shots = voice.lengths(<int>[1, 1, 1]); // seconds
/// ```
@immutable
class Narration {
  Narration(List<Line> lines, {this.lead = 0.7, this.gap = 0.45, this.tail = 1.3})
    : lines = List<Line>.unmodifiable(lines) {
    double at = lead;
    final List<double> from = <double>[];
    for (final Line line in lines) {
      from.add(at);
      at += line.spoken + gap;
    }
    starts = List<double>.unmodifiable(from);
  }

  final List<Line> lines;

  /// Silence before the first line.
  final double lead;

  /// Silence between lines.
  final double gap;

  /// Silence after the last.
  final double tail;

  /// When each line starts being said, in seconds.
  late final List<double> starts;

  /// When each line stops being said.
  List<double> get ends => <double>[for (int i = 0; i < lines.length; i++) starts[i] + lines[i].spoken];

  /// How long the video is: the last word, and a breath.
  double get seconds => ends.last + tail;

  /// [seconds], in frames at [fps].
  int framesAt(int fps) => (seconds * fps).ceil();

  /// Line [i], as a [Say] for a [Performance].
  Say say(int i) => Say(lines[i], at: starts[i]);

  /// Where to cut so each shot holds [counts] lines: the middle of the pause
  /// after the last line of each shot, and the start and end of the video.
  /// `counts` must add up to the number of lines.
  List<double> cuts(List<int> counts) {
    assert(counts.fold(0, (int a, int b) => a + b) == lines.length, 'The shots have to hold every line, once.');
    final List<double> out = <double>[0];
    int line = 0;
    for (final int n in counts) {
      line += n;
      out.add(line == lines.length ? seconds : ends[line - 1] + gap / 2 + (starts[line] - ends[line - 1] - gap) / 2);
    }
    return out;
  }

  /// How long each shot is, in seconds, for shots holding [counts] lines.
  List<double> lengths(List<int> counts) {
    final List<double> c = cuts(counts);
    return <double>[for (int i = 0; i < counts.length; i++) c[i + 1] - c[i]];
  }

  /// The audio of every line at [fps], each from when it is said. Place it
  /// in the composition itself, not inside a scene, so a cut does not cut it
  /// off.
  List<Widget> audio({required int fps, double volume = 1}) => <Widget>[
    for (int i = 0; i < lines.length; i++)
      Sequence(
        from: (starts[i] * fps).round(),
        durationInFrames: (lines[i].seconds * fps).ceil() + 1,
        child: Audio(src: lines[i].audio, volume: volume),
      ),
  ];

  /// The line being said at [seconds], or the one just said if it is still
  /// within [linger] -- as long as a caption should stay up.
  int? lineAt(double seconds, {double linger = 0.35}) {
    int? out;
    for (int i = 0; i < lines.length; i++) {
      if (starts[i] - 0.05 <= seconds && seconds <= ends[i] + linger) out = i;
    }
    return out;
  }
}

/// Captions that follow the voice: the line being said, set in a pill at the
/// bottom of the frame, each word lighting up as it is spoken.
///
/// Words come from the timings the voice reported, so they are lit exactly
/// when they are heard. Words already said are solid, the one being said is
/// in [highlight], and the ones to come are faint.
class Captions extends StatelessWidget {
  const Captions({
    super.key,
    required this.narration,
    this.style = const TextStyle(fontSize: 54, fontWeight: FontWeight.w700, height: 1.18),
    this.color = const Color(0xFFFFFFFF),
    this.highlight = const Color(0xFFFFC857),
    this.pill = const Color(0xB3160D2A),
    this.bottom = 96,
    this.maxWidth = 1500,
  });

  final Narration narration;
  final TextStyle style;
  final Color color;
  final Color highlight;
  final Color pill;

  /// Distance of the pill from the bottom of the frame.
  final double bottom;
  final double maxWidth;

  /// When each word of [line] is said, in seconds from the start of the line:
  /// `(start, end)` per word of [Line.text], split on spaces.
  ///
  /// The voice's words and the text's words line up one to one unless the
  /// voice read something differently (a number, a hyphen); then the words
  /// are spread over the time the voice spent speaking.
  static List<(double, double)> wordTimes(Line line) {
    final List<String> tokens = line.text.split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
    if (line.words.length == tokens.length) {
      return <(double, double)>[for (final (int, int, String) w in line.words) (w.$1 / 1e7, (w.$1 + w.$2) / 1e7)];
    }
    final double from = line.words.isEmpty ? 0 : line.words.first.$1 / 1e7, to = line.spoken;
    final double each = (to - from) / math.max(tokens.length, 1);
    return <(double, double)>[for (int i = 0; i < tokens.length; i++) (from + each * i, from + each * (i + 1))];
  }

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = frame / Video.fps(context);
    final int? i = narration.lineAt(t);
    if (i == null) return const SizedBox.shrink();

    final Line line = narration.lines[i];
    final double local = t - narration.starts[i];
    final List<String> tokens = line.text.split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
    final List<(double, double)> times = wordTimes(line);

    // The pill eases in over the first few frames of a line, and out over
    // the last.
    final double fadeIn = (local / 0.18 + 0.3).clamp(0.0, 1.0);
    final double fadeOut = ((narration.ends[i] + 0.35 - t) / 0.18).clamp(0.0, 1.0);
    final double show = Curves.easeOut.transform(math.min(fadeIn, fadeOut));

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Opacity(
          opacity: show,
          child: Transform.translate(
            offset: Offset(0, (1 - show) * 14),
            child: DecoratedBox(
              decoration: BoxDecoration(color: pill, borderRadius: BorderRadius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        for (int w = 0; w < tokens.length; w++)
                          TextSpan(
                            text: w == tokens.length - 1 ? tokens[w] : '${tokens[w]} ',
                            style: TextStyle(
                              color: local >= times[w].$2
                                  ? color
                                  : local >= times[w].$1
                                  ? highlight
                                  : color.withValues(alpha: 0.42),
                            ),
                          ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
