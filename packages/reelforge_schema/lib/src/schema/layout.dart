import '../names.dart';
import '../node.dart';
import '../reader.dart';

/// The layout primitives: what each one accepts, and nothing about widgets.
///
/// Mirrored by `reelforge_json/lib/src/nodes/layout.dart`, which holds the
/// builder for each of these names in the same order.
void registerLayoutSchema() {
  registerNode(
    NodeType(
      name: 'column',
      properties: <String>{'main', 'cross', 'size', 'spacing'},
      lists: <String>{'children'},
      validate: (Reader r) => r
        ..oneOf('main', mainAxisNames)
        ..oneOf('cross', crossAxisNames)
        ..oneOf('size', mainAxisSizeNames)
        ..plainNumber('spacing'),
    ),
  );

  registerNode(
    NodeType(
      name: 'row',
      properties: <String>{'main', 'cross', 'size', 'spacing'},
      lists: <String>{'children'},
      validate: (Reader r) => r
        ..oneOf('main', mainAxisNames)
        ..oneOf('cross', crossAxisNames)
        ..oneOf('size', mainAxisSizeNames)
        ..plainNumber('spacing'),
    ),
  );

  registerNode(
    NodeType(
      name: 'stack',
      properties: <String>{'alignment', 'fit'},
      lists: <String>{'children'},
      validate: (Reader r) => r
        ..oneOf('alignment', alignmentNames)
        ..oneOf('fit', stackFitNames),
    ),
  );

  registerNode(
    NodeType(
      name: 'padding',
      properties: <String>{'padding'},
      slots: <String>{'child'},
      validate: (Reader r) => r.insets('padding'),
    ),
  );

  registerNode(NodeType(name: 'center', slots: <String>{'child'}));

  registerNode(
    NodeType(
      name: 'align',
      properties: <String>{'alignment'},
      slots: <String>{'child'},
      validate: (Reader r) => r.oneOf('alignment', alignmentNames),
    ),
  );

  registerNode(
    NodeType(
      name: 'expanded',
      properties: <String>{'flex'},
      slots: <String>{'child'},
      parentData: true,
      validate: (Reader r) => r.plainInt('flex'),
    ),
  );

  registerNode(
    NodeType(
      name: 'sizedBox',
      properties: <String>{'width', 'height'},
      slots: <String>{'child'},
      validate: (Reader r) => r
        ..animated('width')
        ..animated('height'),
    ),
  );

  registerNode(
    NodeType(
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
    ),
  );

  registerNode(
    NodeType(
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
        ..oneOf('style', textRoles)
        ..animated('size')
        ..colour('color')
        ..oneOf('weight', fontWeightNames)
        ..oneOf('align', textAlignNames)
        ..animated('letterSpacing')
        ..animated('lineHeight')
        ..plainInt('maxLines'),
    ),
  );

  registerNode(
    NodeType(
      name: 'opacity',
      properties: <String>{'value'},
      slots: <String>{'child'},
      validate: (Reader r) => r.animated('value', required: true),
    ),
  );

  registerNode(
    NodeType(
      name: 'transform',
      properties: <String>{'x', 'y', 'scale', 'rotate', 'alignment'},
      slots: <String>{'child'},
      validate: (Reader r) => r
        ..animated('x')
        ..animated('y')
        ..animated('scale')
        ..animated('rotate')
        ..oneOf('alignment', alignmentNames),
    ),
  );

  // A local theme override, which is how a document says "the same scene,
  // quieter" without repeating a size on every component inside it.
  registerNode(
    NodeType(
      name: 'theme',
      properties: <String>{'scale', 'font', 'palette'},
      slots: <String>{'child'},
      validate: (Reader r) => r
        ..plainNumber('scale')
        ..string('font')
        ..oneOf('palette', paletteNames),
    ),
  );

  registerNode(
    NodeType(
      name: 'sequence',
      properties: <String>{'from', 'durationInFrames', 'layout'},
      slots: <String>{'child'},
      validate: (Reader r) => r
        ..plainInt('from', required: true)
        ..plainInt('durationInFrames')
        ..oneOf('layout', sequenceLayoutNames),
    ),
  );

  registerNode(
    NodeType(
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
        ..oneOf('direction', axisNames)
        ..oneOf('main', mainAxisNames)
        ..oneOf('cross', crossAxisNames)
        ..boolean('expandChildren'),
    ),
  );

  registerNode(
    NodeType(
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
        ..oneOf('mode', enterModes)
        ..plainInt('delay')
        ..plainInt('duration')
        ..oneOf('curve', curveNames)
        ..boolean('fade')
        ..plainNumber('distance')
        ..plainNumber('scale')
        ..plainNumber('stiffness')
        ..plainNumber('damping'),
    ),
  );
}
