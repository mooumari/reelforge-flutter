import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

/// "Hi there.", as Azure might time it: two words, then a second of silence.
const Line _hi = Line(
  text: 'Hi there.',
  audio: 'assets/hi.wav',
  seconds: 2.0,
  visemes: <(int, int)>[(500000, 0), (1000000, 12), (3000000, 4), (8000000, 0)],
  words: <(int, int, String)>[(500000, 3000000, 'Hi'), (4000000, 4000000, 'there')],
);

void main() {
  group('Line', () {
    test('is spoken until the last sound, not the end of the audio', () {
      expect(_hi.spoken, closeTo(0.8, 1e-9));
    });

    test('moves the mouth from when it is said', () {
      final Speech s = _hi.speech(start: 3);
      expect(s.visemes.first.seconds, closeTo(3.05, 1e-9));
      expect(s.words.last.text, 'there');
      expect(s.words.last.end, closeTo(3.8, 1e-9));
    });
  });

  group('Performance', () {
    const Say first = Say(_hi, at: 1);
    final Say second = Say(_hi, at: first.end + 0.5);
    final Performance p = Performance(
      fps: 30,
      startX: 100,
      beats: <Beat>[
        second,
        const Move(700, at: 0.5, seconds: 2),
        first,
        const Feel(Emotion.happy, at: 1, ease: 0.5),
        const Feel(Emotion.neutral, at: 3, ease: 0.5),
        const Look(Offset(0.5, 0), at: 1),
        const Act(Character.nod, at: 2, add: true),
      ],
    );

    test('lays a line out after the one before it has been said', () {
      expect(second.at, closeTo(2.3, 1e-9));
      expect(p.lines, <Say>[first, second]);
      // The nod, at 2s, is the last thing done.
      expect(p.end, closeTo(4, 1e-9));
    });

    test('walks its moves as a route', () {
      final List<Waypoint> route = p.route;
      expect(route.map((Waypoint w) => w.frame), <int>[0, 15, 75]);
      expect(route.map((Waypoint w) => w.x), <double>[100, 100, 700]);
    });

    test('says each line and lets the bubble linger', () {
      expect(p.sayingAt(20), isNull);
      expect(p.sayingAt(31), first);
      expect(p.sayingAt(60), first);
      expect(p.sayingAt(72), second);
      expect(p.sayingAt(200), isNull);
    });

    test('feels, and lets the feeling go', () {
      const FaceStyle face = FaceStyle();
      expect(p.face(face, 20), isNot(p.face(face, 45)));
      expect(p.face(face, 120), p.face(face, 130));
    });

    test('plays a gesture over the body while it lasts', () {
      expect(p.acts(30, Pose.rest), Pose.rest);
      expect(p.acts(70, Pose.rest)['head'].degrees, greaterThan(0));
      expect(p.acts(200, Pose.rest), Pose.rest);
    });

    testWidgets('plays each line\'s audio from when it is said', (WidgetTester tester) async {
      final List<Widget> audio = p.audio();
      expect(audio, hasLength(2));
      final Sequence s = audio.last as Sequence;
      expect(s.from, 69);
      expect((s.child as Audio).src, 'assets/hi.wav');
    });
  });

  test('a stroll is steady through the middle', () {
    const Stroll stroll = Stroll(0.2);
    expect(stroll.transform(0), 0);
    expect(stroll.transform(1), 1);
    expect(stroll.transform(0.5), closeTo(0.5, 1e-9));
    final double mid = stroll.transform(0.45) - stroll.transform(0.4);
    expect(stroll.transform(0.75) - stroll.transform(0.7), closeTo(mid, 1e-9));
    expect(stroll.transform(0.05) - stroll.transform(0), lessThan(mid / 2));
  });
}
