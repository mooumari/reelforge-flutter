# reelforge_stage

*A spike, not a release.* Vector parts, puppets and a parallax camera for
ReelForge compositions: drawn, rigged and animated in code, with nothing
imported from an illustration or animation tool.

```dart
final Part hero = Part(
  name: 'body',
  children: <Part>[
    Part(name: 'shoulder', at: Offset(12, -98), shapes: [/* upper arm */], children: [
      Part(name: 'elbow', at: Offset(0, 56), shapes: [/* forearm */]),
    ]),
  ],
);

const Take wave = Take(<Keyframe>[
  Keyframe(0, Pose.rest),
  Keyframe(12, Pose({'shoulder': Joint.rotate(-128)})),
]);

Camera(
  keyframes: const <CameraKeyframe>[CameraKeyframe(0), CameraKeyframe(90, zoom: 2)],
  child: Stack(children: <Widget>[
    ParallaxLayer(depth: 0.3, child: Drawing(hills)),
    ParallaxLayer(child: Drawing(hero, pose: wave.at(frame))),
  ]),
)
```

| | |
|---|---|
| `Shape`, `Paths` | a path with a fill; the outlines a flat illustration is made of |
| `Part` | shapes and child parts around a joint at the origin; immutable, so reuse is `placed()` |
| `Pose`, `Joint` | where a tree's joints are, by name; `overlay` and `plus` layer them |
| `Take`, `Keyframe` | poses at frames, blended; loops for cycles |
| `Drawing` | paints a part in a pose |
| `Camera`, `ParallaxLayer` | pan and zoom over layers at different depths |
| `reach`, `frameOf` | two-bone IK to a point; forward kinematics, the painter's own arithmetic |
| `Walk`, `Waypoint`, `Biped` | footsteps planned from a route; planted feet stay planted |
| `Gait`, `Quadruped` | the same for four legs: hind, fore, hind, fore, never fewer than two paws down |
| `Lion` | a four-legged template -- lion, lioness, cub -- with a face that emotes and talks |
| `followThrough`, `Jiggle` | carried parts lag, overshoot and settle on springs |
| `Life`, `noise`, `drift` | breathing, head drift, blinks and glances, seeded |
| `Gesture` | wind-up, overshoot, settle, and joints that trail each other |
| `Morph`, `Shape.morph`, `Joint.morph` | one outline through key shapes, posed and keyed like a joint |
| `Skin`, `Shape.skin`, `Paths.taper` | one outline over several bones, so a bend is a curve |
| `Chain` | a skinned row of joints -- tail, trunk, kelp -- with `wave`, `curl` and `jiggles` |
| `Blend`, `Shape.blend`, `Joint.weights` | shape keys that mix: a mouth that is "ah" and smiling at once |
| `Part.clip` | children only inside the part's own shapes: pupils in eyes, teeth in a mouth |
| `FaceStyle`, `FaceJoints`, `Emotion` | a face drawn from a style; eight emotions, `look`, `turn`, `moods` |
| `Speech`, `Viseme`, `Gaze` | mouth shapes from Azure's visemes or from text; eyes that hold and dart |
| `Narration`, `Captions` | a voice-over laid end to end, the picture cut in its pauses, and captions that light each word as it is said |
| `Performance`, `Beat`, `Line` | a performer's part in seconds -- `Move`, `Say`, `Feel`, `Look`, `Act` -- with voiced lines, their audio and their mouth |
| `Character`, `Body`, `Garment`, `Fitting` | a person from proportions, a skin, a face and an outfit; walks, waves and talks |
| the wardrobe | hair, beards, hats, headcloths, helmets, robes, armour, hides and furs, boots, robot parts, props -- each fits any `Body` |
| `Rain`, `RainSplash`, `Fire`, `Lightning` | weather and flame as seeded arithmetic on the frame: streaks on the lens, ripples on the ground, a fire that flickers, a flash that is lit and then dark |
| `Light`, `Shade` | light for flat drawings: a gradient, a shadow crescent, a rim and cast shadows, from the outline alone |
| `Shape.live`, `Where` | an outline computed from the pose: a robe's hem that spans both legs mid-stride |
| `Part.bake` | fold a pose into the drawing, so it is where animation starts |

