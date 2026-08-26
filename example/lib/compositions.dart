import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';

/// Hoisted deliberately. A provider constructed inside build() would be a new
/// object on every frame and would never match what the preloader decoded.
const AssetImage badge = AssetImage('assets/badge.png');

final Composition helloFlutter = Composition(
  id: 'HelloFlutter',
  width: 1920,
  height: 1080,
  fps: 60,
  durationInFrames: 120,
  builder: (BuildContext context) => const _HelloFlutter(),
);

final Composition weeklyDeals = Composition(
  id: 'WeeklyDeals',
  width: 1080,
  height: 1920,
  fps: 60,
  durationInFrames: 300,
  builder: (BuildContext context) => const _WeeklyDeals(),
);

/// A video clip composited like any other widget: rounded, shadowed, tilted,
/// and with Flutter drawing on top of it. None of that is possible with a
/// platform view, which renders in its own layer and exports as a black hole.
final Composition videoShowcase = Composition(
  id: 'VideoShowcase',
  width: 1280,
  height: 720,
  fps: 60,
  durationInFrames: 120,
  builder: (BuildContext context) => const _VideoShowcase(),
);

/// Exists to verify frame accuracy, not to look good.
///
/// `assets/probe.mp4` encodes each frame's own index as its grey value
/// (frame i is rgb(2i, 2i, 2i)), so reading one pixel out of an exported frame
/// says exactly which source frame landed there. That is how the shard
/// boundary test proves the mapping is independent of where decoding started.
/// A grey ramp, painted rather than decoded, to measure the encoder alone.
///
/// Frame *f* is a flat `rgb(2f, 2f, 2f)`. Reading the grey back out of the
/// exported file measures every step from a widget to an H.264 frame with no
/// video decode anywhere in it, which is the only way to say what the encoder
/// itself costs.
///
/// It exists because that cost is real and worth knowing rather than
/// assuming: on Android a flat frame two levels off the last one is a residual
/// small enough that a variable-rate encoder will spend nothing on it and hand
/// the previous frame's grey back instead. The video probes cannot report this
/// -- they carry their frame index in black and white precisely so that the
/// encoder cannot smudge it -- so the number comes from here.
final Composition encoderProbe = Composition(
  id: 'EncoderProbe',
  width: 320,
  height: 240,
  fps: 60,
  durationInFrames: 120,
  builder: (BuildContext context) => const _GreyRamp(),
);

class _GreyRamp extends StatelessWidget {
  const _GreyRamp();

  @override
  Widget build(BuildContext context) {
    final int grey = 2 * Video.frame(context);
    return ColoredBox(color: Color.fromARGB(255, grey, grey, grey));
  }
}

final Composition videoProbe = Composition(
  id: 'VideoProbe',
  width: 320,
  height: 240,
  fps: 60,
  durationInFrames: 200,
  builder: (BuildContext context) => const _VideoProbe(),
);

/// The same probe, at half the source's frame rate.
///
/// `probe.mp4` runs at 60fps, so a 60fps composition asks for one source frame
/// per composition frame and a decoder that simply took the next one was
/// right by accident. This composition asks for every second source frame
/// instead, which is the case that told the ffmpeg decoder and the in-app
/// decoder apart: composition frame *k* of the window must show source frame
/// *2k*, and therefore grey `4k`.
final Composition videoProbeHalf = Composition(
  id: 'VideoProbeHalf',
  width: 320,
  height: 240,
  fps: 30,
  durationInFrames: 100,
  builder: (BuildContext context) => const _VideoProbeHalf(),
);

class _VideoProbeHalf extends StatelessWidget {
  const _VideoProbeHalf();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF000000),
        child: Sequence(
          from: 20,
          // 60 composition frames at 30fps is the whole 2.0s source.
          durationInFrames: 60,
          child: VideoClip(src: 'assets/probe.mp4', fit: BoxFit.fill),
        ),
      );
}

class _VideoProbe extends StatelessWidget {
  const _VideoProbe();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF000000),
        child: Sequence(
          from: 40,
          durationInFrames: 120,
          child: VideoClip(src: 'assets/probe.mp4', fit: BoxFit.fill),
        ),
      );
}

/// Exists to verify where a sound lands, not to be listened to.
///
/// One 20ms click, mounted on a known frame, in a format that carries no
/// encoder delay of its own -- an MP3 declares a priming offset that some
/// decoders strip and others keep, which would put the thing being measured
/// inside the measurement.
final Composition audioProbe = Composition(
  id: 'AudioProbe',
  width: 320,
  height: 240,
  fps: 60,
  durationInFrames: 120,
  builder: (BuildContext context) => const _AudioProbe(),
);

class _AudioProbe extends StatelessWidget {
  const _AudioProbe();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF000000),
        child: Sequence(
          from: 60,
          durationInFrames: 30,
          child: Audio(src: 'assets/click.wav'),
        ),
      );
}

class _VideoShowcase extends StatelessWidget {
  const _VideoShowcase();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double enter = spring(frame, stiffness: 90, damping: 16);

