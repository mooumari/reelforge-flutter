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
