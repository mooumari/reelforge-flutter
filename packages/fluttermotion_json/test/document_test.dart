import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion_json/fluttermotion_json.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';

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

List<String> problems(Map<String, Object?> json) =>
    MotionDocument.problemsIn(json)
        .map((SchemaProblem problem) => problem.toString())
        .toList();

void main() {
  group('shape', () {
    test('a minimal storyboard parses and knows how long it is', () {
      final MotionDocument document = MotionDocument.parse(base(<String, Object?>{}));
      expect(document.id, 'Test');
      expect(document.durationInFrames, 60);
      expect(document.toComposition().durationInFrames, 60);
    });

    test('a JSON string parses as readily as a decoded map', () {
      expect(
        MotionDocument.parse(
          '{"id":"S","width":10,"height":10,"fps":30,'
          '"root":{"type":"text","value":"x"},"durationInFrames":5}',
        ).durationInFrames,
        5,
      );
    });

    test('malformed JSON is a schema problem, not a crash', () {
      expect(
        () => MotionDocument.parse('{not json'),
        throwsA(isA<SchemaException>()),
      );
    });

    test('a document is a storyboard or a tree, never both or neither', () {
      expect(
        problems(base(<String, Object?>{
          'root': <String, Object?>{'type': 'text', 'value': 'x'},
        })),
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
        problems(base(<String, Object?>{'version': currentDocumentVersion + 1})),
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
        problems(base(<String, Object?>{
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
        })),
        contains(startsWith('scenes[0].child.children[1].type:')),
      );
    });

    test('a misspelt property is a problem, not a silent default', () {
      expect(
        problems(base(<String, Object?>{
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
        })),
        contains(contains('unknown property "subhed"')),
      );
    });

    test('an unknown filter is caught before it renders as nothing', () {
      expect(
        problems(base(<String, Object?>{
          'scenes': <Object?>[
            <String, Object?>{
              'seconds': 1,
              'child': <String, Object?>{
                'type': 'sizedBox',
                'width': '{{ n | shout }}',
              },
            },
          ],
        })),
        contains(contains('unknown filter "shout"')),
      );
    });

    test('keyframes out of order are named rather than asserted on', () {
      expect(
        problems(base(<String, Object?>{
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
        })),
        contains(contains('increasing frame order')),
      );
    });

    test('a source that leaves the project is refused', () {
      for (final String src in <String>['../secrets.mp4', '/etc/passwd']) {
        expect(
          problems(base(<String, Object?>{
            'scenes': <Object?>[
              <String, Object?>{
                'seconds': 1,
                'child': <String, Object?>{'type': 'video', 'src': src},
              },
            ],
          })),
          contains(contains('leaves the project directory')),
          reason: src,
        );
      }
    });

    test('a scene needs exactly one of seconds or frames', () {
      expect(
        problems(base(<String, Object?>{
          'scenes': <Object?>[
            <String, Object?>{
              'seconds': 1,
              'frames': 30,
              'child': <String, Object?>{'type': 'text', 'value': 'x'},
            },
          ],
        })),
        contains(contains('exactly one of "seconds" or "frames"')),
      );
    });
  });

  group('theme', () {
    test('a named palette and a font reach the composition', () {
      final MotionDocument document = MotionDocument.parse(base(<String, Object?>{
        'theme': <String, Object?>{
          'palette': 'light',
          'font': 'Roboto',
          'scale': 0.5,
        },
      }));
      expect(document.palette.background, MotionPalette.light.background);
      expect(document.typography.fontFamily, 'Roboto');
      expect(document.typography.headlineSize, 58 * 0.5);
    });

    test('roles can be overridden with hex on top of a base', () {
      final MotionDocument document = MotionDocument.parse(base(<String, Object?>{
        'theme': <String, Object?>{
          'palette': <String, Object?>{'base': 'dark', 'accent': '#FF00FF'},
        },
      }));
      expect(document.palette.accent, const Color(0xFFFF00FF));
      expect(document.palette.background, MotionPalette.dark.background);
    });

    test('a role cannot be defined as another role', () {
      expect(
        problems(base(<String, Object?>{
          'theme': <String, Object?>{
            'palette': <String, Object?>{'accent': 'warning'},
          },
        })),
        contains(contains('cannot define a role as another role')),
      );
    });
  });

  test('the vocabulary is enumerable', () {
    expect(knownNodeTypes.keys, contains('barChart'));
    expect(knownNodeTypes['barChart']!.specs, contains('bars'));
    expect(knownNodeTypes['column']!.knownKeys, contains('children'));
  });
}
