import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'args.dart';
import 'audio_mixer.dart';
import 'document_entry.dart';
import 'host.dart';

/// Renders a composition to MP4 by sharding frame ranges across host
/// processes.
///
/// Sharding rather than pipelining is deliberate: the spike measured that
/// overlapping in-flight rasterisations inside one process yields no reliable
/// gain, because the raster path is already saturated. Separate processes are
/// the only lever that might scale -- see `--shards`.
Future<int> renderCommand(CliArgs args) async {
  final Directory projectDir = Directory(args.value('project', '.'));
  if (!projectDir.existsSync()) {
    stderr.writeln('No such project directory: ${projectDir.path}');
    return 1;
  }

  final String ffmpeg = await _resolveFfmpeg(args.optional('ffmpeg'));
  final HostTarget target = hostTargetFor(args, projectDir);
  final RenderHost host = RenderHost(
    projectDir: projectDir,
    entryPoint: target.entryPoint,
    flutter: args.value('flutter', 'flutter'),
    allowSandbox: args.flag('allow-sandbox'),
    hostArgs: target.hostArgs,
  );

  final File binary = args.flag('no-build')
      ? host.locateBinary()
      : await host.build(log: stdout.writeln);

  final List<CompositionInfo> available = await host.list(binary);
  if (available.isEmpty) {
    stderr.writeln('The host defines no compositions.');
    return 1;
  }

  final String? requested = args.optional('composition');
  final CompositionInfo info;
  if (requested == null) {
    if (available.length > 1) {
      stderr.writeln(
        'Multiple compositions available; pass --composition <id>:\n'
        '${available.map((CompositionInfo c) => '  ${c.id}').join('\n')}',
      );
      return 1;
    }
    info = available.single;
  } else {
    final Iterable<CompositionInfo> matches =
        available.where((CompositionInfo c) => c.id == requested);
    if (matches.isEmpty) {
      stderr.writeln(
        'No composition "$requested". Available: '
        '${available.map((CompositionInfo c) => c.id).join(', ')}',
      );
      return 1;
    }
    info = matches.first;
  }

  // CLI overrides win over what the composition declares.
  final (int, int)? size = args.optionalSize('size');
  final int width = size?.$1 ?? args.optionalInt('width') ?? info.width;
  final int height = size?.$2 ?? args.optionalInt('height') ?? info.height;
  final int fps = args.optionalInt('fps') ?? info.fps;
  final int frames = args.optionalInt('frames') ?? info.durationInFrames;

  final String outPath = args.value('out', '${info.id}.mp4');
  final int shards = _resolveShards(args.optional('shards'), frames);

  stdout.writeln(
    'Rendering ${info.id}  ${width}x$height @${fps}fps  '
    '$frames frames (${(frames / fps).toStringAsFixed(2)}s)  '
    'across $shards ${shards == 1 ? 'process' : 'processes'}',
  );

  final Directory work =
      Directory.systemTemp.createTempSync('fluttermotion_render_');
  final Stopwatch stopwatch = Stopwatch()..start();

  try {
    final List<_Shard> plan = _planShards(frames, shards, work);
    int completed = 0;
    final int total = frames;
    Map<String, Object?>? manifest;

    void reportProgress() {
      completed++;
      if (completed % 10 != 0 && completed != total) return;
      final double pct = 100 * completed / total;
      stdout.write('\r  ${pct.toStringAsFixed(1)}%  '
          '($completed/$total frames)   ');
    }

    await Future.wait(<Future<void>>[
      for (final _Shard shard in plan)
        _runShard(
          binary: binary,
          shard: shard,
          compositionId: info.id,
          width: width,
          height: height,
          fps: fps,
          frames: frames,
          ffmpeg: ffmpeg,
          ffprobe: args.optional('ffprobe'),
          projectPath: projectDir.absolute.path,
          codec: args.value('codec', 'h264_videotoolbox'),
          bitrate: args.value('bitrate', '12M'),
          onFrame: reportProgress,
          onManifest: (Map<String, Object?> m) => manifest ??= m,
          hostArgs: target.hostArgs,
        ),
    ]);
    stdout.writeln();
    _reportVideoWarnings(manifest);

    final List<AudioClip> clips = args.flag('no-audio')
        ? const <AudioClip>[]
        : _resolveAudio(manifest, projectDir);

    if (clips.isEmpty) {
      await _concat(plan, outPath, ffmpeg);
    } else {
      // Audio is mixed once against the *concatenated* video, never per
      // shard: a clip can straddle a shard boundary, and a shard knows
      // nothing about the frames outside its own range.
      final String silent = '${work.path}/silent.mp4';
      await _concat(plan, silent, ffmpeg);
      stdout.writeln(
        '  mixing ${clips.length} audio '
        '${clips.length == 1 ? 'clip' : 'clips'}',
      );
      await mixAudio(
        ffmpeg: ffmpeg,
        plan: buildAudioMixPlan(
          clips: clips,
          videoPath: silent,
          outPath: outPath,
          fps: fps,
          totalFrames: frames,
          audioCodec: args.value('audio-codec', 'aac'),
          audioBitrate: args.value('audio-bitrate', '192k'),
        ),
      );
    }
    stopwatch.stop();

    final File out = File(outPath);
    final double seconds = stopwatch.elapsedMilliseconds / 1000;
    final double videoSeconds = frames / fps;
    stdout.writeln(
      'Wrote $outPath  '
      '(${(out.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB) '
      'in ${seconds.toStringAsFixed(2)}s  '
      '= ${(videoSeconds / seconds).toStringAsFixed(2)}x realtime',
    );
    return 0;
  } finally {
    if (!args.flag('keep-temp')) {
      work.deleteSync(recursive: true);
    } else {
      stdout.writeln('Segments kept in ${work.path}');
    }
  }
}

