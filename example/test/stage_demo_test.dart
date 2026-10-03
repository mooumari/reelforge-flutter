import 'dart:typed_data';

import 'package:example/stage_compare.dart';
import 'package:example/stage_demo.dart';
import 'package:example/stage_faces.dart';
import 'package:example/stage_shapes.dart';
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
  final ByteData data = await renderer.renderFrameRgba(frame);
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
}
