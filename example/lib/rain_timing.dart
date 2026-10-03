import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

import 'rain_voices.dart';

/// The narration of the rain video, and the arithmetic every shot of it is
/// timed with: when a line, or a word of it, is said, in seconds into a shot.
const int rainFps = 30;

final Narration rainVoice = Narration(
  <Line>[
    RainVoices.start,
    RainVoices.week,
    RainVoices.what,
    RainVoices.left,
    RainVoices.dayOne,
    RainVoices.huts,
  ],
  // A title card's worth of quiet after "So what do you do?".
  pauses: const <int, double>{2: 3.4},
);

/// How many lines each shot holds: one each.
const List<int> rainShots = <int>[1, 1, 1, 1, 1, 1];

final List<double> rainCuts = rainVoice.cuts(rainShots);

/// Frames each shot lasts, cut to cut, rounded as cumulative frames so that
/// none of the rounding adds up.
final List<int> rainLengths = <int>[
  for (int i = 0; i < rainShots.length; i++) (rainCuts[i + 1] * rainFps).round() - (rainCuts[i] * rainFps).round(),
];

/// Seconds into [shot] at which word [word] of line [line] starts to be said.
double saidAt(int shot, int line, int word) =>
    rainVoice.starts[line] + Captions.wordTimes(rainVoice.lines[line])[word].$1 - rainCuts[shot];

/// Seconds into [shot] at which word [word] of line [line] has been said.
double saidTo(int shot, int line, int word) =>
    rainVoice.starts[line] + Captions.wordTimes(rainVoice.lines[line])[word].$2 - rainCuts[shot];

/// How far along something is: 0 at [from] seconds, 1 [over] seconds later.
double along(double t, double from, double over, [Curve curve = Curves.easeInOut]) =>
    curve.transform(((t - from) / over).clamp(0.0, 1.0));

/// Seconds into the shot being drawn.
double secondsOf(BuildContext context) => Video.frame(context) / Video.fps(context);

double lerpD(double a, double b, double t) => a + (b - a) * t;

/// A sound effect [at] seconds into the shot it is mounted in, lasting
/// [seconds] (a looping one is held to that long). Positioned with a
/// [Sequence], so the same file can sound again elsewhere.
Widget sfx(String name, double at, {double volume = 0.5, double seconds = 0.3, bool loop = false, String ext = 'wav'}) => Sequence(
      from: (at * rainFps).round(),
      durationInFrames: (seconds * rainFps).round(),
      child: Audio(src: 'assets/sound/$name.$ext', volume: volume, loop: loop),
    );
