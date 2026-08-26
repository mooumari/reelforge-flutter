import 'package:fluttermotion_cli/src/audio_mixer.dart';
import 'package:test/test.dart';

AudioClip clip({
  String src = 'a.mp3',
  int startFrame = 0,
  int endFrame = 59,
  double volume = 1.0,
  int trimStartInFrames = 0,
  bool loop = false,
}) =>
    AudioClip(
      src: src,
      startFrame: startFrame,
      endFrame: endFrame,
      volume: volume,
      trimStartInFrames: trimStartInFrames,
      loop: loop,
    );

/// The value ffmpeg receives for a named flag.
String? argAfter(List<String> args, String flag) {
  final int i = args.indexOf(flag);
  return i == -1 || i + 1 >= args.length ? null : args[i + 1];
}

void main() {
  group('AudioClip', () {
    test('duration is inclusive of the end frame', () {
      expect(clip(startFrame: 40, endFrame: 64).durationInFrames, 25);
      expect(clip(startFrame: 7, endFrame: 7).durationInFrames, 1);
    });

    test('round-trips the manifest JSON the host emits', () {
      final AudioClip parsed = AudioClip.fromJson(<String, Object?>{
        'src': 'assets/chime.mp3',
        'startFrame': 40,
        'endFrame': 64,
        'volume': 1,
        'trimStartInFrames': 0,
        'loop': false,
      });
      expect(parsed.src, 'assets/chime.mp3');
      // JSON gives an int for a whole-number volume; it must survive as double.
      expect(parsed.volume, 1.0);
    });

    test('resolves relative paths against the project, absolute untouched', () {
      expect(clip(src: 'assets/x.mp3').resolvedAgainst('/p').src,
          '/p/assets/x.mp3');
      expect(clip(src: '/abs/x.mp3').resolvedAgainst('/p').src, '/abs/x.mp3');
    });
  });

  group('buildAudioMixPlan', () {
    test('places a clip at its start frame, in milliseconds', () {
      // Frame 40 at 60fps is 666.67ms.
      final AudioMixPlan plan = buildAudioMixPlan(
        clips: <AudioClip>[clip(startFrame: 40, endFrame: 64)],
        videoPath: 'v.mp4',
        outPath: 'o.mp4',
        fps: 60,
        totalFrames: 300,
      );
      expect(plan.filterGraph, contains('adelay=667:all=1'));
    });

    test('trims and limits to the clip window', () {
      final AudioMixPlan plan = buildAudioMixPlan(
        clips: <AudioClip>[
          clip(startFrame: 0, endFrame: 119, trimStartInFrames: 30),
        ],
        videoPath: 'v.mp4',
        outPath: 'o.mp4',
        fps: 60,
        totalFrames: 120,
      );
      expect(plan.filterGraph,
          contains('atrim=start=0.500000:duration=2.000000'));
      // Without rebasing, adelay would stack on top of the trim offset.
      expect(plan.filterGraph, contains('asetpts=PTS-STARTPTS'));
    });

    test('omits the volume filter at unity and includes it otherwise', () {
      expect(
        buildAudioMixPlan(
          clips: <AudioClip>[clip()],
          videoPath: 'v.mp4', outPath: 'o.mp4', fps: 60, totalFrames: 60,
        ).filterGraph,
        isNot(contains('volume=')),
      );
      expect(
        buildAudioMixPlan(
          clips: <AudioClip>[clip(volume: 0.4)],
          videoPath: 'v.mp4', outPath: 'o.mp4', fps: 60, totalFrames: 60,
        ).filterGraph,
        contains('volume=0.4'),
      );
    });

    test('loops at the input, and only for clips that ask for it', () {
      final AudioMixPlan plan = buildAudioMixPlan(
        clips: <AudioClip>[
          clip(src: 'loop.mp3', loop: true),
          clip(src: 'once.mp3'),
        ],
        videoPath: 'v.mp4', outPath: 'o.mp4', fps: 60, totalFrames: 60,
      );
      final int looped = plan.args.indexOf('loop.mp3');
      expect(plan.args[looped - 3], '-stream_loop');
      final int once = plan.args.indexOf('once.mp3');
      expect(plan.args[once - 1], '-i');
      expect(plan.args[once - 2], isNot('-1'));
    });

    test('mixes without normalising, so a sound effect cannot duck the bed',
        () {
      final AudioMixPlan plan = buildAudioMixPlan(
        clips: <AudioClip>[clip(src: 'a.mp3'), clip(src: 'b.mp3')],
        videoPath: 'v.mp4', outPath: 'o.mp4', fps: 60, totalFrames: 60,
      );
      expect(plan.filterGraph, contains('amix=inputs=2:normalize=0'));
    });

    test('numbers audio streams from 1, because the video is input 0', () {
      final AudioMixPlan plan = buildAudioMixPlan(
        clips: <AudioClip>[clip(src: 'a.mp3'), clip(src: 'b.mp3')],
        videoPath: 'v.mp4', outPath: 'o.mp4', fps: 60, totalFrames: 60,
      );
      expect(plan.args.indexOf('v.mp4'), lessThan(plan.args.indexOf('a.mp3')));
      expect(plan.filterGraph, contains('[1:a]'));
      expect(plan.filterGraph, contains('[2:a]'));
      expect(plan.filterGraph, isNot(contains('[0:a]')));
    });

    test('copies the video stream and clamps output to the video length', () {
      final AudioMixPlan plan = buildAudioMixPlan(
        clips: <AudioClip>[clip()],
        videoPath: 'v.mp4', outPath: 'o.mp4', fps: 60, totalFrames: 300,
      );
      expect(argAfter(plan.args, '-c:v'), 'copy');
      expect(argAfter(plan.args, '-t'), '5.000000');
      expect(plan.args.last, 'o.mp4');
    });

    test('resolveSrc rewrites the paths handed to ffmpeg', () {
      final AudioMixPlan plan = buildAudioMixPlan(
        clips: <AudioClip>[clip(src: 'a.mp3')],
        videoPath: 'v.mp4', outPath: 'o.mp4', fps: 60, totalFrames: 60,
        resolveSrc: (String s) => '/root/$s',
      );
      expect(plan.args, contains('/root/a.mp3'));
    });
  });
}
