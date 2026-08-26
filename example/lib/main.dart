import 'dart:io';

import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_encoder/fluttermotion_encoder.dart';

import 'compositions.dart';

/// Preview app. `flutter run -d macos` here, then scrub -- and hot reload
/// applies to compositions like any other Flutter code.
///
/// Passing an [encoderFactory] adds an Export button that renders the
/// composition to MP4 *inside this app*, with the platform's own hardware
/// encoder and no ffmpeg involved. The [videoBackendFactory] is the other half
/// of that: video clips decode through AVFoundation, so scrubbing a
/// composition with footage in it does not need ffmpeg on the machine either.
void main() => previewMain(
      <Composition>[
        helloFlutter,
        weeklyDeals,
        videoShowcase,
        videoProbe,
        audioProbe,
        tickerProbe,
      ],
      encoderFactory: NativeVideoEncoder.new,
      videoBackendFactory: NativeVideoBackend.new,
      exportPathBuilder: (Composition composition) =>
          '${Directory.systemTemp.path}/fluttermotion/${composition.id}.mp4',
    );
