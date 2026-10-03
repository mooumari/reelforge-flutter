import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'outline.dart';
import 'part.dart';
import 'pose.dart';
import 'shape.dart';

/// The joints of a face built by [FaceStyle.build].
///
/// Expressions, speech, gaze and blinks are all poses on these names, so
/// anything written against them works on every face -- a cowboy's, a
/// cyborg's, a lion's -- whatever it looks like.
abstract final class FaceJoints {
  static const String face = 'face';
  static const String eyeL = 'eyeL';
  static const String eyeR = 'eyeR';
  static const String pupilL = 'pupilL';
  static const String pupilR = 'pupilR';
  static const String browL = 'browL';
  static const String browR = 'browR';
  static const String mouth = 'mouth';
  static const List<String> eyes = <String>[eyeL, eyeR];
  static const List<String> pupils = <String>[pupilL, pupilR];
}

/// The feelings a face can show. Each is a pose; see [FaceStyle.express].
enum Emotion { neutral, happy, sad, angry, surprised, worried, disgusted, smug }

/// What a face looks like, and how to pose it.
///
/// One style is one look -- eye size and spacing, brows, mouth, colours --
/// and [build] draws it as parts. Everything that animates a face goes
/// through the same joints and shape keys, so a new character is a new
/// style, and every expression, viseme and glance already works on it.
///
/// The face is drawn around its own origin, between the eyes, front on.
/// [turn] slides the features across the head for a three-quarter view.
@immutable
class FaceStyle {
  const FaceStyle({
    this.eyeSpacing = 62,
    this.eyeY = 0,
    this.eyeWidth = 30,
    this.eyeHeight = 36,
    this.eyeColor = const Color(0xFFFFFFFF),
    this.pupilColor = const Color(0xFF1E1433),
    this.pupilRadius = 9,
    this.highlight = true,
    this.browGap = 32,
    this.browLength = 32,
    this.browThickness = 7,
    this.browColor = const Color(0xFF3A2416),
    this.mouthY = 44,
    this.mouthWidth = 46,
    this.mouthColor = const Color(0xFF5A1F2B),
    this.teethColor = const Color(0xFFFFFFFF),
    this.tongueColor = const Color(0xFFE0707E),
    this.nose = const <Shape>[],
    this.noseY = 22,
    this.cheeks,
    this.turnRange = 20,
  });

  /// Between the eyes' centres.
  final double eyeSpacing;
  final double eyeY;
  final double eyeWidth;
  final double eyeHeight;
  final Color eyeColor;
  final Color pupilColor;
  final double pupilRadius;

  /// A glint on each pupil.
  final bool highlight;

  /// How far above each eye's centre its brow sits.
  final double browGap;
  final double browLength;

  /// Zero draws no brows.
  final double browThickness;
  final Color browColor;

  final double mouthY;
  final double mouthWidth;

  /// The inside of the mouth -- what shows of it is the mouth.
  final Color mouthColor;
  final Color teethColor;
  final Color tongueColor;

  /// Drawn at [noseY] below the eyes, under them in the stack. Empty for no
  /// nose.
  final List<Shape> nose;
  final double noseY;

  /// A blush under each eye, if given.
  final Color? cheeks;

  /// How far the features slide when the head is fully turned; see [turn].
  final double turnRange;

  double get _rx => eyeWidth / 2;
  double get _ry => eyeHeight / 2;

  // --- drawing ---

