@Tags(<String>['integration'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge/src/media/ffmpeg_paths.dart';

/// The probe encodes each frame's own index as its grey value: source frame i
/// is rgb(2i, 2i, 2i). Reading one pixel therefore says exactly which source
/// frame was decoded, with no tolerance for hand-waving.
const String projectPath = '../../example';
const String probe = 'assets/probe.mp4';

/// The clip as the VideoProbe composition mounts it.
const int clipStart = 40;
const int clipEnd = 159;

Future<int> greyAt(VideoFrames frames, VideoDeclaration declaration) async {
  final ui.Image? image = frames[declaration];
  expect(image, isNotNull, reason: 'no image decoded for $declaration');
  final ByteData bytes =
      (await image!.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final int centre = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
  return bytes.getUint8(centre);
}

void main() {
  final String? ffmpeg = FfmpegPaths.find('ffmpeg');
  final String? ffprobe = FfmpegPaths.find('ffprobe');
  final bool haveTools = ffmpeg != null &&
      ffprobe != null &&
      File('$projectPath/$probe').existsSync();

  group('decoding a real file', () {
    const VideoDeclaration declaration = VideoDeclaration(src: probe);

    late VideoFrames frames;

    setUp(() async {
      frames = await VideoPreloader.open(
        const <VideoTimelineEntry>[
          VideoTimelineEntry(
            declaration: declaration,
            startFrame: clipStart,
            endFrame: clipEnd,
          ),
        ],
        fps: 60,
        backend: FfmpegVideoBackend(ffmpeg: ffmpeg!, ffprobe: ffprobe!),
        projectPath: projectPath,
      );
    });

    tearDown(() => frames.dispose());

    test('the clip starts at its own first frame, not the timeline\'s', () async {
      await frames.advanceTo(clipStart);
      expect(await greyAt(frames, declaration), closeTo(0, 1));
    });

    test('consecutive frames advance one source frame each', () async {
      await frames.advanceTo(clipStart);
      for (int i = 1; i <= 5; i++) {
        await frames.advanceTo(clipStart + i);
        expect(await greyAt(frames, declaration), closeTo(2 * i, 1),
            reason: 'composition frame ${clipStart + i}');
      }
    });

    test('a forward jump lands exactly, not approximately', () async {
      // This is the shard-entry case: decoding begins mid-clip.
      await frames.advanceTo(clipStart + 60);
      expect(await greyAt(frames, declaration), closeTo(120, 1));
    });

    test('scrubbing backwards restarts the decoder and still lands exactly',
        () async {
      // The exporter never does this; the preview does it constantly.
      await frames.advanceTo(clipStart + 80);
      expect(await greyAt(frames, declaration), closeTo(160, 1));
      await frames.advanceTo(clipStart + 10);
      expect(await greyAt(frames, declaration), closeTo(20, 1));
      await frames.advanceTo(clipStart + 81);
      expect(await greyAt(frames, declaration), closeTo(162, 1));
    });

    test('entering at a frame gives the same pixels as streaming to it',
        () async {
      const int target = clipStart + 37;

      await frames.advanceTo(clipStart);
      for (int f = clipStart + 1; f <= target; f++) {
        await frames.advanceTo(f);
      }
      final int streamed = await greyAt(frames, declaration);

      // A second, independent set entering directly at the target -- exactly
      // what a shard boundary does.
      final VideoFrames direct = await VideoPreloader.open(
        const <VideoTimelineEntry>[
          VideoTimelineEntry(
            declaration: declaration,
            startFrame: clipStart,
            endFrame: clipEnd,
          ),
        ],
        fps: 60,
        backend: FfmpegVideoBackend(ffmpeg: ffmpeg!, ffprobe: ffprobe!),
        projectPath: projectPath,
      );
      await direct.advanceTo(target);
      final int seeked = await greyAt(direct, declaration);
      await direct.dispose();

      expect(seeked, streamed);
      expect(streamed, closeTo(2 * 37, 1));
    });

    test('a clip outside its window paints nothing', () async {
      await frames.advanceTo(clipStart - 1);
      expect(frames[declaration], isNull);
      await frames.advanceTo(clipEnd + 1);
      expect(frames[declaration], isNull);
    });

    test('warns when a source is shorter than the window it is mounted for',
        () async {
      // The probe is 120 frames; ask for 200.
      final VideoFrames short = await VideoPreloader.open(
        const <VideoTimelineEntry>[
          VideoTimelineEntry(
            declaration: declaration,
            startFrame: 0,
            endFrame: 199,
          ),
        ],
        fps: 60,
        backend: FfmpegVideoBackend(ffmpeg: ffmpeg!, ffprobe: ffprobe!),
        projectPath: projectPath,
      );
      expect(short.warnings, hasLength(1));
      expect(short.warnings.single, contains('probe.mp4'));
      expect(short.warnings.single, contains('200'));
      await short.dispose();
    });

    test('the same clip placed twice keeps both placements', () async {
      // Found by rendering a real 60-second reel: a composition that shows the
      // same file in two different scenes rendered one of them black. The
      // manifest split them correctly -- it was the decoder set that collapsed
      // them, because VideoDeclaration has value equality and both placements
      // hash to the same key.
      final VideoFrames twice = await VideoPreloader.open(
        const <VideoTimelineEntry>[
          VideoTimelineEntry(declaration: declaration, startFrame: 0, endFrame: 19),
          VideoTimelineEntry(declaration: declaration, startFrame: 60, endFrame: 79),
        ],
        fps: 60,
        backend: FfmpegVideoBackend(ffmpeg: ffmpeg!, ffprobe: ffprobe!),
        projectPath: projectPath,
      );

      // Each placement starts the clip again from its own first frame, so both
      // windows open on source frame 0.
      await twice.advanceTo(0);
      expect(await greyAt(twice, declaration), closeTo(0, 1));
      await twice.advanceTo(5);
      expect(await greyAt(twice, declaration), closeTo(2 * 5, 1));

      await twice.advanceTo(60);
      expect(await greyAt(twice, declaration), closeTo(0, 1),
          reason: 'the second placement should restart the clip, not be black');
      await twice.advanceTo(65);
      expect(await greyAt(twice, declaration), closeTo(2 * 5, 1));

      await twice.dispose();
    });

    test('between two placements of one clip, nothing paints', () async {
      final VideoFrames twice = await VideoPreloader.open(
        const <VideoTimelineEntry>[
          VideoTimelineEntry(declaration: declaration, startFrame: 0, endFrame: 19),
          VideoTimelineEntry(declaration: declaration, startFrame: 60, endFrame: 79),
        ],
        fps: 60,
        backend: FfmpegVideoBackend(ffmpeg: ffmpeg!, ffprobe: ffprobe!),
        projectPath: projectPath,
      );

      await twice.advanceTo(0);
      // The gap between the two windows is not a window.
      await twice.advanceTo(40);
      expect(twice[declaration], isNull);
      await twice.dispose();
    });

    test('a looping clip restarts the source instead of freezing', () async {
      // The probe is 120 frames; mount it for 300 and it has to wrap twice.
      // Without loop this is the "held last frame" case, which is warned about
      // but still a frozen picture under a nine-second scene.
      const VideoDeclaration looping =
          VideoDeclaration(src: probe, loop: true);
      final VideoFrames frames = await VideoPreloader.open(
        const <VideoTimelineEntry>[
          VideoTimelineEntry(
              declaration: looping, startFrame: 0, endFrame: 299),
        ],
        fps: 60,
        backend: FfmpegVideoBackend(ffmpeg: ffmpeg!, ffprobe: ffprobe!),
        projectPath: projectPath,
      );

      // Nothing to warn about: outlasting the source is the whole point.
      expect(frames.warnings, isEmpty);

      for (final (int composition, int source) in <(int, int)>[
        (0, 0),
        (10, 10),
        (119, 119),
        (120, 0), // wraps
        (125, 5),
        (240, 0), // wraps again
        (245, 5),
      ]) {
        await frames.advanceTo(composition);
        expect(await greyAt(frames, looping), closeTo(2 * source, 1),
            reason: 'composition frame $composition should show source $source');
      }
      await frames.dispose();
    });

    test('a looping clip wrapping mid-stream matches entering there', () async {
      // The wrap is a discontinuity in source time inside a continuous run of
      // composition frames, which is exactly the case a shard boundary also
      // creates. They have to agree.
      const VideoDeclaration looping =
          VideoDeclaration(src: probe, loop: true);
      Future<VideoFrames> open() => VideoPreloader.open(
            const <VideoTimelineEntry>[
              VideoTimelineEntry(
                  declaration: looping, startFrame: 0, endFrame: 299),
            ],
            fps: 60,
            backend: FfmpegVideoBackend(ffmpeg: ffmpeg!, ffprobe: ffprobe!),
            projectPath: projectPath,
          );

      final VideoFrames streamed = await open();
      for (int f = 115; f <= 125; f++) {
        await streamed.advanceTo(f);
      }
      final int afterStreaming = await greyAt(streamed, looping);

      final VideoFrames direct = await open();
      await direct.advanceTo(125);
      final int afterSeeking = await greyAt(direct, looping);

      expect(afterSeeking, afterStreaming);
      expect(afterStreaming, closeTo(2 * 5, 1));
      await streamed.dispose();
      await direct.dispose();
    });

    test('a missing file fails by name rather than rendering a hole', () async {
      await expectLater(
        VideoPreloader.open(
          const <VideoTimelineEntry>[
            VideoTimelineEntry(
              declaration: VideoDeclaration(src: 'assets/nope.mp4'),
              startFrame: 0,
              endFrame: 10,
            ),
          ],
          fps: 60,
          backend: FfmpegVideoBackend(ffmpeg: ffmpeg!, ffprobe: ffprobe!),
          projectPath: projectPath,
        ),
        throwsA(isA<StateError>().having(
            (StateError e) => e.message, 'message', contains('nope.mp4'))),
      );
    });
  },
      skip: haveTools
          ? false
          : 'needs ffmpeg, ffprobe and example/assets/probe.mp4');
}
