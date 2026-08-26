import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_schema/fluttermotion_schema.dart';

import '../node.dart';
import '../values.dart';

/// Builders for video, audio and images.
void registerMediaBuilders() {
  registerBuilder(
    'video',
    (BuildContext context, MotionNode node) => VideoClip(
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
  );

  registerBuilder(
    'audio',
    (BuildContext context, MotionNode node) => Audio(
      src: node['src']! as String,
      volume: node.number(context, 'volume', fallback: 1),
      loop: node.flag(context, 'loop'),
      trimStartInFrames: node.integer(context, 'trimStartInFrames'),
    ),
  );

  registerBuilder(
    'image',
    (BuildContext context, MotionNode node) => MotionImage.asset(
      node['src']! as String,
      fit: node.named('fit', namedFits) ?? BoxFit.cover,
      alignment: node.named('alignment', namedAlignments) ?? Alignment.center,
      opacity: node.number(context, 'opacity', fallback: 1).clamp(0.0, 1.0),
      width: node.optionalNumber(context, 'width'),
      height: node.optionalNumber(context, 'height'),
    ),
  );
}