class _Shard {
  _Shard({required this.index, required this.start, required this.end,
      required this.output});
  final int index;
  final int start;
  final int end;
  final String output;
  int get frames => end - start;
}

List<_Shard> _planShards(int frames, int shards, Directory work) {
  final List<_Shard> plan = <_Shard>[];
  // Distribute the remainder over the leading shards so ranges stay
  // contiguous and no shard is empty.
  final int base = frames ~/ shards;
  final int remainder = frames % shards;
  int cursor = 0;
  for (int i = 0; i < shards; i++) {
    final int length = base + (i < remainder ? 1 : 0);
    if (length == 0) continue;
    plan.add(_Shard(
      index: i,
      start: cursor,
      end: cursor + length,
      output: '${work.path}/segment_${i.toString().padLeft(3, '0')}.mp4',
    ));
    cursor += length;
  }
  assert(cursor == frames);
  return plan;
}

Future<void> _runShard({
  required File binary,
  required _Shard shard,
  required String compositionId,
  required int width,
  required int height,
  required int fps,
  required int frames,
  required String ffmpeg,
  required String? ffprobe,
  required String projectPath,
  required String codec,
  required String bitrate,
  required void Function() onFrame,
  required void Function(Map<String, Object?>) onManifest,
  List<String> hostArgs = const <String>[],
}) async {
  final Process process = await Process.start(binary.path, <String>[
    '--composition', compositionId,
    '--start', '${shard.start}',
    '--end', '${shard.end}',
    '--out', shard.output,
    '--width', '$width',
    '--height', '$height',
    '--fps', '$fps',
    '--duration-in-frames', '$frames',
    '--ffmpeg', ffmpeg,
    if (ffprobe != null) ...<String>['--ffprobe', ffprobe],
    // The host resolves audio and video paths against this; its own working
    // directory is the CLI's, not the project's.
    '--project', projectPath,
    '--codec', codec,
    '--bitrate', bitrate,
    ...hostArgs,
  ]);

  String? failure;
  final Completer<void> done = Completer<void>();

  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((String line) {
    final Map<String, Object?>? event = decodeHostEvent(line);
    if (event == null) return;
    switch (event['event']) {
      case 'frame':
        onFrame();
      case 'manifest':
        onManifest(event);
      case 'error':
        failure = '${event['message']}\n${event['stack']}';
      default:
        break;
    }
  }, onDone: () {
    if (!done.isCompleted) done.complete();
  });

  final StringBuffer errors = StringBuffer();
  process.stderr.transform(utf8.decoder).listen(errors.write);

  final int code = await process.exitCode;
  await done.future;

  if (code != 0) {
    throw StateError(
      'Shard ${shard.index} (frames ${shard.start}-${shard.end}) failed '
      'with exit code $code.\n${failure ?? errors.toString().trim()}',
    );
  }
}

