import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_json/fluttermotion_json.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';

/// What a parsed document becomes once there is a Flutter engine under it.
///
/// The format itself -- its shape, its paths, and every problem it can have --
/// is tested in `fluttermotion_schema`, in plain Dart and without a binding.
/// What is left here is the half that needs one: a theme that has become a
/// palette, and a document that has become a `Composition`.
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

void main() {
  group('becoming a composition', () {
    test('a document carries its own size and length across', () {
      final MotionDocument document = MotionDocument.parse(
        base(<String, Object?>{}),
      );
      final Composition composition = document.toComposition();
      expect(composition.id, 'Test');
      expect(composition.width, 1080);
      expect(composition.height, 1920);
      expect(composition.fps, 30);
      expect(composition.durationInFrames, 60);
    });

    test('the parsed document is reachable as data', () {
      // The same DocumentSpec a validator would look at -- there is one parse,
      // not one for checking and another for rendering.
      final MotionDocument document = MotionDocument.parse(
        base(<String, Object?>{}),
      );
      expect(document.spec, isA<DocumentSpec>());
      expect(document.spec.scenes.single.frames, 60);
    });

    test('problemsIn is the schema\'s answer, unchanged', () {
      expect(
        MotionDocument.problemsIn(<String, Object?>{
          'id': 'x',
        }).map((SchemaProblem p) => p.path),
        DocumentSpec.problemsIn(<String, Object?>{
          'id': 'x',
        }).map((SchemaProblem p) => p.path),
      );
    });

    test('a broken document throws with every problem, not the first', () {
      expect(
        () => MotionDocument.parse('{not json'),
        throwsA(isA<SchemaException>()),
      );
    });
  });

  group('theme', () {
    test('a named palette and a font reach the composition', () {
      final MotionDocument document = MotionDocument.parse(
        base(<String, Object?>{
          'theme': <String, Object?>{
            'palette': 'light',
            'font': 'Roboto',
            'scale': 0.5,
          },
        }),
      );
      expect(document.palette.background, MotionPalette.light.background);
      expect(document.typography.fontFamily, 'Roboto');
      expect(document.typography.headlineSize, 58 * 0.5);
    });

    test('roles can be overridden with hex on top of a base', () {
      final MotionDocument document = MotionDocument.parse(
        base(<String, Object?>{
          'theme': <String, Object?>{
            'palette': <String, Object?>{'base': 'dark', 'accent': '#FF00FF'},
          },
        }),
      );
      expect(document.palette.accent, const Color(0xFFFF00FF));
      expect(document.palette.background, MotionPalette.dark.background);
    });

    test('a size the document sets moves; the rest keep the kit\'s', () {
      // Overriding one size used to mean restating all seven, which is how a
      // default drifts. The document now carries only what it said.
      final MotionDocument document = MotionDocument.parse(
        base(<String, Object?>{
          'theme': <String, Object?>{
            'sizes': <String, Object?>{'headline': 40},
          },
        }),
      );
      const MotionTypography kit = MotionTypography();
      expect(document.typography.headline, 40);
      expect(document.typography.display, kit.display);
      expect(document.typography.statistic, kit.statistic);
    });
  });
}
