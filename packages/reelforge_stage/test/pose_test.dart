import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

void main() {
  group('Pose', () {
    test('a joint it does not mention is a joint at rest', () {
      expect(Pose.rest['elbow'], Joint.rest);
    });

    test('overlay replaces what it names and leaves the rest', () {
      const Pose walk = Pose(<String, Joint>{
        'hip': Joint.rotate(20),
        'shoulder': Joint.rotate(10),
      });
      const Pose wave = Pose(<String, Joint>{'shoulder': Joint.rotate(-120)});
      final Pose merged = walk.overlay(wave);
      expect(merged['hip'].degrees, 20);
      expect(merged['shoulder'].degrees, -120);
    });

    test('plus adds angles and multiplies scales', () {
      const Pose a = Pose(<String, Joint>{
        'head': Joint(degrees: 4, move: Offset(1, 2), scaleY: 0.5),
      });
      const Pose b = Pose(<String, Joint>{
        'head': Joint(degrees: 3, move: Offset(1, 1), scaleY: 0.5),
        'tail': Joint.rotate(9),
      });
      final Pose sum = a.plus(b);
      expect(sum['head'].degrees, 7);
      expect(sum['head'].move, const Offset(2, 3));
      expect(sum['head'].scaleY, 0.25);
      expect(sum['tail'].degrees, 9);
    });

    test('lerp blends a joint only one side mentions against rest', () {
      const Pose a = Pose(<String, Joint>{'arm': Joint.rotate(100)});
      final Pose half = Pose.lerp(a, Pose.rest, 0.5);
      expect(half['arm'].degrees, 50);
    });

    test('poses compare by what they say, not by identity', () {
      expect(
        const Pose(<String, Joint>{'a': Joint.rotate(1)}),
        const Pose(<String, Joint>{'a': Joint.rotate(1)}),
      );
      expect(
        const Pose(<String, Joint>{'a': Joint.rotate(1)}),
        isNot(const Pose(<String, Joint>{'a': Joint.rotate(2)})),
      );
    });
  });

  group('Take', () {
    const Take take = Take(<Keyframe>[
      Keyframe(10, Pose(<String, Joint>{'arm': Joint.rotate(0)}), curve: Curves.linear),
      Keyframe(20, Pose(<String, Joint>{'arm': Joint.rotate(100)}), curve: Curves.linear),
      Keyframe(30, Pose(<String, Joint>{'arm': Joint.rotate(0)}), curve: Curves.linear),
    ]);

    test('holds the first pose before it starts and the last after it ends', () {
      expect(take.at(0)['arm'].degrees, 0);
      expect(take.at(99)['arm'].degrees, 0);
    });

    test('lands exactly on a keyframe and blends between them', () {
      expect(take.at(20)['arm'].degrees, 100);
      expect(take.at(15)['arm'].degrees, 50);
      expect(take.at(25)['arm'].degrees, 50);
    });

    test('a keyframe\'s curve shapes the way in, not the way out', () {
      const Take eased = Take(<Keyframe>[
        Keyframe(0, Pose(<String, Joint>{'arm': Joint.rotate(0)})),
        Keyframe(10, Pose(<String, Joint>{'arm': Joint.rotate(100)}), curve: Curves.easeIn),
        Keyframe(20, Pose(<String, Joint>{'arm': Joint.rotate(0)}), curve: Curves.linear),
      ]);
      expect(eased.at(5)['arm'].degrees, lessThan(50)); // easeIn is slow early
      expect(eased.at(15)['arm'].degrees, 50); // the way back is linear
    });

    test('a loop repeats, and its seam is the same pose both sides', () {
      const Take cycle = Take(<Keyframe>[
        Keyframe(0, Pose(<String, Joint>{'leg': Joint.rotate(-20)}), curve: Curves.linear),
        Keyframe(12, Pose(<String, Joint>{'leg': Joint.rotate(20)}), curve: Curves.linear),
        Keyframe(24, Pose(<String, Joint>{'leg': Joint.rotate(-20)}), curve: Curves.linear),
      ], loop: true);
      expect(cycle.at(6)['leg'].degrees, cycle.at(6 + 24)['leg'].degrees);
      expect(cycle.at(6)['leg'].degrees, cycle.at(6 + 24 * 50)['leg'].degrees);
      expect(cycle.at(24)['leg'].degrees, cycle.at(0)['leg'].degrees);
    });

    test('length is first keyframe to last', () {
      expect(take.length, 20);
    });
  });

  test('oscillate is a function of frame and fps, not of either alone', () {
    // One hertz at 30fps and at 60fps is the same motion.
    expect(oscillate(15, 30, hertz: 1), closeTo(oscillate(30, 60, hertz: 1), 1e-9));
    expect(oscillate(0, 30), 0);
  });
}
