import 'package:flutter/widgets.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_kit/reelforge_kit.dart';

import 'compositions.dart' show typeset;
import 'rain_look.dart';
import 'rain_open_clues.dart';
import 'rain_open_shots.dart';
import 'rain_open_timing.dart';
import 'rain_timing.dart' show sfx;

/// The opening of "What did ancient humans do when it rained all week?",
/// scored in example/voices/rain_week_v2.md: one idea (stay warm, stay fed,
/// stay together), a picture for each line, and the silences between them
/// written down. [rainOpen] is the explainer look; [rainOpenDoodle] is the
/// same script, timings and cast drawn as a doodle.
Widget _with(Widget shot, List<Widget> sounds) => Stack(fit: StackFit.expand, children: <Widget>[shot, ...sounds]);

List<Scene> _scenes(Look look) {
  final (double first, double beat) = stoneBeat();
  final List<Widget> shots = <Widget>[
    _with(MapShot(look), <Widget>[sfx('pop', said(0, Say.ago, 0) + 0.04, volume: 0.4, seconds: 0.3)]),
    ValleyShot(look),
    _with(StoneShot(look), <Widget>[for (int i = 0; i < 7; i++) sfx('tick', first + beat * i + 0.03, volume: 0.45, seconds: 0.2)]),
    _with(CampShot(look), <Widget>[
      sfx('tick', said(3, Say.app, 0) + 0.02, volume: 0.5, seconds: 0.2),
      sfx('tick', said(3, Say.store, 0) + 0.02, volume: 0.5, seconds: 0.2),
      sfx('crackle', 0.0, volume: 0.06, seconds: 4.2, loop: true, ext: 'm4a'),
    ]),
    BandShot(look),
    FacesShot(look),
    _with(JobsShot(look), <Widget>[
      sfx('crackle', lineAt(6, Say.warm) - 0.3, volume: 0.2, seconds: 8, loop: true, ext: 'm4a'),
      sfx('pop', lineAt(6, Say.fed) - 0.2, volume: 0.4, seconds: 0.3),
      sfx('pop', lineAt(6, Say.together) - 0.2, volume: 0.4, seconds: 0.3),
    ]),
    _with(TitleShot(look), <Widget>[sfx('swell', 0.0, volume: 0.4, seconds: 3)]),
    DuskShot(look),
    AshShot(look),
    _with(ToolsShot(look), <Widget>[for (int i = 0; i < 4; i++) sfx('tick', i * 0.1 + 0.15, volume: 0.4, seconds: 0.2)]),
    _with(BonesShot(look), <Widget>[for (int i = 0; i < 3; i++) sfx('tick', i * 0.18 + 0.1, volume: 0.35, seconds: 0.2)]),
    PaintingShot(look),
    _with(TodayShot(look), <Widget>[sfx('pop', said(13, Say.today, 4) + 0.05, volume: 0.4, seconds: 0.3)]),
  ];
  return <Scene>[
    for (int i = 0; i < shots.length; i++)
      Scene(
        frames: openLengths[i],
        child: shots[i],
        transition: i == 0 ? null : SceneTransition.fade(frames: i == 7 ? 12 : 6),
      ),
  ];
}

/// Rain, a quiet bed under it, and the rain building as the lines say it:
/// first drops, a little more on "rain", twice as much on "a whole week".
/// (Audio plays at one volume, so the build is three layers entering.)
Widget _weather() {
  Widget layer(double at, double volume) => Sequence(
        from: (at * openFps).round(),
        durationInFrames: ((openVoice.seconds - at) * openFps).ceil(),
        child: Audio(src: 'assets/sound/rain.m4a', volume: volume, loop: true),
      );
  return Stack(children: <Widget>[
    const Audio(src: 'assets/sound/bed.m4a', volume: 0.09),
    layer(0.35, 0.07),
    layer(openVoice.starts[Say.ago] + 2.2, 0.08),
    layer(openVoice.starts[Say.week] - 0.3, 0.1),
  ]);
}

Composition _open(String id, Look look) {
  final List<Scene> scenes = _scenes(look);
  return Composition(
    id: id,
    width: 1920,
    height: 1080,
    fps: openFps,
    durationInFrames: Storyboard.totalFrames(scenes, fps: openFps),
    builder: (BuildContext context) => typeset(
      Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Storyboard(scenes: scenes),
          _weather(),
          ...openVoice.audio(fps: openFps),
        ],
      ),
    ),
  );
}

final Composition rainOpen = _open('RainOpen', Look.explainer);
final Composition rainOpenDoodle = _open('RainOpenDoodle', Look.drawn);