The demo is `example/lib/stage_demo.dart`: two characters on one skeleton,
each given only a route; a wave and a wave back; a camera that follows and
then pushes in. `example/lib/stage_compare.dart` walks the first spike's
hand-keyed cycle beside `Walk`, with a trail of every ground contact: on the
same route the old walk slips 1,492px in total; `Walk` slips none.

`example/lib/stage_shapes.dart` shows outlines that move: the same arm as two
rigid parts and as one skin, a shape morphing through key outlines, the
hero's mouth shapes, and chains -- a hopping critter's tail on follow-through
and kelp on a travelling wave.

```bash
cd example
reelforge render --composition StageDemo --out stage.mp4
reelforge render --composition WalkCompare --out compare.mp4
reelforge render --composition StageShapes --out shapes.mp4
reelforge render --composition StageFaces --out faces.mp4
```

`example/lib/stage_faces.dart` has one person talking -- mood on cue words,
captions from the speech's own word timings, eyes that glance and then follow
a firefly with the head turning after them -- and six more people, a robot and
an alien among them, showing all eight emotions on the same rig.

`example/lib/stage_cast.dart` has ten people from one template -- a cowboy,
a Bedouin man and woman, a legionary, a pharaoh, a philosopher, a cyborg, a
scientist, a kid and a grandmother -- walking on in two rows, waving and
saying hello.

`example/lib/stage_savanna.dart` has a lion walking on four legs and a
monkey walking on two, meeting at sunset and saying hello.

## Characters

A `Character` is a `Body`'s proportions, a skin colour, a `FaceStyle` and a
list of `Garment`s:

```dart
const Character cowboy = Character(
  skin: Color(0xFFE2A27A),
  outfit: <Garment>[
    ShortHair(Color(0xFF6B4226)),
    Moustache(Color(0xFF5A3A22)),
    Shirt(Color(0xFFB8432F)),
    Vest(Color(0xFF6E4B2A)),
    Trousers(Color(0xFF35507A)),
    CowboyBoots(Color(0xFF7A4A26)),
    CowboyHat(Color(0xFFB98A55)),
  ],
);

final Walk walk = Walk(rig: cowboy.part, body: cowboy.biped, ...);
final Pose pose = cowboy.life(seed).at(frame, fps)
    .plus(cowboy.face.express(Emotion.happy));
```

Its rig has the joint names everything else here uses, so `Walk`, `Life`,
`followThrough` (with `cowboy.jiggles` for capes and ponytails), gestures,
emotions and speech all work on it unchanged. `Character.wave` and
`Character.nod` are ready-made hellos. `Body.child`, `stocky`, `slim` and
`elder` are starting points; every measurement can be changed.

A `HeadShape` is the head's silhouette: `oval`, `square`, `heart`, `long` and
`round` share one skull and differ in the cheek, jaw and chin, so every hat
fits every head. Mix two with `HeadShape.lerp`, or nudge one with
`adjusted(jaw:, width:)`, so that two people with the same preset still look
like two people.

Garments are measured from the body, not drawn for it: head pieces in head
radii around the head and cut round the face, torso pieces from the torso's
own outline, sleeves and trouser legs as `Cover`s skinned to the limb, and
robes and skirts as live outlines from the legs' posed positions. So the
cowboy hat fits the child, and a robe stays closed over a stride. A new
garment is a class with one method, `dress(Fitting)`, that adds drawings to
the layers it belongs in. `Character.build(hold: ...)` hangs props on the
hands; `Props` has a staff, a cane, a spear, a shield, a scroll and more.

Hair is a mass, darker locks inside it that say which way it is combed, a
band of shine, and a small shadow cast on the forehead: `ShortHair`, `Buzz`,
`Quiff`, `Curls` (each curl lit), `LongHair` (with or without a fringe; what
falls below the head hangs behind the body), `Bun`, `Ponytail` (it swings)
and `Balding`. `example/lib/stage_wardrobe.dart` puts every hairstyle and
headpiece on one sheet.

