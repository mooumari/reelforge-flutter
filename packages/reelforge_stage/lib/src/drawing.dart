import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'kinematics.dart';
import 'part.dart';
import 'pose.dart';
import 'shape.dart';

/// Paints a [Part] tree, posed, in its parent's coordinate space.
///
/// The origin is the top-left of the box this is given, so a part's [Part.at]
/// is a position in that box -- the stage, usually. It takes whatever room its
/// parent offers (so put it in a `Stack` or a `SizedBox`, not an unbounded
/// column) and paints outside it freely; clipping is the [Camera]'s job.
///
/// One painter per puppet rather than one for the whole scene, because a pose
/// is looked up by part name and two copies of one character would otherwise
/// have to share a pose.
class Drawing extends StatelessWidget {
  const Drawing(this.part, {super.key, this.pose = Pose.rest, this.light = const Light()});

  final Part part;
  final Pose pose;

  /// The light [Shade]d shapes take. Unshaded shapes ignore it.
  final Light light;

  @override
  Widget build(BuildContext context) {
    assert(() {
      final Set<String> names = part.names;
      final List<String> unknown = pose.joints.keys
          .where((String name) => !names.contains(name))
          .toList();
      if (unknown.isNotEmpty) {
        throw FlutterError(
          'Pose names joints that ${part.name.isEmpty ? 'this part' : '"${part.name}"'} '
          'does not have: ${unknown.join(', ')}.\n'
          'Its joints are: ${(names.toList()..sort()).join(', ')}.\n'
          'A misspelt joint does nothing, which looks like an animation that '
          'is merely subtle -- so this is an error rather than a no-op.',
        );
      }
      return true;
    }());
    return CustomPaint(
      size: Size.infinite,
      painter: _PartPainter(part, pose, light),
    );
  }
}

class _PartPainter extends CustomPainter {
  const _PartPainter(this.part, this.pose, this.light);

  final Part part;
  final Pose pose;
  final Light light;

  @override
  void paint(Canvas canvas, Size size) {
    // Cast shadows land only on what this drawing has already painted, so
    // the drawing gets a layer of its own to land on.
    final bool casts = _casts(part);
    if (casts) canvas.saveLayer(null, Paint());
    _paintPart(canvas, part, part, pose, Affine.identity, light);
    if (casts) canvas.restore();
  }

  @override
  bool shouldRepaint(_PartPainter oldDelegate) =>
      oldDelegate.part != part || oldDelegate.pose != pose || oldDelegate.light != light;
}

final Expando<bool> _castsCache = Expando<bool>();

bool _casts(Part part) => _castsCache[part] ??=
    part.shapes.any((Shape s) => (s.shade?.cast ?? 0) > 0) || part.children.any(_casts);

void _paintPart(Canvas canvas, Part root, Part part, Pose pose, Affine parent, Light light) {
  final Joint joint = part.name.isEmpty ? Joint.rest : pose[part.name];
  final double opacity = (part.opacity * joint.opacity).clamp(0.0, 1.0);
  if (opacity <= 0) return;

  // Where this part is in the drawing: what a live shape measures from.
  final Affine here = parent * Affine.of(part, joint);
  canvas.save();
  canvas.translate(part.at.dx + joint.move.dx, part.at.dy + joint.move.dy);
  final double degrees = part.degrees + joint.degrees;
  if (degrees != 0) canvas.rotate(degrees * math.pi / 180);
  canvas.scale(part.scaleX * joint.scaleX, part.scaleY * joint.scaleY);

  // A faded part has to fade as one thing: fading each shape alone would show
  // the overlap between a limb and the body it is joined to.
  final bool faded = opacity < 1;
  if (faded) {
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
  }
  final List<Path> outlines = <Path>[
    for (final Shape shape in part.shapes)
      shape.path ??
          shape.morph?.at(joint.morph) ??
          shape.blend?.at(joint.weights) ??
          shape.skin?.deformed(root, pose) ??
          shape.live!(Where(root, pose, here)),
  ];
  // The light, turned into this part's own space.
  Offset toLight = Offset.zero;
  if (part.shapes.any((Shape s) => s.shade != null) && here.determinant != 0) {
    toLight = here.inverse.applyVector(light.from);
  }
  for (int i = 0; i < outlines.length; i++) {
    part.shapes[i].paint(canvas, outlines[i], light: light, toLight: toLight);
  }
  if (part.clip && part.children.isNotEmpty) {
    canvas.save();
    final Path inside = Path();
    for (final Path outline in outlines) {
      inside.addPath(outline, Offset.zero);
    }
    canvas.clipPath(inside);
  }
  for (final Part child in part.children) {
    _paintPart(canvas, root, child, pose, here, light);
  }
  if (part.clip && part.children.isNotEmpty) canvas.restore();
  if (faded) canvas.restore();

  canvas.restore();
}
