import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';

import 'compositions.dart';
import 'longform.dart';
import 'longform_json.dart';
import 'report_data.dart';
import 'showreel.dart';

/// Render host entry point. The CLI builds this and drives it.
///
/// Note the shape: anything a composition needs is loaded *here*, before
/// `renderMain`, not inside a widget. A composition has to be a pure function
/// of frame number, and a FutureBuilder that is still loading on frame 0 is
/// not one.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadReport();
  await loadLongformJson();
  await renderMain(args, <Composition>[
    longform,
    longformJson,
    showreel,
    helloFlutter,
    weeklyDeals,
    videoShowcase,
    videoProbe,
    videoProbeHalf,
    encoderProbe,
    audioProbe,
    tickerProbe,
  ]);
}
