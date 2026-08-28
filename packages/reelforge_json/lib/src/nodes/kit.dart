import 'package:flutter/widgets.dart';
import 'package:reelforge_kit/reelforge_kit.dart';
import 'package:reelforge_schema/reelforge_schema.dart';

import '../node.dart';
import '../values.dart';

/// Builders for the kit's scenes, charts and cards.
///
/// What each of these accepts is declared in
/// `reelforge_schema/lib/src/schema/kit.dart`, in the same order.
void registerKitBuilders() {
  registerBuilder(
    'titleCard',
    (BuildContext context, MotionNode node) => TitleCard(
      headline: node.text(context, 'headline'),
      kicker: node.optionalText(context, 'kicker'),
      subhead: node.optionalText(context, 'subhead'),
      padding: node.insets(context, 'padding') ?? const EdgeInsets.all(90),
      alignment:
          node.named('alignment', namedKitCrossAxis) ??
          CrossAxisAlignment.start,
      centred: node.flag(context, 'centred'),
      headlineColor: node.colour(context, 'headlineColor'),
      kickerColor: node.colour(context, 'kickerColor'),
    ),
  );

  registerBuilder(
    'sceneLabel',
    (BuildContext context, MotionNode node) => SceneLabel(
      node.text(context, 'value'),
      color: node.colour(context, 'color'),
    ),
  );

  registerBuilder(
    'labelledScene',
    (BuildContext context, MotionNode node) => LabelledScene(
      label: node.text(context, 'label'),
      padding:
          node.insets(context, 'padding') ??
          const EdgeInsets.fromLTRB(70, 150, 70, 150),
      gap: node.number(context, 'gap', fallback: 50),
      child: node.slot(context, 'child') ?? const SizedBox.shrink(),
    ),
  );

  registerBuilder(
    'bigStat',
    (BuildContext context, MotionNode node) => BigStat(
      value: node.slot(context, 'value') ?? const SizedBox.shrink(),
      label: node.text(context, 'label'),
      color: node.colour(context, 'color'),
    ),
  );

  registerBuilder(
    'bigStatList',
    (BuildContext context, MotionNode node) => BigStatList(
      spacing: node.number(context, 'spacing', fallback: 60),
      crossAxisAlignment:
          node.named('cross', namedKitCrossAxis) ?? CrossAxisAlignment.start,
      children: node.children(context, 'children'),
    ),
  );

  registerBuilder('counter', (BuildContext context, MotionNode node) {
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
  });

  registerBuilder(
    'barChart',
    (BuildContext context, MotionNode node) => BarChart(
      bars: <BarDatum>[
        for (final ScopedSpec bar in node.data(context, 'bars'))
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
  );

  registerBuilder(
    'lineChart',
    (BuildContext context, MotionNode node) => LineChart(
      points: <LineDatum>[
        for (final ScopedSpec point in node.data(context, 'points'))
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
  );

  registerBuilder(
    'statCard',
    (BuildContext context, MotionNode node) => StatCard(
      title: node.text(context, 'title'),
      value: node.text(context, 'value'),
      badge: node.optionalText(context, 'badge'),
      signedBy: node.optionalNumber(context, 'signedBy'),
      color: node.colour(context, 'color'),
      padding: node.insets(context, 'padding') ?? const EdgeInsets.all(22),
      radius: node.number(context, 'radius', fallback: 20),
    ),
  );

  registerBuilder(
    'cardGrid',
    (BuildContext context, MotionNode node) => CardGrid(
      crossAxisCount: node.integer(context, 'crossAxisCount', fallback: 3),
      spacing: node.number(context, 'spacing', fallback: 20),
      aspectRatio: node.number(context, 'aspectRatio', fallback: 0.92),
      delay: node.integer(context, 'delay', fallback: 8),
      step: node.integer(context, 'step', fallback: 4),
      children: node.children(context, 'children'),
    ),
  );

  registerBuilder(
    'footageOverlay',
    (BuildContext context, MotionNode node) => FootageOverlay(
      src: node['src']! as String,
      caption: node.optionalText(context, 'caption'),
      fit: node.named('fit', namedFits) ?? BoxFit.cover,
      loop: node.flag(context, 'loop', fallback: true),
      trimStartInFrames: node.integer(context, 'trimStartInFrames'),
      scrim: node.flag(context, 'scrim', fallback: true),
      scrimFrom:
          node.named('scrimFrom', namedAlignments) ?? Alignment.topCenter,
      captionDelay: node.integer(context, 'captionDelay', fallback: 10),
      captionPadding:
          node.insets(context, 'captionPadding') ??
          const EdgeInsets.only(left: 70, right: 70, bottom: 200),
      child: node.slot(context, 'child'),
    ),
  );

  registerBuilder(
    'splitScreen',
    (BuildContext context, MotionNode node) => SplitScreen(
      first: node.slot(context, 'first') ?? const SizedBox.shrink(),
      second: node.slot(context, 'second') ?? const SizedBox.shrink(),
      direction: node.named('direction', namedAxes) ?? Axis.vertical,
      gap: node.number(context, 'gap', fallback: 8),
      slideFrames: node.integer(context, 'slideFrames', fallback: 30),
      curve: node.curve('curve', fallback: Curves.easeInOutCubic),
      delay: node.integer(context, 'delay'),
    ),
  );
}