  /// The face as parts: a `face` part holding the brows, eyes (pupils clipped
  /// inside them) and mouth (teeth and tongue clipped inside it).
  Part build() => Part(
        name: FaceJoints.face,
        children: <Part>[
          if (cheeks != null)
            for (final double side in <double>[-1, 1])
              Part(
                at: Offset(side * (eyeSpacing / 2 + _rx * 0.3), eyeY + _ry + 10),
                shapes: <Shape>[Shape(Paths.ellipse(Offset.zero, _rx * 0.9, _ry * 0.35), color: cheeks)],
              ),
          if (nose.isNotEmpty) Part(at: Offset(0, eyeY + noseY), shapes: nose),
          _eye(FaceJoints.eyeL, FaceJoints.pupilL, -1),
          _eye(FaceJoints.eyeR, FaceJoints.pupilR, 1),
          if (browThickness > 0) ...<Part>[
            Part(
              name: FaceJoints.browL,
              at: Offset(-eyeSpacing / 2, eyeY - browGap),
              shapes: <Shape>[Shape.blend(_brows, color: browColor)],
            ),
            Part(
              name: FaceJoints.browR,
              at: Offset(eyeSpacing / 2, eyeY - browGap),
              shapes: <Shape>[Shape.blend(_brows, color: browColor)],
            ),
          ],
          Part(
            name: FaceJoints.mouth,
            at: Offset(0, eyeY + mouthY),
            clip: true,
            shapes: <Shape>[Shape.blend(_mouth, color: mouthColor)],
            children: <Part>[
              Part(shapes: <Shape>[
                Shape(
                  Paths.rect(Rect.fromLTRB(-mouthWidth, -mouthWidth, mouthWidth, -0.07 * mouthWidth)),
                  color: teethColor,
                ),
                Shape(
                  Paths.ellipse(Offset(0, 0.47 * mouthWidth), 0.28 * mouthWidth, 0.18 * mouthWidth),
                  color: tongueColor,
                ),
              ]),
            ],
          ),
        ],
      );

  /// [side] is -1 for the eye on the left of the drawing, 1 for the right.
  Part _eye(String name, String pupil, double side) => Part(
        name: name,
        at: Offset(side * eyeSpacing / 2, eyeY),
        clip: true,
        shapes: <Shape>[Shape.blend(side < 0 ? _eyeLeft : _eyeRight, color: eyeColor)],
        children: <Part>[
          Part(
            name: pupil,
            shapes: <Shape>[
              Shape(Paths.circle(Offset.zero, pupilRadius), color: pupilColor),
              if (highlight)
                Shape(
                  Paths.circle(Offset(-pupilRadius * 0.35, -pupilRadius * 0.4), pupilRadius * 0.32),
                  color: const Color(0xDDFFFFFF),
                ),
            ],
          ),
        ],
      );

  // Shape keys. Every eye key is the same sixteen points round the ellipse,
  // moved; every mouth key the same eight. Drawn alike, they blend cleanly
  // in any mix.

  static final Expando<Blend> _eyeLefts = Expando<Blend>();
  static final Expando<Blend> _eyeRights = Expando<Blend>();
  static final Expando<Blend> _browBlends = Expando<Blend>();
  static final Expando<Blend> _mouthBlends = Expando<Blend>();

  Blend get _eyeLeft => _eyeLefts[this] ??= _eyeBlend(-1);
  Blend get _eyeRight => _eyeRights[this] ??= _eyeBlend(1);
  Blend get _brows => _browBlends[this] ??= _browBlend();
  Blend get _mouth => _mouthBlends[this] ??= _mouthBlend();

  /// [outer] is the side the eye's outer corner is on: -1 left, 1 right.
  Blend _eyeBlend(double outer) {
    final double rx = _rx, ry = _ry;
    Path eye(Offset Function(double x, double y, bool top) move) => Paths.smooth(<Offset>[
          for (int k = 0; k < 16; k++)
            () {
              final double a = k * math.pi / 8;
              final double x = rx * math.cos(a), y = ry * math.sin(a);
              return move(x, y, math.sin(a) < -1e-9);
            }(),
        ]);
    double arc(double x) => math.sqrt(math.max(0, 1 - (x / rx) * (x / rx)));
    return Blend(
      eye((double x, double y, bool top) => Offset(x, y)),
      <String, Path>{
        // Lids meeting a little below the middle, in a slight smile.
        'closed': eye((double x, double y, bool top) =>
            Offset(x * 1.05, ry * 0.25 + y * 0.06 - ry * 0.12 * arc(x))),
        // An upturned crescent: the cheeks pushing the eye up.
        'happy': eye((double x, double y, bool top) => Offset(
              x * 1.05,
              top ? ry * 0.3 - ry * 1.0 * arc(x) : ry * 0.3 - ry * 0.45 * arc(x),
            )),
        'squint': eye((double x, double y, bool top) => Offset(x * 1.04, top ? y * 0.45 : y * 0.75)),
        'wide': eye((double x, double y, bool top) => Offset(x * 1.12, y * 1.22)),
        // The upper lid dropping at the outer corner...
        'sad': eye((double x, double y, bool top) => Offset(
              x,
              top ? y + ry * 0.75 * math.max(0, x * outer / rx) * (1 + y / ry * 0.3) : y,
            )),
        // ...or at the inner one.
        'angry': eye((double x, double y, bool top) => Offset(
              x,
              top ? y + ry * 0.62 * math.max(0, -x * outer / rx + 0.15) / 1.15 : y,
            )),
      },
      overriding: const <String>{'closed'},
    );
  }

