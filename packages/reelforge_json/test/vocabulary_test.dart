import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge_json/reelforge_json.dart';
import 'package:reelforge_kit/reelforge_kit.dart';

/// The seam between the format and the widgets that draw it.
///
/// `reelforge_schema` says which names a document may use;
/// `reelforge_json` says what each of those names is. Splitting them is
/// what lets `validate` run in plain Dart -- and it is also what makes it
/// possible for the two halves to disagree.
///
/// Every test here is about one failure: a name one side knows and the other
/// does not. That failure is silent in the worst way. A curve the validator
/// accepts with no entry in the table renders as `linear`; a node the builder
/// draws with no schema renders in the app and fails `validate`. Both look
/// like the document is wrong.
void main() {
  setUpAll(
    () => MotionDocument.parse(<String, Object?>{
      'id': 'Warm',
      'width': 10,
      'height': 10,
      'fps': 30,
      'durationInFrames': 1,
      'root': <String, Object?>{'type': 'text', 'value': 'x'},
    }),
  );

  group('every name has a value behind it', () {
    void covers<T>(String label, Set<String> names, Map<String, T> table) {
      test(label, () {
        expect(
          table.keys.toSet(),
          names,
          reason:
              '$label: the schema and the table disagree. A name in the '
              'schema with no value renders as a default; a value with no '
              'name cannot be written in a document.',
        );
      });
    }

    covers('curves', curveNames, namedCurves);
    covers('alignments', alignmentNames, namedAlignments);
    covers('fits', fitNames, namedFits);
    covers('main axis', mainAxisNames, namedMainAxis);
    covers('cross axis', crossAxisNames, namedCrossAxis);
    covers('kit cross axis', kitCrossAxisNames, namedKitCrossAxis);
    covers('main axis size', mainAxisSizeNames, namedMainAxisSize);
    covers('stack fits', stackFitNames, namedStackFits);
    covers('font weights', fontWeightNames, namedWeights);
    covers('text aligns', textAlignNames, namedTextAligns);
    covers('axes', axisNames, namedAxes);

    test('palette roles', () {
      // No table to compare against -- the roles are a switch over a palette
      // -- so this asks the switch instead, and would catch a role added to
      // the schema that quietly falls through to `outline`.
      const MotionPalette palette = MotionPalette.dark;
      final Set<Color> seen = <Color>{};
      for (final String role in paletteRoles) {
        seen.add(roleColour(palette, role));
      }
      expect(
        seen.length,
        paletteRoles.length,
        reason:
            'two roles resolve to the same colour, which means one of '
            'them is falling through the switch',
      );
    });

    test('text roles', () {
      const MotionTypography type = MotionTypography();
      final Set<double> seen = <double>{};
      for (final String role in textRoles) {
        seen.add(roleSize(type, role));
      }
      expect(
        seen.length,
        textRoles.length,
        reason:
            'two text roles resolve to the same size, which means one '
            'of them is falling through to body',
      );
    });

    test('palettes', () {
      expect(
        basePalette('light').background,
        isNot(basePalette('dark').background),
      );
      for (final String name in paletteNames) {
        expect(basePalette(name), isA<MotionPalette>());
      }
    });
  });

  group('every node type can be drawn', () {
    test('nothing the schema declares is missing a builder', () {
      expect(
        unbuildableNodeTypes,
        isEmpty,
        reason: 'these node types validate but cannot render',
      );
    });

    test('a builder cannot be registered for a type with no schema', () {
      // The direction that matters. A node that draws but does not validate
      // would work in the app and be rejected by the CLI, which reads as the
      // document being wrong when it is the build that is.
      expect(
        () => registerBuilder(
          'notANode',
          (BuildContext context, MotionNode node) => const SizedBox.shrink(),
        ),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('No schema for node type'),
          ),
        ),
      );
    });

    test('the counts line up', () {
      expect(knownNodeTypes.length, greaterThan(25));
      for (final String name in knownNodeTypes.keys) {
        expect(builderFor(name), isNotNull, reason: name);
      }
    });
  });

  group('transitions', () {
    test('every transition name builds something', () {
      for (final String name in transitionNames) {
        expect(
          sceneTransition(switch (name) {
            'none' => const TransitionSpec.none(),
            'slide' => const TransitionSpec.slide(),
            'scale' => const TransitionSpec.scale(),
            _ => const TransitionSpec.fade(),
          }),
          isA<SceneTransition>(),
          reason: name,
        );
      }
    });

    test('the format\'s defaults are the ones that reach the kit', () {
      // The spec fills its defaults at parse time and the builder passes them
      // straight through, so there is exactly one place a document\'s default
      // fade length is written down.
      const TransitionSpec fade = TransitionSpec.fade();
      expect(fade.frames, 8);
      expect(sceneTransition(fade), isA<SceneTransition>());
    });
  });
}
