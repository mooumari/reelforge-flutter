import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_encoder/fluttermotion_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(NativeVideoEncoder.channelName);
  final List<MethodCall> calls = <MethodCall>[];
  Object? Function(MethodCall)? handler;

  setUp(() {
    calls.clear();
    handler = (MethodCall call) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return handler!(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  NativeVideoEncoder encoder() => NativeVideoEncoder(channel: channel);

  test('start sends the resolved settings, not the raw ones', () async {
    await encoder().start(const EncoderSettings(
      outputPath: '/tmp/a.mp4',
      width: 1920,
      height: 1080,
      fps: 60,
    ));

    expect(calls.single.method, 'start');
    final Map<Object?, Object?> args =
        calls.single.arguments as Map<Object?, Object?>;
    expect(args['width'], 1920);
    expect(args['fps'], 60);
    // The platform side must never have to guess a bitrate.
    expect(args['bitrate'], isA<int>());
    expect(args['bitrate'], greaterThan(0));
  });

  test('frames cross as raw bytes, with their index', () async {
    final NativeVideoEncoder e = encoder();
    await e.start(const EncoderSettings(
        outputPath: '/tmp/a.mp4', width: 2, height: 2, fps: 30));
    await e.addFrame(Uint8List(2 * 2 * 4), 7);

    final MethodCall call = calls.last;
    expect(call.method, 'addFrame');
    final Map<Object?, Object?> args = call.arguments as Map<Object?, Object?>;
    expect(args['index'], 7);
    // Typed data, so the codec copies memory rather than encoding text.
    expect(args['frame'], isA<Uint8List>());
    expect((args['frame']! as Uint8List).length, 16);
  });

  test('a platform failure becomes an EncoderException', () async {
    handler = (MethodCall call) {
      if (call.method == 'addFrame') {
        throw PlatformException(code: 'append-failed', message: 'rejected');
      }
      return null;
    };

    final NativeVideoEncoder e = encoder();
    await e.start(const EncoderSettings(
        outputPath: '/tmp/a.mp4', width: 2, height: 2, fps: 30));

    await expectLater(
      e.addFrame(Uint8List(16), 0),
      throwsA(isA<EncoderException>().having(
          (EncoderException x) => x.message, 'message', contains('rejected'))),
    );
  });

  test('a missing plugin says to rebuild rather than hot restart', () async {
    handler = (MethodCall call) => throw MissingPluginException();
    await expectLater(
      encoder().start(const EncoderSettings(
          outputPath: '/tmp/a.mp4', width: 2, height: 2, fps: 30)),
      throwsA(isA<EncoderException>().having(
          (EncoderException x) => x.message, 'message', contains('rebuild'))),
    );
  });

  test('dispose before a successful start does not call through', () async {
    handler = (MethodCall call) => throw MissingPluginException();
    try {
      await encoder().start(const EncoderSettings(
          outputPath: '/tmp/a.mp4', width: 2, height: 2, fps: 30));
    } on EncoderException {
      // expected
    }
    calls.clear();

    // The exporter always disposes; a second error from a teardown that had
    // nothing to tear down would bury the real one.
    handler = (MethodCall call) => null;
    await encoder().dispose();
    expect(calls, isEmpty);
  });

  test('finish then dispose releases the native side exactly once', () async {
    final NativeVideoEncoder e = encoder();
    await e.start(const EncoderSettings(
        outputPath: '/tmp/a.mp4', width: 2, height: 2, fps: 30));
    await e.finish();
    await e.dispose();

    expect(calls.map((MethodCall c) => c.method),
        <String>['start', 'finish']);
  });
}
