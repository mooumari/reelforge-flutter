import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';

/// A backend that decodes nothing and records that it was asked.
///
/// The point of the test is *which* backend the preview reaches for, so this
/// one only has to be distinguishable from the ffmpeg one.
class FakeBackend implements VideoBackend {
  int opened = 0;
  final List<String> resolved = <String>[];

  @override
  Future<String> resolve(String src, {String? projectPath}) async {
    resolved.add(src);
    return '/fake/$src';
  }

  @override
  Future<VideoSourceInfo> probe(String path) async =>
      const VideoSourceInfo(width: 4, height: 4, durationInSeconds: 10);

  @override
  VideoFrameSource open({
    required VideoDeclaration declaration,
    required int startFrame,
    required int endFrame,
    required int fps,
    required String path,
    required VideoSourceInfo info,
  }) {
    opened++;
    return FakeSource(startFrame: startFrame, endFrame: endFrame);
  }
}

class FakeSource implements VideoFrameSource {
  FakeSource({required this.startFrame, required this.endFrame});

  @override
  final int startFrame;

  @override
  final int endFrame;

  @override
  bool get exhausted => false;

  @override
  int sourceFrameFor(int compositionFrame) => compositionFrame - startFrame;

  @override
  Future<ui.Image?> frameAt(int compositionFrame) async => null;

  @override
  Future<void> dispose() async {}
}

Composition withClip() => Composition(
      id: 'Clip',
      width: 200,
      height: 100,
      fps: 25,
      durationInFrames: 50,
      builder: (BuildContext context) =>
          const VideoClip(src: 'assets/clip.mp4'),
    );

Future<void> pump(WidgetTester tester, VideoBackend Function()? factory) async {
  tester.view.physicalSize = const Size(1000, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1000, 700)),
        child: CompositionPlayer(
          composition: withClip(),
          videoBackendFactory: factory,
          stopwatchFactory: tester.binding.clock.stopwatch,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an injected backend is used instead of looking for ffmpeg',
      (WidgetTester tester) async {
    // On a machine that has ffmpeg the fallback would also work, which is
    // exactly why this asserts on the injected one being *used* rather than on
    // video appearing at all.
    final FakeBackend backend = FakeBackend();
    await pump(tester, () => backend);

    expect(backend.opened, 1);
    expect(backend.resolved, <String>['assets/clip.mp4']);
  });

  testWidgets('the factory is asked once per prepare, not per frame',
      (WidgetTester tester) async {
    int calls = 0;
    final FakeBackend backend = FakeBackend();
    await pump(tester, () {
      calls++;
      return backend;
    });

    expect(calls, 1);
    expect(backend.opened, 1);
  });

  testWidgets('with no backend and no ffmpeg on this machine, it says so',
      (WidgetTester tester) async {
    // A silently empty rectangle is the failure this message exists to
    // prevent.
    await pump(tester, null);
    expect(find.textContaining('No video decoder'), findsOneWidget);
    // Skipped rather than returned early where ffmpeg is installed, since
    // there the fallback legitimately finds one -- and a test that passes by
    // doing nothing reads exactly like a test that passed.
  }, skip: FfmpegVideoBackend.findOnPath() != null);
}