/// Stream-copies the segments together. Each segment is independently
/// decodable (the encoder opens every segment with a keyframe), so no
/// re-encode is needed and the result is bit-identical to the shard output.
Future<void> _concat(
  List<_Shard> plan,
  String outPath,
  String ffmpeg,
) async {
  if (plan.length == 1) {
    File(plan.single.output).copySync(outPath);
    return;
  }
  final File list = File('${File(plan.first.output).parent.path}/segments.txt');
  list.writeAsStringSync(
    plan.map((_Shard s) => "file '${s.output}'").join('\n'),
  );

  final ProcessResult result = await Process.run(ffmpeg, <String>[
    '-y',
    '-hide_banner',
    '-loglevel', 'error',
    '-f', 'concat',
    '-safe', '0',
    '-i', list.path,
    '-c', 'copy',
    outPath,
  ]);
  if (result.exitCode != 0) {
    throw StateError('Concat failed:\n${result.stderr}');
  }
}

/// A clip whose source runs out mid-window is a real mistake that would
/// otherwise show up as an unexplained freeze in the export.
void _reportVideoWarnings(Map<String, Object?>? manifest) {
  final List<Object?> warnings =
      (manifest?['videoWarnings'] as List<Object?>?) ?? const <Object?>[];
  for (final Object? warning in warnings) {
    stdout.writeln('Warning: $warning');
  }
}

/// Turns the manifest's audio timeline into clips with on-disk paths.
///
/// `src` is a filesystem path relative to the project directory, NOT a Flutter
/// asset key -- ffmpeg reads these files directly and knows nothing about the
/// asset bundle. For a file under `assets/` the two strings happen to match,
/// which is convenient but coincidental; a clip that resolves to nothing is
/// reported rather than silently dropped.
List<AudioClip> _resolveAudio(
  Map<String, Object?>? manifest,
  Directory projectDir,
) {
  if (manifest == null) return const <AudioClip>[];
  final List<Object?> raw =
      (manifest['audio'] as List<Object?>?) ?? const <Object?>[];

  final List<AudioClip> clips = <AudioClip>[];
  final List<String> missing = <String>[];
  for (final Object? entry in raw) {
    final AudioClip clip =
        AudioClip.fromJson(entry! as Map<String, Object?>).resolvedAgainst(
      projectDir.absolute.path,
    );
    if (File(clip.src).existsSync()) {
      clips.add(clip);
    } else {
      missing.add(clip.src);
    }
  }

  if (missing.isNotEmpty) {
    stdout.writeln(
      'Warning: ${missing.length} audio '
      '${missing.length == 1 ? 'clip' : 'clips'} could not be found on disk '
      'and will be missing from the output:\n'
      '${missing.map((String m) => '  $m').join('\n')}',
    );
  }
  return clips;
}

int _resolveShards(String? raw, int frames) {
  if (raw == null || raw == 'auto') {
    // Conservative default. Whether more processes actually help is a GPU
    // contention question, not a CPU one -- measure before raising this.
    return frames < 4 ? 1 : 4;
  }
  final int? parsed = int.tryParse(raw);
  if (parsed == null || parsed < 1) {
    throw FormatException('--shards must be a positive integer or "auto"');
  }
  return parsed > frames ? frames : parsed;
}

Future<String> _resolveFfmpeg(String? override) async {
  if (override != null) return override;
  for (final String candidate in <String>[
    '/opt/homebrew/bin/ffmpeg',
    '/usr/local/bin/ffmpeg',
    '/usr/bin/ffmpeg',
  ]) {
    if (File(candidate).existsSync()) return candidate;
  }
  final ProcessResult which = await Process.run('which', <String>['ffmpeg']);
  if (which.exitCode == 0) {
    return (which.stdout as String).trim();
  }
  throw StateError(
    'ffmpeg not found. Install it (brew install ffmpeg) or pass --ffmpeg.',
  );
}
