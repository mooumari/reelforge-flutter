import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';

import '../node.dart';
import '../values.dart';

const Map<String, MainAxisAlignment> _mainAxis = <String, MainAxisAlignment>{
  'start': MainAxisAlignment.start,
  'end': MainAxisAlignment.end,
  'center': MainAxisAlignment.center,
  'spaceBetween': MainAxisAlignment.spaceBetween,
  'spaceAround': MainAxisAlignment.spaceAround,
  'spaceEvenly': MainAxisAlignment.spaceEvenly,
};

const Map<String, CrossAxisAlignment> _crossAxis = <String, CrossAxisAlignment>{
  'start': CrossAxisAlignment.start,
  'end': CrossAxisAlignment.end,
  'center': CrossAxisAlignment.center,
  'stretch': CrossAxisAlignment.stretch,
  'baseline': CrossAxisAlignment.baseline,
};

const Map<String, MainAxisSize> _mainSize = <String, MainAxisSize>{
  'min': MainAxisSize.min,
  'max': MainAxisSize.max,
};

const Map<String, StackFit> _stackFits = <String, StackFit>{
  'loose': StackFit.loose,
  'expand': StackFit.expand,
  'passthrough': StackFit.passthrough,
};

const Map<String, FontWeight> _weights = <String, FontWeight>{
  'thin': FontWeight.w100,
  'light': FontWeight.w300,
  'regular': FontWeight.w400,
  'medium': FontWeight.w500,
  'semibold': FontWeight.w600,
  'bold': FontWeight.w700,
  'black': FontWeight.w900,
};

const Map<String, TextAlign> _textAligns = <String, TextAlign>{
  'left': TextAlign.left,
  'right': TextAlign.right,
  'center': TextAlign.center,
  'justify': TextAlign.justify,
  'start': TextAlign.start,
  'end': TextAlign.end,
};

const Map<String, Axis> _axes = <String, Axis>{
  'horizontal': Axis.horizontal,
  'vertical': Axis.vertical,
};

/// The named sizes a `text` node can ask for.
///
/// Naming a role rather than a number is what keeps a document readable at two
/// resolutions: `headline` follows the theme's scale, `58` does not.
const Set<String> _textRoles = <String>{
  'display',
  'headline',
  'title',
  'body',
  'label',
  'caption',
  'statistic',
};

double _roleSize(MotionTypography type, String role) => switch (role) {
      'display' => type.displaySize,
      'headline' => type.headlineSize,
      'title' => type.titleSize,
      'label' => type.labelSize,
      'caption' => type.captionSize,
      'statistic' => type.statisticSize,
      _ => type.bodySize,
    };

/// The animation shapes an `enter` node can name.
const Set<String> _enterModes = <String>{
  'fade',
  'scale',
  'spring',
  'slideUp',
  'slideDown',
  'slideLeft',
  'slideRight',
};