Everything is drawn from one angle, three-quarters on and facing right --
body, head, face, ear, hair and clothes agree about which way the
character is facing -- and every surface is `Shade`d, so a `Drawing`'s
`Light` gives it form: a lit side, a shadow side, a bright rim, and the hat
brim's shadow across the eyes. Shadows are a deeper shade of each surface's
own colour, nudged towards the light's shadow colour, so skin in shadow
stays skin. `example/lib/stage_style.dart` is the style test: one
character, lit by a low sun, with a close-up of the face.

## Animals

A `Lion` is numbers, as a `Body` is -- `length` from hip to shoulder, `leg`,
`depth`, `headRadius` -- with `Lion.male`, `Lion.female` and `Lion.cub` to
start from. Its rig is a `Quadruped`'s: the root is the hips, the hind legs
hang from them and the forelegs from a `chest` further along, and the torso
is one `Skin` over both, so the back gives when the shoulders drop. Its face
is a `FaceStyle`, so `express`, `look`, `Speech` and `Life` work on it as on
a person, and its tail is a `Chain` with `jiggles`.

```dart
final Gait gait = Gait(rig: Lion.male.part, body: Lion.male.quadruped, route: ..., groundY: 940, fps: 30);
final Posed p = gait.at(frame, adjust: (Pose pose) => pose.plus(Lion.male.stance).plus(speech.at(frame, fps)));
```

`Gait` plans footfalls the way `Walk` does, by distance, so a planted paw
stays where it landed; the legs step a quarter of a stride apart, hind then
fore on the same side, and when the route ends each takes one last step to
stand square. Each leg has three bones (a `PawLeg`: thigh or upper arm,
shin or forearm, hock or wrist, then the paw), and each step is a cat's
step: the paw peels off heel first over its toes, the leg folds -- the hock
flexes, the forepaw tucks under the wrist -- swings forward, reaches out and
lands flat. The hips ride the hind legs and the chest the forelegs, eased so
they never rise or sink faster than a body does; the shoulder blades slide
with the forelegs, and the head holds its line. `toeAt` says where each
paw's toes are.

An animal that stands and talks is a `Character` in fur. A monkey is a body
with long arms and short legs, a skin the colour of its coat, and `Fur` (a
pale belly, a darker crown), `MonkeyFace` (a mask, a muzzle and nostrils in
place of the nose, big ears) and `Tail` (a `Chain` that curls up at rest and
swings on follow-through). It walks, waves and talks like anyone else.

## Performances and voices

A scene is acted by giving each performer a `Performance`: a list of beats
in seconds. `Move` walks to an x (a `Stroll`: setting off, steady, arriving),
`Say` speaks a `Line`, `Feel` eases into an `Emotion` until the next one,
`Look` darts the eyes, and `Act` plays a gesture such as `Character.wave`
over the body. Beats are values with an `end`, so a scene is laid out with
arithmetic rather than frame numbers:

```dart
const Say hello = Say(SavannaVoices.leoHello, at: 6.0);
final Say answer = Say(SavannaVoices.momoHi, at: hello.end + 0.45);

final Performance momo = Performance(fps: 30, startX: 2120, beats: <Beat>[
  const Move(1370, at: 1.0, seconds: 4.9),
  Act(Character.wave, at: answer.at - 0.3),
  answer,
]);

final Walk walk = Walk(rig: ..., route: momo.route, ...);
Posed at(int frame) => walk.at(frame, adjust: (Pose pose) =>
    momo.acts(frame, pose).plus(momo.face(face, frame)));
// and in the scene's Stack: ...momo.audio()
```

Lines are voiced, not guessed. `tool/voice.py` reads a script -- a cast of
Azure neural voices (with a style, rate and pitch) and their lines -- and
writes each line's audio and a Dart file of `Line`s carrying Azure's
visemes and word timings, so `hello.end` is when the voice really stops and
the mouth moves to the voice itself:

```sh
python3 -m venv tool/.venv && tool/.venv/bin/pip install azure-cognitiveservices-speech
tool/.venv/bin/python tool/voice.py example/voices/savanna.json
```

