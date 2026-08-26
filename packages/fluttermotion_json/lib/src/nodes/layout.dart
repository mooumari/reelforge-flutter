import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';
import 'package:fluttermotion_schema/fluttermotion_schema.dart';

import '../node.dart';
import '../values.dart';

/// Builders for the layout primitives.
///
/// What each of these accepts is declared in
/// `fluttermotion_schema/lib/src/schema/layout.dart`, in the same order.
/// Registering a name that has no schema throws, so the two cannot drift into
/// a node that renders but will not validate.
void registerLayoutBuilders() {
  registerBuilder(
    'column',
    (BuildContext context, MotionNode node) => Column(
      mainAxisAlignment:
          node.named('main', namedMainAxis) ?? MainAxisAlignment.start,
      crossAxisAlignment:
          node.named('cross', namedCrossAxis) ?? CrossAxisAlignment.start,
      mainAxisSize: node.named('size', namedMainAxisSize) ?? MainAxisSize.max,
      spacing: node.number(context, 'spacing'),
      children: node.children(context, 'children'),
    ),
  );

  registerBuilder(
    'row',
    (BuildContext context, MotionNode node) => Row(
      mainAxisAlignment:
          node.named('main', namedMainAxis) ?? MainAxisAlignment.start,
      crossAxisAlignment:
          node.named('cross', namedCrossAxis) ?? CrossAxisAlignment.center,
      mainAxisSize: node.named('size', namedMainAxisSize) ?? MainAxisSize.max,
      spacing: node.number(context, 'spacing'),
      children: node.children(context, 'children'),
    ),
  );

  registerBuilder(
    'stack',
    (BuildContext context, MotionNode node) => Stack(
      alignment: node.named('alignment', namedAlignments) ?? Alignment.center,
      fit: node.named('fit', namedStackFits) ?? StackFit.loose,
      children: node.children(context, 'children'),
    ),
  );

  registerBuilder(
    'padding',
    (BuildContext context, MotionNode node) => Padding(
      padding: node.insets(context, 'padding') ?? EdgeInsets.zero,
      child: node.slot(context, 'child'),
    ),
  );

  registerBuilder(
    'center',
    (BuildContext context, MotionNode node) =>
        Center(child: node.slot(context, 'child')),
  );

  registerBuilder(
    'align',
    (BuildContext context, MotionNode node) => Align(
      alignment: node.named('alignment', namedAlignments) ?? Alignment.center,
      child: node.slot(context, 'child'),
    ),
  );

  registerBuilder(
    'expanded',
    (BuildContext context, MotionNode node) => Expanded(
      flex: node.integer(context, 'flex', fallback: 1),
      child: node.slot(context, 'child') ?? const SizedBox.shrink(),
    ),
  );

  registerBuilder(
    'sizedBox',
    (BuildContext context, MotionNode node) => SizedBox(
      width: node.optionalNumber(context, 'width'),
      height: node.optionalNumber(context, 'height'),
      child: node.slot(context, 'child'),
    ),
  );

  registerBuilder('box', (BuildContext context, MotionNode node) {
    final Color? border = node.colour(context, 'border');
    return Container(
      width: node.optionalNumber(context, 'width'),
      height: node.optionalNumber(context, 'height'),
      padding: node.insets(context, 'padding'),
      decoration: BoxDecoration(
        color: node.colour(context, 'color'),
        borderRadius: BorderRadius.circular(node.number(context, 'radius')),
        border: border == null
            ? null
            : Border.all(
                color: border,
                width: node.number(context, 'borderWidth', fallback: 1),
              ),
      ),
      child: node.slot(context, 'child'),
    );
  });

  registerBuilder('text', (BuildContext context, MotionNode node) {
    final MotionTheme theme = MotionTheme.of(context);
    final String? role = node['style'] as String?;
    final double? size =
        node.optionalNumber(context, 'size') ??
        (role == null ? null : roleSize(theme.typography, role));
    final Color? color = node.colour(context, 'color');
    final TextStyle style = TextStyle(
      fontSize: size,
      color: color,
      fontWeight: node.named('weight', namedWeights),
      letterSpacing: node.optionalNumber(context, 'letterSpacing'),
      height: node.optionalNumber(context, 'lineHeight'),
    );
    return Text(
      node.text(context, 'value'),
      style: style,
      textAlign: node.named('align', namedTextAligns),
      maxLines: node.optionalInteger(context, 'maxLines'),
    );
  });

  registerBuilder(
    'opacity',
    (BuildContext context, MotionNode node) => Opacity(
      // Clamped rather than trusted: a spring overshoots past one, and an
      // opacity outside [0, 1] is an assertion in a debug build and undefined
      // in a release one. A document should be able to say "spring the
      // opacity" without knowing that.
      opacity: node.number(context, 'value', fallback: 1).clamp(0.0, 1.0),
      child: node.slot(context, 'child'),
    ),
  );

  registerBuilder('transform', (BuildContext context, MotionNode node) {
    final Alignment origin =
        node.named('alignment', namedAlignments) ?? Alignment.center;
    Widget child = node.slot(context, 'child') ?? const SizedBox.shrink();
    final double rotate = node.number(context, 'rotate');
    if (rotate != 0) {
      child = Transform.rotate(angle: rotate, alignment: origin, child: child);
    }
    final double scale = node.number(context, 'scale', fallback: 1);
    if (scale != 1) {
      child = Transform.scale(scale: scale, alignment: origin, child: child);
    }
    return Transform.translate(
      offset: Offset(node.number(context, 'x'), node.number(context, 'y')),
      child: child,
    );
  });

  // A local theme override, which is how a document says "the same scene,
  // quieter" without repeating a size on every component inside it.
  registerBuilder('theme', (BuildContext context, MotionNode node) {
    final MotionTheme theme = MotionTheme.of(context);
    final String? name = node['palette'] as String?;
    return MotionTheme(
      palette: paletteNames.contains(name) ? basePalette(name!) : theme.palette,
      typography: theme.typography.copyWith(
        scale: node.optionalNumber(context, 'scale'),
        fontFamily: node['font'] as String?,
      ),
      child: node.slot(context, 'child') ?? const SizedBox.shrink(),
    );
  });

  registerBuilder(
    'sequence',
    (BuildContext context, MotionNode node) => Sequence(
      from: node.integer(context, 'from'),
      durationInFrames: node.optionalInteger(context, 'durationInFrames'),
      layout: node['layout'] == 'fill'
          ? SequenceLayout.fill
          : SequenceLayout.none,
      child: node.slot(context, 'child') ?? const SizedBox.shrink(),
    ),
  );

  registerBuilder(
    'stagger',
    (BuildContext context, MotionNode node) => Stagger(
      step: node.integer(context, 'step', fallback: 3),
      delay: node.integer(context, 'delay'),
      direction: node.named('direction', namedAxes) ?? Axis.horizontal,
      mainAxisAlignment:
          node.named('main', namedMainAxis) ?? MainAxisAlignment.start,
      crossAxisAlignment:
          node.named('cross', namedCrossAxis) ?? CrossAxisAlignment.center,
      expandChildren: node.flag(context, 'expandChildren'),
      children: node.children(context, 'children'),
    ),
  );

  registerBuilder('enter', (BuildContext context, MotionNode node) {
    final Widget child = node.slot(context, 'child') ?? const SizedBox.shrink();
    final int delay = node.integer(context, 'delay');
    final int duration = node.integer(context, 'duration', fallback: 12);
    final Curve curve = node.curve('curve', fallback: Curves.easeOutCubic);
    final bool fade = node.flag(context, 'fade', fallback: true);
    final double distance = node.number(context, 'distance', fallback: 60);

    return switch (node['mode']) {
      'scale' => Enter.scale(
        delay: delay,
        duration: duration,
        curve: curve,
        fade: fade,
        scale: node.number(context, 'scale', fallback: 0.9),
        child: child,
      ),
      'spring' => Enter.spring(
        delay: delay,
        from: Offset(0, distance),
        scale: node.number(context, 'scale', fallback: 0.9),
        stiffness: node.number(context, 'stiffness', fallback: 130),
        damping: node.number(context, 'damping', fallback: 15),
        fade: fade,
        child: child,
      ),
      'slideUp' => Enter.slideUp(
        delay: delay,
        duration: duration,
        curve: curve,
        fade: fade,
        distance: distance,
        child: child,
      ),
      'slideDown' => Enter.slideDown(
        delay: delay,
        duration: duration,
        curve: curve,
        fade: fade,
        distance: distance,
        child: child,
      ),
      'slideLeft' => Enter.slideLeft(
        delay: delay,
        duration: duration,
        curve: curve,
        fade: fade,
        distance: distance,
        child: child,
      ),
      'slideRight' => Enter.slideRight(
        delay: delay,
        duration: duration,
        curve: curve,
        fade: fade,
        distance: distance,
        child: child,
      ),
      _ => Enter.fade(
        delay: delay,
        duration: duration,
        curve: curve,
        child: child,
      ),
    };
  });
}
