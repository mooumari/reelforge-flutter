import 'package:example/rain_open.dart';
import 'package:example/stick_proto.dart';
import 'package:example/rain_week.dart';
import 'package:example/stage_cast.dart';
import 'package:example/stage_compare.dart';
import 'package:example/stage_demo.dart';
import 'package:example/lion_sleep.dart';
import 'package:example/stage_faces.dart';
import 'package:example/stage_savanna.dart';
import 'package:example/stage_shapes.dart';
import 'package:example/stage_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';

/// The stage demo draws planned walks, a wave, blinks, speech, follow-through
/// and a camera move with nothing but the frame number to go on. This is where
/// a controller, a ticker or an accumulated value would show up: the frame
/// would still look right playing forwards and come apart when a render is
/// sharded or scrubbed.
///
/// Follow-through is the one to watch. It is a spring, and springs carry state;
/// it gets away with being a pure function by replaying a window of frames
/// before the one asked for. If that ever leaked state between calls, the
/// fresh-renderer test is what would catch it.
Future<Uint8List> _frame(CompositionRenderer renderer, int frame) async {
  // A build error is drawn as a red screen, which is the same red screen every
  // time: deterministic, and wrong. Fail on it instead.
  final FlutterExceptionHandler? before = FlutterError.onError;
  final List<String> errors = <String>[];
  FlutterError.onError = (FlutterErrorDetails d) {
    // The renderer runs outside a testWidgets body, which the binding grumbles about.
    if (!d.exceptionAsString().contains("'inTest'")) errors.add(d.exceptionAsString());
  };
  final ByteData data;
  try {
    data = await renderer.renderFrameRgba(frame);
  } finally {
    FlutterError.onError = before;
  }
  expect(errors, isEmpty, reason: 'frame $frame threw while building');
  return Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// Standing, speeding up, cruising, stopping and the settling steps, both
// waves, speech, and the camera's push-in.
const List<int> _sampled = <int>[0, 13, 31, 70, 117, 141, 150, 165, 175, 200, 240, 260, 299];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh renderer draws the frame one that walked there drew', () async {
    final CompositionRenderer walked = CompositionRenderer(stageDemo);
    final Map<int, Uint8List> expected = <int, Uint8List>{};
    for (int frame = 0; frame <= _sampled.last; frame++) {
      final Uint8List bytes = await _frame(walked, frame);
      if (_sampled.contains(frame)) expected[frame] = bytes;
    }
    for (final int frame in _sampled) {
      final CompositionRenderer fresh = CompositionRenderer(stageDemo);
      expect(_same(await _frame(fresh, frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs when entered directly');
    }
  });

  test('scrubbing backwards lands on the pixels it passed going up', () async {
    final CompositionRenderer renderer = CompositionRenderer(stageDemo);
    final Map<int, Uint8List> forwards = <int, Uint8List>{
      for (final int f in _sampled) f: await _frame(renderer, f),
    };
    for (final int frame in _sampled.reversed) {
      expect(_same(await _frame(renderer, frame), forwards[frame]!), isTrue,
          reason: 'frame $frame differs on the way back down');
    }
  });

  test('it is actually moving: walk, wave and camera each change the picture',
      () async {
    // The control. Identical pixels is also what a composition that drew
    // nothing would give, so say that the things that should differ do.
    final CompositionRenderer renderer = CompositionRenderer(stageDemo);
    // One stride apart -- different leg poses, hero somewhere else on screen.
    expect(_same(await _frame(renderer, 13), await _frame(renderer, 19)), isFalse);
    // Stopped, then waving: the arm is up at the wave's high point.
    expect(_same(await _frame(renderer, 158), await _frame(renderer, 176)), isFalse);
    // Same stance, camera pushed in.
    expect(_same(await _frame(renderer, 165), await _frame(renderer, 240)), isFalse);
  });

  test('the walk comparison is deterministic too', () async {
    // Its footprint trail replays 45 earlier frames on every frame, which is
    // exactly the kind of thing that would drift if it were not pure.
    final CompositionRenderer walked = CompositionRenderer(walkCompare);
    final Map<int, Uint8List> expected = <int, Uint8List>{};
    for (int frame = 0; frame <= 120; frame += 4) {
      expected[frame] = await _frame(walked, frame);
    }
    for (final int frame in <int>[40, 80, 120]) {
      expect(_same(await _frame(CompositionRenderer(walkCompare), frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs when entered directly');
    }
  });

  test('the shapes showcase is deterministic, and its morph and tail move', () async {
    // Skins and morphs cache their binding and in-betweens; a cache keyed
    // wrongly would show up as a frame that depends on what came before.
    final CompositionRenderer walked = CompositionRenderer(stageShapes);
    final Map<int, Uint8List> expected = <int, Uint8List>{};
    for (int frame = 0; frame <= 160; frame += 8) {
      expected[frame] = await _frame(walked, frame);
    }
    for (final int frame in <int>[48, 104, 160]) {
      expect(_same(await _frame(CompositionRenderer(stageShapes), frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs when entered directly');
    }
    expect(_same(expected[40]!, expected[80]!), isFalse);
  });

  test('the faces demo is deterministic, and its faces move', () async {
    // Speech, moods, gaze, blinks and the blend-shape cache all feed every
    // frame; none of it may depend on the frames drawn before.
    final CompositionRenderer walked = CompositionRenderer(stageFaces);
    final Map<int, Uint8List> expected = <int, Uint8List>{};
    for (int frame = 0; frame <= 480; frame += 16) {
      expected[frame] = await _frame(walked, frame);
    }
    for (final int frame in <int>[64, 208, 480]) {
      expect(_same(await _frame(CompositionRenderer(stageFaces), frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs when entered directly');
    }
    expect(_same(expected[64]!, expected[80]!), isFalse);
  });

  test('the savanna is deterministic, and the lion walks on', () async {
    // A four-legged gait, two tails on follow-through and two speeches.
    final CompositionRenderer walked = CompositionRenderer(stageSavanna);
    final Map<int, Uint8List> expected = <int, Uint8List>{};
    for (int frame = 0; frame <= 320; frame += 20) {
      expected[frame] = await _frame(walked, frame);
    }
    for (final int frame in <int>[80, 180, 260]) {
      expect(_same(await _frame(CompositionRenderer(stageSavanna), frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs when entered directly');
    }
    expect(_same(expected[60]!, expected[80]!), isFalse);
  });

  test('the explainer is deterministic, cut to its narration, and its shots differ', () async {
    // Five shots, captions, a camera and graphics that land on words.
    final CompositionRenderer walked = CompositionRenderer(lionSleep);
    final Map<int, Uint8List> expected = <int, Uint8List>{};
    for (int frame = 0; frame < lionSleep.durationInFrames; frame += 60) {
      expected[frame] = await _frame(walked, frame);
    }
    for (final int frame in <int>[120, 540, 1020]) {
      expect(_same(await _frame(CompositionRenderer(lionSleep), frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs when entered directly');
    }
    expect(_same(expected[120]!, expected[300]!), isFalse);
    // Every voiced line is declared as audio, and the bed under them.
    final RenderManifest manifest = DeclarationPass.run(lionSleep);
    final Set<String> sources = manifest.audio.map((AudioTimelineEntry e) => e.declaration.src).toSet();
    expect(sources, containsAll(<String>[
      for (final String name in <String>['intro', 'hours', 'compare', 'lazy', 'hunt', 'save', 'close']) 'assets/voices/lion_sleep/$name.wav',
      'assets/sound/bed.m4a',
    ]));
  });

  test('the cast is deterministic, and walks on', () async {
    // Ten characters, live hems, a cape and a ponytail on follow-through,
    // and every garment's paths built once and cached.
    final CompositionRenderer walked = CompositionRenderer(stageCast);
    final Map<int, Uint8List> expected = <int, Uint8List>{};
    for (int frame = 0; frame <= 440; frame += 20) {
      expected[frame] = await _frame(walked, frame);
    }
    for (final int frame in <int>[100, 300, 440]) {
      expect(_same(await _frame(CompositionRenderer(stageCast), frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs when entered directly');
    }
    expect(_same(expected[100]!, expected[120]!), isFalse);
  });

  test('the style test is deterministic: light, cast shadows and the close-up', () async {
    // Shading is worked out per part per frame from the pose, and cast
    // shadows paint into a layer; none of it may carry between frames.
    final CompositionRenderer walked = CompositionRenderer(stageStyle);
    final Map<int, Uint8List> expected = <int, Uint8List>{};
    for (int frame = 0; frame <= 280; frame += 20) {
      expected[frame] = await _frame(walked, frame);
    }
    for (final int frame in <int>[40, 140, 280]) {
      expect(_same(await _frame(CompositionRenderer(stageStyle), frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs when entered directly');
    }
    expect(_same(expected[120]!, expected[140]!), isFalse);
  });

  test('the rain video is deterministic: weather, fire, walks and a camera through the ground', () async {
    // One frame from inside each shot, so every set, effect and camera move
    // is drawn. Rain, splashes, fire and smoke are all seeded arithmetic on
    // the frame; a leaked random or a ticking value would show here.
    const List<int> sampled = <int>[60, 170, 400, 640, 760, 880, 1010, 1100, 1290, 1450];
    final CompositionRenderer first = CompositionRenderer(rainWeek);
    final Map<int, Uint8List> expected = <int, Uint8List>{
      for (final int f in sampled) f: await _frame(first, f),
    };
    for (final int frame in <int>[170, 760, 1010, 1450]) {
      expect(_same(await _frame(CompositionRenderer(rainWeek), frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs when entered directly');
    }
    for (final int frame in sampled.reversed) {
      expect(_same(await _frame(first, frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs on the way back down');
    }
    // And the picture does move: the sky, the strata and the huts.
    expect(_same(expected[60]!, expected[170]!), isFalse);
    expect(_same(expected[640]!, expected[760]!), isFalse);
    expect(_same(expected[1290]!, expected[1450]!), isFalse);
  });

  for (final Composition open in <Composition>[rainOpen, rainOpenDoodle]) {
    test('${open.id} is deterministic: the map, the weather, the ink and the camera', () async {
      // One frame from inside each of the fourteen shots.
      const List<int> sampled = <int>[70, 165, 235, 330, 440, 530, 700, 940, 1050, 1125, 1165, 1205, 1250, 1350];
      final CompositionRenderer first = CompositionRenderer(open);
      final Map<int, Uint8List> expected = <int, Uint8List>{
        for (final int f in sampled) f: await _frame(first, f),
      };
      for (final int frame in <int>[165, 440, 700, 1250, 1350]) {
        expect(_same(await _frame(CompositionRenderer(open), frame), expected[frame]!), isTrue,
            reason: 'frame $frame differs when entered directly');
      }
      for (final int frame in sampled.reversed) {
        expect(_same(await _frame(first, frame), expected[frame]!), isTrue,
            reason: 'frame $frame differs on the way back down');
      }
      expect(_same(expected[70]!, expected[165]!), isFalse);
      expect(_same(expected[1125]!, expected[1165]!), isFalse);
    });
  }

  test('StickProto is deterministic: the walks, the stirring and the close-up', () async {
    const List<int> sampled = <int>[20, 70, 110, 149, 170, 230];
    final CompositionRenderer first = CompositionRenderer(stickProto);
    final Map<int, Uint8List> expected = <int, Uint8List>{
      for (final int f in sampled) f: await _frame(first, f),
    };
    for (final int frame in <int>[70, 230]) {
      expect(_same(await _frame(CompositionRenderer(stickProto), frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs when entered directly');
    }
    for (final int frame in sampled.reversed) {
      expect(_same(await _frame(first, frame), expected[frame]!), isTrue,
          reason: 'frame $frame differs on the way back down');
    }
    expect(_same(expected[20]!, expected[110]!), isFalse);
  });
}