  Blend _browBlend() {
    final double half = browLength / 2, t = browThickness / 2;
    Path brow(double arch) => Paths.smooth(<Offset>[
          for (int k = 0; k <= 6; k++)
            () {
              final double x = -half + browLength * k / 6;
              final double u = x / half;
              return Offset(x, -t * (1 - u * u * 0.6) - arch * (1 - u * u));
            }(),
          for (int k = 6; k >= 0; k--)
            () {
              final double x = -half + browLength * k / 6;
              final double u = x / half;
              return Offset(x, t * (1 - u * u * 0.6) - arch * (1 - u * u));
            }(),
        ]);
    return Blend(brow(3), <String, Path>{'raise': brow(9), 'flat': brow(-1)});
  }

  Blend _mouthBlend() {
    final double w = mouthWidth;
    Path mouth({
      double width = 1,
      double top = -0.02,
      double bottom = 0.045,
      double left = 0,
      double right = 0,
    }) {
      final double hw = w / 2 * width;
      return Paths.smooth(<Offset>[
        Offset(-hw, left * w),
        Offset(-hw * 0.55, (top * 0.8 + left * 0.35) * w),
        Offset(0, top * w),
        Offset(hw * 0.55, (top * 0.8 + right * 0.35) * w),
        Offset(hw, right * w),
        Offset(hw * 0.55, (bottom * 0.8 + right * 0.35) * w),
        Offset(0, bottom * w),
        Offset(-hw * 0.55, (bottom * 0.8 + left * 0.35) * w),
      ]);
    }

    return Blend(mouth(), <String, Path>{
      // Speech.
      'closed': mouth(width: 0.92, top: 0, bottom: 0.025),
      'teeth': mouth(top: -0.14, bottom: 0.14),
      'ee': mouth(width: 1.15, top: -0.11, bottom: 0.16, left: -0.03, right: -0.03),
      'ah': mouth(width: 0.95, top: -0.14, bottom: 0.56),
      'oh': mouth(width: 0.62, top: -0.2, bottom: 0.42),
      'oo': mouth(width: 0.38, top: -0.12, bottom: 0.18),
      'fv': mouth(width: 0.95, top: -0.1, bottom: 0.08),
      'l': mouth(width: 0.85, top: -0.12, bottom: 0.3),
      // Feeling.
      'smile': mouth(width: 1.1, top: -0.05, bottom: 0.06, left: -0.2, right: -0.2),
      'frown': mouth(width: 0.95, top: 0.04, bottom: 0.08, left: 0.14, right: 0.14),
      'smirk': mouth(width: 1.02, top: -0.04, bottom: 0.05, left: 0.03, right: -0.18),
    });
  }

  // --- posing ---

  /// [emotion] as a pose on the face's joints, [amount] of the way from
  /// neutral. Blend between two with [Pose.lerp]; layer speech and blinks on
  /// top with [Pose.plus].
  Pose express(Emotion emotion, {double amount = 1}) {
    final Pose full = _expressions[emotion]!;
    return amount == 1 ? full : Pose.lerp(Pose.rest, full, amount);
  }

  static Pose _face({
    Map<String, double> eyes = const <String, double>{},
    Map<String, double> mouth = const <String, double>{},
    double browIn = 0,
    double browY = 0,
    double browSquash = 0,
    Map<String, double> brows = const <String, double>{},
    double pupils = 1,
    Offset look = Offset.zero,
    double browLeftY = 0,
  }) =>
      Pose(<String, Joint>{
        FaceJoints.eyeL: Joint(weights: eyes),
        FaceJoints.eyeR: Joint(weights: eyes),
        FaceJoints.pupilL: Joint(scaleX: pupils, scaleY: pupils, move: look),
        FaceJoints.pupilR: Joint(scaleX: pupils, scaleY: pupils, move: look),
        // Positive [browIn] lowers the inner ends: cross. Negative raises
        // them: sad, worried.
        FaceJoints.browL: Joint(
          degrees: browIn,
          move: Offset(browSquash, browY + browLeftY),
          weights: brows,
        ),
        FaceJoints.browR: Joint(degrees: -browIn, move: Offset(-browSquash, browY), weights: brows),
        FaceJoints.mouth: Joint(weights: mouth),
      });

