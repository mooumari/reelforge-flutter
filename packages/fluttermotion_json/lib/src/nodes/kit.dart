import 'package:flutter/widgets.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';

import '../node.dart';
import '../scope.dart';
import '../values.dart';

const Map<String, CrossAxisAlignment> _cross = <String, CrossAxisAlignment>{
  'start': CrossAxisAlignment.start,
  'end': CrossAxisAlignment.end,
  'center': CrossAxisAlignment.center,
  'stretch': CrossAxisAlignment.stretch,
};

const Map<String, Axis> _axes = <String, Axis>{
  'horizontal': Axis.horizontal,
  'vertical': Axis.vertical,
};

void registerKitNodes() {
  registerNode(NodeType(
    name: 'titleCard',
    properties: <String>{
      'headline',
      'kicker',
      'subhead',
      'padding',
      'alignment',
      'centred',
      'headlineColor',
      'kickerColor',
    },
    validate: (Reader r) => r
      ..string('headline', required: true)
      ..string('kicker')
      ..string('subhead')
      ..insets('padding')
      ..oneOf('alignment', _cross.keys.toSet())
      ..boolean('centred')
      ..colour('headlineColor')
      ..colour('kickerColor'),
    build: (BuildContext context, MotionNode node) => TitleCard(
      headline: node.text(context, 'headline'),
      kicker: node.optionalText(context, 'kicker'),
      subhead: node.optionalText(context, 'subhead'),
      padding: node.insets(context, 'padding') ?? const EdgeInsets.all(90),
      alignment: node.named('alignment', _cross) ?? CrossAxisAlignment.start,
      centred: node.flag(context, 'centred'),
      headlineColor: node.colour(context, 'headlineColor'),
      kickerColor: node.colour(context, 'kickerColor'),
    ),
  ));

  registerNode(NodeType(
    name: 'sceneLabel',
    properties: <String>{'value', 'color'},
    validate: (Reader r) => r
      ..string('value', required: true)
      ..colour('color'),
    build: (BuildContext context, MotionNode node) => SceneLabel(
      node.text(context, 'value'),
      color: node.colour(context, 'color'),
    ),
  ));

  registerNode(NodeType(
    name: 'labelledScene',
    properties: <String>{'label', 'padding', 'gap'},
    slots: <String>{'child'},
    validate: (Reader r) => r
      ..string('label', required: true)
      ..insets('padding')
      ..plainNumber('gap'),
    build: (BuildContext context, MotionNode node) => LabelledScene(
      label: node.text(context, 'label'),
      padding: node.insets(context, 'padding') ??
          const EdgeInsets.fromLTRB(70, 150, 70, 150),
      gap: node.number(context, 'gap', fallback: 50),
      child: node.slot(context, 'child') ?? const SizedBox.shrink(),
    ),
  ));

  registerNode(NodeType(
    name: 'bigStat',
    properties: <String>{'label', 'color'},
    slots: <String>{'value'},
    validate: (Reader r) => r
      ..string('label', required: true)
      ..colour('color'),
    build: (BuildContext context, MotionNode node) => BigStat(
      value: node.slot(context, 'value') ?? const SizedBox.shrink(),
      label: node.text(context, 'label'),
      color: node.colour(context, 'color'),
    ),
  ));

  registerNode(NodeType(
    name: 'bigStatList',
    properties: <String>{'spacing', 'cross'},
    lists: <String>{'children'},
    validate: (Reader r) => r
      ..plainNumber('spacing')
      ..oneOf('cross', _cross.keys.toSet()),
    build: (BuildContext context, MotionNode node) => BigStatList(
      spacing: node.number(context, 'spacing', fallback: 60),
      crossAxisAlignment:
          node.named('cross', _cross) ?? CrossAxisAlignment.start,
      children: node.children(context, 'children'),
    ),
  ));

  registerNode(NodeType(
    name: 'counter',
    properties: <String>{
      'to',
      'from',
      'delay',
      'duration',
      'curve',
      'decimals',
      'prefix',
      'suffix',
      'color',
      'size',
    },
    validate: (Reader r) => r
      ..animated('to', required: true)
      ..animated('from')
      ..plainInt('delay')
      ..plainInt('duration')
      ..oneOf('curve', namedCurves.keys.toSet())
      ..plainInt('decimals')
      ..string('prefix')
      ..string('suffix')
      ..colour('color')
      ..animated('size'),
    build: (BuildContext context, MotionNode node) {
      final int decimals = node.integer(context, 'decimals');
      final String prefix = node.text(context, 'prefix');
      final String suffix = node.text(context, 'suffix');
      final Color? color = node.colour(context, 'color');
      final double? size = node.optionalNumber(context, 'size');
      return Counter(
        // Read at parse-scope rather than animated: a counter's *target* is
        // data, and animating it as well would be two animations arguing.
        to: node.number(context, 'to'),
        from: node.number(context, 'from'),
        delay: node.integer(context, 'delay'),
        duration: node.integer(context, 'duration', fallback: 45),
        curve: node.curve('curve', fallback: Curves.easeOutExpo),
        format: (double value) =>
            '$prefix${value.toStringAsFixed(decimals)}$suffix',
        style: color == null && size == null
            ? null
            : TextStyle(color: color, fontSize: size),
      );
    },
  ));

  registerNode(NodeType(
    name: 'barChart',
    properties: <String>{
      'maxValue',
      'delay',
      'step',
      'stiffness',
      'damping',
      'color',
      'showValues',
      'barRadius',
      'barSpacing',
      'valueHeadroom',
    },
    specs: <String>{'bars'},
    validate: (Reader r) => r
      ..plainNumber('maxValue')
      ..plainInt('delay')
      ..plainInt('step')
      ..plainNumber('stiffness')
      ..plainNumber('damping')
      ..colour('color')
      ..boolean('showValues')
      ..plainNumber('barRadius')
      ..plainNumber('barSpacing')
      ..plainNumber('valueHeadroom'),
    build: (BuildContext context, MotionNode node) => BarChart(
      bars: <BarDatum>[
        for (final ScopedSpec bar
            in node.specs['bars']?.resolve(MotionScope.of(context)) ??
                const <ScopedSpec>[])
          BarDatum(
            value: bar.number(context, 'value'),
            label: bar.text(context, 'label'),
            color: bar.colour(context, 'color'),
          ),
      ],
      maxValue: node.optionalNumber(context, 'maxValue'),
      delay: node.integer(context, 'delay', fallback: 10),
      step: node.integer(context, 'step', fallback: 3),
      stiffness: node.number(context, 'stiffness', fallback: 140),
      damping: node.number(context, 'damping', fallback: 16),
      color: node.colour(context, 'color'),
      showValues: node.flag(context, 'showValues', fallback: true),
      barRadius: node.number(context, 'barRadius', fallback: 10),
      barSpacing: node.number(context, 'barSpacing', fallback: 6),
      valueHeadroom: node.number(context, 'valueHeadroom', fallback: 44),
    ),
  ));

  registerNode(NodeType(
    name: 'lineChart',
    properties: <String>{
      'maxValue',
      'delay',
      'duration',
      'curve',
      'color',
      'strokeWidth',
      'dotRadius',
      'showLabels',
    },
    specs: <String>{'points'},
    validate: (Reader r) => r
      ..plainNumber('maxValue')
      ..plainInt('delay')
      ..plainInt('duration')
      ..oneOf('curve', namedCurves.keys.toSet())
      ..colour('color')
      ..plainNumber('strokeWidth')
      ..plainNumber('dotRadius')
      ..boolean('showLabels'),
    build: (BuildContext context, MotionNode node) => LineChart(
      points: <LineDatum>[
        for (final ScopedSpec point
            in node.specs['points']?.resolve(MotionScope.of(context)) ??
                const <ScopedSpec>[])
          LineDatum(
            value: point.number(context, 'value'),
            label: point.text(context, 'label'),
          ),
      ],
      maxValue: node.optionalNumber(context, 'maxValue'),
      delay: node.integer(context, 'delay', fallback: 8),
      duration: node.optionalInteger(context, 'duration'),
      curve: node.curve('curve', fallback: Curves.easeInOutCubic),
      color: node.colour(context, 'color'),
      strokeWidth: node.number(context, 'strokeWidth', fallback: 6),
      dotRadius: node.number(context, 'dotRadius', fallback: 9),
      showLabels: node.flag(context, 'showLabels', fallback: true),
    ),
  ));

  registerNode(NodeType(
    name: 'statCard',
    properties: <String>{
      'title',
      'value',
      'badge',
      'signedBy',
      'color',
      'padding',
      'radius',
    },
    validate: (Reader r) => r
      ..string('title', required: true)
      ..string('value', required: true)
      ..string('badge')
      ..animated('signedBy')
      ..colour('color')
      ..insets('padding')
      ..plainNumber('radius'),
    build: (BuildContext context, MotionNode node) => StatCard(
      title: node.text(context, 'title'),
      value: node.text(context, 'value'),
      badge: node.optionalText(context, 'badge'),
      signedBy: node.optionalNumber(context, 'signedBy'),
      color: node.colour(context, 'color'),
      padding: node.insets(context, 'padding') ?? const EdgeInsets.all(22),
      radius: node.number(context, 'radius', fallback: 20),
    ),
  ));

  registerNode(NodeType(
    name: 'cardGrid',
    properties: <String>{
      'crossAxisCount',
      'spacing',
      'aspectRatio',
      'delay',
      'step',
    },
    lists: <String>{'children'},
    validate: (Reader r) => r
      ..plainInt('crossAxisCount')
      ..plainNumber('spacing')
      ..plainNumber('aspectRatio')
      ..plainInt('delay')
      ..plainInt('step'),
    build: (BuildContext context, MotionNode node) => CardGrid(
      crossAxisCount: node.integer(context, 'crossAxisCount', fallback: 3),
      spacing: node.number(context, 'spacing', fallback: 20),
      aspectRatio: node.number(context, 'aspectRatio', fallback: 0.92),
      delay: node.integer(context, 'delay', fallback: 8),
      step: node.integer(context, 'step', fallback: 4),
      children: node.children(context, 'children'),
    ),
  ));

  registerNode(NodeType(
    name: 'footageOverlay',
    properties: <String>{
      'src',
      'caption',
      'fit',
      'loop',
      'trimStartInFrames',
      'scrim',
      'scrimFrom',
      'captionDelay',
      'captionPadding',
    },
    slots: <String>{'child'},
    validate: (Reader r) => r
      ..source('src', required: true)
      ..string('caption')
      ..oneOf('fit', namedFits.keys.toSet())
      ..boolean('loop')
      ..plainInt('trimStartInFrames')
      ..boolean('scrim')
      ..oneOf('scrimFrom', namedAlignments.keys.toSet())
      ..plainInt('captionDelay')
      ..insets('captionPadding'),
    build: (BuildContext context, MotionNode node) => FootageOverlay(
      src: node['src']! as String,
      caption: node.optionalText(context, 'caption'),
      fit: node.named('fit', namedFits) ?? BoxFit.cover,
      loop: node.flag(context, 'loop', fallback: true),
      trimStartInFrames: node.integer(context, 'trimStartInFrames'),
      scrim: node.flag(context, 'scrim', fallback: true),
      scrimFrom:
          node.named('scrimFrom', namedAlignments) ?? Alignment.topCenter,
      captionDelay: node.integer(context, 'captionDelay', fallback: 10),
      captionPadding: node.insets(context, 'captionPadding') ??
          const EdgeInsets.only(left: 70, right: 70, bottom: 200),
      child: node.slot(context, 'child'),
    ),
  ));

  registerNode(NodeType(
    name: 'splitScreen',
    properties: <String>{'direction', 'gap', 'slideFrames', 'curve', 'delay'},
    slots: <String>{'first', 'second'},
    validate: (Reader r) => r
      ..oneOf('direction', _axes.keys.toSet())
      ..plainNumber('gap')
      ..plainInt('slideFrames')
      ..oneOf('curve', namedCurves.keys.toSet())
      ..plainInt('delay'),
    build: (BuildContext context, MotionNode node) => SplitScreen(
      first: node.slot(context, 'first') ?? const SizedBox.shrink(),
      second: node.slot(context, 'second') ?? const SizedBox.shrink(),
      direction: node.named('direction', _axes) ?? Axis.vertical,
      gap: node.number(context, 'gap', fallback: 8),
      slideFrames: node.integer(context, 'slideFrames', fallback: 30),
      curve: node.curve('curve', fallback: Curves.easeInOutCubic),
      delay: node.integer(context, 'delay'),
    ),
  ));
}
