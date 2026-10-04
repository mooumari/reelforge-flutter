import 'dart:io';

import 'package:example/rain_cast.dart';
import 'package:example/rain_open.dart';
import 'package:example/stick_lab.dart';
import 'package:example/stick_proto.dart';
import 'package:example/rain_week.dart';
import 'package:example/lion_sleep.dart';
import 'package:example/stage_cast.dart';
import 'package:example/walk_lab.dart';
import 'package:example/stage_compare.dart';
import 'package:example/stage_style.dart';
import 'package:example/stage_demo.dart';
import 'package:example/stage_savanna.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';

/// Looks at a composition without rendering the video: a handful of frames,
/// as PNGs, in a couple of seconds.
///
///     flutter test tool/stills_test.dart \
///       --dart-define=COMP=StageSavanna --dart-define=FRAMES=0,90,200 --dart-define=OUT=/tmp/stills
///
/// It is a test only so that it runs inside Flutter's engine; with no
/// COMP given it does nothing.
const String _comp = String.fromEnvironment('COMP');
const String _frames = String.fromEnvironment('FRAMES');
const String _out = String.fromEnvironment('OUT', defaultValue: '/tmp/stills');

final Map<String, Composition> _all = <String, Composition>{
  stageSavanna.id: stageSavanna,
  rainCast.id: rainCast,
  rainWeek.id: rainWeek,
  rainOpen.id: rainOpen,
  rainOpenDoodle.id: rainOpenDoodle,
  stickLab.id: stickLab,
  stickProto.id: stickProto,
  stageDemo.id: stageDemo,
  stageCast.id: stageCast,
  walkCompare.id: walkCompare,
  stageStyle.id: stageStyle,
  lionSleep.id: lionSleep,
  walkLab.id: walkLab,
  walkLabDoodle.id: walkLabDoodle,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('stills', () async {
    if (_comp.isEmpty) return;
    final Composition composition = _all[_comp] ?? (throw ArgumentError('No composition $_comp: ${_all.keys}'));
    // The font the compositions ask for, or text is drawn as boxes.
    final FontLoader roboto = FontLoader('Roboto');
    for (final (String file, int _) in <(String, int)>[('Regular', 400), ('Medium', 500), ('Bold', 700)]) {
      roboto.addFont(Future<ByteData>.value(ByteData.sublistView(File('assets/fonts/Roboto-$file.ttf').readAsBytesSync())));
    }
    await roboto.load();
    final FontLoader hand = FontLoader('PatrickHand')
      ..addFont(Future<ByteData>.value(ByteData.sublistView(File('assets/fonts/PatrickHand-Regular.ttf').readAsBytesSync())));
    await hand.load();
    Directory(_out).createSync(recursive: true);
    // ignore: avoid_print
    print('${composition.id}: ${composition.durationInFrames} frames at ${composition.fps} fps');
    // A build error is drawn as a red screen; say what it was.
    FlutterError.onError = (FlutterErrorDetails d) {
      // ignore: avoid_print
      if (!d.exceptionAsString().contains("'inTest'")) print('BUILD ERROR: ${d.toString(minLevel: DiagnosticLevel.debug)}');
    };
    final CompositionRenderer renderer = CompositionRenderer(composition);
    for (final String f in _frames.split(',').where((String s) => s.isNotEmpty)) {
      final int frame = int.parse(f);
      final data = await renderer.renderFramePng(frame);
      File('$_out/$_comp-${frame.toString().padLeft(4, '0')}.png')
          .writeAsBytesSync(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
