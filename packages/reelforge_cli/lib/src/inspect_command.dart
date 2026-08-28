import 'dart:convert';
import 'dart:io';

import 'args.dart';
import 'document_entry.dart';
import 'host.dart';

/// Reports what a composition declares, without rendering a frame.
///
/// The declaration pass builds every frame of the timeline, so this is an
/// exact answer rather than a sample: a sound that plays for two frames inside
/// a Sequence shows up here.
Future<int> inspectCommand(CliArgs args) async {
  final Directory projectDir = Directory(args.value('project', '.'));
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
  final String? requested = args.optional('composition');
  final List<CompositionInfo> targets = requested == null
      ? available
      : available.where((CompositionInfo c) => c.id == requested).toList();

  if (targets.isEmpty) {
    stderr.writeln(
      'No composition "$requested". Available: '
      '${available.map((CompositionInfo c) => c.id).join(', ')}',
    );
    return 1;
  }

  for (final CompositionInfo info in targets) {
    final Map<String, Object?>? manifest =
        await readManifest(binary, info.id, hostArgs: target.hostArgs);
    stdout.writeln('');
    stdout.writeln(info.toString());
    if (manifest == null) {
      stdout.writeln('  (no manifest returned)');
      continue;
    }
    printManifest(manifest, indent: '  ');
  }
  return 0;
}

/// Runs the host in manifest-only mode.
Future<Map<String, Object?>?> readManifest(
  File binary,
  String id, {
  List<String> hostArgs = const <String>[],
}) async {
  final ProcessResult result = await Process.run(
    binary.path,
    <String>['--manifest', '--composition', id, ...hostArgs],
  );
  for (final String line in const LineSplitter().convert('${result.stdout}')) {
    final Map<String, Object?>? event = decodeHostEvent(line);
    if (event == null) continue;
    if (event['event'] == 'manifest') return event;
    if (event['event'] == 'error') {
      throw StateError('Host error: ${event['message']}');
    }
  }
  return null;
}

void printManifest(Map<String, Object?> manifest, {String indent = ''}) {
  final List<Object?> audio =
      (manifest['audio'] as List<Object?>?) ?? const <Object?>[];
  final List<Object?> video =
      (manifest['video'] as List<Object?>?) ?? const <Object?>[];
  final List<Object?> images =
      (manifest['images'] as List<Object?>?) ?? const <Object?>[];

  stdout.writeln(
    '${indent}swept ${manifest['framesVisited']} frames '
    'in ${manifest['elapsedMs']}ms',
  );

  if (audio.isEmpty && video.isEmpty && images.isEmpty) {
    stdout.writeln('${indent}nothing declared');
    return;
  }

  if (audio.isNotEmpty) {
    stdout.writeln('${indent}audio:');
    for (final Object? entry in audio) {
      final Map<String, Object?> a = entry! as Map<String, Object?>;
      final int start = a['startFrame']! as int;
      final int end = a['endFrame']! as int;
      stdout.writeln(
        '$indent  ${a['src']}  frames $start-$end '
        '(${end - start + 1})  vol ${a['volume']}'
        '${(a['trimStartInFrames'] as int) > 0
            ? '  trim ${a['trimStartInFrames']}'
            : ''}'
        '${a['loop'] == true ? '  loop' : ''}',
      );
    }
  }

  if (video.isNotEmpty) {
    stdout.writeln('${indent}video:');
    for (final Object? entry in video) {
      final Map<String, Object?> v = entry! as Map<String, Object?>;
      final int start = v['startFrame']! as int;
      final int end = v['endFrame']! as int;
      final int? decodeWidth = v['decodeWidth'] as int?;
      final int? decodeHeight = v['decodeHeight'] as int?;
      stdout.writeln(
        '$indent  ${v['src']}  frames $start-$end '
        '(${end - start + 1})'
        '${(v['trimStartInFrames'] as int) > 0
            ? '  trim ${v['trimStartInFrames']}'
            : ''}'
        '${decodeWidth != null || decodeHeight != null
            ? '  decode ${decodeWidth ?? 'auto'}x${decodeHeight ?? 'auto'}'
            : ''}',
      );
    }
  }

  if (images.isNotEmpty) {
    stdout.writeln('${indent}images:');
    for (final Object? image in images) {
      stdout.writeln('$indent  $image');
    }
  }
}
