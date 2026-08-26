import 'package:flutter/widgets.dart';

import 'manifest.dart';

/// Gathers declarations while the timeline is swept.
///
/// A widget declares by simply being mounted: the collector records the frame
/// it was seen on, and contiguous runs become timeline entries. That is why
/// putting `Audio` inside a [Sequence] positions it correctly with no extra
/// API -- the Sequence already controls whether it is mounted.
class DeclarationCollector {
  int _frame = 0;

  final Map<String, _Run> _audio = <String, _Run>{};
  final Map<ImageProvider<Object>, ImageDeclaration> _images =
      <ImageProvider<Object>, ImageDeclaration>{};

  /// The frame currently being swept. Always the composition's own frame,
  /// never a Sequence-local one, so entries land on the real timeline.
  int get frame => _frame;
  set frame(int value) => _frame = value;

  void declareAudio(AudioDeclaration declaration) {
    final _Run? existing = _audio[declaration.key];
    if (existing == null) {
      _audio[declaration.key] = _Run(declaration, _frame, _frame);
      return;
    }
    // A gap means the clip was unmounted and remounted -- two placements of
    // the same sound. Keep the earliest start and latest end for now and let
    // the split happen below.
    existing.observe(_frame);
  }

  void declareImage(ImageDeclaration declaration) {
    _images.putIfAbsent(declaration.provider, () => declaration);
  }

  RenderManifest build({
    required int framesVisited,
    required Duration elapsed,
  }) {
    final List<AudioTimelineEntry> audio = <AudioTimelineEntry>[
      for (final _Run run in _audio.values)
        for (final (int start, int end) in run.ranges)
          AudioTimelineEntry(
            declaration: run.declaration,
            startFrame: start,
            endFrame: end,
          ),
    ]..sort((AudioTimelineEntry a, AudioTimelineEntry b) =>
        a.startFrame.compareTo(b.startFrame));

    return RenderManifest(
      audio: audio,
      images: _images.values.toList(),
      framesVisited: framesVisited,
      elapsed: elapsed,
    );
  }
}

/// Tracks the frames a declaration was seen on, splitting on gaps so the same
/// sound used twice in a composition becomes two entries rather than one long
/// one spanning the silence between them.
class _Run {
  _Run(this.declaration, int start, int end)
      : ranges = <(int, int)>[(start, end)];

  final AudioDeclaration declaration;
  final List<(int, int)> ranges;

  void observe(int frame) {
    final (int start, int end) = ranges.last;
    if (frame == end || frame == end + 1) {
      ranges[ranges.length - 1] = (start, frame);
    } else if (frame > end + 1) {
      ranges.add((frame, frame));
    }
  }
}

/// Makes the active [DeclarationCollector] available to widgets during a
/// declaration pass. Absent during preview and during rasterisation, so
/// declaring widgets must tolerate a null collector.
class DeclarationScope extends InheritedWidget {
  const DeclarationScope({
    super.key,
    required this.collector,
    required super.child,
  });

  final DeclarationCollector? collector;

  static DeclarationCollector? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DeclarationScope>()
        ?.collector;
  }

  @override
  bool updateShouldNotify(DeclarationScope oldWidget) =>
      collector != oldWidget.collector;
}
