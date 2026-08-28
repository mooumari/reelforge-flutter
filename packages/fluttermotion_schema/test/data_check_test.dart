import 'package:fluttermotion_schema/fluttermotion_schema.dart';
import 'package:test/test.dart';

/// Whether a document and its data go together.
///
/// The failure this guards against produced a sixty-second video in which
/// every bound value was empty and every `repeat` drew nothing, with no
/// warning and a zero exit code, because the data file was simply not passed.
/// A missing binding renders as absence, and absence looks exactly like a
/// scene that was meant to be sparse.

/// A document with [child] as its only scene.
DocumentSpec docWith(Map<String, Object?> child) =>
    DocumentSpec.parse(<String, Object?>{
      'id': 'Test',
      'width': 1080,
      'height': 1920,
      'fps': 30,
      'scenes': <Object?>[
        <String, Object?>{'seconds': 2, 'child': child},
      ],
    });

List<String> against(
  Map<String, Object?> child,
  Map<String, Object?> data,
) => dataProblems(
  docWith(child),
  data,
).map((SchemaProblem problem) => problem.toString()).toList();

Map<String, Object?> text(String value) =>
    <String, Object?>{'type': 'text', 'value': value};

/// A bar chart repeating [over], bound to each item's `shipped` and `label`.
Map<String, Object?> chartOver(String over) => <String, Object?>{
  'type': 'barChart',
  'bars': <String, Object?>{
    'repeat': over,
    'as': <String, Object?>{'value': '{{ shipped }}', 'label': '{{ label }}'},
  },
};