  static final Map<Emotion, Pose> _expressions = <Emotion, Pose>{
    Emotion.neutral: Pose.rest,
    Emotion.happy: _face(
      eyes: const <String, double>{'happy': 0.75},
      mouth: const <String, double>{'smile': 1, 'teeth': 0.25},
      browY: -4,
      brows: const <String, double>{'raise': 0.5},
    ),
    Emotion.sad: _face(
      eyes: const <String, double>{'sad': 0.85},
      mouth: const <String, double>{'frown': 0.9},
      browIn: -14,
      browY: -2,
      look: const Offset(0, 3),
    ),
    Emotion.angry: _face(
      eyes: const <String, double>{'angry': 0.9},
      mouth: const <String, double>{'frown': 0.7, 'teeth': 0.35},
      browIn: 18,
      browY: 5,
      browSquash: 4,
      brows: const <String, double>{'flat': 1},
      pupils: 0.9,
    ),
    Emotion.surprised: _face(
      eyes: const <String, double>{'wide': 1},
      mouth: const <String, double>{'oh': 0.85},
      browY: -11,
      brows: const <String, double>{'raise': 1},
      pupils: 0.78,
    ),
    Emotion.worried: _face(
      eyes: const <String, double>{'wide': 0.45, 'sad': 0.4},
      mouth: const <String, double>{'frown': 0.45, 'teeth': 0.4, 'ee': 0.2},
      browIn: -12,
      browY: -6,
      pupils: 0.85,
    ),
    Emotion.disgusted: _face(
      eyes: const <String, double>{'squint': 0.85},
      mouth: const <String, double>{'frown': 0.9, 'ee': 0.45, 'teeth': 0.3, 'smirk': -0.5},
      browIn: 12,
      browY: 4,
      browLeftY: 7,
    ),
    Emotion.smug: _face(
      eyes: const <String, double>{'squint': 0.5},
      mouth: const <String, double>{'smirk': 1},
      browIn: 4,
      browLeftY: 4,
      brows: const <String, double>{'raise': 0.3},
    ),
  };

  /// A sequence of feelings: each `(frame, emotion)` is reached [transition]
  /// frames after its frame and held until the next.
  Take moods(List<(int, Emotion)> cues, {int transition = 8, double amount = 1}) {
    assert(cues.isNotEmpty);
    assert(
      <int>[for (int i = 1; i < cues.length; i++) cues[i].$1 - cues[i - 1].$1]
          .every((int gap) => gap > transition),
      'Each feeling needs more than `transition` frames before the next.',
    );
    return Take(<Keyframe>[
      Keyframe(0, express(cues.first.$2, amount: amount)),
      for (final (int frame, Emotion e) in cues.skip(1)) ...<Keyframe>[
        Keyframe(frame, _holdBefore(cues, frame, amount)),
        Keyframe(frame + transition, express(e, amount: amount), curve: Curves.easeInOutCubic),
      ],
    ]);
  }

  Pose _holdBefore(List<(int, Emotion)> cues, int frame, double amount) {
    Emotion before = cues.first.$2;
    for (final (int f, Emotion e) in cues) {
      if (f < frame) before = e;
    }
    return express(before, amount: amount);
  }

  /// Pupils looking towards [direction], each axis in -1 to 1: `(1, 0)` is
  /// as far right as the eyes can look.
  Pose look(Offset direction) {
    final Offset d = Offset(direction.dx.clamp(-1.0, 1.0), direction.dy.clamp(-1.0, 1.0));
    final Offset move = Offset(d.dx * (_rx - pupilRadius * 0.6), d.dy * (_ry - pupilRadius * 0.7));
    return Pose(<String, Joint>{
      FaceJoints.pupilL: Joint.move(move),
      FaceJoints.pupilR: Joint.move(move),
    });
  }

