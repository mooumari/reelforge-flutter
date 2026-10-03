import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

void main() {
  group('Fire.flicker', () {
    test('is a pure function of time and stays near 1', () {
      for (double t = 0; t < 20; t += 0.037) {
        final double v = Fire.flicker(t, seed: 4);
        expect(v, closeTo(1, 0.19));
        expect(Fire.flicker(t, seed: 4), v);
      }
    });

    test('differs between fires, so two never burn in step', () {
      expect(Fire.flicker(1.3, seed: 1), isNot(Fire.flicker(1.3, seed: 2)));
    });
  });

  group('Lightning.flash', () {
    test('is dark away from a strike and bright at it', () {
      const List<double> strikes = <double>[1.0, 4.0];
      expect(Lightning.flash(strikes, 0.5), 0);
      expect(Lightning.flash(strikes, 2.5), 0);
      expect(Lightning.flash(strikes, 1.06), closeTo(1, 1e-9));
      expect(Lightning.flash(strikes, 4.06), closeTo(1, 1e-9));
    });

    test('has a dark beat between the first stroke and the second', () {
      const List<double> strikes = <double>[0.0];
      final double stroke = Lightning.flash(strikes, 0.06);
      final double beat = Lightning.flash(strikes, 0.15);
      final double second = Lightning.flash(strikes, 0.17);
      expect(beat, lessThan(stroke));
      expect(second, lessThan(stroke));
      expect(Lightning.flash(strikes, 0.8), 0);
    });

    test('never goes outside 0 to 1', () {
      for (double t = -1; t < 3; t += 0.01) {
        final double v = Lightning.flash(const <double>[0.0, 0.1, 0.2], t);
        expect(v, inInclusiveRange(0, 1));
      }
    });
  });
}
