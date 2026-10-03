import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';

import 'compositions.dart';
import 'longform.dart';
import 'longform_json.dart';
import 'report_data.dart';
import 'showreel.dart';
import 'stage_compare.dart';
import 'stage_cast.dart';
import 'stage_faces.dart';
import 'stage_heads.dart';
import 'stage_wardrobe.dart';
import 'lion_sleep.dart';
import 'rain_week.dart';
import 'stage_savanna.dart';
import 'stage_style.dart';
import 'stage_shapes.dart';
import 'stage_demo.dart';

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
    stageDemo,
    walkCompare,
    stageShapes,
    stageFaces,
    stageCast,
    stageStyle,
    stageHeads,
    stageWardrobe,
    stageSavanna,
    lionSleep,
    rainWeek,
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