void registerLayoutNodes() {
  registerNode(NodeType(
    name: 'column',
    properties: <String>{'main', 'cross', 'size', 'spacing'},
    lists: <String>{'children'},
    validate: (Reader r) => r
      ..oneOf('main', _mainAxis.keys.toSet())
      ..oneOf('cross', _crossAxis.keys.toSet())
      ..oneOf('size', _mainSize.keys.toSet())
      ..plainNumber('spacing'),
    build: (BuildContext context, MotionNode node) => Column(
      mainAxisAlignment:
          node.named('main', _mainAxis) ?? MainAxisAlignment.start,
      crossAxisAlignment:
          node.named('cross', _crossAxis) ?? CrossAxisAlignment.start,
      mainAxisSize: node.named('size', _mainSize) ?? MainAxisSize.max,
      spacing: node.number(context, 'spacing'),
      children: node.children(context, 'children'),
    ),
  ));

  registerNode(NodeType(
    name: 'row',
    properties: <String>{'main', 'cross', 'size', 'spacing'},
    lists: <String>{'children'},
    validate: (Reader r) => r
      ..oneOf('main', _mainAxis.keys.toSet())
      ..oneOf('cross', _crossAxis.keys.toSet())
      ..oneOf('size', _mainSize.keys.toSet())
      ..plainNumber('spacing'),
    build: (BuildContext context, MotionNode node) => Row(
      mainAxisAlignment:
          node.named('main', _mainAxis) ?? MainAxisAlignment.start,
      crossAxisAlignment:
          node.named('cross', _crossAxis) ?? CrossAxisAlignment.center,
      mainAxisSize: node.named('size', _mainSize) ?? MainAxisSize.max,
      spacing: node.number(context, 'spacing'),
      children: node.children(context, 'children'),
    ),
  ));

  registerNode(NodeType(
    name: 'stack',
    properties: <String>{'alignment', 'fit'},
    lists: <String>{'children'},
    validate: (Reader r) => r
      ..oneOf('alignment', namedAlignments.keys.toSet())
      ..oneOf('fit', _stackFits.keys.toSet()),
    build: (BuildContext context, MotionNode node) => Stack(
      alignment: node.named('alignment', namedAlignments) ?? Alignment.center,
      fit: node.named('fit', _stackFits) ?? StackFit.loose,
      children: node.children(context, 'children'),
    ),
  ));

  registerNode(NodeType(
    name: 'padding',
    properties: <String>{'padding'},
    slots: <String>{'child'},
    validate: (Reader r) => r.insets('padding'),
    build: (BuildContext context, MotionNode node) => Padding(
      padding: node.insets(context, 'padding') ?? EdgeInsets.zero,
      child: node.slot(context, 'child'),
    ),
  ));

  registerNode(NodeType(
    name: 'center',
    slots: <String>{'child'},
    build: (BuildContext context, MotionNode node) =>
        Center(child: node.slot(context, 'child')),
  ));

  registerNode(NodeType(
    name: 'align',
    properties: <String>{'alignment'},
    slots: <String>{'child'},
    validate: (Reader r) => r.oneOf('alignment', namedAlignments.keys.toSet()),
    build: (BuildContext context, MotionNode node) => Align(
      alignment: node.named('alignment', namedAlignments) ?? Alignment.center,
      child: node.slot(context, 'child'),
    ),
  ));

  registerNode(NodeType(
    name: 'expanded',
    properties: <String>{'flex'},
    slots: <String>{'child'},
    parentData: true,
    validate: (Reader r) => r.plainInt('flex'),
    build: (BuildContext context, MotionNode node) => Expanded(
      flex: node.integer(context, 'flex', fallback: 1),
      child: node.slot(context, 'child') ?? const SizedBox.shrink(),
    ),
  ));

  registerNode(NodeType(
    name: 'sizedBox',
    properties: <String>{'width', 'height'},
    slots: <String>{'child'},
    validate: (Reader r) => r
      ..animated('width')
      ..animated('height'),
    build: (BuildContext context, MotionNode node) => SizedBox(
      width: node.optionalNumber(context, 'width'),
      height: node.optionalNumber(context, 'height'),
      child: node.slot(context, 'child'),
    ),
  ));

  registerNode(NodeType(
    name: 'box',
    properties: <String>{
      'color',
      'width',
      'height',
      'radius',
      'padding',
      'border',
      'borderWidth',
    },
    slots: <String>{'child'},
    validate: (Reader r) => r
      ..colour('color')
      ..colour('border')
      ..animated('width')
      ..animated('height')
      ..animated('radius')
      ..animated('borderWidth')
      ..insets('padding'),
    build: (BuildContext context, MotionNode node) {
      final Color? border = node.colour(context, 'border');
      return Container(
        width: node.optionalNumber(context, 'width'),
        height: node.optionalNumber(context, 'height'),
        padding: node.insets(context, 'padding'),
        decoration: BoxDecoration(
          color: node.colour(context, 'color'),
          borderRadius:
              BorderRadius.circular(node.number(context, 'radius')),
          border: border == null
              ? null
              : Border.all(
                  color: border,
                  width: node.number(context, 'borderWidth', fallback: 1),
                ),
        ),
        child: node.slot(context, 'child'),
      );
    },
  ));

  registerNode(NodeType(
    name: 'text',
    properties: <String>{
      'value',
      'style',
      'size',
      'color',
      'weight',
      'align',
      'letterSpacing',
      'lineHeight',
      'maxLines',
    },
    validate: (Reader r) => r
      ..string('value', required: true)
      ..oneOf('style', _textRoles)
      ..animated('size')
      ..colour('color')
      ..oneOf('weight', _weights.keys.toSet())
      ..oneOf('align', _textAligns.keys.toSet())
      ..animated('letterSpacing')
      ..animated('lineHeight')
      ..plainInt('maxLines'),
    build: (BuildContext context, MotionNode node) {
      final MotionTheme theme = MotionTheme.of(context);
      final String? role = node['style'] as String?;
      final double? size = node.optionalNumber(context, 'size') ??
          (role == null ? null : _roleSize(theme.typography, role));
      final Color? color = node.colour(context, 'color');
      final TextStyle style = TextStyle(
        fontSize: size,
        color: color,
        fontWeight: node.named('weight', _weights),
        letterSpacing: node.optionalNumber(context, 'letterSpacing'),
        height: node.optionalNumber(context, 'lineHeight'),
      );
      return Text(
        node.text(context, 'value'),
        style: style,
        textAlign: node.named('align', _textAligns),
        maxLines: node.optionalInteger(context, 'maxLines'),
      );
    },
  ));

  registerNode(NodeType(
    name: 'opacity',
    properties: <String>{'value'},
    slots: <String>{'child'},
    validate: (Reader r) => r.animated('value', required: true),
    build: (BuildContext context, MotionNode node) => Opacity(
      // Clamped rather than trusted: a spring overshoots past one, and an
      // opacity outside [0, 1] is an assertion in a debug build and undefined
      // in a release one. A document should be able to say "spring the
      // opacity" without knowing that.
      opacity: node.number(context, 'value', fallback: 1).clamp(0.0, 1.0),
      child: node.slot(context, 'child'),
    ),
  ));

  registerNode(NodeType(
    name: 'transform',
    properties: <String>{'x', 'y', 'scale', 'rotate', 'alignment'},
    slots: <String>{'child'},
    validate: (Reader r) => r
      ..animated('x')
      ..animated('y')
      ..animated('scale')
      ..animated('rotate')
      ..oneOf('alignment', namedAlignments.keys.toSet()),
    build: (BuildContext context, MotionNode node) {
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
    },
  ));

  // A local theme override, which is how a document says "the same scene,
  // quieter" without repeating a size on every component inside it.
  registerNode(NodeType(
    name: 'theme',
    properties: <String>{'scale', 'font', 'palette'},
    slots: <String>{'child'},
    validate: (Reader r) => r
      ..plainNumber('scale')
      ..string('font')
      ..oneOf('palette', <String>{'dark', 'light'}),
    build: (BuildContext context, MotionNode node) {
      final MotionTheme theme = MotionTheme.of(context);
      return MotionTheme(
        palette: switch (node['palette']) {
          'dark' => MotionPalette.dark,
          'light' => MotionPalette.light,
          _ => theme.palette,
        },
        typography: theme.typography.copyWith(
          scale: node.optionalNumber(context, 'scale'),
          fontFamily: node['font'] as String?,
        ),
        child: node.slot(context, 'child') ?? const SizedBox.shrink(),
      );
    },
  ));

  registerNode(NodeType(
    name: 'sequence',
    properties: <String>{'from', 'durationInFrames', 'layout'},
    slots: <String>{'child'},
    validate: (Reader r) => r
      ..plainInt('from', required: true)
      ..plainInt('durationInFrames')
      ..oneOf('layout', <String>{'none', 'fill'}),
    build: (BuildContext context, MotionNode node) => Sequence(
      from: node.integer(context, 'from'),
      durationInFrames: node.optionalInteger(context, 'durationInFrames'),
      layout: node['layout'] == 'fill'
          ? SequenceLayout.fill
          : SequenceLayout.none,
      child: node.slot(context, 'child') ?? const SizedBox.shrink(),
    ),
  ));

  registerNode(NodeType(
    name: 'stagger',
    properties: <String>{
      'step',
      'delay',
      'direction',
      'main',
      'cross',
      'expandChildren',
    },
    lists: <String>{'children'},
    validate: (Reader r) => r
      ..plainInt('step')
      ..plainInt('delay')
      ..oneOf('direction', _axes.keys.toSet())
      ..oneOf('main', _mainAxis.keys.toSet())
      ..oneOf('cross', _crossAxis.keys.toSet())
      ..boolean('expandChildren'),
    build: (BuildContext context, MotionNode node) => Stagger(
      step: node.integer(context, 'step', fallback: 3),
      delay: node.integer(context, 'delay'),
      direction: node.named('direction', _axes) ?? Axis.horizontal,
      mainAxisAlignment:
          node.named('main', _mainAxis) ?? MainAxisAlignment.start,
      crossAxisAlignment:
          node.named('cross', _crossAxis) ?? CrossAxisAlignment.center,
      expandChildren: node.flag(context, 'expandChildren'),
      children: node.children(context, 'children'),
    ),
  ));

  registerNode(NodeType(
    name: 'enter',
    properties: <String>{
      'mode',
      'delay',
      'duration',
      'curve',
      'fade',
      'distance',
      'scale',
      'stiffness',
      'damping',
    },
    slots: <String>{'child'},
    validate: (Reader r) => r
      ..oneOf('mode', _enterModes)
      ..plainInt('delay')
      ..plainInt('duration')
      ..oneOf('curve', namedCurves.keys.toSet())
      ..boolean('fade')
      ..plainNumber('distance')
      ..plainNumber('scale')
      ..plainNumber('stiffness')
      ..plainNumber('damping'),
    build: (BuildContext context, MotionNode node) {
      final Widget child =
          node.slot(context, 'child') ?? const SizedBox.shrink();
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
    },
  ));
}
