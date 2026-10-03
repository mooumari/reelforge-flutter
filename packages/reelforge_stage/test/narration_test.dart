import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_stage/reelforge_stage.dart';

/// A line of [words] one-second words, spoken over `words` seconds and
/// followed by half a second of silence in the audio.
Line _line(String text, {int? voiced}) {
  final List<String> tokens = text.split(' ');
  return Line(
    text: text,
    audio: 'assets/${tokens.first}.wav',
    seconds: tokens.length + 0.5,
    visemes: const <(int, int)>[(0, 0)],
    words: <(int, int, String)>[
      for (int i = 0; i < (voiced ?? tokens.length); i++) (i * 10000000, 10000000, tokens[i]),
    ],
  );
}

void main() {
  final Narration voice = Narration(
    <Line>[_line('one two'), _line('three'), _line('four five six')],
    lead: 1,
    gap: 0.5,
    tail: 2,
  );

  group('Narration', () {
    test('lays lines end to end by how long they are said', () {
      expect(voice.starts, <double>[1, 3.5, 5]);
      expect(voice.ends, <double>[3, 4.5, 8]);
      expect(voice.seconds, 10);
      expect(voice.framesAt(30), 300);
    });

    test('cuts in the middle of the pauses, and the shots add up to the video', () {
      expect(voice.cuts(<int>[1, 2]), <double>[0, 3.25, 10]);
      expect(voice.cuts(<int>[1, 1, 1]), <double>[0, 3.25, 4.75, 10]);
      final List<double> lengths = voice.lengths(<int>[1, 1, 1]);
      expect(lengths.fold(0.0, (double a, double b) => a + b), voice.seconds);
    });

    test('says which line is being said, and keeps it a moment', () {
      expect(voice.lineAt(0.2), isNull);
      expect(voice.lineAt(2), 0);
      expect(voice.lineAt(3.2), 0);
      expect(voice.lineAt(3.6), 1);
      expect(voice.lineAt(9), isNull);
    });

    testWidgets('plays each line from when it is said', (WidgetTester tester) async {
      final List<Sequence> audio = voice.audio(fps: 30).cast<Sequence>();
      expect(audio.map((Sequence s) => s.from), <int>[30, 105, 150]);
      expect((audio.last.child as Audio).src, 'assets/four.wav');
    });
  });

  group('Captions', () {
    test("takes the voice's own times for each word", () {
      final List<(double, double)> times = Captions.wordTimes(_line('one two three'));
      expect(times, <(double, double)>[(0, 1), (1, 2), (2, 3)]);
    });

    test('spreads the words over the speech when the voice heard them differently', () {
      // The voice reported two words for three: say, "twenty-one" for "21".
      final List<(double, double)> times = Captions.wordTimes(_line('it is 21', voiced: 2));
      expect(times, hasLength(3));
      expect(times.first.$1, 0);
      expect(times.last.$2, closeTo(2, 1e-9));
      expect(times[1].$1, closeTo(times[0].$2, 1e-9));
    });
  });
}
