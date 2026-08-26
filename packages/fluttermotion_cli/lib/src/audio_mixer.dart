import 'dart:io';

/// One sound placed on the timeline, as reported by the declaration pass.
class AudioClip {
  const AudioClip({
    required this.src,
    required this.startFrame,
    required this.endFrame,
    required this.volume,
    required this.trimStartInFrames,
    required this.loop,
  });

  factory AudioClip.fromJson(Map<String, Object?> json) => AudioClip(
        src: json['src']! as String,
        startFrame: json['startFrame']! as int,
        endFrame: json['endFrame']! as int,
        volume: (json['volume']! as num).toDouble(),
        trimStartInFrames: json['trimStartInFrames']! as int,
        loop: json['loop']! as bool,
      );

  final String src;
  final int startFrame;
  final int endFrame;
  final double volume;
  final int trimStartInFrames;
  final bool loop;

  int get durationInFrames => endFrame - startFrame + 1;

  /// Re-roots a relative `src` on the project directory, leaving absolute
  /// paths alone.
  AudioClip resolvedAgainst(String projectPath) {
    if (src.startsWith('/')) return this;
    return AudioClip(
      src: '$projectPath/$src',
      startFrame: startFrame,
      endFrame: endFrame,
      volume: volume,
      trimStartInFrames: trimStartInFrames,
      loop: loop,
    );
  }
}

/// The ffmpeg invocation that lays the declared clips over a silent video.
///
/// Built as a pure function so the filter graph can be tested without running
/// ffmpeg -- getting a delay or a trim wrong is silent (literally) and would
/// otherwise only show up by listening.
class AudioMixPlan {
  const AudioMixPlan({required this.args, required this.filterGraph});

  final List<String> args;
  final String filterGraph;
}

/// Seconds, formatted so ffmpeg parses it exactly and tests can assert on it.
String _seconds(int frames, int fps) => (frames / fps).toStringAsFixed(6);

AudioMixPlan buildAudioMixPlan({
  required List<AudioClip> clips,
  required String videoPath,
  required String outPath,
  required int fps,
  required int totalFrames,
  String Function(String src)? resolveSrc,
  String audioCodec = 'aac',
  String audioBitrate = '192k',
}) {
  assert(clips.isNotEmpty, 'buildAudioMixPlan called with no clips');

  final List<String> inputs = <String>[];
  final List<String> filters = <String>[];
  final List<String> labels = <String>[];

  for (int i = 0; i < clips.length; i++) {
    final AudioClip clip = clips[i];
    final String path = resolveSrc?.call(clip.src) ?? clip.src;

    // Looping is done at the input, which is far simpler than aloop's
    // sample-counted form and works for any source length.
    if (clip.loop) {
      inputs.addAll(<String>['-stream_loop', '-1']);
    }
    inputs.addAll(<String>['-i', path]);

    // Input 0 is the video, so audio inputs start at 1.
    final int stream = i + 1;
    final String label = 'a$stream';
    labels.add('[$label]');

    final List<String> chain = <String>[
      'atrim=start=${_seconds(clip.trimStartInFrames, fps)}'
          ':duration=${_seconds(clip.durationInFrames, fps)}',
      // Rebase timestamps after trimming, or adelay would compound with the
      // original offset.
      'asetpts=PTS-STARTPTS',
      // Resample to a common rate so amix does not have to guess.
      'aresample=48000',
      if (clip.volume != 1.0) 'volume=${clip.volume}',
      // all=1 delays every channel, not just the first.
      'adelay=${(clip.startFrame / fps * 1000).round()}:all=1',
    ];
    filters.add('[$stream:a]${chain.join(',')}[$label]');
  }

  if (clips.length == 1) {
    filters.add('${labels.single}anull[aout]');
  } else {
    // normalize=0: without it amix divides by the input count, so adding a
    // quiet sound effect would duck the music under it.
    filters.add(
      '${labels.join()}amix=inputs=${clips.length}'
      ':normalize=0:dropout_transition=0[aout]',
    );
  }

  final String filterGraph = filters.join(';');

  return AudioMixPlan(
    filterGraph: filterGraph,
    args: <String>[
      '-y',
      '-hide_banner',
      '-loglevel', 'error',
      '-i', videoPath,
      ...inputs,
      '-filter_complex', filterGraph,
      '-map', '0:v',
      '-map', '[aout]',
      // The video is already encoded; only the audio needs work.
      '-c:v', 'copy',
      '-c:a', audioCodec,
      '-b:a', audioBitrate,
      // Clamp to the video's length in case a clip runs past the end.
      '-t', _seconds(totalFrames, fps),
      outPath,
    ],
  );
}

/// Runs the mix, turning ffmpeg's diagnostics into a useful error.
Future<void> mixAudio({
  required AudioMixPlan plan,
  required String ffmpeg,
}) async {
  final ProcessResult result = await Process.run(ffmpeg, plan.args);
  if (result.exitCode != 0) {
    throw StateError(
      'Mixing audio failed (${result.exitCode}).\n'
      'Filter graph:\n  ${plan.filterGraph}\n'
      '${(result.stderr as String).trim()}',
    );
  }
}
