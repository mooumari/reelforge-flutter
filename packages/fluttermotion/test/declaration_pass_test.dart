import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:flutter_test/flutter_test.dart';

Composition withBody(Widget body, {int durationInFrames = 60}) {
  return Composition(
    id: 'T',
    width: 100,
    height: 100,
    fps: 30,
    durationInFrames: durationInFrames,
    builder: (BuildContext context) => Stack(children: <Widget>[body]),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a composition that declares nothing produces an empty manifest', () {
    final RenderManifest manifest =
        DeclarationPass.run(withBody(const SizedBox()));
    expect(manifest.isEmpty, isTrue);
    expect(manifest.framesVisited, 60);
  });

  test('audio spans the frames its widget is mounted on', () {
    final RenderManifest manifest = DeclarationPass.run(
      withBody(
        const Sequence(
          from: 10,
          durationInFrames: 20,
          child: Audio(src: 'whoosh.mp3'),
        ),
      ),
    );
    expect(manifest.audio, hasLength(1));
    final AudioTimelineEntry entry = manifest.audio.single;
    expect(entry.declaration.src, 'whoosh.mp3');
    expect(entry.startFrame, 10);
    expect(entry.endFrame, 29);
    expect(entry.durationInFrames, 20);
  });

  test('audio that runs to the end of the composition is captured', () {
    final RenderManifest manifest = DeclarationPass.run(
      withBody(const Audio(src: 'music.mp3')),
    );
    expect(manifest.audio.single.startFrame, 0);
    expect(manifest.audio.single.endFrame, 59);
  });

  test('the same sound used twice becomes two entries', () {
    final RenderManifest manifest = DeclarationPass.run(
      withBody(
        const Stack(
          children: <Widget>[
            Sequence(from: 0, durationInFrames: 10, child: Audio(src: 'a.mp3')),
            Sequence(from: 40, durationInFrames: 5, child: Audio(src: 'a.mp3')),
          ],
        ),
      ),
    );
    expect(manifest.audio, hasLength(2));
    expect(manifest.audio[0].startFrame, 0);
    expect(manifest.audio[0].endFrame, 9);
    expect(manifest.audio[1].startFrame, 40);
    expect(manifest.audio[1].endFrame, 44);
  });

  test('different volumes are different clips', () {
    final RenderManifest manifest = DeclarationPass.run(
      withBody(
        const Stack(
          children: <Widget>[
            Audio(src: 'a.mp3'),
            Audio(src: 'a.mp3', volume: 0.5),
          ],
        ),
      ),
    );
    expect(manifest.audio, hasLength(2));
  });

  test('a clip lasting a single frame is not missed', () {
    final RenderManifest manifest = DeclarationPass.run(
      withBody(
        const Sequence(
          from: 33,
          durationInFrames: 1,
          child: Audio(src: 'blip.mp3'),
        ),
      ),
    );
    expect(manifest.audio, hasLength(1));
    expect(manifest.audio.single.startFrame, 33);
    expect(manifest.audio.single.endFrame, 33);
  });

  test('nested sequences place audio on the composition timeline', () {
    final RenderManifest manifest = DeclarationPass.run(
      withBody(
        const Sequence(
          from: 10,
          child: Sequence(
            from: 5,
            durationInFrames: 4,
            child: Audio(src: 'nested.mp3'),
          ),
        ),
      ),
    );
    expect(manifest.audio.single.startFrame, 15);
    expect(manifest.audio.single.endFrame, 18);
  });

  test('images are declared once however many frames they appear on', () {
    final RenderManifest manifest = DeclarationPass.run(
      withBody(MotionImage(image: const AssetImage('photo.png'))),
    );
    expect(manifest.images, hasLength(1));
  });

  test('the pass visits every frame and is cheap', () {
    final RenderManifest manifest = DeclarationPass.run(
      withBody(const Audio(src: 'a.mp3'), durationInFrames: 300),
    );
    expect(manifest.framesVisited, 300);
    // Guards the design assumption: sweeping the whole timeline is affordable
    // precisely because building is far cheaper than rasterising.
    expect(manifest.elapsed.inMilliseconds, lessThan(2000));
  });

  test('the manifest serialises for the CLI', () {
    final RenderManifest manifest = DeclarationPass.run(
      withBody(const Sequence(
        from: 5,
        durationInFrames: 10,
        child: Audio(src: 'a.mp3', volume: 0.25, trimStartInFrames: 3),
      )),
    );
    final Map<String, Object?> json = manifest.toJson();
    final List<Object?> audio = json['audio']! as List<Object?>;
    expect(audio, hasLength(1));
    expect((audio.single as Map<String, Object?>)['volume'], 0.25);
    expect((audio.single as Map<String, Object?>)['trimStartInFrames'], 3);
    expect((audio.single as Map<String, Object?>)['startFrame'], 5);
  });
}
