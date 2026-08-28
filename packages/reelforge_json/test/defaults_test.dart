import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_kit/reelforge_kit.dart';

import 'build_test.dart' show pump;

/// A node with no properties set must be the kit widget with none set either.
///
/// This is the failure mode a JSON layer invites: the node has to restate
/// every default in order to pass an argument at all, and a restated default
/// that drifts from the real one is invisible. It does not throw, it does not
/// fail validation, and it does not look wrong on its own -- it only shows up
/// as a scene that animates a few pixels differently from the Dart it was
/// transcribed from, which is exactly how `enter`'s spring stiffness was found
/// (130 in the kit, 120 here) after a full 1800-frame render came back with a
/// grid of cards a hair behind.
void main() {
  testWidgets('enter modes default to the kit\'s own defaults',
      (WidgetTester tester) async {
    const Enter fade = Enter.fade(child: SizedBox.shrink());
    const Enter scale = Enter.scale(child: SizedBox.shrink());
    const Enter spring = Enter.spring(child: SizedBox.shrink());
    final Enter slideUp = Enter.slideUp(child: const SizedBox.shrink());

    for (final (String mode, Enter expected) in <(String, Enter)>[
      ('fade', fade),
      ('scale', scale),
      ('spring', spring),
      ('slideUp', slideUp),
    ]) {
      await pump(tester, <String, Object?>{
        'type': 'enter',
        'mode': mode,
        'child': <String, Object?>{'type': 'text', 'value': 'x'},
      });
      final Enter built = tester.widget<Enter>(find.byType(Enter));
      expect(built.delay, expected.delay, reason: '$mode delay');
      expect(built.duration, expected.duration, reason: '$mode duration');
      expect(built.curve, expected.curve, reason: '$mode curve');
      expect(built.fade, expected.fade, reason: '$mode fade');
      expect(built.from, expected.from, reason: '$mode from');
      expect(built.scaleFrom, expected.scaleFrom, reason: '$mode scaleFrom');
      expect(built.stiffness, expected.stiffness, reason: '$mode stiffness');
      expect(built.damping, expected.damping, reason: '$mode damping');
    }
  });

  testWidgets('kit components default to what the kit says they do',
      (WidgetTester tester) async {
    await pump(tester, <String, Object?>{
      'type': 'barChart',
      'bars': <Object?>[
        <String, Object?>{'value': 1, 'label': 'a'},
      ],
    });
    final BarChart bars = tester.widget<BarChart>(find.byType(BarChart));
    const BarChart barDefaults = BarChart(bars: <BarDatum>[]);
    expect(bars.delay, barDefaults.delay);
    expect(bars.step, barDefaults.step);
    expect(bars.stiffness, barDefaults.stiffness);
    expect(bars.damping, barDefaults.damping);
    expect(bars.showValues, barDefaults.showValues);
    expect(bars.barRadius, barDefaults.barRadius);
    expect(bars.barSpacing, barDefaults.barSpacing);
    expect(bars.valueHeadroom, barDefaults.valueHeadroom);

    await pump(tester, <String, Object?>{
      'type': 'lineChart',
      'points': <Object?>[
        <String, Object?>{'value': 1, 'label': 'a'},
      ],
    });
    final LineChart line = tester.widget<LineChart>(find.byType(LineChart));
    const LineChart lineDefaults = LineChart(points: <LineDatum>[]);
    expect(line.delay, lineDefaults.delay);
    expect(line.duration, lineDefaults.duration);
    expect(line.curve, lineDefaults.curve);
    expect(line.strokeWidth, lineDefaults.strokeWidth);
    expect(line.dotRadius, lineDefaults.dotRadius);
    expect(line.showLabels, lineDefaults.showLabels);

    await pump(tester, <String, Object?>{
      'type': 'cardGrid',
      'children': <Object?>[],
    });
    final CardGrid grid = tester.widget<CardGrid>(find.byType(CardGrid));
    const CardGrid gridDefaults = CardGrid(children: <Widget>[]);
    expect(grid.crossAxisCount, gridDefaults.crossAxisCount);
    expect(grid.spacing, gridDefaults.spacing);
    expect(grid.aspectRatio, gridDefaults.aspectRatio);
    expect(grid.delay, gridDefaults.delay);
    expect(grid.step, gridDefaults.step);

    await pump(tester, <String, Object?>{
      'type': 'splitScreen',
      'first': <String, Object?>{'type': 'box', 'color': 'surface'},
      'second': <String, Object?>{'type': 'box', 'color': 'surface'},
    });
    final SplitScreen split =
        tester.widget<SplitScreen>(find.byType(SplitScreen));
    const SplitScreen splitDefaults = SplitScreen(
      first: SizedBox.shrink(),
      second: SizedBox.shrink(),
    );
    expect(split.direction, splitDefaults.direction);
    expect(split.gap, splitDefaults.gap);
    expect(split.slideFrames, splitDefaults.slideFrames);
    expect(split.curve, splitDefaults.curve);
    expect(split.delay, splitDefaults.delay);

    await pump(tester, <String, Object?>{
      'type': 'footageOverlay',
      'src': 'assets/x.mp4',
    });
    final FootageOverlay footage =
        tester.widget<FootageOverlay>(find.byType(FootageOverlay));
    const FootageOverlay footageDefaults = FootageOverlay(src: 'x');
    expect(footage.fit, footageDefaults.fit);
    expect(footage.loop, footageDefaults.loop);
    expect(footage.scrim, footageDefaults.scrim);
    expect(footage.scrimFrom, footageDefaults.scrimFrom);
    expect(footage.captionDelay, footageDefaults.captionDelay);
    expect(footage.captionPadding, footageDefaults.captionPadding);

    await pump(tester, <String, Object?>{
      'type': 'counter',
      'to': 10,
    });
    final Counter counter = tester.widget<Counter>(find.byType(Counter));
    const Counter counterDefaults = Counter(to: 0);
    expect(counter.from, counterDefaults.from);
    expect(counter.delay, counterDefaults.delay);
    expect(counter.duration, counterDefaults.duration);
    expect(counter.curve, counterDefaults.curve);
    expect(counter.format(3.0), counterDefaults.format(3.0));

    await pump(tester, <String, Object?>{
      'type': 'titleCard',
      'headline': 'x',
    });
    final TitleCard title = tester.widget<TitleCard>(find.byType(TitleCard));
    const TitleCard titleDefaults = TitleCard(headline: 'x');
    expect(title.padding, titleDefaults.padding);
    expect(title.alignment, titleDefaults.alignment);
    expect(title.centred, titleDefaults.centred);

    await pump(tester, <String, Object?>{
      'type': 'statCard',
      'title': 'x',
      'value': 'y',
    });
    final StatCard card = tester.widget<StatCard>(find.byType(StatCard));
    const StatCard cardDefaults = StatCard(title: 'x', value: 'y');
    expect(card.padding, cardDefaults.padding);
    expect(card.radius, cardDefaults.radius);

    await pump(tester, <String, Object?>{
      'type': 'labelledScene',
      'label': 'x',
      'child': <String, Object?>{'type': 'text', 'value': 'y'},
    });
    final LabelledScene labelled =
        tester.widget<LabelledScene>(find.byType(LabelledScene));
    const LabelledScene labelledDefaults =
        LabelledScene(label: 'x', child: SizedBox.shrink());
    expect(labelled.padding, labelledDefaults.padding);
    expect(labelled.gap, labelledDefaults.gap);

    await pump(tester, <String, Object?>{
      'type': 'bigStatList',
      'children': <Object?>[],
    });
    final BigStatList stats =
        tester.widget<BigStatList>(find.byType(BigStatList));
    const BigStatList statDefaults = BigStatList(children: <Widget>[]);
    expect(stats.spacing, statDefaults.spacing);
    expect(stats.crossAxisAlignment, statDefaults.crossAxisAlignment);

    await pump(tester, <String, Object?>{
      'type': 'stagger',
      'children': <Object?>[],
    });
    final Stagger stagger = tester.widget<Stagger>(find.byType(Stagger));
    const Stagger staggerDefaults = Stagger(children: <Widget>[]);
    expect(stagger.step, staggerDefaults.step);
    expect(stagger.delay, staggerDefaults.delay);
    expect(stagger.direction, staggerDefaults.direction);
    expect(stagger.mainAxisAlignment, staggerDefaults.mainAxisAlignment);
    expect(stagger.crossAxisAlignment, staggerDefaults.crossAxisAlignment);
    expect(stagger.expandChildren, staggerDefaults.expandChildren);
  });

  testWidgets('media nodes default to what the framework says they do',
      (WidgetTester tester) async {
    // The media nodes restate more defaults than any others -- a source is
    // the only required property, so every one of these has to be written out
    // here in order for the optional ones to be passable at all. They are also
    // the ones a render is least likely to catch: a video decoded at the wrong
    // size or held instead of looped still looks like a video.
    await pump(tester, <String, Object?>{'type': 'video', 'src': 'a.mp4'});
    final VideoClip video = tester.widget<VideoClip>(find.byType(VideoClip));
    const VideoClip videoDefaults = VideoClip(src: 'a.mp4');
    expect(video.fit, videoDefaults.fit);
    expect(video.alignment, videoDefaults.alignment);
    expect(video.opacity, videoDefaults.opacity);
    expect(video.loop, videoDefaults.loop);
    expect(video.trimStartInFrames, videoDefaults.trimStartInFrames);
    expect(video.width, videoDefaults.width);
    expect(video.height, videoDefaults.height);
    expect(video.decodeWidth, videoDefaults.decodeWidth);
    expect(video.decodeHeight, videoDefaults.decodeHeight);

    await pump(tester, <String, Object?>{'type': 'audio', 'src': 'a.m4a'});
    final Audio audio = tester.widget<Audio>(find.byType(Audio));
    const Audio audioDefaults = Audio(src: 'a.m4a');
    expect(audio.volume, audioDefaults.volume);
    expect(audio.loop, audioDefaults.loop);
    expect(audio.trimStartInFrames, audioDefaults.trimStartInFrames);

    await pump(tester, <String, Object?>{'type': 'image', 'src': 'a.png'});
    final MotionImage image =
        tester.widget<MotionImage>(find.byType(MotionImage));
    final MotionImage imageDefaults = MotionImage.asset('a.png');
    expect(image.fit, imageDefaults.fit);
    expect(image.alignment, imageDefaults.alignment);
    expect(image.opacity, imageDefaults.opacity);
    expect(image.width, imageDefaults.width);
    expect(image.height, imageDefaults.height);
  });
}
