import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

const List<String> _ankles = <String>['footF', 'pawF', 'footB', 'pawB'];

/// Walks [lion] seven strides at a lion's pace, and stops.
Gait _gait(Lion lion, {bool left = false}) {
  final double stride = lion.leg * 1.2 * 0.95, start = left ? 1600.0 : 0.0, dir = left ? -1.0 : 1.0;
  return Gait(
    rig: lion.part,
    route: <Waypoint>[
      Waypoint(0, start),
      Waypoint(12, start + dir * stride * 0.4, curve: Curves.easeInSine),
      Waypoint(100, start + dir * stride * 6.4, curve: Curves.linear),
      Waypoint(130, start + dir * stride * 7),
    ],
    groundY: 900,
    fps: 30,
    scale: 1.2,
    body: lion.quadruped,
  );
}

Offset _ankle(Posed p, String name) => frameOf(p.part, p.pose, name).apply(Offset.zero);

void main() {
  group('Gait', () {
    for (final (String, Lion) l in const <(String, Lion)>[('lion', Lion.male), ('lioness', Lion.female), ('cub', Lion.cub)]) {
      test('a ${l.$1} reaches every footfall, every frame, either way', () {
        for (final bool left in <bool>[false, true]) {
          final Gait gait = _gait(l.$2, left: left);
          for (int f = 0; f <= 160; f++) {
            final Posed p = gait.at(f);
            for (int leg = 0; leg < 4; leg++) {
              expect((_ankle(p, _ankles[leg]) - gait.ankleAt(leg, f)).distance, lessThan(0.05),
                  reason: '${_ankles[leg]}, frame $f, ${left ? 'left' : 'right'}');
            }
          }
        }
      });
    }

    test('a planted paw stays where it landed', () {
      final Gait gait = _gait(Lion.male);
      for (int leg = 0; leg < 4; leg++) {
        int checked = 0;
        for (final Footstep step in gait.steps.where((Footstep s) => s.foot == leg)) {
          final List<Offset> at = <Offset>[];
          for (int f = step.land.ceil(); gait.plantedAt(leg, f) && f < 200; f++) {
            at.add(_ankle(gait.at(f), _ankles[leg]));
          }
          for (final Offset a in at) {
            expect((a - at.first).distance, lessThan(0.05), reason: '${_ankles[leg]} slid after landing at ${step.land}');
          }
          checked += at.length;
        }
        expect(checked, greaterThan(20));
      }
    });

    test('the legs go hind, fore, hind, fore, and every leg steps', () {
      final Gait gait = _gait(Lion.male);
      final List<Footstep> strides = gait.steps.where((Footstep s) => (s.to - s.from).abs() > gait.stepLength * 0.6).toList();
      for (int leg = 0; leg < 4; leg++) {
        expect(strides.where((Footstep s) => s.foot == leg).length, greaterThan(3));
      }
      for (int i = 1; i < 8; i++) {
        expect(strides[i].foot, (strides[i - 1].foot + 1) % 4, reason: 'step $i');
      }
    });

    test('never fewer than two paws on the ground', () {
      final Gait gait = _gait(Lion.male);
      for (double f = 0; f < 160; f += 0.25) {
        final int down = <int>[0, 1, 2, 3].where((int leg) => gait.plantedAt(leg, f)).length;
        expect(down, greaterThanOrEqualTo(2), reason: 'frame $f');
      }
    });

    test('it stands square when it stops', () {
      final Gait gait = _gait(Lion.male);
      for (int leg = 0; leg < 4; leg++) {
        expect(gait.plantedAt(leg, 200), isTrue);
      }
      expect(gait.at(200).pose, gait.at(220).pose);
    });

    test('a frame is a function of its number', () {
      final Gait a = _gait(Lion.male), b = _gait(Lion.male);
      for (final int f in <int>[0, 37, 80, 121, 190]) {
        expect(a.at(f).pose, b.at(f).pose);
      }
    });
  });

  group('Lion', () {
    test('has the joints its gait, life and follow-through drive', () {
      for (final Lion lion in const <Lion>[Lion.male, Lion.female, Lion.cub]) {
        for (final String joint in <String>[
          'hips', 'chest', 'head', ..._ankles, 'kneeF', 'elbowF', 'tail0', ...FaceJoints.eyes, FaceJoints.mouth,
        ]) {
          expect(pathTo(lion.part, joint), isNotNull, reason: joint);
        }
        for (final Jiggle j in lion.jiggles) {
          expect(pathTo(lion.part, j.joint), isNotNull, reason: j.joint);
        }
      }
    });

    testWidgets('draws, with and without a mane', (WidgetTester tester) async {
      for (final Lion lion in const <Lion>[Lion.male, Lion.female, Lion.cub]) {
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Drawing(lion.part.placed(at: lion.standing(400, 500)), pose: lion.stance.plus(lion.life(1).at(20, 30))),
        ));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('a monkey', () {
    const Character monkey = Character(
      skin: Color(0xFF8A5A3A),
      outfit: <Garment>[Fur(Color(0xFFD9AE84), crown: Color(0xFF6E4429)), MonkeyFace(Color(0xFFF0C9A0)), Tail(Color(0xFF8A5A3A))],
    );

    test('has a tail that curls at rest and swings', () {
      expect(pathTo(monkey.part, 'tail0'), isNotNull);
      expect(monkey.stance['tail4'].degrees, greaterThan(0));
      expect(monkey.jiggles.map((Jiggle j) => j.joint), contains('tail6'));
    });

    test('its muzzle replaces the nose', () {
      int shapes(Part p) => p.shapes.length + p.children.fold(0, (int n, Part c) => n + shapes(c));
      const Character bare = Character(skin: Color(0xFF8A5A3A), outfit: <Garment>[MonkeyFace(Color(0xFFF0C9A0))]);
      const Character person = Character(skin: Color(0xFF8A5A3A));
      // The face adds a mask, a muzzle, nostrils and an ear, and takes away
      // the nose and the person's ear.
      expect(shapes(bare.part) - shapes(person.part), 6 - 1 - 2);
    });
  });
}
