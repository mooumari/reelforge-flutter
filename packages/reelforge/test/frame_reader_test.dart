import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/src/media/frame_reader.dart';

/// Bytes 0,1,2,... so a misassembled frame is obvious rather than plausible.
Uint8List ramp(int start, int length) =>
    Uint8List.fromList(<int>[for (int i = 0; i < length; i++) (start + i) % 251]);

void main() {
  group('FrameReader', () {
    test('reassembles a frame split across many chunks', () async {
      final StreamController<List<int>> source = StreamController<List<int>>();
      final FrameReader reader =
          FrameReader(source.stream, maxBufferedBytes: 1024);

      final Future<Uint8List?> pending = reader.read(10);
      // Deliberately ragged: 3 + 3 + 4.
      source.add(ramp(0, 3));
      source.add(ramp(3, 3));
      source.add(ramp(6, 4));

      expect(await pending, ramp(0, 10));
      await source.close();
    });

    test('splits one chunk across several frames, keeping the remainder',
        () async {
      final StreamController<List<int>> source = StreamController<List<int>>();
      final FrameReader reader =
          FrameReader(source.stream, maxBufferedBytes: 1024);

      source.add(ramp(0, 25));
      expect(await reader.read(10), ramp(0, 10));
      expect(await reader.read(10), ramp(10, 10));

      // The 5 left over must survive until the rest arrives.
      final Future<Uint8List?> pending = reader.read(10);
      source.add(ramp(25, 5));
      expect(await pending, ramp(20, 10));
      await source.close();
    });

    test('returns null when the stream ends mid-frame', () async {
      final StreamController<List<int>> source = StreamController<List<int>>();
      final FrameReader reader =
          FrameReader(source.stream, maxBufferedBytes: 1024);

      source.add(ramp(0, 4));
      final Future<Uint8List?> pending = reader.read(10);
      await source.close();

      // A short read is the source running out, not a frame of garbage.
      expect(await pending, isNull);
    });

    test('returns null immediately once the stream has already ended',
        () async {
      final StreamController<List<int>> source = StreamController<List<int>>();
      final FrameReader reader =
          FrameReader(source.stream, maxBufferedBytes: 1024);
      await source.close();
      await pumpEventQueue();
      expect(await reader.read(10), isNull);
    });

    test('serves a buffered frame without waiting for more data', () async {
      final StreamController<List<int>> source = StreamController<List<int>>();
      final FrameReader reader =
          FrameReader(source.stream, maxBufferedBytes: 1024);
      source.add(ramp(0, 40));
      await pumpEventQueue();

      // No further data will arrive; this must still complete.
      expect(await reader.read(10).timeout(const Duration(seconds: 1)),
          ramp(0, 10));
      await source.close();
    });

    test('pauses the source once buffered, and resumes on read', () async {
      bool paused = false;
      final StreamController<List<int>> source = StreamController<List<int>>(
        onPause: () => paused = true,
        onResume: () => paused = false,
      );
      final FrameReader reader =
          FrameReader(source.stream, maxBufferedBytes: 20);

      source.add(ramp(0, 30));
      await pumpEventQueue();
      // A 1080p frame is 8 MB; letting ffmpeg run ahead unbounded would cost
      // hundreds of megabytes on a long clip.
      expect(paused, isTrue);

      // Still at the cap after one frame, so still paused.
      expect(await reader.read(10), ramp(0, 10));
      expect(paused, isTrue);

      // Below the cap now: ffmpeg is let go again without waiting for a read
      // to block, which is what keeps the pipe flowing instead of stuttering.
      expect(await reader.read(10), ramp(10, 10));
      await pumpEventQueue();
      expect(paused, isFalse);

      final Future<Uint8List?> pending = reader.read(10);
      source.add(ramp(30, 10));
      expect(await pending, ramp(20, 10));
      await source.close();
    });

    test('propagates a stream error rather than yielding a partial frame',
        () async {
      final StreamController<List<int>> source = StreamController<List<int>>();
      final FrameReader reader =
          FrameReader(source.stream, maxBufferedBytes: 1024);
      final Future<Uint8List?> pending = reader.read(10);
      source.addError(StateError('ffmpeg died'));
      await expectLater(pending, throwsStateError);
      await source.close();
    });
  });
}
