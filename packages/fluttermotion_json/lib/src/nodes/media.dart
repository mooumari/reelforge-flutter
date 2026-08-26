import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';

import '../node.dart';
import '../values.dart';

void registerMediaNodes() {
  registerNode(NodeType(
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
      ..oneOf('fit', namedFits.keys.toSet())
      ..oneOf('alignment', namedAlignments.keys.toSet())
      ..animated('opacity')
      ..boolean('loop')
      ..plainInt('trimStartInFrames')
      ..animated('width')
      ..animated('height')
      ..plainInt('decodeWidth')
      ..plainInt('decodeHeight'),
    build: (BuildContext context, MotionNode node) => VideoClip(
      // Not `node.text`: a source is collected during the declaration pass,
      // before any frame is rendered, and a binding that resolved differently
      // per frame would mean a file the preloader never opened.
      src: node['src']! as String,
      fit: node.named('fit', namedFits) ?? BoxFit.cover,
      alignment: node.named('alignment', namedAlignments) ?? Alignment.center,
      opacity: node.number(context, 'opacity', fallback: 1).clamp(0.0, 1.0),
      loop: node.flag(context, 'loop'),
      trimStartInFrames: node.integer(context, 'trimStartInFrames'),
      width: node.optionalNumber(context, 'width'),
      height: node.optionalNumber(context, 'height'),
      decodeWidth: node.optionalInteger(context, 'decodeWidth'),
      decodeHeight: node.optionalInteger(context, 'decodeHeight'),
    ),
  ));

  registerNode(NodeType(
    name: 'audio',
    properties: <String>{'src', 'volume', 'loop', 'trimStartInFrames'},
    validate: (Reader r) => r
      ..source('src', required: true)
      ..plainNumber('volume')
      ..boolean('loop')
      ..plainInt('trimStartInFrames'),
    build: (BuildContext context, MotionNode node) => Audio(
      src: node['src']! as String,
      volume: node.number(context, 'volume', fallback: 1),
      loop: node.flag(context, 'loop'),
      trimStartInFrames: node.integer(context, 'trimStartInFrames'),
    ),
  ));

  registerNode(NodeType(
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
      ..oneOf('fit', namedFits.keys.toSet())
      ..oneOf('alignment', namedAlignments.keys.toSet())
      ..animated('opacity')
      ..animated('width')
      ..animated('height'),
    build: (BuildContext context, MotionNode node) => MotionImage.asset(
      node['src']! as String,
      fit: node.named('fit', namedFits) ?? BoxFit.cover,
      alignment: node.named('alignment', namedAlignments) ?? Alignment.center,
      opacity: node.number(context, 'opacity', fallback: 1).clamp(0.0, 1.0),
      width: node.optionalNumber(context, 'width'),
      height: node.optionalNumber(context, 'height'),
    ),
  ));
}
