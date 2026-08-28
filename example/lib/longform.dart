import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_kit/reelforge_kit.dart';

import 'report_data.dart';

/// A 60-second, data-driven vertical reel.
///
/// This exists to be *hard*, not to be pretty. Everything else in this example
/// is a few seconds long and does one thing; this one runs 1800 frames through
/// eight scenes, holds two video decoders open at once, mixes nine audio
/// clips, and draws every number in it from `assets/report.json`. It is the
/// shape of a composition someone would actually ship, at the length they
/// would actually ship it, which is the only way to find the things a
/// 200-frame probe cannot.
///
/// It is also the example that `reelforge_kit` was extracted from. Every
/// scene here was a bespoke widget first; what survived being made general is
/// what the kit contains. The file is now roughly a fifth of its former length
/// and says what each scene *is* rather than how it is drawn -- which is the
/// only honest test of whether the extraction was worth doing.
const int fps = 30;

/// The one place a scene's length is written down.
///
/// Start frames are derived from these, so moving a scene moves its content,
/// its sting and its transition together, and nothing anywhere holds a
/// hardcoded frame number.
///
/// Content is behind builders rather than built here: this list is a top-level
/// `final` and the composition needs its length before `main` has loaded
/// `report.json`. The lengths are known that early; the data is not.
final List<Scene> scenes = <Scene>[
  Scene(
    seconds: 5,
    builder: (BuildContext context) => TitleCard(
      kicker: report.period,
      headline: report.headline,
      subhead: '${report.releases} releases · ${report.incidents} incidents',
    ),
  ),
  Scene(
    seconds: 9,
    sting: _sting,
    builder: (BuildContext context) => LabelledScene(
      label: 'Shipped per week',
      child: BarChart(
        bars: <BarDatum>[
          for (final Week week in report.weeks)
            BarDatum(value: week.shipped, label: week.label),
        ],
      ),
    ),
  ),
  const Scene(
    seconds: 9,
    sting: _sting,
    // Two seconds of footage under a nine-second scene, so it loops; without
    // that the picture freezes for seven.
    child: FootageOverlay(
      src: 'assets/clip.mp4',
      caption: 'Every frame is a widget,\nincluding the ones over footage.',
    ),
  ),
  Scene(
    seconds: 8,
    sting: _sting,
    builder: (BuildContext context) => LabelledScene(
      label: 'By team',
      padding: const EdgeInsets.fromLTRB(70, 220, 70, 220),
      child: CardGrid(
        children: <Widget>[
          for (final Team team in report.teams)
            Enter.spring(
              child: StatCard(
                badge: team.owner,
                title: team.name,
                value: '${team.delta >= 0 ? '+' : ''}'
                    '${team.delta.toStringAsFixed(1)}%',
                signedBy: team.delta,
              ),
            ),
        ],
      ),
    ),
  ),
  // Two clips on screen at once: two decoders open, both streaming, both
  // expected to stay on the same frame as each other. Nothing before this ever
  // asked for more than one at a time.
  const Scene(
    seconds: 9,
    sting: _sting,
    child: SplitScreen(
      first: VideoClip(src: 'assets/clip.mp4', fit: BoxFit.cover, loop: true),
      second: VideoClip(
        src: 'assets/demo_clip.mp4',
        fit: BoxFit.cover,
        loop: true,
        // Enters the source part way in, so this is also a trim landing on an
        // exact frame while another decoder is running -- and a loop that
        // wraps to the trim point rather than to zero.
        trimStartInFrames: 45,
      ),
    ),
  ),
  Scene(
    seconds: 8,
    sting: _sting,
    // Counters that count. Each is a pure function of the frame, so scrubbing
    // backwards through them lands on exactly the same number.
    builder: (BuildContext context) => Padding(
      padding: const EdgeInsets.all(80),
      child: BigStatList(
        children: <Widget>[
          BigStat(
            value: Counter(to: report.releases, delay: 6),
            label: 'releases',
          ),
          BigStat(
            value: Counter(
              to: report.uptime,
              delay: 20,
              format: (double v) => v.toStringAsFixed(2),
            ),
            label: 'percent uptime',
            color: MotionTheme.paletteOf(context).accent,
          ),
          BigStat(
            value: Counter(to: report.incidents, delay: 34),
            label: 'incidents',
            color: MotionTheme.paletteOf(context).warning,
          ),
        ],
      ),
    ),
  ),
  Scene(
    seconds: 7,
    sting: _sting,
    builder: (BuildContext context) => LabelledScene(
      label: 'Reverts, week by week',
      child: LineChart(
        points: <LineDatum>[
          for (final Week week in report.weeks)
            LineDatum(value: week.reverted, label: week.label),
        ],
      ),
    ),
  ),
  Scene(
    seconds: 5,
    sting: _sting,
    builder: (BuildContext context) => MotionTheme(
      // The outro is the same card as the opening, quieter. Scale is the knob
      // for that, rather than a size argument on every component it contains.
      typography: MotionTheme.typeOf(context).copyWith(scale: 0.83),
      child: TitleCard.centred(
        headline: report.period,
        subhead: 'rendered from a JSON file',
      ),
    ),
  ),
];

const Widget _sting = Audio(src: 'assets/chime.mp3', volume: 0.5);

final Composition longform = Composition(
  id: 'Longform',
  width: 1080,
  height: 1920,
  fps: fps,
  durationInFrames: Storyboard.totalFrames(scenes, fps: fps),
  wrapper: (BuildContext context, Widget child) => MotionSurface(
    // The fonts travel with the composition. Without this the reel draws in SF
    // on macOS and Roboto on Android, and the two exports agree on every shape
    // and disagree on every glyph.
    typography: const MotionTypography(fontFamily: 'Roboto'),
    child: child,
  ),
  builder: (BuildContext context) => Storyboard(
    scenes: scenes,
    // A music bed under the whole thing, plus one sting per scene change.
    // Nine audio clips is well past anything tested elsewhere.
    bed: const Audio(src: 'assets/music.mp3', volume: 0.35, loop: true),
  ),
);
