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
/// The rule is the rest of ReelForge's: a frame is a pure function of its
/// frame number. Nothing here holds state, runs a clock or reads one.
library;

export 'src/camera.dart';
export 'src/drawing.dart';
export 'src/face.dart';
export 'src/follow.dart';
export 'src/gesture.dart';
export 'src/kinematics.dart';
export 'src/life.dart';
export 'src/outline.dart';
export 'src/part.dart';
export 'src/pose.dart';
export 'src/shape.dart';
export 'src/skin.dart';
export 'src/walk.dart';
