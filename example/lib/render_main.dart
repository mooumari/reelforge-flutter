import 'package:fluttermotion/fluttermotion.dart';

import 'compositions.dart';

/// Render host entry point. The CLI builds this and drives it.
void main(List<String> args) => renderMain(args, <Composition>[
      helloFlutter,
      weeklyDeals,
      videoShowcase,
      videoProbe,
    ]);
