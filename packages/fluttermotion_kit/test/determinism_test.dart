import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';

/// Every kit component that draws, on one timeline.
///
/// The kit's whole promise is that it does not break the framework's: a
/// composition is a pure function of its frame number. A component that
/// reached for an `AnimationController`, a `Ticker` or a wall clock would
/// still *look* right while it was playing and would come apart the moment a
/// render was sharded across processes or a scrubber jumped backwards. This
/// is where that would show up.
const int _fps = 30;

const List<BarDatum> _bars = <BarDatum>[
  BarDatum(value: 12, label: 'w1'),
  BarDatum(value: 31, label: 'w2'),
  BarDatum(value: 7, label: 'w3'),
  BarDatum(value: 24, label: 'w4'),
];

const List<LineDatum> _points = <LineDatum>[
  LineDatum(value: 4, label: 'w1'),
  LineDatum(value: 1, label: 'w2'),
  LineDatum(value: 6, label: 'w3'),
  LineDatum(value: 2, label: 'w4'),
];

final List<Scene> _scenes = <Scene>[
  const Scene(
    seconds: 2,
    child: TitleCard(
      kicker: 'Week 42',
      headline: 'Everything shipped',
      subhead: '128 releases · 3 incidents',
    ),
  ),
  const Scene(
    seconds: 2,
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SceneLabel('Shipped per week'),
          SizedBox(height: 30),
          Expanded(child: BarChart(bars: _bars)),
        ],
      ),
    ),
  ),
  const Scene(
    seconds: 2,
    child: Padding(
      padding: EdgeInsets.all(40),
      child: LineChart(points: _points),
    ),
  ),
  Scene(
    seconds: 2,
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: CardGrid(
        crossAxisCount: 2,
        children: <Widget>[
          for (int i = 0; i < 4; i++)
            Enter.spring(
              child: StatCard(
                badge: 'T$i',
                title: 'team $i',
                value: '${i.isEven ? '+' : '-'}$i.5%',
                signedBy: i.isEven ? 1 : -1,
              ),
            ),
        ],
      ),
    ),
  ),
  const Scene(
    seconds: 2,
    child: Padding(
      padding: EdgeInsets.all(40),
      child: BigStatList(
        children: <Widget>[
          BigStat(value: Counter(to: 128), label: 'releases'),
          BigStat(value: Counter(to: 3, delay: 14), label: 'incidents'),
        ],
      ),
    ),
  ),
  const Scene(
    seconds: 2,
    child: SplitScreen(
      first: ColoredBox(color: Color(0xFF224466)),
      second: ColoredBox(color: Color(0xFF664422)),
    ),
  ),
];

final Composition kitchenSink = Composition(
  id: 'KitchenSink',
  width: 270,
  height: 480,
  fps: _fps,
  durationInFrames: Storyboard.totalFrames(_scenes, fps: _fps),
  wrapper: (BuildContext context, Widget child) => MotionSurface(
    typography: const MotionTypography(scale: 0.25),
    child: child,
  ),
  builder: (BuildContext context) => Storyboard(
    scenes: _scenes,
    transition: const SceneTransition.fade(frames: 6),
  ),
);

Future<Uint8List> renderOnce(CompositionRenderer renderer, int frame) async {
  final ByteData data = await renderer.renderFrameRgba(frame);
  return Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

/// Frames spread across every scene, including both sides of each boundary.
List<int> get _sampled {
  final List<int> starts = Storyboard.startsAt(_scenes, fps: _fps);
  return <int>[
    for (int i = 0; i < starts.length - 1; i++) ...<int>[
      starts[i],
      starts[i] + 3,
      starts[i] + 20,
      starts[i + 1] - 1,
    ],
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh renderer draws the same frame as one that played to it',
      () async {
    // This is the sharding guarantee. Frame 200 rendered by a process that
    // started at 200 has to equal frame 200 rendered by one that walked there
    // from 0, or a four-shard render seams at every boundary.
    final CompositionRenderer streamed = CompositionRenderer(kitchenSink);
    final Map<int, Uint8List> walked = <int, Uint8List>{};
    final Set<int> wanted = _sampled.toSet();
    for (int frame = 0; frame < kitchenSink.durationInFrames; frame++) {
      final Uint8List bytes = await renderOnce(streamed, frame);
      if (wanted.contains(frame)) walked[frame] = bytes;
    }

    for (final int frame in _sampled) {
      final CompositionRenderer fresh = CompositionRenderer(kitchenSink);
      expect(
        await renderOnce(fresh, frame),
        walked[frame],
        reason: 'frame $frame differs when entered directly',
      );
    }
  });

  test('scrubbing backwards lands on the pixels it passed on the way up',
      () async {
    final CompositionRenderer renderer = CompositionRenderer(kitchenSink);
    final List<int> frames = _sampled;

    final Map<int, Uint8List> forwards = <int, Uint8List>{};
    for (final int frame in frames) {
      forwards[frame] = await renderOnce(renderer, frame);
    }
    for (final int frame in frames.reversed) {
      expect(
        await renderOnce(renderer, frame),
        forwards[frame],
        reason: 'frame $frame differs on the way back down',
      );
    }
  });

  test('every scene is actually moving', () async {
    // The control. A determinism test passes trivially if the composition
    // never changes, and "identical pixels" is exactly what a broken
    // component that drew nothing would produce. So: each scene has to differ
    // from itself between two frames where its content is on screen.
    //
    // Adjacent *sampled* frames are not the check, because a scene's first
    // and last frames are both fully faded out and therefore legitimately
    // identical -- as is any scene that has finished moving and is holding.
    final CompositionRenderer renderer = CompositionRenderer(kitchenSink);
    final List<int> starts = Storyboard.startsAt(_scenes, fps: _fps);

    for (int i = 0; i < _scenes.length; i++) {
      final Uint8List early = await renderOnce(renderer, starts[i] + 8);
      final Uint8List later = await renderOnce(renderer, starts[i] + 25);
      expect(
        _same(early, later),
        isFalse,
        reason: 'scene $i draws the same thing at frame 8 and frame 25',
      );
    }
  });
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
