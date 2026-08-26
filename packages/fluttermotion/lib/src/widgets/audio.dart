import 'package:flutter/widgets.dart';

import '../declarations/manifest.dart';
import '../declarations/scope.dart';
import '../frame.dart';

/// Places a sound on the timeline.
///
/// Draws nothing. Its position and length come from where it is mounted, so
/// wrapping it in a [Sequence] is how you schedule it:
///
/// ```dart
/// Sequence(
///   from: 30,
///   durationInFrames: 90,
///   child: Audio(src: 'assets/whoosh.mp3'),
/// )
/// ```
///
/// Audio is never played by Flutter. The declaration pass collects these and
/// the encoder mixes them, which is why a composition stays a pure function of
/// frame number.
class Audio extends StatelessWidget {
  const Audio({
    super.key,
    required this.src,
    this.volume = 1.0,
    this.trimStartInFrames = 0,
    this.loop = false,
  })  : assert(volume >= 0),
        assert(trimStartInFrames >= 0);

  /// Path to the audio file, resolved relative to the project being rendered.
  final String src;

  final double volume;

  /// How far into the source file playback starts.
  final int trimStartInFrames;

  final bool loop;

  @override
  Widget build(BuildContext context) {
    // Depend on the frame so this rebuilds on every frame of the pass. The
    // collector infers the clip's range from which frames it was seen on, and
    // a widget that builds once would register a single frame and look like a
    // one-frame blip. The local frame is not used -- the collector places the
    // clip on the composition's own timeline.
    Video.frame(context);

    DeclarationScope.maybeOf(context)?.declareAudio(
      AudioDeclaration(
        src: src,
        volume: volume,
        trimStartInFrames: trimStartInFrames,
        loop: loop,
      ),
    );
    return const SizedBox.shrink();
  }
}