    return ColoredBox(
      color: const Color(0xFF07070C),
      child: Center(
        child: Transform.scale(
          scale: 0.6 + 0.4 * enter,
          child: Transform.rotate(
            angle: interpolate(frame, <num>[0, 120], <num>[-0.06, 0.06],
                easing: Curves.easeInOut),
            child: Container(
              width: 900,
              height: 506,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.6),
                    blurRadius: 60,
                    offset: const Offset(0, 30),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // Decoding at 640 wide rather than the source's native size
                    // is the single biggest lever on video render cost.
                    const VideoClip(
                      src: 'assets/clip.mp4',
                      decodeWidth: 960,
                      decodeHeight: 540,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              const Color(0x00000000),
                              const Color(0xFF000000).withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                        child: Opacity(
                          opacity: interpolate(frame, <num>[20, 45], <num>[0, 1])
                              .toDouble(),
                          child: const Text(
                            'Video, inside the widget tree',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelloFlutter extends StatelessWidget {
  const _HelloFlutter();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    return ColoredBox(
      color: const Color(0xFF0B0B10),
      child: Center(
        child: Transform.scale(
          scale: spring(frame, stiffness: 120, damping: 14),
          child: Opacity(
            opacity: interpolate(frame, <int>[0, 20], <double>[0, 1]),
            child: const Text(
              'Hello Flutter',
              style: TextStyle(
                fontSize: 120,
                color: Color(0xFFFFFFFF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A deliberately expensive composition: gradients, 40 shadowed cards, a
/// backdrop blur, and per-frame CustomPaint. Matches the benchmark harness so
/// CLI timings are comparable to the raw spike numbers.
class _WeeklyDeals extends StatelessWidget {
  const _WeeklyDeals();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = Video.time(context);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Declares itself to the pass; never played by Flutter.
        const Audio(src: 'assets/music.mp3', volume: 0.4),
        const Sequence(
          from: 40,
          durationInFrames: 25,
          child: Audio(src: 'assets/chime.mp3'),
        ),
        const Sequence(
          from: 180,
          durationInFrames: 25,
          child: Audio(src: 'assets/chime.mp3'),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.lerp(
                    const Color(0xFF1B1035), const Color(0xFF0C2A4D), t)!,
                const Color(0xFF05060A),
              ],
            ),
          ),
        ),
        for (int i = 0; i < 40; i++)
          Positioned(
            left: 40 + (i % 4) * 250.0,
            top: 120 + (i ~/ 4) * 180.0 + math.sin((frame + i * 7) / 18.0) * 14,
            child: Transform.rotate(
              angle: math.sin((frame + i * 11) / 40.0) * 0.05,
              child: _ProductCard(index: i, frame: frame, t: t),
            ),
          ),
        Positioned(
          right: 60,
          top: 60,
          child: Transform.rotate(
            angle: math.sin(frame / 30) * 0.15,
            child: ClipOval(
              child: MotionImage(
                image: badge,
                width: 160,
                height: 160,
              ),
            ),
          ),
        ),
        Sequence(
          from: 0,
          layout: SequenceLayout.fill,
          child: Builder(
            builder: (BuildContext context) {
              final int local = Video.frame(context);
              return Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    interpolate(local, <int>[0, 30], <double>[200, 0]),
                  ),
                  child: const _DealsBanner(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.index, required this.frame, required this.t});

  final int index;
  final int frame;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFF14161F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22FFFFFF)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8 + math.sin(t + index) * 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Product ${index + 1}',
            style: const TextStyle(
              fontSize: 22,
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\$${(19.99 + index * 3.5).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, color: Color(0xFF7DE2A8)),
          ),
          const Spacer(),
          SizedBox(
            height: 8,
            child: CustomPaint(
              size: const Size(190, 8),
              painter: _BarPainter(phase: frame + index * 5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DealsBanner extends StatelessWidget {
  const _DealsBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 180,
          color: const Color(0x33FFFFFF),
          alignment: Alignment.center,
          child: const Text(
            'WEEKLY DEALS',
            style: TextStyle(
              fontSize: 56,
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.phase});

  final int phase;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = const Color(0xFF4C7DFF);
    const int bars = 14;
    final double w = size.width / (bars * 1.6);
    for (int i = 0; i < bars; i++) {
      final double h =
          (0.5 + 0.5 * math.sin((phase + i * 9) / 12.0)) * size.height;
      canvas.drawRect(Rect.fromLTWH(i * w * 1.6, size.height - h, w, h), paint);
    }
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) => oldDelegate.phase != phase;
}

/// A widget written the way an app widget is written: it owns an
/// [AnimationController] on its own ticker and knows nothing about frames.
/// Its grey value is the controller's value, so reading one pixel out of an
/// exported frame says exactly where the animation was.
class TickerProbe extends StatefulWidget {
  const TickerProbe({super.key});

  @override
  State<TickerProbe> createState() => _TickerProbeState();
}

class _TickerProbeState extends State<TickerProbe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final int grey = (_controller.value * 255).round().clamp(0, 255);
          return ColoredBox(color: Color.fromARGB(255, grey, grey, grey));
        },
      );
}

/// 1000ms repeat at 60fps: frame f should read grey = round((f % 60) / 60 * 255).
final Composition tickerProbe = Composition(
  id: 'TickerProbe',
  width: 320,
  height: 240,
  fps: 60,
  durationInFrames: 180,
  builder: (BuildContext context) => const TickerProbe(),
);
