import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';

/// Records what the exporter asked of it, so the pipeline can be tested
/// without a single line of platform code.
/// A [FakeEncoder] that also accepts audio, which is what makes the exporter
/// hand it any -- the capability is the interface, not a flag.
class MixingEncoder extends FakeEncoder implements AudioCapableEncoder {
  List<AudioTrackRequest> tracks = const <AudioTrackRequest>[];

  @override
  Future<void> setAudio(List<AudioTrackRequest> value) async => tracks = value;
}

class FakeEncoder implements VideoEncoder {
  EncoderSettings? settings;
  final List<int> frameIndices = <int>[];
  final List<int> frameLengths = <int>[];
  final List<String> calls = <String>[];

  /// Set to make [addFrame] throw on that index.
  int? failOnFrame;

  @override
  Future<void> start(EncoderSettings s) async {
    calls.add('start');
    settings = s;
  }

  @override
  Future<void> addFrame(Uint8List rgba, int frameIndex) async {
    if (frameIndex == failOnFrame) throw const EncoderException('boom');
    frameIndices.add(frameIndex);
    frameLengths.add(rgba.length);
  }

  @override
  Future<void> finish() async => calls.add('finish');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

Composition compose({
  int width = 64,
  int height = 32,
  int durationInFrames = 5,
  Widget Function(BuildContext)? builder,
}) =>
    Composition(
      id: 'Test',
      width: width,
      height: height,
      fps: 30,
      durationInFrames: durationInFrames,
      builder: builder ??
          (BuildContext context) => ColoredBox(
                color: Color(0xFF000000 + Video.frame(context)),
              ),
    );

void main() {
  // The renderer rasterises through the binding's raster thread.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('writes every frame once, in order', () async {
    final FakeEncoder encoder = FakeEncoder();
    final ExportResult result = await InAppExporter.export(
      composition: compose(durationInFrames: 5),
      encoder: encoder,
      outputPath: '/tmp/x.mp4',
    );

    expect(encoder.frameIndices, <int>[0, 1, 2, 3, 4]);
    expect(result.frames, 5);
    expect(encoder.calls, <String>['start', 'finish', 'dispose']);
  });

  test('hands the encoder exactly width * height * 4 bytes', () async {
    final FakeEncoder encoder = FakeEncoder();
    await InAppExporter.export(
      composition: compose(width: 64, height: 32),
      encoder: encoder,
      outputPath: '/tmp/x.mp4',
    );
    expect(encoder.frameLengths, everyElement(64 * 32 * 4));
  });

  test('scale changes pixel dimensions and the bytes that follow', () async {
    final FakeEncoder encoder = FakeEncoder();
    final ExportResult result = await InAppExporter.export(
      composition: compose(width: 64, height: 32),
      encoder: encoder,
      outputPath: '/tmp/x.mp4',
      scale: 2,
    );

    expect(result.width, 128);
    expect(result.height, 64);
    expect(encoder.settings!.width, 128);
    expect(encoder.frameLengths.first, 128 * 64 * 4);
  });

  test('rounds odd dimensions down and says so rather than silently', () async {
    // H.264 has no representation for an odd width.
    final FakeEncoder encoder = FakeEncoder();
    final ExportResult result = await InAppExporter.export(
      composition: compose(width: 65, height: 33),
      encoder: encoder,
      outputPath: '/tmp/x.mp4',
    );

    expect(result.width, 64);
    expect(result.height, 32);
    expect(result.warnings, contains(contains('even dimensions')));
  });

  group('EncoderSettings', () {
    test('scales the default bitrate with pixels and frame rate', () {
      const EncoderSettings hd = EncoderSettings(
          outputPath: 'a', width: 1920, height: 1080, fps: 30);
      const EncoderSettings uhd = EncoderSettings(
          outputPath: 'a', width: 3840, height: 2160, fps: 30);
      expect(uhd.effectiveBitrate, greaterThan(hd.effectiveBitrate));
    });

    test('an explicit bitrate wins', () {
      const EncoderSettings settings = EncoderSettings(
          outputPath: 'a', width: 1920, height: 1080, fps: 30,
          bitrate: 5000000);
      expect(settings.effectiveBitrate, 5000000);
    });

    test('clamps absurd extremes', () {
      const EncoderSettings tiny =
          EncoderSettings(outputPath: 'a', width: 16, height: 16, fps: 1);
      expect(tiny.effectiveBitrate, greaterThanOrEqualTo(1000000));
    });
  });

  test('reports progress that reaches exactly 100%', () async {
    final List<ExportProgress> seen = <ExportProgress>[];
    await InAppExporter.export(
      composition: compose(durationInFrames: 4),
      encoder: FakeEncoder(),
      outputPath: '/tmp/x.mp4',
      onProgress: seen.add,
    );

    expect(seen, hasLength(4));
    expect(seen.first.frame, 1);
    expect(seen.last.fraction, 1.0);
    // No estimate before there is anything to estimate from.
    expect(seen.first.remaining, isNull);
  });

  test('cancelling stops early and still disposes the encoder', () async {
    final FakeEncoder encoder = FakeEncoder();
    final ExportCancellation cancellation = ExportCancellation();

    await expectLater(
      InAppExporter.export(
        composition: compose(durationInFrames: 100),
        encoder: encoder,
        outputPath: '/tmp/x.mp4',
        cancellation: cancellation,
        onProgress: (ExportProgress p) {
          if (p.frame == 3) cancellation.cancel();
        },
      ),
      throwsA(isA<ExportCancelled>()),
    );

    expect(encoder.frameIndices, <int>[0, 1, 2]);
    // finish() must NOT run: a cancelled export should leave no playable file.
    expect(encoder.calls, <String>['start', 'dispose']);
  });

  test('an encoder failure disposes rather than leaking the output', () async {
    final FakeEncoder encoder = FakeEncoder()..failOnFrame = 2;
    await expectLater(
      InAppExporter.export(
        composition: compose(durationInFrames: 10),
        encoder: encoder,
        outputPath: '/tmp/x.mp4',
      ),
      throwsA(isA<EncoderException>()),
    );
    expect(encoder.calls, <String>['start', 'dispose']);
  });

  test('refuses a composition with video rather than exporting a hole',
      () async {
    // Video is structural: a rectangle of nothing where the footage should be
    // is worse than a clear refusal naming what is missing.
    await expectLater(
      InAppExporter.export(
        composition: compose(
          builder: (BuildContext context) =>
              const VideoClip(src: 'assets/clip.mp4'),
        ),
        encoder: FakeEncoder(),
        outputPath: '/tmp/x.mp4',
      ),
      throwsA(isA<EncoderException>().having(
        (EncoderException e) => e.message,
        'message',
        allOf(contains('video'), contains('videoBackend')),
      )),
    );
  });

  test('an encoder that cannot mix says so, and still exports the frames',
      () async {
    final ExportResult result = await InAppExporter.export(
      composition: compose(
        builder: (BuildContext context) => const Audio(src: 'a.mp3'),
      ),
      encoder: FakeEncoder(),
      outputPath: '/tmp/x.mp4',
    );

    expect(result.frames, 5);
    expect(result.warnings, contains(contains('writes video only')));
  });

  test('a sound that is nowhere is named, not silently dropped', () async {
    // Audio is additive, so this is a warning rather than a refusal -- but a
    // clip going missing without a word is how a video ships without its
    // music and nobody finds out until it is posted.
    final MixingEncoder encoder = MixingEncoder();
    final ExportResult result = await InAppExporter.export(
      composition: compose(
        builder: (BuildContext context) => const Audio(src: 'nowhere.mp3'),
      ),
      encoder: encoder,
      outputPath: '/tmp/x.mp4',
    );

    expect(result.frames, 5);
    expect(result.warnings, contains(contains('nowhere.mp3')));
    expect(encoder.tracks, isEmpty);
  });

  test('an audio-capable encoder is handed the clip, placed', () async {
    final Directory dir = Directory.systemTemp.createTempSync('fm_export');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/a.mp3').writeAsBytesSync(<int>[0]);

    final MixingEncoder encoder = MixingEncoder();
    final ExportResult result = await InAppExporter.export(
      composition: compose(
        builder: (BuildContext context) => const Sequence(
          from: 1,
          durationInFrames: 3,
          child: Audio(src: 'a.mp3', volume: 0.4),
        ),
      ),
      encoder: encoder,
      outputPath: '/tmp/x.mp4',
      projectPath: dir.path,
    );

    expect(result.warnings, isEmpty);
    final AudioTrackRequest track = encoder.tracks.single;
    expect(track.path, '${dir.path}/a.mp3');
    expect(track.startFrame, 1);
    expect(track.endFrame, 3);
    expect(track.volume, 0.4);
  });

  test('the encoder is told the length before the first frame', () async {
    // An encoder writing an audio track has to clamp it to the video, and
    // cannot wait until the last frame to learn how long that is.
    final MixingEncoder encoder = MixingEncoder();
    await InAppExporter.export(
      composition: compose(),
      encoder: encoder,
      outputPath: '/tmp/x.mp4',
    );
    expect(encoder.settings!.totalFrames, 5);
  });

  test('rejects a scale that cannot produce an encodable frame', () async {
    await expectLater(
      InAppExporter.export(
        composition: compose(width: 64, height: 32),
        encoder: FakeEncoder(),
        outputPath: '/tmp/x.mp4',
        scale: 0.01,
      ),
      throwsArgumentError,
    );
  });
}
