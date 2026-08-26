import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_encoder/fluttermotion_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(NativeVideoBackend.channelName);
  final List<MethodCall> calls = <MethodCall>[];

  /// Frames the fake platform will hand out, oldest first.
  late int remaining;

  setUp(() {
    calls.clear();
    remaining = 1000;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'probe':
          return <String, Object?>{
            'width': 320,
            'height': 240,
            'duration': 2.0,
          };
        case 'open':
          return <String, Object?>{'handle': 1, 'width': 320, 'height': 240};
        case 'nextFrame':
          if (remaining <= 0) return null;
          remaining--;
          // 2x2 RGBA, which is all decodeImageFromPixels needs.
          return Uint8List(2 * 2 * 4);
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  VideoFrameSource source({
    VideoDeclaration declaration = const VideoDeclaration(src: 'a.mp4'),
    int startFrame = 10,
    int endFrame = 40,
  }) {
    return NativeVideoFrameSource(
      channel: channel,
      declaration: declaration,
      startFrame: startFrame,
      endFrame: endFrame,
      fps: 60,
      path: '/tmp/a.mp4',
      // 2x2 so the bytes the fake returns are the right length.
      info: const VideoSourceInfo(width: 2, height: 2, durationInSeconds: 2),
    );
  }

  List<String> methods() =>
      calls.map((MethodCall call) => call.method).toList();

  group('probing', () {
    test('reports what the platform found', () async {
      final VideoSourceInfo info =
          await NativeVideoBackend(channel: channel).probe('/tmp/a.mp4');
      expect(info.width, 320);
      expect(info.height, 240);
      expect(info.durationInSeconds, 2.0);
      // 2 seconds at 60fps is 120 frames the clip can cover.
      expect(info.frameCapacity(60), 120);
    });
  });

  group('frame mapping', () {
    test('a clip starts at its own first frame, not the timeline\'s', () {
      // The clip is mounted at composition frame 10, so that frame shows the
      // source's frame 0 -- what a viewer means by "the start of the clip".
      expect(source().sourceFrameFor(10), 0);
      expect(source().sourceFrameFor(25), 15);
    });

    test('a trim offsets the whole mapping', () {
      final VideoFrameSource trimmed = source(
        declaration:
            const VideoDeclaration(src: 'a.mp4', trimStartInFrames: 90),
      );
      expect(trimmed.sourceFrameFor(10), 90);
      expect(trimmed.sourceFrameFor(11), 91);
    });
  });

  group('streaming', () {
    test('opens once at the entry frame and then just reads', () async {
      final VideoFrameSource s = source();
      await s.frameAt(10);
      await s.frameAt(11);
      await s.frameAt(12);

      expect(methods(), <String>['open', 'nextFrame', 'nextFrame', 'nextFrame']);
      // Entering at composition frame 10 means entering the source at 0.
      expect(
        (calls.first.arguments as Map<Object?, Object?>)['startSourceFrame'],
        0,
      );
      await s.dispose();
    });

    test('opening mid-clip enters the source mid-clip', () async {
      final VideoFrameSource s = source();
      await s.frameAt(25);
      expect(
        (calls.first.arguments as Map<Object?, Object?>)['startSourceFrame'],
        15,
      );
      await s.dispose();
    });

    test('the same frame twice does not decode twice', () async {
      final VideoFrameSource s = source();
      await s.frameAt(10);
      await s.frameAt(10);
      expect(methods(), <String>['open', 'nextFrame']);
      await s.dispose();
    });
  });

  group('seeking', () {
    test('a non-adjacent jump seeks, in source frames', () async {
      final VideoFrameSource s = source();
      await s.frameAt(10);
      await s.frameAt(30);

      expect(methods(), <String>['open', 'nextFrame', 'seek', 'nextFrame']);
      final Map<Object?, Object?> seek =
          calls[2].arguments as Map<Object?, Object?>;
      expect(seek['sourceFrame'], 20);
      expect(seek['handle'], 1);
      await s.dispose();
    });

    test('scrubbing backwards seeks rather than reading forwards', () async {
      final VideoFrameSource s = source();
      await s.frameAt(20);
      await s.frameAt(11);

      expect(methods().where((String m) => m == 'seek'), hasLength(1));
      expect((calls[2].arguments as Map<Object?, Object?>)['sourceFrame'], 1);
      await s.dispose();
    });
  });

  group('running out', () {
    test('a source shorter than its window holds its last frame', () async {
      final VideoFrameSource s = source();
      remaining = 2;
      await s.frameAt(10);
      final Object? last = await s.frameAt(11);
      final Object? beyond = await s.frameAt(12);

      // Not an error and not a black flash: the declaration pass has already
      // warned about this clip by name.
      expect(s.exhausted, isTrue);
      expect(beyond, same(last));
      await s.dispose();
    });

    test('holding the last frame does not re-read the source', () async {
      // Found by rendering a 60-second reel: a clip mounted seven seconds
      // longer than it lasts re-opened the decoder on every frame past the
      // end, decoded the whole file, and got nothing back. Three such clips
      // dominated the render -- 63 seconds of work for 14 seconds of frames.
      final VideoFrameSource s = source(endFrame: 200);
      remaining = 1;
      await s.frameAt(10);
      await s.frameAt(11);
      expect(s.exhausted, isTrue);

      final int before = calls.length;
      for (int f = 12; f < 60; f++) {
        await s.frameAt(f);
      }
      expect(calls.length, before,
          reason: '48 frames past the end should cost nothing');
      await s.dispose();
    });

    test('scrubbing back before the end decodes again', () async {
      final VideoFrameSource s = source(endFrame: 200);
      remaining = 1;
      await s.frameAt(10);
      await s.frameAt(11);
      await s.frameAt(30);
      expect(s.exhausted, isTrue);

      // Back inside the part of the source that does exist.
      remaining = 5;
      await s.frameAt(10);
      expect(methods().where((String m) => m == 'seek'), hasLength(1));
      await s.dispose();
    });

    test('the next request after running dry re-enters the source', () async {
      final VideoFrameSource s = source();
      remaining = 1;
      await s.frameAt(10);
      await s.frameAt(11);
      expect(s.exhausted, isTrue);

      // A frame *before* the point it ran dry is a legitimate re-read: the
      // source has those frames, it just did not have the later ones.
      remaining = 5;
      await s.frameAt(10);
      expect(methods().where((String m) => m == 'seek'), hasLength(1));
      expect(s.exhausted, isFalse);
      await s.dispose();
    });
  });

  group('closing', () {
    test('dispose closes the platform decoder exactly once', () async {
      final VideoFrameSource s = source();
      await s.frameAt(10);
      await s.dispose();
      await s.dispose();

      expect(methods().where((String m) => m == 'close'), hasLength(1));
      expect((calls.last.arguments as Map<Object?, Object?>)['handle'], 1);
    });

    test('a source that never decoded closes nothing', () async {
      await source().dispose();
      expect(methods(), isEmpty);
    });
  });
}
