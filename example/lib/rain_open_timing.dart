import 'package:reelforge_stage/reelforge_stage.dart';

import 'rain_open_voices.dart';

/// The opening of the rain video, timed from its score
/// (example/voices/rain_week_v2.md): every phrase its own voice line, with the
/// silence after it written down, and the picture cut inside the silences.
const int openFps = 30;

/// The lines, in the order they are said.
abstract final class Say {
  static const int ago = 0, shower = 1, week = 2, app = 3, store = 4, people = 5, what = 6, jobs = 7, warm = 8, fed = 9;
  static const int together = 10, written = 11, clues = 12, ash = 13, tools = 14, bones = 15, paintings = 16, today = 17;
}

final Narration openVoice = Narration(
  <Line>[
    RainOpen.ago,
    RainOpen.shower,
    RainOpen.week,
    RainOpen.app,
    RainOpen.store,
    RainOpen.people,
    RainOpen.what,
    RainOpen.jobs,
    RainOpen.warm,
    RainOpen.fed,
    RainOpen.together,
    RainOpen.written,
    RainOpen.clues,
    RainOpen.ash,
    RainOpen.tools,
    RainOpen.bones,
    RainOpen.paintings,
    RainOpen.today,
  ],
  lead: 1.5,
  gap: 0,
  tail: 2.5,
  // The silence after each line: the beat the picture needs to land. After
  // "Stay together" it is the title card's three seconds and a breath before.
  pauses: const <int, double>{
    Say.ago: 1.2,
    Say.shower: 1.0,
    Say.week: 2.0,
    Say.app: 0.5,
    Say.store: 1.0,
    Say.people: 1.0,
    Say.what: 2.5,
    Say.jobs: 1.0,
    Say.warm: 1.0,
    Say.fed: 1.0,
    Say.together: 4.5,
    Say.written: 0.8,
    Say.clues: 0.8,
    Say.ash: 0.6,
    Say.tools: 0.6,
    Say.bones: 0.6,
    Say.paintings: 1.0,
  },
);

/// Where each shot starts, in seconds, and the end of the last. A shot is cut
/// in the quiet after a line, never through speech.
final List<double> openCuts = () {
  final List<double> end = openVoice.ends, start = openVoice.starts;
  return <double>[
    0,
    end[Say.ago] + 0.6, // map of Europe
    end[Say.shower] + 0.5, // the valley, drizzle
    end[Say.week] + 0.9, // the stone and its seven marks
    end[Say.store] + 0.5, // the camp under the sky, and the two things it hasn't got
    end[Say.people] + 0.5, // the twenty
    end[Say.what] + 1.25, // faces
    end[Say.together] + 1.5, // the three jobs
    start[Say.written], // the title
    end[Say.clues] + 0.4, // the valley at dusk
    end[Say.ash] + 0.3,
    end[Say.tools] + 0.3,
    end[Say.bones] + 0.3,
    end[Say.paintings] + 0.5,
    openVoice.seconds,
  ];
}();

const List<String> openShotNames = <String>[
  'map', 'valley', 'stone', 'camp', 'band', 'faces', 'jobs', 'title', 'dusk', 'ash', 'tools', 'bones', 'painting', 'today',
];

int get openShots => openShotNames.length;

/// Frames each shot lasts: cumulative, so the rounding never adds up.
final List<int> openLengths = <int>[
  for (int i = 0; i < openShots; i++) (openCuts[i + 1] * openFps).round() - (openCuts[i] * openFps).round(),
];

/// Seconds into [shot] at which word [word] of [line] starts to be said.
double said(int shot, int line, int word) =>
    openVoice.starts[line] + Captions.wordTimes(openVoice.lines[line])[word].$1 - openCuts[shot];

/// Seconds into [shot] at which word [word] of [line] has been said.
double saidTo(int shot, int line, int word) =>
    openVoice.starts[line] + Captions.wordTimes(openVoice.lines[line])[word].$2 - openCuts[shot];

/// Seconds into [shot] at which [line] starts.
double lineAt(int shot, int line) => openVoice.starts[line] - openCuts[shot];

/// Seconds into [shot] at which [line] has been said.
double lineEnd(int shot, int line) => openVoice.ends[line] - openCuts[shot];
