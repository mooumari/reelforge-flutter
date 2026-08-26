import 'package:fluttermotion/fluttermotion.dart';

import 'compositions.dart';

/// Preview app. `flutter run -d macos` here, then scrub -- and hot reload
/// applies to compositions like any other Flutter code.
void main() => previewMain(<Composition>[
      helloFlutter,
      weeklyDeals,
      videoShowcase,
      videoProbe,
    ]);
