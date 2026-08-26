import 'dart:io';

import 'package:fluttermotion_cli/src/args.dart';
import 'package:fluttermotion_cli/src/host.dart';
import 'package:fluttermotion_cli/src/render_command.dart';

const String _usage = '''
FlutterMotion — render Flutter compositions to video.

Usage:
  fluttermotion render [options]
  fluttermotion list [options]

Common options:
  --project <dir>       Flutter project to render from (default: .)
  --entry <path>        Entry point calling renderMain
                        (default: lib/render_main.dart)
  --no-build            Reuse the existing release build
  --ffmpeg <path>       ffmpeg binary (default: autodetected)
  --flutter <path>      flutter binary (default: flutter)

render options:
  --composition <id>    Which composition (required if more than one)
  --out <path>          Output file (default: <id>.mp4)
  --size <WxH>          Override the composition's size, e.g. 1080x1920
  --fps <n>             Override frame rate
  --frames <n>          Override duration in frames
  --shards <n|auto>     Renderer processes to run (default: auto)
  --codec <name>        Video codec (default: h264_videotoolbox)
  --bitrate <rate>      Target bitrate (default: 12M)
  --keep-temp           Leave the per-shard segments on disk
''';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty ||
      arguments.first == '--help' ||
      arguments.first == '-h') {
    stdout.write(_usage);
    exit(0);
  }

  final String command = arguments.first;
  final CliArgs args = CliArgs(arguments.skip(1).toList());

  try {
    switch (command) {
      case 'render':
        exit(await renderCommand(args));
      case 'list':
        exit(await _listCommand(args));
      default:
        stderr.writeln('Unknown command "$command".\n');
        stderr.write(_usage);
        exit(64);
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exit(64);
  } catch (error) {
    stderr.writeln('$error');
    exit(1);
  }
}

Future<int> _listCommand(CliArgs args) async {
  final RenderHost host = RenderHost(
    projectDir: Directory(args.value('project', '.')),
    entryPoint: args.value('entry', 'lib/render_main.dart'),
    flutter: args.value('flutter', 'flutter'),
  );
  final File binary =
      args.flag('no-build') ? host.locateBinary() : await host.build(
          log: stdout.writeln);
  for (final CompositionInfo info in await host.list(binary)) {
    stdout.writeln(info);
  }
  return 0;
}
