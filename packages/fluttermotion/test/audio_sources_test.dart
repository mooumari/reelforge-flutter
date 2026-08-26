// The same `src` means two different things depending on where the render is:
// a path relative to a project on a laptop, an asset key inside a running app.
// Native encoders can open neither an asset nor a relative path, so this is
// where both become a file.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('fm_audio');
    cache = Directory('${root.path}/cache');
  });
  tearDown(() => root.deleteSync(recursive: true));

  File write(String relative, List<int> bytes) {
    final File file = File('${root.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file;
  }

  AudioSourceResolver resolver({
    String? projectPath,
    AssetLoader? loadAsset,
  }) =>
      AudioSourceResolver(
        cacheDir: cache,
        projectPath: projectPath,
        loadAsset: loadAsset ??
            (String key) => throw StateError('no asset "$key"'),
      );

  test('an absolute path to a real file is used as it is', () async {
    final File file = write('sounds/music.mp3', <int>[1, 2, 3]);
    expect(await resolver().pathFor(file.path), file.path);
  });

  test('a relative path is resolved against the project', () async {
    write('assets/music.mp3', <int>[1, 2, 3]);
    final String path =
        await resolver(projectPath: root.path).pathFor('assets/music.mp3');
    expect(path, '${root.path}/assets/music.mp3');
  });

  test('an asset is spilled to a real file, keeping its extension', () async {
    // The extension is not cosmetic: AVURLAsset decides what a file is by
    // looking at it, so a spilled .mp3 without the suffix will not open.
    final AudioSourceResolver r = resolver(
      loadAsset: (String key) async =>
          ByteData.view(Uint8List.fromList(<int>[9, 8, 7]).buffer),
    );
    final String path = await r.pathFor('assets/music.mp3');
    expect(path, endsWith('.mp3'));
    expect(File(path).readAsBytesSync(), <int>[9, 8, 7]);
  });

  test('two assets with the same basename do not collide', () async {
    final AudioSourceResolver r = resolver(
      loadAsset: (String key) async =>
          ByteData.view(Uint8List.fromList(key.codeUnits).buffer),
    );
    final String a = await r.pathFor('one/hit.wav');
    final String b = await r.pathFor('two/hit.wav');
    expect(a, isNot(b));
    expect(File(a).readAsStringSync(), 'one/hit.wav');
    expect(File(b).readAsStringSync(), 'two/hit.wav');
  });

  test('an asset is only loaded once, however often it is used', () async {
    // A jingle used in eight places is one file, not eight copies of it.
    int loads = 0;
    final AudioSourceResolver r = resolver(loadAsset: (String key) async {
      loads++;
      return ByteData(4);
    });
    final String first = await r.pathFor('assets/chime.mp3');
    final String second = await r.pathFor('assets/chime.mp3');
    expect(second, first);
    expect(loads, 1);
  });

  test('a source that is nowhere says so by name', () async {
    await expectLater(
      resolver().pathFor('assets/missing.mp3'),
      throwsA(
        isA<SourceFileException>().having(
          (SourceFileException e) => e.toString(),
          'message',
          allOf(contains('assets/missing.mp3'), contains('pubspec')),
        ),
      ),
    );
  });

  group('resolving a whole timeline', () {
    AudioTimelineEntry entry(String src, {int start = 0, int end = 10}) =>
        AudioTimelineEntry(
          declaration: AudioDeclaration(src: src, volume: 0.5, loop: true),
          startFrame: start,
          endFrame: end,
        );

    test('carries the placement through untouched', () async {
      write('a.wav', <int>[1]);
      final AudioResolution resolved = await resolver(projectPath: root.path)
          .resolveAll(<AudioTimelineEntry>[entry('a.wav', start: 30, end: 90)]);

      expect(resolved.failures, isEmpty);
      final AudioTrackRequest track = resolved.tracks.single;
      expect(track.startFrame, 30);
      expect(track.endFrame, 90);
      expect(track.durationInFrames, 61);
      expect(track.volume, 0.5);
      expect(track.loop, isTrue);
    });

    test('one missing sound does not lose the others', () async {
      // Audio is additive: an export that drops a chime is still a correct
      // video, so this reports rather than throwing.
      write('there.wav', <int>[1]);
      final AudioResolution resolved =
          await resolver(projectPath: root.path).resolveAll(
        <AudioTimelineEntry>[
          entry('gone.wav'),
          entry('there.wav'),
        ],
      );

      expect(resolved.tracks, hasLength(1));
      expect(resolved.tracks.single.path, endsWith('there.wav'));
      expect(resolved.failures.single, contains('gone.wav'));
    });
  });
}
