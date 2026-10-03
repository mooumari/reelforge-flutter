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
| `followThrough`, `Jiggle` | carried parts lag, overshoot and settle on springs |
| `Life`, `noise`, `drift` | breathing, head drift, blinks and glances, seeded |
| `Gesture` | wind-up, overshoot, settle, and joints that trail each other |
| `Morph`, `Shape.morph`, `Joint.morph` | one outline through key shapes, posed and keyed like a joint |
| `Skin`, `Shape.skin`, `Paths.taper` | one outline over several bones, so a bend is a curve |
| `Chain` | a skinned row of joints -- tail, trunk, kelp -- with `wave`, `curl` and `jiggles` |

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
```

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
