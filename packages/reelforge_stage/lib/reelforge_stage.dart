/// Vector parts, puppets and a parallax camera for ReelForge compositions.
///
/// Everything is drawn, rigged and animated in code; nothing is imported from
/// an illustration or animation tool. The vocabulary is four ideas:
///
///  * a [Shape] is a path with a fill, and [Paths] has the outlines a flat
///    illustration is made of;
///  * a [Part] is shapes plus child parts around a joint at its origin, and
///    because parts are immutable one drawing is reused by placing it again;
///  * a [Pose] says where a tree's joints are, a [Take] blends poses over
///    frames, and [Drawing] paints a part in a pose;
///  * a [Camera] pans and zooms over [ParallaxLayer]s at different depths.
///
/// And on top, the motion that makes a puppet a character: [reach] solves a
/// limb to a point; a [Walk] plans footsteps and keeps planted feet planted;
/// [followThrough] lets carried parts lag and settle; [Life] keeps a held
/// pose breathing; a [Gesture] winds up, overshoots and settles.
///
/// And outlines that move rather than only turn: a [Morph] changes one shape
/// into another on a joint's [Joint.morph]; a [Skin] lays one outline over
/// several joints so a limb bends in a curve; a [Chain] is a skinned row of
/// joints -- tail, trunk, tentacle -- with a travelling [Chain.wave].
///
/// And faces: a [FaceStyle] draws eyes, brows and a mouth whose shape keys
/// mix by [Joint.weights] in a [Blend]; [FaceStyle.express] poses an
/// [Emotion], [Speech] turns Azure's visemes (or plain text) into mouth
/// shapes, and [Gaze] moves the eyes the way eyes move.
///
/// And people: a [Character] is a [Body]'s proportions, a skin, a face and
/// an outfit of [Garment]s -- hair, beards, hats, robes, armour, boots --
/// that fit any body. The rig it builds walks, breathes, waves and talks
/// with everything above.
///
/// And a scene's acting: a [Performance] is a performer's [Beat]s -- [Move],
/// [Say], [Feel], [Look], [Act] -- in seconds, laid out with arithmetic on
/// when each ends. Lines are [Line]s, voiced by `tool/voice.py` with Azure
/// so their timing is the voice's own; it plays their audio, moves the
/// mouth to them, and gives the route to walk.
///
/// And a voice-over: a [Narration] lays [Line]s end to end and says where to
/// cut the picture, and [Captions] light each word as it is spoken.
///
/// And animals: a [Lion] is a four-legged template -- a lion, a lioness, a
/// cub -- that walks with a [Gait], hind and fore legs in turn with every
/// paw planted. An animal that stands up and talks is a [Character] in fur:
/// a monkey is a body with long arms, [Fur], a [MonkeyFace] and a [Tail].
///
/// The rule is the rest of ReelForge's: a frame is a pure function of its
/// frame number. Nothing here holds state, runs a clock or reads one.
library;

export 'src/animals.dart';
export 'src/camera.dart';
export 'src/character.dart';
export 'src/drawing.dart';
export 'src/face.dart';
export 'src/follow.dart';
export 'src/gait.dart';
export 'src/gesture.dart';
export 'src/kinematics.dart';
export 'src/life.dart';
export 'src/outline.dart';
export 'src/narration.dart';
export 'src/part.dart';
export 'src/performance.dart';
export 'src/pose.dart';
export 'src/shape.dart';
export 'src/skin.dart';
export 'src/walk.dart';
export 'src/wardrobe.dart';
