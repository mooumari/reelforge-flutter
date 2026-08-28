import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_kit/reelforge_kit.dart';

import 'harness.dart';

const List<Scene> _scenes = <Scene>[
  Scene(seconds: 5, child: Text('one')),
  Scene(seconds: 9, child: Text('two')),
  Scene(frames: 45, child: Text('three')),
];

void main() {
  group('length arithmetic', () {
    test('seconds and frames add up at the composition rate', () {
      // 5s and 9s at 30fps is 150 + 270, plus an explicit 45.
      expect(Storyboard.totalFrames(_scenes, fps: 30), 465);
      // The same scenes at 60fps are twice as long -- except the one that
      // asked for frames, which is why saying seconds is usually what you
      // mean.
      expect(Storyboard.totalFrames(_scenes, fps: 60), 300 + 540 + 45);
    });

    test('starts is one longer than scenes, ending past the last frame', () {
      expect(Storyboard.startsAt(_scenes, fps: 30), <int>[0, 150, 420, 465]);
    });

    test('a scene needs exactly one of seconds and frames', () {
      expect(() => Scene(child: const Text('x')), throwsAssertionError);
      expect(
        () => Scene(seconds: 1, frames: 30, child: const Text('x')),
        throwsAssertionError,
      );
    });

    test('a scene needs exactly one of child and builder', () {
      expect(() => Scene(seconds: 1), throwsAssertionError);
      expect(
        () => Scene(
          seconds: 1,
          child: const Text('x'),
          builder: (BuildContext context) => const Text('y'),
        ),
        throwsAssertionError,
      );
    });

    test('an empty storyboard is zero frames, not an error', () {
      expect(Storyboard.totalFrames(const <Scene>[], fps: 30), 0);
      expect(Storyboard.startsAt(const <Scene>[], fps: 30), <int>[0]);
    });
  });

  group('which scene is on screen', () {
    Future<void> pumpAt(WidgetTester tester, int frame) => tester.pumpWidget(
          at(
            frame,
            const Storyboard(
              scenes: _scenes,
              transition: SceneTransition.none(),
            ),
            durationInFrames: 465,
          ),
        );

    testWidgets('only the scene whose window contains the frame builds',
        (WidgetTester tester) async {
      await pumpAt(tester, 0);
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsNothing);

      // 149 is the last frame of a 150-frame scene; 150 is the first of the
      // next. An off-by-one here would show as a one-frame flash of two
      // scenes at once, which is exactly the kind of thing nobody sees until
      // it is in a finished video.
      await pumpAt(tester, 149);
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsNothing);

      await pumpAt(tester, 150);
      expect(find.text('one'), findsNothing);
      expect(find.text('two'), findsOneWidget);

      await pumpAt(tester, 464);
      expect(find.text('three'), findsOneWidget);
    });

    testWidgets('a scene sees its own frame zero, not the timeline\'s',
        (WidgetTester tester) async {
      late int seen;
      final List<Scene> scenes = <Scene>[
        const Scene(seconds: 5, child: SizedBox.shrink()),
        Scene(
          seconds: 5,
          child: Builder(
            builder: (BuildContext context) {
              seen = Video.frame(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ];

      await tester.pumpWidget(at(
        153,
        Storyboard(scenes: scenes, transition: const SceneTransition.none()),
        durationInFrames: 300,
      ));
      expect(seen, 3);
    });
  });

  group('transitions', () {
    testWidgets('a fade is dark at both ends and clear in the middle',
        (WidgetTester tester) async {
      Future<double> opacityAt(int frame) async {
        await tester.pumpWidget(at(
          frame,
          const Storyboard(
            scenes: <Scene>[Scene(frames: 100, child: Text('x'))],
            transition: SceneTransition.fade(frames: 10),
          ),
          durationInFrames: 100,
        ));
        return tester.widget<Opacity>(find.byType(Opacity)).opacity;
      }

      expect(await opacityAt(0), 0);
      expect(await opacityAt(5), closeTo(0.5, 1e-9));
      expect(await opacityAt(10), 1);
      expect(await opacityAt(50), 1);
      // Frame 99 is the last one this scene is on screen for, so that is
      // where the fade has to reach zero -- not frame 100, which never
      // renders.
      expect(await opacityAt(89), 1);
      expect(await opacityAt(94), closeTo(0.5, 1e-9));
      expect(await opacityAt(99), 0);
    });

    testWidgets('a scene shorter than two transitions still renders',
        (WidgetTester tester) async {
      // Written as the smaller of two ramps rather than one four-point
      // interpolation precisely so this case overlaps instead of asserting on
      // a non-monotonic range.
      await tester.pumpWidget(at(
        3,
        const Storyboard(
          scenes: <Scene>[Scene(frames: 6, child: Text('x'))],
          transition: SceneTransition.fade(frames: 20),
        ),
        durationInFrames: 6,
      ));
      final double opacity =
          tester.widget<Opacity>(find.byType(Opacity)).opacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
    });

    testWidgets('a scene can override the storyboard transition',
        (WidgetTester tester) async {
      await tester.pumpWidget(at(
        0,
        const Storyboard(
          scenes: <Scene>[
            Scene(frames: 50, child: Text('x'), transition: SceneTransition.none()),
          ],
          transition: SceneTransition.fade(frames: 10),
        ),
        durationInFrames: 50,
      ));
      // The storyboard fade would have made frame 0 fully transparent.
      expect(find.byType(Opacity), findsNothing);
    });
  });

  testWidgets('a builder is not called until its scene is on screen',
      (WidgetTester tester) async {
    // The reason builders exist. A storyboard is a top-level final whose
    // length has to be known before the Composition is built, but the data
    // its scenes draw is usually still loading at that point. A builder that
    // ran early would read it and throw.
    int calls = 0;
    final List<Scene> scenes = <Scene>[
      const Scene(seconds: 2, child: Text('first')),
      Scene(
        seconds: 2,
        builder: (BuildContext context) {
          calls++;
          return const Text('second');
        },
      ),
    ];

    // Constructing the list and measuring it must not touch the builder.
    expect(Storyboard.totalFrames(scenes, fps: 30), 120);
    expect(calls, 0);

    await tester.pumpWidget(at(
      0,
      Storyboard(scenes: scenes, transition: const SceneTransition.none()),
      durationInFrames: 120,
    ));
    expect(calls, 0);

    await tester.pumpWidget(at(
      70,
      Storyboard(scenes: scenes, transition: const SceneTransition.none()),
      durationInFrames: 120,
    ));
    expect(calls, greaterThan(0));
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('a builder sees the scene\'s own frame zero',
      (WidgetTester tester) async {
    late int seen;
    final List<Scene> scenes = <Scene>[
      const Scene(seconds: 5, child: SizedBox.shrink()),
      Scene(
        seconds: 5,
        builder: (BuildContext context) {
          seen = Video.frame(context);
          return const SizedBox.shrink();
        },
      ),
    ];

    await tester.pumpWidget(at(
      157,
      Storyboard(scenes: scenes, transition: const SceneTransition.none()),
      durationInFrames: 300,
    ));
    expect(seen, 7);
  });

  testWidgets('a sting plays at the scene start and stops',
      (WidgetTester tester) async {
    final List<Scene> scenes = <Scene>[
      const Scene(seconds: 1, child: Text('one')),
      const Scene(
        seconds: 5,
        sting: Text('ding'),
        stingFrames: 10,
        child: Text('two'),
      ),
    ];

    Future<void> pumpAt(int frame) => tester.pumpWidget(at(
          frame,
          Storyboard(scenes: scenes, transition: const SceneTransition.none()),
          durationInFrames: 180,
        ));

    await pumpAt(29);
    expect(find.text('ding'), findsNothing);
    await pumpAt(30);
    expect(find.text('ding'), findsOneWidget);
    await pumpAt(39);
    expect(find.text('ding'), findsOneWidget);
    await pumpAt(40);
    expect(find.text('ding'), findsNothing);
    // The scene it belongs to is still very much on screen.
    expect(find.text('two'), findsOneWidget);
  });
}
