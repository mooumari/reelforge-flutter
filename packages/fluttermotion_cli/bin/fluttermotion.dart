import 'dart:io';

import 'package:fluttermotion_cli/src/args.dart';
import 'package:fluttermotion_cli/src/cli_error.dart';
import 'package:fluttermotion_cli/src/document_entry.dart';
import 'package:fluttermotion_cli/src/host.dart';
import 'package:fluttermotion_cli/src/init_command.dart';
import 'package:fluttermotion_cli/src/inspect_command.dart';
import 'package:fluttermotion_cli/src/preview_command.dart';
import 'package:fluttermotion_cli/src/render_command.dart';
import 'package:fluttermotion_cli/src/validate_command.dart';

const String _usage = '''
FlutterMotion — render Flutter compositions to video.

Usage:
  fluttermotion init     [options]
  fluttermotion preview  [<document.json>] [options]
  fluttermotion render   [<document.json>] [options]
  fluttermotion validate <document.json> [options]
  fluttermotion inspect  [options]
  fluttermotion list     [<document.json>] [options]

A composition is either Dart in your project (the default, found through
--entry) or a JSON document. Passing a .json file renders it through a
generated two-line host, so both take exactly the same path from there on.

Common options:
  --project <dir>       Flutter project to render from (default: .)
  --entry <path>        Entry point calling renderMain
                        (default: lib/render_main.dart)
                        For `preview`, the one calling previewMain
                        (default: lib/video/preview_main.dart)
  --no-build            Reuse the existing release build
  --ffmpeg <path>       ffmpeg binary (default: autodetected)
  --flutter <path>      flutter binary (default: flutter)
  --allow-sandbox       Build even though the app enables App Sandbox

document options:
  --document <path>     The document to render (or pass it positionally)
  --data <path>         JSON object the document's {{ bindings }} read from

init options:
  --json                Scaffold a JSON document instead of a Dart composition
  --fluttermotion <p>   Path to the fluttermotion package
                        (default: alongside this CLI)
  --fix-entitlements    Turn App Sandbox off in the macOS release
                        entitlements, which a render host needs

preview options:
  --device <id>         Device to run on (default: this desktop)

inspect options:
  --composition <id>    Which composition (default: all)

render options:
  --composition <id>    Which composition (required if more than one)
  --out <path>          Output file (default: <id>.mp4)
  --size <WxH>          Override the composition's size, e.g. 1080x1920
  --fps <n>             Override frame rate
  --frames <n>          Override duration in frames
  --shards <n|auto>     Renderer processes to run (default: auto)
  --codec <name>        Video codec (default: h264_videotoolbox)
  --bitrate <rate>      Target bitrate (default: 12M)
  --ffprobe <path>      ffprobe binary (default: alongside ffmpeg)
  --audio-codec <name>  Audio codec (default: aac)
  --audio-bitrate <r>   Audio bitrate (default: 192k)
  --no-audio            Skip mixing, even if clips are declared
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
      case 'init':
        exit(await initCommand(args));
      case 'preview':
        exit(await previewCommand(args));
      case 'render':
        exit(await renderCommand(args));
      case 'validate':
        exit(await validateCommand(args));
      case 'inspect':
        exit(await inspectCommand(args));
      case 'list':
        exit(await _listCommand(args));
      default:
        stderr.writeln('Unknown command "$command".\n');
        stderr.write(_usage);
        exit(64);
    }
  } on CliError catch (error) {
    stderr.writeln(error.message);
    exit(1);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exit(64);
  } catch (error) {
    stderr.writeln('$error');
    exit(1);
  }
}

Future<int> _listCommand(CliArgs args) async {
  final Directory projectDir = Directory(args.value('project', '.'));
  final HostTarget target = hostTargetFor(args, projectDir);
  final RenderHost host = RenderHost(
    projectDir: projectDir,
    entryPoint: target.entryPoint,
    flutter: args.value('flutter', 'flutter'),
    allowSandbox: args.flag('allow-sandbox'),
    hostArgs: target.hostArgs,
  );
  final File binary =
      args.flag('no-build') ? host.locateBinary() : await host.build(
          log: stdout.writeln);
  for (final CompositionInfo info in await host.list(binary)) {
    stdout.writeln(info);
  }
  return 0;
}
