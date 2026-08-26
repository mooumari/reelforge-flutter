import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion/fluttermotion.dart';

/// A backend that only exists to say how a file is tagged.
///
/// Deliberately not the ffmpeg one: what is under test is what the framework
/// *does* with the answer, and an untagged fixture on disk would be a thing to
/// fix rather than a thing to keep.
class TaggedBackend implements VideoBackend {
  TaggedBackend(this.declaresColour);

  final bool? declaresColour;

  @override
  Future<String> resolve(String src, {String? projectPath}) async => '/fake/$src';

  @override
  Future<VideoSourceInfo> probe(String path) async => VideoSourceInfo(
        width: 1280,
        height: 720,
        durationInSeconds: 60,
        declaresColour: declaresColour,
      );

  @override
  VideoFrameSource open({
    required VideoDeclaration declaration,
    required int startFrame,
    required int endFrame,
    required int fps,
    required String path,
    required VideoSourceInfo info,
  }) =>
      _Silent(startFrame: startFrame, endFrame: endFrame);
}

class _Silent implements VideoFrameSource {
  _Silent({required this.startFrame, required this.endFrame});

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

Future<List<String>> warningsFor(
  bool? declaresColour, {
  int placements = 1,
}) async {
  final VideoFrames frames = await VideoPreloader.open(
    <VideoTimelineEntry>[
      for (int i = 0; i < placements; i++)
        const VideoTimelineEntry(
          declaration: VideoDeclaration(src: 'assets/clip.mp4'),
          startFrame: 0,
          endFrame: 59,
        ),
    ],
    fps: 30,
    backend: TaggedBackend(declaresColour),
  );
  final List<String> warnings = List<String>.of(frames.warnings);
  await frames.dispose();
  return warnings;
}

void main() {
  test('an untagged source is called out by name', () async {
    // This cost two days across two platforms before it was a warning: a 720p
    // clip with no tags sits exactly on the boundary where ffmpeg guesses
    // BT.601 and VideoToolbox guesses BT.709, so the same composition came out
    // tinted differently on macOS and on an iPhone with nothing to point at.
    final List<String> warnings = await warningsFor(false);
    expect(warnings, hasLength(1));
    expect(warnings.single, contains('assets/clip.mp4'));
    expect(warnings.single, contains('colour space'));
    // Says how to fix it, not just that it is wrong.
    expect(warnings.single, contains('h264_metadata'));
  });

  test('a tagged source says nothing', () async {
    expect(await warningsFor(true), isEmpty);
  });

  test('a backend that cannot tell says nothing either', () async {
    // Null is not false. A platform decoder that does not expose the
    // container's tags must not accuse every file it opens.
    expect(await warningsFor(null), isEmpty);
  });

  test('one file mounted three times is one thing to fix', () async {
    // Unlike running out mid-window, which is a property of the mounting,
    // colour tagging is a property of the file.
    expect(await warningsFor(false, placements: 3), hasLength(1));
  });
}