  /// The head turned [amount] of the way to a three-quarter view: 1 to the
  /// drawing's right, -1 to its left, 0 front on.
  ///
  /// A flat face cannot really turn, but features sliding across a round
  /// head, with the far side foreshortened, reads as one that does -- and
  /// layered on a head's own small turn it is the classic cut-out-animation
  /// trick for it.
  Pose turn(double amount) {
    final double t = amount.clamp(-1.0, 1.0);
    // The eye on the side the head turns towards goes round the curve of
    // the head: narrower, and drawn in towards the middle.
    final double farL = 1 - 0.32 * math.max(0, -t), farR = 1 - 0.32 * math.max(0, t);
    final double eyesIn = eyeSpacing * 0.08 * t.abs();
    final Offset inL = Offset(t < 0 ? eyesIn : 0, 0), inR = Offset(t > 0 ? -eyesIn : 0, 0);
    return Pose(<String, Joint>{
      FaceJoints.face: Joint.move(Offset(t * turnRange, 0)),
      FaceJoints.eyeL: Joint(scaleX: farL, move: inL),
      FaceJoints.eyeR: Joint(scaleX: farR, move: inR),
      FaceJoints.browL: Joint(scaleX: farL, move: inL),
      FaceJoints.browR: Joint(scaleX: farR, move: inR),
      FaceJoints.mouth: Joint(scaleX: 1 - 0.18 * t.abs(), move: Offset(t * turnRange * 0.25, 0)),
    });
  }
}

/// Eyes that hold, then dart: each `(frame, direction)` is looked at from
/// that frame, reached in a quick [dart] of a few frames, as eyes do.
///
/// [at] is the eyes; [follow] is the same path taken slowly and late, for the
/// head to turn after them.
@immutable
class Gaze {
  const Gaze(this.cues, {this.dart = 4});

  final List<(int, Offset)> cues;
  final int dart;

  Offset at(num frame) => _at(frame, dart, Curves.easeOutCubic);

  /// Where the head is pointing: the eyes' path, [lag] frames late and eased
  /// over [over] frames.
  Offset follow(num frame, {int lag = 3, int over = 14}) =>
      _at(frame - lag, over, Curves.easeInOutCubic);

  Offset _at(num frame, int over, Curve curve) {
    if (cues.isEmpty) return Offset.zero;
    // Before the first cue, and at it, the eyes are simply there. After
    // that each cue starts from wherever the last move had got to.
    Offset from = cues.first.$2, to = cues.first.$2;
    int start = cues.first.$1;
    Offset reached(int now) =>
        Offset.lerp(from, to, curve.transform(((now - start) / over).clamp(0.0, 1.0)))!;
    for (final (int f, Offset d) in cues.skip(1)) {
      if (f > frame) break;
      from = reached(f);
      to = d;
      start = f;
    }
    return Offset.lerp(from, to, curve.transform(((frame - start) / over).clamp(0.0, 1.0)))!;
  }
}

// --- speech ---

/// Mouth shapes for speech: the [FaceStyle] mouth keys, plus [rest].
enum Viseme {
  rest,

  /// m, b, p: lips pressed.
  closed,

  /// s, t, k, d, n...: teeth together, lips parted.
  teeth,
  ee,
  ah,
  oh,
  oo,

  /// f, v: lower lip under the teeth.
  fv,

  /// l, th: tongue up, mouth half open.
  l;

  /// The mouth weights this shape is.
  Map<String, double> get weights =>
      this == rest ? const <String, double>{} : <String, double>{name: 1};

  /// Azure Speech's viseme ids (0 to 21, as in its `VisemeReceived` event)
  /// as mouth shapes.
  static const List<Viseme> azure = <Viseme>[
    rest, // 0 silence
    ah, // 1 æ ə ʌ
    ah, // 2 ɑ
    oh, // 3 ɔ
    ee, // 4 ɛ ʊ
    teeth, // 5 ɝ
    ee, // 6 j i ɪ
    oo, // 7 w u
    oh, // 8 o
    ah, // 9 aʊ
    oh, // 10 ɔɪ
    ah, // 11 aɪ
    ah, // 12 h
    oo, // 13 ɹ
    l, // 14 l
    teeth, // 15 s z
    teeth, // 16 ʃ tʃ dʒ ʒ
    l, // 17 ð
    fv, // 18 f v
    l, // 19 d t n θ
    teeth, // 20 k g ŋ
    closed, // 21 p b m
  ];
}

