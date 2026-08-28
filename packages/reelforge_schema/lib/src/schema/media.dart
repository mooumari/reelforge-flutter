import '../names.dart';
import '../node.dart';
import '../reader.dart';

/// Video, audio and images.
///
/// Every one of these takes a `src`, which is why they are the nodes that
/// carry the path check: a document is a thing a server can send to an app,
/// so a source is untrusted input.
void registerMediaSchema() {
  registerNode(
    NodeType(
      name: 'video',
      properties: <String>{
        'src',
        'fit',
        'alignment',
        'opacity',
        'loop',
        'trimStartInFrames',
        'width',
        'height',
        'decodeWidth',
        'decodeHeight',
      },
      validate: (Reader r) => r
        ..source('src', required: true)
        ..oneOf('fit', fitNames)
        ..oneOf('alignment', alignmentNames)
        ..animated('opacity')
        ..boolean('loop')
        ..plainInt('trimStartInFrames')
        ..animated('width')
        ..animated('height')
        ..plainInt('decodeWidth')
        ..plainInt('decodeHeight'),
    ),
  );

  registerNode(
    NodeType(
      name: 'audio',
      properties: <String>{'src', 'volume', 'loop', 'trimStartInFrames'},
      validate: (Reader r) => r
        ..source('src', required: true)
        ..plainNumber('volume')
        ..boolean('loop')
        ..plainInt('trimStartInFrames'),
    ),
  );

  registerNode(
    NodeType(
      name: 'image',
      properties: <String>{
        'src',
        'fit',
        'alignment',
        'opacity',
        'width',
        'height',
      },
      validate: (Reader r) => r
        ..source('src', required: true)
        ..oneOf('fit', fitNames)
        ..oneOf('alignment', alignmentNames)
        ..animated('opacity')
        ..animated('width')
        ..animated('height'),
    ),
  );
}
