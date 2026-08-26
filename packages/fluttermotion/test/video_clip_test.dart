import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion/src/media/video_decoder.dart';

Composition compose(Widget Function(BuildContext) builder,
        {int durationInFrames = 100}) =>
    Composition(
      id: 'Test',
      width: 320,
      height: 240,
      fps: 60,
      durationInFrames: durationInFrames,
      builder: builder,
    );

void main() {
  group('VideoDeclaration', () {
    test('two clips of the same file at the same trim are one clip', () {
      expect(
        const VideoDeclaration(src: 'a.mp4'),
        const VideoDeclaration(src: 'a.mp4'),
      );
    });

    test('a different trim is a different clip', () {
      expect(
        const VideoDeclaration(src: 'a.mp4'),
        isNot(const VideoDeclaration(src: 'a.mp4', trimStartInFrames: 30)),
      );
    });

    test('a different decode size is a different clip, not a shared pipe', () {
      // They cannot share a decoder: one ffmpeg process yields one size.
      expect(
        const VideoDeclaration(src: 'a.mp4', decodeWidth: 640),
        isNot(const VideoDeclaration(src: 'a.mp4', decodeWidth: 1280)),
      );
    });
  });

  group('declaration pass', () {
    test('infers a clip window from where it is mounted', () {
      final RenderManifest manifest = DeclarationPass.run(
        compose(
          (BuildContext context) => const Sequence(
            from: 40,
            durationInFrames: 25,
            child: VideoClip(src: 'assets/clip.mp4'),
          ),
        ),
      );

      expect(manifest.video, hasLength(1));
      expect(manifest.video.single.startFrame, 40);
      expect(manifest.video.single.endFrame, 64);
      expect(manifest.video.single.durationInFrames, 25);
    });

    test('the same file used twice becomes two entries, not one long one', () {
      final RenderManifest manifest = DeclarationPass.run(
        compose(
          (BuildContext context) => const Stack(
            children: <Widget>[
              Sequence(
                from: 0,
                durationInFrames: 10,
                child: VideoClip(src: 'a.mp4'),
              ),
              Sequence(
                from: 50,
                durationInFrames: 10,
                child: VideoClip(src: 'a.mp4'),
              ),
            ],
          ),
        ),
      );

      expect(manifest.video, hasLength(2));
      expect(manifest.video[0].startFrame, 0);
      expect(manifest.video[0].endFrame, 9);
      expect(manifest.video[1].startFrame, 50);
      expect(manifest.video[1].endFrame, 59);
    });

    test('a clip in a LayoutBuilder is still found', () {
      // Layout runs during the pass precisely so this cannot be missed.
      final RenderManifest manifest = DeclarationPass.run(
        compose(
          (BuildContext context) => LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                const VideoClip(src: 'deep.mp4'),
          ),
        ),
      );
      expect(manifest.video.single.declaration.src, 'deep.mp4');
    });

    test('audio and video are collected in one sweep', () {
      final RenderManifest manifest = DeclarationPass.run(
        compose(
          (BuildContext context) => const Stack(
            children: <Widget>[
              Audio(src: 'music.mp3'),
              VideoClip(src: 'clip.mp4'),
            ],
          ),
        ),
      );
      expect(manifest.audio, hasLength(1));
      expect(manifest.video, hasLength(1));
      expect(manifest.isEmpty, isFalse);
    });

    test('reports video in the JSON the CLI reads', () {
      final Map<String, Object?> json = DeclarationPass.run(
        compose(
          (BuildContext context) => const Sequence(
            from: 5,
            durationInFrames: 10,
            child: VideoClip(
              src: 'c.mp4',
              trimStartInFrames: 12,
              decodeWidth: 640,
              decodeHeight: 360,
            ),
          ),
        ),
      ).toJson();

      final Map<String, Object?> entry =
          (json['video']! as List<Object?>).single! as Map<String, Object?>;
      expect(entry, <String, Object?>{
        'src': 'c.mp4',
        'startFrame': 5,
        'endFrame': 14,
        'trimStartInFrames': 12,
        'decodeWidth': 640,
        'decodeHeight': 360,
      });
    });
  });

  group('VideoClip widget', () {
    testWidgets('takes up its layout size with nothing decoded', (
      WidgetTester tester,
    ) async {
      // The declaration pass runs before anything is decoded; a clip must
      // occupy the right space rather than collapsing and shifting layout.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VideoFrame(
            frame: 0,
            fps: 60,
            durationInFrames: 100,
            width: 320,
            height: 240,
            // Centred so the root's tight constraints do not force the size.
            child: Center(
              child: VideoClip(src: 'a.mp4', width: 200, height: 100),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(VideoClip)), const Size(200, 100));
    });
  });

  group('frame mapping', () {
    test('maps composition frames onto absolute source frames', () {
      final VideoDecoder decoder = VideoDecoder(
        declaration: const VideoDeclaration(src: 'a.mp4',
            trimStartInFrames: 30),
        startFrame: 40,
        endFrame: 100,
        fps: 60,
        path: 'a.mp4',
        ffmpeg: 'ffmpeg',
        info: const VideoSourceInfo(
            width: 320, height: 240, durationInSeconds: 10),
      );

      // The clip's first frame shows the trim point, not frame 0.
      expect(decoder.sourceFrameFor(40), 30);
      expect(decoder.sourceFrameFor(41), 31);
      // Absolute, so a shard entering here computes the same answer.
      expect(decoder.sourceFrameFor(100), 90);
    });

    test('decodes at the source size unless told otherwise', () {
      VideoDecoder build(VideoDeclaration declaration) => VideoDecoder(
            declaration: declaration,
            startFrame: 0,
            endFrame: 10,
            fps: 60,
            path: 'a.mp4',
            ffmpeg: 'ffmpeg',
            info: const VideoSourceInfo(
                width: 1920, height: 1080, durationInSeconds: 1),
          );

      expect(build(const VideoDeclaration(src: 'a.mp4')).width, 1920);
      expect(
        build(const VideoDeclaration(
                src: 'a.mp4', decodeWidth: 960, decodeHeight: 540))
            .width,
        960,
      );
    });

    test('knows how many frames a source can cover', () {
      const VideoSourceInfo info = VideoSourceInfo(
          width: 320, height: 240, durationInSeconds: 2.5);
      expect(info.frameCapacity(60), 150);
      expect(info.frameCapacity(30), 75);
    });
  });

  group('path resolution', () {
    test('resolves a clip against the project, leaving absolute paths', () {
      // src is a filesystem path, not a Flutter asset key -- ffmpeg reads the
      // file directly and knows nothing about the asset bundle.
      expect(VideoPreloader.resolvePath('assets/a.mp4', '/p'),
          '/p/assets/a.mp4');
      expect(VideoPreloader.resolvePath('/abs/a.mp4', '/p'), '/abs/a.mp4');
    });
  });
}