void main() {
  group('plain bindings', () {
    test('data that has the field is no problem at all', () {
      expect(
        against(text('Q{{ quarter }}'), <String, Object?>{'quarter': 3}),
        isEmpty,
      );
    });

    test('a field the data lacks is reported, with its path', () {
      expect(against(text('Q{{ quarter }}'), <String, Object?>{}), <String>[
        'scenes[0].child.value: "{{ quarter }}" has nothing to bind to',
      ]);
    });

    test('each binding in one string is checked separately', () {
      expect(
        against(text('{{ a }} of {{ b }}'), <String, Object?>{'a': 1}),
        <String>['scenes[0].child.value: "{{ b }}" has nothing to bind to'],
      );
    });

    test('a dotted path is followed into the data', () {
      expect(
        against(text('{{ totals.releases }}'), <String, Object?>{
          'totals': <String, Object?>{'releases': 47},
        }),
        isEmpty,
      );
      expect(
        against(text('{{ totals.releases }}'), <String, Object?>{
          'totals': <String, Object?>{'incidents': 3},
        }),
        <String>[
          'scenes[0].child.value: "{{ totals.releases }}" has nothing to '
              'bind to',
        ],
      );
    });

    test('filters are stripped before the lookup', () {
      // The data has `shipped`; it does not have `shipped | round`.
      expect(
        against(text('{{ shipped | round }}'), <String, Object?>{
          'shipped': 1.4,
        }),
        isEmpty,
      );
    });

    test('@index and @item come from the scope, not the data', () {
      expect(against(text('{{ @index }} {{ @item }}'), <String, Object?>{}),
          isEmpty);
    });

    test('a binding inside a written-out list of objects is found', () {
      // Bindings are not only top-level string properties. Walking the shape
      // is cheaper than knowing which properties may hold one.
      expect(
        against(<String, Object?>{
          'type': 'barChart',
          'bars': <Object?>[
            <String, Object?>{'value': '{{ shipped }}', 'label': 'W27'},
          ],
        }, <String, Object?>{}),
        <String>[
          'scenes[0].child.bars[0].value: "{{ shipped }}" has nothing to '
              'bind to',
        ],
      );
    });
  });

  group('repeats', () {
    test('a list that is there, with the fields the template reads', () {
      expect(
        against(chartOver('weeks'), <String, Object?>{
          'weeks': <Object?>[
            <String, Object?>{'shipped': 12, 'label': 'W27'},
          ],
        }),
        isEmpty,
      );
    });

    test('repeating over something the data lacks is reported once', () {
      expect(against(chartOver('weeks'), <String, Object?>{}), <String>[
        'scenes[0].child.bars: repeats over "weeks", which is not in the data',
      ]);
    });

    test('repeating over something that is not a list says what it is', () {
      expect(
        against(chartOver('weeks'), <String, Object?>{'weeks': 12}),
        <String>[
          'scenes[0].child.bars: repeats over "weeks", which is a number, '
              'not a list',
        ],
      );
    });

    test('an empty list is data, not a mistake', () {
      // A week with no releases is a real week. There is also nothing to check
      // the template against, so its fields go unexamined rather than being
      // called absent.
      expect(
        against(chartOver('weeks'), <String, Object?>{
          'weeks': <Object?>[],
        }),
        isEmpty,
      );
    });

    test('a field on some rows and not others is ordinary data', () {
      expect(
        against(chartOver('weeks'), <String, Object?>{
          'weeks': <Object?>[
            <String, Object?>{'shipped': 12},
            <String, Object?>{'shipped': 9, 'label': 'W28'},
          ],
        }),
        isEmpty,
      );
    });

    test('a field on no row at all is reported once, not once per row', () {
      // The whole point of checking the template rather than each rendering:
      // twelve weeks missing a field is one mistake, not twelve.
      expect(
        against(chartOver('weeks'), <String, Object?>{
          'weeks': <Object?>[
            <String, Object?>{'label': 'W27'},
            <String, Object?>{'label': 'W28'},
            <String, Object?>{'label': 'W29'},
          ],
        }),
        <String>[
          'scenes[0].child.bars.as.value: "{{ shipped }}" has nothing to '
              'bind to',
        ],
      );
    });

    test('a template may read the root as well as its own item', () {
      // DataScope checks the item first and falls back to the root, so this
      // has to as well or every outer field inside a repeat reads as missing.
      expect(
        against(<String, Object?>{
          'type': 'barChart',
          'bars': <String, Object?>{
            'repeat': 'weeks',
            'as': <String, Object?>{
              'value': '{{ shipped }}',
              'label': '{{ period }}',
            },
          },
        }, <String, Object?>{
          'period': 'Q3',
          'weeks': <Object?>[
            <String, Object?>{'shipped': 12},
          ],
        }),
        isEmpty,
      );
    });

    test('a repeat template is not checked against the outer data', () {
      // `props` is the node's raw JSON, so it carries the repeat template too.
      // Walking it as though it were a plain property checked `shipped`
      // against the root -- where it is genuinely absent -- and reported a
      // document that renders perfectly well.
      expect(
        against(chartOver('weeks'), <String, Object?>{
          'weeks': <Object?>[
            <String, Object?>{'shipped': 12, 'label': 'W27'},
          ],
        }),
        isEmpty,
        reason: 'shipped lives on the item, not at the root',
      );
    });
  });

  group('reach', () {
    test('the bed and every scene are checked, not just the first', () {
      final DocumentSpec document = DocumentSpec.parse(<String, Object?>{
        'id': 'Test',
        'width': 1080,
        'height': 1920,
        'fps': 30,
        'bed': text('{{ watermark }}'),
        'scenes': <Object?>[
          <String, Object?>{'seconds': 1, 'child': text('{{ one }}')},
          <String, Object?>{'seconds': 1, 'child': text('{{ two }}')},
        ],
      });
      expect(
        dataProblems(document, const <String, Object?>{})
            .map((SchemaProblem p) => p.path)
            .toList(),
        <String>['bed.value', 'scenes[0].child.value', 'scenes[1].child.value'],
      );
    });

    test('a slot deeper than the scene root is reached', () {
      expect(
        against(<String, Object?>{
          'type': 'padding',
          'padding': 10,
          'child': text('{{ missing }}'),
        }, <String, Object?>{}),
        <String>[
          'scenes[0].child.child.value: "{{ missing }}" has nothing to bind to',
        ],
      );
    });
  });
}
