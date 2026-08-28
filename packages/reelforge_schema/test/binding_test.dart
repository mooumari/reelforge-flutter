import 'package:reelforge_schema/reelforge_schema.dart';
import 'package:test/test.dart';

/// The binding language, which is the half of the format that is not a shape.
///
/// A document is a template and the data is what fills it; everything here is
/// about that seam, and none of it needs a widget.
void main() {
  const DataScope root = DataScope(
    data: <String, Object?>{
      'period': 'Q3',
      'releases': 128,
      'delta': -18.42,
      'weeks': <Object?>[
        <String, Object?>{'label': 'W27', 'shipped': 12},
        <String, Object?>{'label': 'W28', 'shipped': 18},
      ],
    },
  );

  group('resolving a path', () {
    test('a plain key', () => expect(root.resolve('period'), 'Q3'));

    test(
      'through lists by index',
      () => expect(root.resolve('weeks.1.label'), 'W28'),
    );

    test('a missing field is null, not an exception', () {
      // A template naming a field the data does not have should render empty
      // rather than take the whole video down.
      expect(root.resolve('nope'), isNull);
      expect(root.resolve('weeks.9.label'), isNull);
      expect(root.resolve('period.deeper'), isNull);
    });

    test('an item shadows the root, and the root still shows through', () {
      final DataScope item = root.forItem(<String, Object?>{
        'label': 'W27',
        'shipped': 12,
      }, 0);
      expect(item.resolve('label'), 'W27');
      expect(
        item.resolve('period'),
        'Q3',
        reason: 'a nested template should not need a prefix to reach out',
      );
      expect(item.resolve('@index'), 0);
      expect(item.resolve('@item'), isA<Map<String, Object?>>());
    });
  });

  group('filling a template', () {
    test('several bindings in one string', () {
      expect(
        fillString(root, '{{ period }}: {{ releases }} releases'),
        'Q3: 128 releases',
      );
    });

    test('a whole-string binding keeps its type', () {
      // "{{ releases }}" used where a number is wanted has to give the number,
      // or every animated property would have to be written twice.
      expect(isWholeBinding('{{ releases }}'), isTrue);
      expect(isWholeBinding('n = {{ releases }}'), isFalse);
      expect(fillValue(root, '{{ releases }}'), 128);
    });

    test('a whole number renders without a trailing .0', () {
      expect(fillString(root, '{{ releases }}'), '128');
    });

    test('filters apply left to right', () {
      expect(fillString(root, '{{ delta | fixed(1) | sign }}'), '-18.4');
      expect(fillString(root, '{{ releases | fixed(1) | sign }}'), '+128.0');
      expect(fillString(root, '{{ period | upper }}'), 'Q3');
      expect(fillString(root, '{{ period | lower }}'), 'q3');
      expect(fillString(root, '{{ delta | round }}'), '-18');
    });

    test('an unknown filter passes the value through rather than failing', () {
      // Reported at parse time; at build time a frame must still render.
      expect(fillString(root, '{{ period | shout }}'), 'Q3');
    });

    test('every filter name in a string is reportable', () {
      expect(
        filtersIn('{{ a | fixed(1) | sign }} and {{ b | upper }}'),
        <String>['fixed', 'sign', 'upper'],
      );
      for (final String filter in filtersIn('{{ a | round | nope }}')) {
        expect(knownFilters.contains(filter), filter != 'nope');
      }
    });
  });

  group('colours are integers here', () {
    test(
      '#RRGGBB gains an opaque alpha',
      () => expect(parseHex('#4ADE80'), 0xFF4ADE80),
    );

    test(
      '#AARRGGBB is taken as written',
      () => expect(parseHex('#804ADE80'), 0x804ADE80),
    );

    test('anything else is not a colour', () {
      for (final String value in <String>[
        '4ADE80',
        '#GGG',
        '#12345',
        'accent',
      ]) {
        expect(parseHex(value), isNull, reason: value);
      }
    });
  });
}
