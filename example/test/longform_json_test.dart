import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion/fluttermotion.dart';

import 'package:example/longform.dart';
import 'package:example/longform_json.dart';
import 'package:example/report_data.dart';

/// The claim `fluttermotion_json` has to earn.
///
/// A document is meant to be the same video by a different route, not an
/// approximation of it. The strongest available check is the declaration
/// manifest: it is derived by walking all 1800 frames and recording what each
/// one mounts, so it catches a scene that is a frame too long, a sting on the
/// wrong cut, a clip that forgot to loop, or a trim that landed elsewhere --
/// every structural thing a hand-written document could plausibly get wrong.
///
/// It does not compare pixels, because a test binding cannot: rasterising one
/// 1080x1920 frame under `flutter test` takes minutes, where the CLI does 1800
/// of them in ten seconds against a real engine and a real view. Pixel
/// equality is checked out of band instead, by rendering both reels with the
/// CLI and comparing the two files -- see the JSON section of the README.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadReport();
    await loadLongformJson();
  });

  testWidgets('the JSON reel declares exactly what the Dart reel does',
      (WidgetTester tester) async {
    expect(longformJson.width, longform.width);
    expect(longformJson.height, longform.height);
    expect(longformJson.fps, longform.fps);
    expect(longformJson.durationInFrames, longform.durationInFrames);

    final RenderManifest fromDart = DeclarationPass.run(longform);
    final RenderManifest fromJson = DeclarationPass.run(longformJson);

    expect(_audio(fromJson), _audio(fromDart));
    expect(_video(fromJson), _video(fromDart));
  });

  testWidgets('the reel is long enough to be worth comparing',
      (WidgetTester tester) async {
    // A guard on the guard. If either reel were somehow empty the comparison
    // above would pass while proving nothing, so the shape it is asserting
    // over is pinned here.
    final RenderManifest manifest = DeclarationPass.run(longformJson);
    expect(longformJson.durationInFrames, 1800);
    expect(manifest.audio, hasLength(8));
    expect(manifest.video, hasLength(3));
  });
}

List<String> _audio(RenderManifest manifest) => <String>[
      for (final AudioTimelineEntry entry in manifest.audio)
        '${entry.declaration.src} ${entry.startFrame}-${entry.endFrame} '
        'vol=${entry.declaration.volume} loop=${entry.declaration.loop} '
        'trim=${entry.declaration.trimStartInFrames}',
    ]..sort();

List<String> _video(RenderManifest manifest) => <String>[
      for (final VideoTimelineEntry entry in manifest.video)
        '${entry.declaration.src} ${entry.startFrame}-${entry.endFrame} '
        'loop=${entry.declaration.loop} '
        'trim=${entry.declaration.trimStartInFrames}',
    ]..sort();

