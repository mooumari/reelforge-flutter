import 'dart:io';

import 'args.dart';
import 'cli_error.dart';
import 'document_entry.dart';
import 'host.dart';

/// Reports everything wrong with a document, without rendering a frame.
///
/// Every problem at once, each with its JSON path, because a document with
/// four mistakes should take one round trip to fix rather than four.
///
/// It runs inside the host binary rather than in this process: the node
/// vocabulary is Flutter code -- a `titleCard` knows what it accepts because
/// it is the widget -- and there is no second, drifting copy of the schema
/// here to check against. The cost is a build the first time; `--no-build`
/// reuses it afterwards and the check is instant.
Future<int> validateCommand(CliArgs args) async {
  final Directory projectDir = Directory(args.value('project', '.')).absolute;
  if (documentPathFrom(args.rest, args.optional('document')) == null) {
    throw CliError(
      'Nothing to validate.\n\n'
      'Usage: fluttermotion validate reel.json [--project <dir>]',
    );
  }

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

  final ProcessResult result = await Process.run(
    binary.path,
    <String>['--validate', ...target.hostArgs],
    workingDirectory: projectDir.path,
  );
  stdout.write(result.stdout);
  // Only on failure: a macOS app writes engine chatter to stderr on every
  // launch, and a clean validation that prints three lines of it does not look
  // clean.
  if (result.exitCode != 0 && (result.stderr as String).trim().isNotEmpty) {
    stderr.write(result.stderr);
  }
  return result.exitCode;
}