/// A mouth shape from [seconds] into the speech.
@immutable
class VisemeCue {
  const VisemeCue(this.seconds, this.viseme);
  final double seconds;
  final Viseme viseme;

  @override
  String toString() => '${seconds.toStringAsFixed(3)}s ${viseme.name}';
}

/// A word, from [start] to [end] seconds: for captions, and for timing a
/// gesture or a feeling to what is being said.
@immutable
class WordCue {
  const WordCue(this.start, this.end, this.text);
  final double start;
  final double end;
  final String text;

  @override
  String toString() => '$text ${start.toStringAsFixed(2)}-${end.toStringAsFixed(2)}';
}

/// What a voice says, timed: the mouth shapes to make and the words.
///
/// From Azure text-to-speech, [Speech.azure] reads the viseme and word
/// boundary events it reports alongside the audio, so the mouth matches the
/// voice exactly. Until there is audio, [Speech.fromText] guesses both from
/// the spelling, at a natural pace -- close enough to read as speech.
///
/// [at] is a pose for the mouth, a pure function of the frame: each shape is
/// eased into quickly and held, so a closed "m" really closes.
@immutable
class Speech {
  Speech(List<VisemeCue> visemes, {this.words = const <WordCue>[]})
      : visemes = List<VisemeCue>.unmodifiable(
          List<VisemeCue>.of(visemes)..sort((VisemeCue a, VisemeCue b) => a.seconds.compareTo(b.seconds)),
        );

  /// From Azure's events. Each viseme is `{"audioOffset": ticks, "visemeId":
  /// id}` and each word `{"audioOffset": ticks, "duration": ticks, "text":
  /// "word"}`, where a tick is 100ns -- the SDK's own fields and units.
  /// [start] shifts it all, for speech that begins partway into a video.
  factory Speech.azure({
    required List<Map<String, Object?>> visemes,
    List<Map<String, Object?>> words = const <Map<String, Object?>>[],
    double start = 0,
  }) {
    double seconds(Object? ticks) => (ticks! as num) / 1e7;
    return Speech(
      <VisemeCue>[
        for (final Map<String, Object?> v in visemes)
          VisemeCue(start + seconds(v['audioOffset']), Viseme.azure[(v['visemeId']! as num).toInt()]),
      ],
      words: <WordCue>[
        for (final Map<String, Object?> w in words)
          WordCue(
            start + seconds(w['audioOffset']),
            start + seconds(w['audioOffset']) + seconds(w['duration'] ?? 0),
            w['text']! as String,
          ),
      ],
    );
  }

  /// [Speech.azure] from JSON: `{"visemes": [...], "words": [...]}`.
  factory Speech.azureJson(String json, {double start = 0}) {
    final Map<String, Object?> data = (jsonDecode(json) as Map<Object?, Object?>).cast<String, Object?>();
    List<Map<String, Object?>> list(String key) => <Map<String, Object?>>[
          for (final Object? e in (data[key] as List<Object?>?) ?? const <Object?>[])
            (e! as Map<Object?, Object?>).cast<String, Object?>(),
        ];
    return Speech.azure(visemes: list('visemes'), words: list('words'), start: start);
  }

  /// A guess from spelling: syllables at [syllablesPerSecond], letters to
  /// mouth shapes, pauses at punctuation.
  factory Speech.fromText(String text, {double start = 0, double syllablesPerSecond = 4.4}) {
    final List<VisemeCue> visemes = <VisemeCue>[VisemeCue(start, Viseme.rest)];
    final List<WordCue> words = <WordCue>[];
    double t = start;
    for (final Match m in RegExp(r"[A-Za-z']+|[.,!?;:]").allMatches(text)) {
      final String token = m[0]!;
      if (RegExp(r'[.,!?;:]').hasMatch(token)) {
        visemes.add(VisemeCue(t, Viseme.rest));
        t += ',;:'.contains(token) ? 0.22 : 0.42;
        continue;
      }
      final List<(Viseme, double)> sounds = _spell(token.toLowerCase());
      final int syllables = math.max(1, RegExp(r'[aeiouy]+').allMatches(token.toLowerCase()).length);
      final double duration = syllables / syllablesPerSecond;
      final double total = sounds.fold(0, (double s, (Viseme, double) x) => s + x.$2);
      double at = t;
      for (final (Viseme v, double share) in sounds) {
        if (visemes.last.viseme != v) visemes.add(VisemeCue(at, v));
        at += duration * share / total;
      }
      words.add(WordCue(t, t + duration, token));
      t += duration + 0.03;
    }
    visemes.add(VisemeCue(t, Viseme.rest));
    return Speech(visemes, words: words);
  }