It reads `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION` from the environment
or the repository's `.env`, and only calls Azure for lines whose text or
voice changed. The audio and the Dart file are committed, so a render needs
neither the network nor a key.

## Narrated videos

A narrated video is timed to its voice. A `Narration` takes the voiced
`Line`s and lays them end to end -- a lead-in, a pause between lines, a
breath at the end -- so `starts`, `ends` and `seconds` are the voice's own.
It says where to cut: `cuts(<int>[1, 1, 2])` is the middle of the pause after
each shot's last line for shots holding one, one and two lines, and `lengths`
is how long each shot is. Feed those to a `Storyboard` and no frame number
is written by hand.

A graphic lands on the word it is about by asking when that word is said:

```dart
final Narration voice = Narration(<Line>[Voices.intro, Voices.hours, Voices.compare]);
double saidAt(int shot, int line, int word) =>
    voice.starts[line] + Captions.wordTimes(voice.lines[line])[word].$1 - voice.cuts(shots)[shot];
// the giraffe's bar grows at saidAt(2, 2, 7): "A giraffe, about five."
```

`Narration(pauses: {2: 3.4})` adds quiet before line 2 -- for a title card, say. The cut falls in the middle of the silence, so the shots either side share it.

Re-voice a line and the cuts, the bars and the captions move with it.
`Captions(narration: voice)` goes above the storyboard, and
`...voice.audio(fps: 30)` beside it, outside any scene so a cut does not cut
the voice off. Sound under it is made the same way as the pictures, in code:
`tool/sound.py` writes a soft ambient bed and a few effects (a whoosh for a
cut, a pop for a bar, and rain, thunder and a crackling fire) as seeded arithmetic. `example/lib/lion_sleep.dart` is
a whole episode made this way.

## Faces

A face is a `FaceStyle`: sizes, spacing and colours. `build()` draws it as
parts with the joints in `FaceJoints`, and every way of posing a face is a
pose on those joints, so it works on any style:

```dart
final Pose face = style.express(Emotion.happy)       // a feeling
    .plus(speech.at(frame, fps))                      // the mouth, from TTS
    .plus(style.look(gaze.at(frame)))                 // the eyes
    .plus(life.at(frame, fps));                       // breathing and blinks
```

Feelings and visemes are weights on the same mouth `Blend`, and they add: a
smile while saying "ah" is both. A blink is an overriding key, so it closes a
smiling eye rather than adding to it. Pupils are clipped to the eye's
outline, so a closed or squinting eye hides them without their being posed.

`Speech.azure` takes Azure's `VisemeReceived` and `WordBoundary` events as
the SDK reports them (offsets in 100ns ticks), and maps its 22 viseme ids to
eight mouth shapes. `Speech.fromText` guesses both from spelling, for work
before there is audio.

## Shapes that move

A `Morph` samples each key path into evenly spaced points round its length,
renumbers each key to start and wind like the one before it, and blends
point by point. Any single-contour paths will do, however they were drawn.
The part's `Joint.morph` says where between the keys it is, so a morph is
keyed in a `Take` and blended by `Pose.lerp` like a turn. Two limits: one
contour per key, and the keys are a line, so going from the first key to the
third passes through the second. Visemes, which jump between any two shapes,
will need weighted blending.

A `Skin` is bound at rest. Each point follows the bones it is nearest to,
blended as dual numbers (a turn and a shift together) rather than as
matrices, which swings points round a joint on an arc instead of collapsing
the inside of the bend. A bend keeps its thickness up to about 120 degrees;
tighter than that, the inside creases.

## Motion, and staying a pure function

A walk plans its footsteps in its constructor, from the route. Footfalls are
spaced by distance, so a foot on the ground stays put however the body speeds
up or stops; the legs are solved to reach them. The hips sit as high as both
planted legs can hold them, which is where the bob comes from.

Follow-through is a spring, and springs carry state. Each frame replays the
second or so of motion before it from rest, which is long enough for the
spring to have forgotten where it started -- so it is still a function of the
frame, and a sharded render has no seams.
