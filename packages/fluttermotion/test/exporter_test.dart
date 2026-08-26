import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion/fluttermotion.dart';

/// Records what the exporter asked of it, so the pipeline can be tested
/// without a single line of platform code.
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
    // In-app video decoding does not exist yet; a rectangle of nothing where
    // the footage should be is worse than a clear refusal.
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
        allOf(contains('video'), contains('ffmpeg')),
      )),
    );
  });

  test('warns about declared audio but still exports the frames', () async {
    final FakeEncoder encoder = FakeEncoder();
    final ExportResult result = await InAppExporter.export(
      composition: compose(
        builder: (BuildContext context) => const Audio(src: 'a.mp3'),
      ),
      encoder: encoder,
      outputPath: '/tmp/x.mp4',
    );

    expect(result.frames, 5);
    expect(result.warnings, contains(contains('not mixed')));
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