  static List<(Viseme, double)> _spell(String w) {
    const Map<String, Viseme> pairs = <String, Viseme>{
      'th': Viseme.l, 'sh': Viseme.teeth, 'ch': Viseme.teeth, 'oo': Viseme.oo,
      'ee': Viseme.ee, 'ea': Viseme.ee, 'ou': Viseme.oh, 'ow': Viseme.oh,
      'ph': Viseme.fv, 'wh': Viseme.oo, 'qu': Viseme.oo, 'ng': Viseme.teeth,
      'ck': Viseme.teeth, 'ai': Viseme.ah, 'ay': Viseme.ee, 'oa': Viseme.oh,
    };
    const String vowels = 'aeiouy';
    final List<(Viseme, double)> out = <(Viseme, double)>[];
    int i = 0;
    while (i < w.length) {
      if (i + 1 < w.length && pairs.containsKey(w.substring(i, i + 2))) {
        final Viseme v = pairs[w.substring(i, i + 2)]!;
        out.add((v, vowels.contains(w[i]) ? 2 : 1));
        i += 2;
        continue;
      }
      final String c = w[i];
      // A silent e at the end of a word ("make") says nothing.
      if (c == 'e' && i == w.length - 1 && w.length > 2) break;
      final Viseme? v = switch (c) {
        'a' => Viseme.ah,
        'e' || 'i' || 'y' => Viseme.ee,
        'o' => Viseme.oh,
        'u' || 'w' || 'r' => Viseme.oo,
        'm' || 'b' || 'p' => Viseme.closed,
        'f' || 'v' => Viseme.fv,
        'l' => Viseme.l,
        'h' || "'" => null,
        _ => Viseme.teeth,
      };
      if (v != null) out.add((v, vowels.contains(c) ? 2 : (v == Viseme.closed ? 1.2 : 1)));
      i++;
    }
    return out.isEmpty ? <(Viseme, double)>[(Viseme.teeth, 1)] : out;
  }

  final List<VisemeCue> visemes;
  final List<WordCue> words;

  /// When the last sound ends.
  double get end => visemes.isEmpty ? 0 : visemes.last.seconds;

  /// The word being said at [seconds], if any.
  WordCue? wordAt(double seconds) {
    for (final WordCue w in words) {
      if (w.start <= seconds && seconds < w.end) return w;
    }
    return null;
  }

  /// Mouth weights at [seconds]: the current shape eased in over at most
  /// 70ms from the one before -- quick enough to hit every shape, slow
  /// enough not to snap.
  Map<String, double> weightsAt(double seconds) {
    int i = -1;
    for (int k = 0; k < visemes.length; k++) {
      if (visemes[k].seconds <= seconds) {
        i = k;
      } else {
        break;
      }
    }
    if (i < 0) return const <String, double>{};
    final VisemeCue cue = visemes[i];
    final double next = i + 1 < visemes.length ? visemes[i + 1].seconds : cue.seconds + 1;
    final double attack = math.min(0.07, 0.6 * (next - cue.seconds));
    final double u = attack <= 0 ? 1 : ((seconds - cue.seconds) / attack).clamp(0.0, 1.0);
    final double b = u * u * (3 - 2 * u);
    final Map<String, double> from = i > 0 ? visemes[i - 1].viseme.weights : const <String, double>{};
    final Map<String, double> to = cue.viseme.weights;
    return <String, double>{
      for (final String k in <String>{...from.keys, ...to.keys}) k: (from[k] ?? 0) * (1 - b) + (to[k] ?? 0) * b,
    };
  }

  /// The mouth at [frame]. [amount] below 1 mumbles, above 1 shouts.
  Pose at(int frame, int fps, {String mouth = FaceJoints.mouth, double amount = 1}) {
    final Map<String, double> w = weightsAt(frame / fps);
    return Pose(<String, Joint>{
      mouth: Joint(weights: <String, double>{for (final MapEntry<String, double> e in w.entries) e.key: e.value * amount}),
    });
  }
}
