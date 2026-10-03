import 'package:example/rain_week.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';

/// Finds things that appear or jump between two frames: the fraction of a
/// region's pixels that change by a lot from one frame to the next, and the
/// frames where that is far above what the shot normally does.
///
///   flutter test tool/pop_test.dart --dart-define=COMP=RainWeek \
///     --dart-define=FROM=0 --dart-define=TO=143 --dart-define=TOP=0 --dart-define=BOTTOM=0.4
const String _comp = String.fromEnvironment('COMP');
const int _from = int.fromEnvironment('FROM');
const int _to = int.fromEnvironment('TO', defaultValue: 60);
const String _top = String.fromEnvironment('TOP', defaultValue: '0');
const String _bottom = String.fromEnvironment('BOTTOM', defaultValue: '1');

final Map<String, Composition> _all = <String, Composition>{rainWeek.id: rainWeek};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('pops', () async {
    if (_comp.isEmpty) return;
    FlutterError.onError = (FlutterErrorDetails d) {};
    final Composition c = _all[_comp]!;
    final CompositionRenderer renderer = CompositionRenderer(c);
    final int rowFrom = (c.height * double.parse(_top)).round(), rowTo = (c.height * double.parse(_bottom)).round();
    Uint8List? last;
    final List<double> series = <double>[];
    for (int f = _from; f <= _to; f++) {
      final ByteData d = await renderer.renderFrameRgba(f);
      final Uint8List now = d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
      if (last != null) {
        int changed = 0, total = 0;
        for (int y = rowFrom; y < rowTo; y += 2) {
          for (int x = 0; x < c.width; x += 2) {
            final int i = (y * c.width + x) * 4;
            final int diff = (now[i] - last[i]).abs() + (now[i + 1] - last[i + 1]).abs() + (now[i + 2] - last[i + 2]).abs();
            total++;
            if (diff > 60) changed++;
          }
        }
        series.add(changed / total);
      }
      last = Uint8List.fromList(now);
    }
    final List<double> sorted = List<double>.of(series)..sort();
    final double median = sorted[sorted.length ~/ 2];
    // ignore: avoid_print
    print('POP $_comp $_from-$_to rows $_top-$_bottom: median ${(median * 100).toStringAsFixed(3)}% changed per frame, max ${(sorted.last * 100).toStringAsFixed(3)}%');
    for (int i = 0; i < series.length; i++) {
      if (series[i] > median * 4 + 0.002) {
        // ignore: avoid_print
        print('POP   frame ${_from + i + 1}: ${(series[i] * 100).toStringAsFixed(3)}%');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
