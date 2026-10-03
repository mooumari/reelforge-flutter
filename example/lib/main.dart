import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_encoder/reelforge_encoder.dart';

import 'compositions.dart';
import 'longform.dart';
import 'stage_compare.dart';
import 'stage_cast.dart';
import 'stage_faces.dart';
import 'stage_heads.dart';
import 'stage_wardrobe.dart';
import 'lion_sleep.dart';
import 'stage_savanna.dart';
import 'stage_style.dart';
import 'stage_shapes.dart';
import 'stage_demo.dart';
import 'report_data.dart';

/// Preview app. `flutter run -d macos` here, then scrub -- and hot reload
/// applies to compositions like any other Flutter code.
///
/// Passing an [encoderFactory] adds an Export button that renders the
/// composition to MP4 *inside this app*, with the platform's own hardware
/// encoder and no ffmpeg involved. The [videoBackendFactory] is the other half
/// of that: video clips decode through AVFoundation, so scrubbing a
/// composition with footage in it does not need ffmpeg on the machine either.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Anything a composition reads has to be there before the first frame.
  await loadReport();
  previewMain(
      <Composition>[
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
        longform,
        helloFlutter,
        weeklyDeals,
        videoShowcase,
        videoProbe,
    videoProbeHalf,
    encoderProbe,
        audioProbe,
        tickerProbe,
      ],
      encoderFactory: NativeVideoEncoder.new,
      videoBackendFactory: NativeVideoBackend.new,
      exportPathBuilder: (Composition composition) =>
          '${Directory.systemTemp.path}/reelforge/${composition.id}.mp4',
    );
}
