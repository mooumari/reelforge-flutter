import 'package:example/rain_open_timing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prints where every shot of the opening starts and ends, and when each
/// line is said.
void main() {
  test('cuts', () {
    // ignore: avoid_print
    for (int i = 0; i < openShots; i++) print('${openShotNames[i].padRight(8)} ${openCuts[i].toStringAsFixed(2)}-${openCuts[i + 1].toStringAsFixed(2)}  ${openLengths[i]}f  start frame ${(openCuts[i] * openFps).round()}');
    // ignore: avoid_print
    for (int l = 0; l < openVoice.lines.length; l++) print('line $l ${openVoice.starts[l].toStringAsFixed(2)}-${openVoice.ends[l].toStringAsFixed(2)}');
    // ignore: avoid_print
    print('total ${openVoice.seconds}');
  });
}
