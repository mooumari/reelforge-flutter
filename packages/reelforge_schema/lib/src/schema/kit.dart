import '../names.dart';
import '../node.dart';
import '../reader.dart';

/// The kit's scenes, charts and cards.
///
/// Mirrored by `reelforge_json/lib/src/nodes/kit.dart`, which holds the
/// builder for each of these names in the same order.
void registerKitSchema() {
  registerNode(
    NodeType(
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
        ..oneOf('alignment', kitCrossAxisNames)
        ..boolean('centred')
        ..colour('headlineColor')
        ..colour('kickerColor'),
    ),
  );

  registerNode(
    NodeType(
      name: 'sceneLabel',
      properties: <String>{'value', 'color'},
      validate: (Reader r) => r
        ..string('value', required: true)
        ..colour('color'),
    ),
  );

  registerNode(
    NodeType(
      name: 'labelledScene',
      properties: <String>{'label', 'padding', 'gap'},
      slots: <String>{'child'},
      validate: (Reader r) => r
        ..string('label', required: true)
        ..insets('padding')
        ..plainNumber('gap'),
    ),
  );

  registerNode(
    NodeType(
      name: 'bigStat',
      properties: <String>{'label', 'color'},
      slots: <String>{'value'},
      validate: (Reader r) => r
        ..string('label', required: true)
        ..colour('color'),
    ),
  );

  registerNode(
    NodeType(
      name: 'bigStatList',
      properties: <String>{'spacing', 'cross'},
      lists: <String>{'children'},
      validate: (Reader r) => r
        ..plainNumber('spacing')
        ..oneOf('cross', kitCrossAxisNames),
    ),
  );

  registerNode(
    NodeType(
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
        ..oneOf('curve', curveNames)
        ..plainInt('decimals')
        ..string('prefix')
        ..string('suffix')
        ..colour('color')
        ..animated('size'),
    ),
  );

  registerNode(
    NodeType(
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
      specs: <String, void Function(Reader)>{
        'bars': (Reader r) => r
          ..rejectUnknownKeys(<String>{'value', 'label', 'color'})
          ..animated('value', required: true)
          ..string('label')
          ..colour('color'),
      },
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
    ),
  );

  registerNode(
    NodeType(
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
      specs: <String, void Function(Reader)>{
        'points': (Reader r) => r
          ..rejectUnknownKeys(<String>{'value', 'label'})
          ..animated('value', required: true)
          ..string('label'),
      },
      validate: (Reader r) => r
        ..plainNumber('maxValue')
        ..plainInt('delay')
        ..plainInt('duration')
        ..oneOf('curve', curveNames)
        ..colour('color')
        ..plainNumber('strokeWidth')
        ..plainNumber('dotRadius')
        ..boolean('showLabels'),
    ),
  );

  registerNode(
    NodeType(
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
    ),
  );

  registerNode(
    NodeType(
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
    ),
  );

  registerNode(
    NodeType(
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
        ..oneOf('fit', fitNames)
        ..boolean('loop')
        ..plainInt('trimStartInFrames')
        ..boolean('scrim')
        ..oneOf('scrimFrom', alignmentNames)
        ..plainInt('captionDelay')
        ..insets('captionPadding'),
    ),
  );

  registerNode(
    NodeType(
      name: 'splitScreen',
      properties: <String>{'direction', 'gap', 'slideFrames', 'curve', 'delay'},
      slots: <String>{'first', 'second'},
      validate: (Reader r) => r
        ..oneOf('direction', axisNames)
        ..plainNumber('gap')
        ..plainInt('slideFrames')
        ..oneOf('curve', curveNames)
        ..plainInt('delay'),
    ),
  );
}
