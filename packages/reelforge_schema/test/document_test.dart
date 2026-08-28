import 'package:reelforge_schema/reelforge_schema.dart';
import 'package:test/test.dart';

/// The document format, checked with no Flutter anywhere.
///
/// These are the tests that used to need a `flutter test` binding and a
/// widget tree to answer "is this document valid". They now run in about a
/// second under plain `dart test`, which is the same second the CLI's
/// `reelforge validate` takes.

/// The smallest document that parses, for tests to vary one thing in.
Map<String, Object?> base(Map<String, Object?> overrides) => <String, Object?>{
  'id': 'Test',
  'width': 1080,
  'height': 1920,
  'fps': 30,
  'scenes': <Object?>[
    <String, Object?>{
      'seconds': 2,
      'child': <String, Object?>{'type': 'text', 'value': 'hello'},
    },
  ],
  ...overrides,
};

List<String> problems(Map<String, Object?> json) => DocumentSpec.problemsIn(
  json,
).map((SchemaProblem problem) => problem.toString()).toList();

void main() {
  group('shape', () {
    test('a minimal storyboard parses and knows how long it is', () {
      final DocumentSpec document = DocumentSpec.parse(
        base(<String, Object?>{}),
      );
      expect(document.id, 'Test');
      expect(document.durationInFrames, 60);
      expect(document.scenes.single.frames, 60);
    });

    test('a JSON string parses as readily as a decoded map', () {
      expect(
        DocumentSpec.parse(
          '{"id":"S","width":10,"height":10,"fps":30,'
          '"root":{"type":"text","value":"x"},"durationInFrames":5}',
        ).durationInFrames,
        5,
      );
    });

    test('malformed JSON is a schema problem, not a crash', () {
      expect(
        () => DocumentSpec.parse('{not json'),
        throwsA(isA<SchemaException>()),
      );
    });

    test('a document is a storyboard or a tree, never both or neither', () {
      expect(
        problems(
          base(<String, Object?>{
            'root': <String, Object?>{'type': 'text', 'value': 'x'},
          }),
        ),
        contains(contains('not both')),
      );
      final Map<String, Object?> neither = base(<String, Object?>{})
        ..remove('scenes');
      expect(problems(neither), contains(contains('needs either')));
    });

    test('a tree needs its own length, a storyboard must not state one', () {
      expect(
        problems(<String, Object?>{
          'id': 'S',
          'width': 10,
          'height': 10,
          'fps': 30,
          'root': <String, Object?>{'type': 'text', 'value': 'x'},
        }),
        contains('durationInFrames: is required'),
      );
      expect(
        problems(base(<String, Object?>{'durationInFrames': 99})),
        contains(contains('set by the scenes')),
      );
    });

    test('a future document version is refused rather than half-read', () {
      expect(
        problems(
          base(<String, Object?>{'version': currentDocumentVersion + 1}),
        ),
        contains(contains('understands up to')),
      );
    });
  });

  group('problems', () {
    test('every problem is reported, not just the first', () {
      final List<String> found = problems(<String, Object?>{
        'id': 'S',
        'width': 'wide',
        'height': 1920,
        'fps': 30,
        'scenes': <Object?>[
          <String, Object?>{
            'seconds': 2,
            'child': <String, Object?>{'type': 'text'},
          },
        ],
      });
      expect(found, contains(contains('width')));
      expect(found, contains(contains('is required')));
      expect(found.length, greaterThanOrEqualTo(2));
    });

    test('a problem says where it is, in JSON path terms', () {
      expect(
        problems(
          base(<String, Object?>{
            'scenes': <Object?>[
              <String, Object?>{
                'seconds': 1,
                'child': <String, Object?>{
                  'type': 'column',
                  'children': <Object?>[
                    <String, Object?>{'type': 'text', 'value': 'ok'},
                    <String, Object?>{'type': 'nope'},
                  ],
                },
              },
            ],
          }),
        ),
        contains(startsWith('scenes[0].child.children[1].type:')),
      );
    });

    test('a misspelt property is a problem, not a silent default', () {
      expect(
        problems(
          base(<String, Object?>{
            'scenes': <Object?>[
              <String, Object?>{
                'seconds': 1,
                'child': <String, Object?>{
                  'type': 'titleCard',
                  'headline': 'x',
                  'subhed': 'oops',
                },
              },
            ],
          }),
        ),
        contains(contains('unknown property "subhed"')),
      );
    });

    test('an unknown filter is caught before it renders as nothing', () {
      expect(
        problems(
          base(<String, Object?>{
            'scenes': <Object?>[
              <String, Object?>{
                'seconds': 1,
                'child': <String, Object?>{
                  'type': 'sizedBox',
                  'width': '{{ n | shout }}',
                },
              },
            ],
          }),
        ),
        contains(contains('unknown filter "shout"')),
      );
    });

    test('keyframes out of order are named rather than asserted on', () {
      expect(
        problems(
          base(<String, Object?>{
            'scenes': <Object?>[
              <String, Object?>{
                'seconds': 1,
                'child': <String, Object?>{
                  'type': 'opacity',
                  'value': <String, Object?>{
                    'keyframes': <Object?>[
                      <Object?>[0, 0],
                      <Object?>[12, 1],
                      <Object?>[6, 1],
                    ],
                  },
                  'child': <String, Object?>{'type': 'text', 'value': 'x'},
                },
              },
            ],
          }),
        ),
        contains(contains('increasing frame order')),
      );
    });

    test('a source that leaves the project is refused', () {
      for (final String src in <String>['../secrets.mp4', '/etc/passwd']) {
        expect(
          problems(
            base(<String, Object?>{
              'scenes': <Object?>[
                <String, Object?>{
                  'seconds': 1,
                  'child': <String, Object?>{'type': 'video', 'src': src},
                },
              ],
            }),
          ),
          contains(contains('leaves the project directory')),
          reason: src,
        );
      }
    });

    test('a scene needs exactly one of seconds or frames', () {
      expect(
        problems(
          base(<String, Object?>{
            'scenes': <Object?>[
              <String, Object?>{
                'seconds': 1,
                'frames': 30,
                'child': <String, Object?>{'type': 'text', 'value': 'x'},
              },
            ],
          }),
        ),
        contains(contains('exactly one of "seconds" or "frames"')),
      );
    });
  });

  group('theme, as data', () {
    test('a named palette, a font and a scale are read', () {
      final DocumentSpec document = DocumentSpec.parse(
        base(<String, Object?>{
          'theme': <String, Object?>{
            'palette': 'light',
            'font': 'Roboto',
            'scale': 0.5,
          },
        }),
      );
      expect(document.theme.base, 'light');
      expect(document.theme.fontFamily, 'Roboto');
      expect(document.theme.scale, 0.5);
    });

    test('an overridden role is kept as an ARGB integer, not a Color', () {
      // The whole point: a theme survives a round trip through a package that
      // has never heard of dart:ui.
      final DocumentSpec document = DocumentSpec.parse(
        base(<String, Object?>{
          'theme': <String, Object?>{
            'palette': <String, Object?>{'base': 'dark', 'accent': '#FF00FF'},
          },
        }),
      );
      expect(document.theme.roles['accent'], 0xFFFF00FF);
      expect(
        document.theme.roles.containsKey('background'),
        isFalse,
        reason:
            'a role the document did not set must stay unset, so the '
            'palette it came from keeps deciding',
      );
    });

    test('a role cannot be defined as another role', () {
      expect(
        problems(
          base(<String, Object?>{
            'theme': <String, Object?>{
              'palette': <String, Object?>{'accent': 'warning'},
            },
          }),
        ),
        contains(contains('cannot define a role as another role')),
      );
    });

    test('only the sizes the document sets are recorded', () {
      final DocumentSpec document = DocumentSpec.parse(
        base(<String, Object?>{
          'theme': <String, Object?>{
            'sizes': <String, Object?>{'headline': 40},
          },
        }),
      );
      expect(document.theme.sizes, <String, double>{'headline': 40});
    });
  });

  group('transitions carry their own defaults', () {
    TransitionSpec transitionOf(Map<String, Object?> spec) =>
        DocumentSpec.parse(
          base(<String, Object?>{'transition': spec}),
        ).defaultTransition;

    test('a document with no transition fades', () {
      expect(
        DocumentSpec.parse(base(<String, Object?>{})).defaultTransition.type,
        'fade',
      );
    });

    test('a named transition fills every field at parse time', () {
      // Nothing downstream should have to invent a number: a renderer that
      // supplies its own default is a default that can drift from the format's.
      final TransitionSpec slide = transitionOf(<String, Object?>{
        'type': 'slide',
      });
      expect(slide.frames, 12);
      expect(slide.y, 60);
      expect(slide.curve, 'outCubic');
      expect(slide.fade, isTrue);
    });

    test('what the document does say wins', () {
      final TransitionSpec scale = transitionOf(<String, Object?>{
        'type': 'scale',
        'frames': 4,
        'scale': 0.5,
      });
      expect(scale.frames, 4);
      expect(scale.scale, 0.5);
      expect(scale.curve, 'outCubic');
    });

    test('an unknown transition is named', () {
      expect(
        problems(
          base(<String, Object?>{
            'transition': <String, Object?>{'type': 'dissolve'},
          }),
        ),
        contains(contains('"dissolve" is not one of')),
      );
    });
  });

  group('the vocabulary is enumerable', () {
    test('every node type reports what it accepts', () {
      expect(knownNodeTypes.keys, contains('titleCard'));
      expect(knownNodeTypes['barChart']!.specs.keys, contains('bars'));
      expect(knownNodeTypes['column']!.lists, contains('children'));
      expect(knownNodeTypes['padding']!.slots, contains('child'));
      expect(knownNodeTypes['expanded']!.parentData, isTrue);
    });

    test('every closed name set is non-empty and lower-camel', () {
      for (final MapEntry<String, Set<String>> entry in <String, Set<String>>{
        'curveNames': curveNames,
        'paletteRoles': paletteRoles,
        'alignmentNames': alignmentNames,
        'fitNames': fitNames,
        'enterModes': enterModes,
        'textRoles': textRoles,
        'transitionNames': transitionNames,
      }.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
        for (final String name in entry.value) {
          expect(
            name,
            matches(RegExp(r'^[a-z][A-Za-z0-9]*$')),
            reason: '${entry.key} contains "$name"',
          );
        }
      }
    });
  });
}
