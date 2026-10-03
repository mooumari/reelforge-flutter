import 'package:flutter/widgets.dart';

import 'shape.dart';

/// A drawing with a joint at its origin: the one building block.
///
/// A part draws its [shapes] around its own origin, then its [children] on top
/// in order, back to front. Each child sits in the part's space, so moving or
/// turning a part carries everything under it -- rotate a shoulder and the arm,
/// forearm and hand go with it. That is the whole of a skeleton: a tree of
/// parts, each pivoting about its own origin, placed in its parent by [at].
///
/// Parts are immutable and shared, which is what reuse means here. A tree drawn
/// once can be placed a hundred times with [placed]; nothing is copied until
/// somebody asks for a variation, and the variation is another part.
///
/// A [name] is how an animation finds the part. Leave it empty on anything an
/// animation never touches.
@immutable
class Part {
  const Part({
    this.name = '',
    this.at = Offset.zero,
    this.degrees = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.opacity = 1,
    this.shapes = const <Shape>[],
    this.children = const <Part>[],
    this.clip = false,
  });

  final String name;

  /// Where this part's origin sits in its parent, before any pose is applied.
  final Offset at;

  /// Clockwise, in degrees. Degrees because this is written by hand, and
  /// "rotate the forearm 40" is a sentence people can check by eye.
  final double degrees;

  final double scaleX;
  final double scaleY;
  final double opacity;

  final List<Shape> shapes;
  final List<Part> children;

  /// Whether [children] only show inside this part's own shapes: a pupil
  /// inside its eye, teeth inside a mouth, a pattern inside a shirt. The clip
  /// follows the shapes as they morph or blend, so an eye that blinks shut
  /// hides its pupil without the pupil being animated at all.
  final bool clip;

  /// This part with its own placement replaced; shapes and children are shared.
  ///
  /// [scale] sets both axes. [scaleX] and [scaleY] win over it when given.
  Part placed({
    String? name,
    Offset? at,
    double? degrees,
    double? scale,
    double? scaleX,
    double? scaleY,
    double? opacity,
  }) =>
      Part(
        name: name ?? this.name,
        at: at ?? this.at,
        degrees: degrees ?? this.degrees,
        scaleX: scaleX ?? scale ?? this.scaleX,
        scaleY: scaleY ?? scale ?? this.scaleY,
        opacity: opacity ?? this.opacity,
        shapes: shapes,
        children: children,
        clip: clip,
      );

  /// Mirrored left to right about this part's own origin.
  Part flipped() => placed(scaleX: -scaleX);

  /// Every name in the tree, this part included.
  ///
  /// A pose that names a joint nothing has is silently a no-op, which is the
  /// kind of mistake that looks like an animation that "doesn't do much".
  /// [Drawing] checks poses against this in debug builds.
  Set<String> get names => <String>{
        if (name.isNotEmpty) name,
        for (final Part child in children) ...child.names,
      };
}
