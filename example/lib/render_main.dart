import 'package:fluttermotion/fluttermotion.dart';

import 'compositions.dart';
import 'showreel.dart';

/// Render host entry point. The CLI builds this and drives it.
void main(List<String> args) => renderMain(args, <Composition>[
      showreel,
      helloFlutter,
      weeklyDeals,
      videoShowcase,
      videoProbe,
      tickerProbe,
    ]);
