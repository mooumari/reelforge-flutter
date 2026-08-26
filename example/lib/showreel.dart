import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fluttermotion/fluttermotion.dart';

import 'compositions.dart';

/// A showreel: one scene per capability, cut on a single continuous
/// background so the joins read as a video rather than as five renders.
///
/// Everything here is a function of the frame number. Nothing samples the
/// wall clock -- including the widgets in [_AppWidgetsScene], which animate on
/// their own `Ticker` and are driven to composition time by the renderer.

/// Hoisted: a provider built inside build() would be a new object every frame
/// and would never match what the preloader decoded.
const AssetImage _badge = AssetImage('assets/badge.png');

// --------------------------------------------------------------- palette
const Color _bg0 = Color(0xFF05060B);
const Color _bg1 = Color(0xFF0C1122);
const Color _blue = Color(0xFF54C5F8);
const Color _indigo = Color(0xFF4C7DFF);
const Color _mint = Color(0xFF7DE2A8);
const Color _amber = Color(0xFFFFB86B);
const Color _text = Color(0xFFFFFFFF);
const Color _muted = Color(0xFF8B93AD);
const Color _panel = Color(0xFF111729);
const Color _hairline = Color(0x1AFFFFFF);

// ------------------------------------------------------------- timeline
// Scene starts and durations, in frames at 60fps.
const int _s1 = 0, _d1 = 180; // title                     3.0s
const int _s2 = 180, _d2 = 240; // a function of the frame 4.0s
const int _s3 = 420, _d3 = 240; // widgets from your app   4.0s
const int _s4 = 660, _d4 = 120; // video in the tree       2.0s  (clip is 120f)
const int _s5 = 780, _d5 = 240; // outro                   4.0s
const int _total = _s5 + _d5; //                          17.0s

/// The ambient state a lifted app widget expects. Without this the cards in
/// [_AppWidgetsScene] would render in stock Material purple and nothing would
/// say a word.
final ThemeData _appTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    primary: _indigo,
    secondary: _mint,
    surface: _panel,
  ),
);

final Composition showreel = Composition(
  id: 'Showreel',
  width: 1920,
  height: 1080,
  fps: 60,
  durationInFrames: _total,
  wrapper: (BuildContext context, Widget child) => Theme(
    data: _appTheme,
    child: DefaultTextStyle(
      style: const TextStyle(color: _text, fontSize: 24, height: 1.3),
      child: child,
    ),
  ),
  builder: (BuildContext context) => typeset(const _Showreel()),
);

class _Showreel extends StatelessWidget {
  const _Showreel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Draws nothing. The declaration pass collects it and ffmpeg mixes it;
        // loop covers 17s of timeline from a 5s file.
        const Audio(src: 'assets/music.mp3', volume: 5.0, loop: true),
        for (final int at in <int>[_s2, _s3, _s4, _s5])
          Sequence(
            from: at,
            durationInFrames: 60,
            child: const Audio(src: 'assets/chime.mp3', volume: 2.0),
          ),

        // One continuous backdrop under every cut.
        const _Backdrop(),

        Sequence(
          from: _s1,
          durationInFrames: _d1,
          layout: SequenceLayout.fill,
          child: const _Scene(child: _TitleScene()),
        ),
        Sequence(
          from: _s2,
          durationInFrames: _d2,
          layout: SequenceLayout.fill,
          child: const _Scene(child: _FunctionScene()),
        ),
        Sequence(
          from: _s3,
          durationInFrames: _d3,
          layout: SequenceLayout.fill,
          child: const _Scene(child: _AppWidgetsScene()),
        ),
        Sequence(
          from: _s4,
          durationInFrames: _d4,
          layout: SequenceLayout.fill,
          child: const _Scene(child: _VideoScene()),
        ),
        Sequence(
          from: _s5,
          durationInFrames: _d5,
          layout: SequenceLayout.fill,
          child: const _Scene(child: _OutroScene()),
        ),

        const _ProgressBar(),
      ],
    );
  }
}

// ----------------------------------------------------------------- chrome

/// Fades and lifts its child at both ends of the enclosing [Sequence], so the
/// cuts land softly against the shared backdrop.
class _Scene extends StatelessWidget {
  const _Scene({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int f = Video.frame(context);
    final int d = Video.durationInFrames(context);
    final double o = interpolate(
      f,
      <num>[0, 16, d - 16, d - 1],
      <num>[0, 1, 1, 0],
      easing: Curves.easeInOut,
    );
    final double dy = interpolate(f, <num>[0, 24], <num>[26, 0],
        easing: Curves.easeOutCubic);

    return Opacity(
      opacity: o,
      child: Transform.translate(offset: Offset(0, dy), child: child),
    );
  }
}

/// A hairline scrubber across the bottom: the composition describing itself.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final double p = Video.progress(context);
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        height: 4,
        width: 1920 * p,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: <Color>[_indigo, _blue, _mint]),
        ),
      ),
    );
  }
}

/// Gradient wash, two drifting glows and a slow grid -- all derived from the
/// frame, so it is identical on every render.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double t = Video.time(context);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.lerp(_bg1, const Color(0xFF141033),
                    0.5 + 0.5 * math.sin(t * 0.4))!,
                _bg0,
              ],
            ),
          ),
        ),
        CustomPaint(painter: _BackdropPainter(frame: frame)),
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.frame});

  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = frame / 60.0;

    // Two soft glows drifting on independent Lissajous paths.
    void glow(Color color, double cx, double cy, double r) {
      final Paint p = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          r,
          <Color>[color.withValues(alpha: 0.30), color.withValues(alpha: 0.0)],
        );
      canvas.drawCircle(Offset(cx, cy), r, p);
    }

    glow(_indigo, size.width * (0.24 + 0.06 * math.sin(t * 0.5)),
        size.height * (0.28 + 0.07 * math.cos(t * 0.37)), 620);
    glow(_blue, size.width * (0.80 + 0.05 * math.cos(t * 0.43)),
        size.height * (0.72 + 0.06 * math.sin(t * 0.6)), 560);

    // A grid that drifts one cell per 4s, to give the wash some structure.
    final Paint line = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1;
    const double cell = 80;
    final double off = (t * 20) % cell;
    for (double x = -off; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = -off; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    // Vignette, so the centre reads brighter than the edges.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height / 2),
          size.width * 0.72,
          <Color>[const Color(0x00000000), const Color(0x99000000)],
        ),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.frame != frame;
}

/// Small caps label above a scene heading.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {this.color = _blue});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(width: 30, height: 3, color: color),
          const SizedBox(width: 14),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.2,
            ),
          ),
        ],
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _text,
          fontSize: 62,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
          height: 1.1,
        ),
      );
}

/// A line of source, styled like source.
class _CodePill extends StatelessWidget {
  const _CodePill(this.code, {this.accent = _mint});

  final String code;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xCC080B15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Text(
          code,
          style: TextStyle(
            color: accent,
            fontSize: 26,
            fontFamily: 'Menlo',
            height: 1.4,
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _panel.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _hairline),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.45),
              blurRadius: 44,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: child,
      );
}

// --------------------------------------------------------------- scene 1

class _TitleScene extends StatelessWidget {
  const _TitleScene();

  @override
  Widget build(BuildContext context) {
    final int f = Video.frame(context);
    final double pop = spring(f, stiffness: 92, damping: 15);
    final double underline =
        interpolate(f, <num>[18, 54], <num>[0, 560], easing: Curves.easeOutCubic);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Opacity(
            opacity: interpolate(f, <num>[0, 18], <num>[0, 1]),
            child: Transform.scale(
              scale: 0.88 + 0.12 * pop,
              child: const Text(
                'FlutterMotion',
                style: TextStyle(
                  color: _text,
                  fontSize: 142,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Container(
            width: underline,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                colors: <Color>[_indigo, _blue, _mint],
              ),
            ),
          ),
          const SizedBox(height: 34),
          Opacity(
            opacity: interpolate(f, <num>[34, 60], <num>[0, 1]),
            child: Transform.translate(
              offset: Offset(
                  0, interpolate(f, <num>[34, 60], <num>[18, 0],
                      easing: Curves.easeOutCubic)),
              child: const Text(
                'Videos built from Flutter widgets',
                style: TextStyle(color: _muted, fontSize: 38),
              ),
            ),
          ),
          const SizedBox(height: 46),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < 3; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 16),
                Opacity(
                  opacity: interpolate(f, <num>[60 + i * 10, 84 + i * 10],
                      <num>[0, 1]),
                  child: Transform.scale(
                    scale: 0.9 +
                        0.1 * spring(f - 60 - i * 10, stiffness: 140, damping: 13),
                    child: _Chip(
                      <String>['deterministic', 'hot reload', 'MP4'][i],
                      <Color>[_blue, _mint, _amber][i],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 24, fontWeight: FontWeight.w600),
        ),
      );
}

// --------------------------------------------------------------- scene 2

/// Plots the very functions that are animating the scene, with a playhead on
/// the current frame. The curve is the value; the dot is now.
class _FunctionScene extends StatelessWidget {
  const _FunctionScene();

  @override
  Widget build(BuildContext context) {
    final int f = Video.frame(context);
    final int d = Video.durationInFrames(context);
    final double springValue = spring(f, stiffness: 90, damping: 14);

    return Padding(
      padding: const EdgeInsets.fromLTRB(120, 96, 120, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Eyebrow('the model'),
          const SizedBox(height: 18),
          const _Heading('Every value is a function of the frame'),
          const SizedBox(height: 40),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 360,
                  child: _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text('frame',
                            style: TextStyle(
                                color: _muted,
                                fontSize: 24,
                                letterSpacing: 2)),
                        const SizedBox(height: 6),
                        Text(
                          '$f',
                          style: const TextStyle(
                            color: _text,
                            fontSize: 108,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Menlo',
                          ),
                        ),
                        const SizedBox(height: 22),
                        _Readout('spring()', springValue, _mint),
                        const SizedBox(height: 12),
                        _Readout(
                          'interpolate()',
                          interpolate(f, <num>[0, d ~/ 2, d - 1], <num>[0, 1, 0],
                              easing: Curves.easeInOut),
                          _amber,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: _Panel(
                    child: CustomPaint(
                      painter: _CurvePainter(frame: f, duration: d),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          Row(
            children: <Widget>[
              const _CodePill('spring(frame, stiffness: 90, damping: 14)'),
              const SizedBox(width: 20),
              _CodePill(
                'interpolate(frame, [0, ${d ~/ 2}, ${d - 1}], [0, 1, 0])',
                accent: _amber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: _muted, fontSize: 22, fontFamily: 'Menlo')),
          ),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
                color: color, fontSize: 26, fontFamily: 'Menlo',
                fontWeight: FontWeight.w600),
          ),
        ],
      );
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.frame, required this.duration});

  final int frame;
  final int duration;

  // The plot's vertical window, in value units. spring() overshoots 1.
  static const double _lo = -0.12;
  static const double _hi = 1.28;

  double _y(Size size, double v) =>
      size.height - (v - _lo) / (_hi - _lo) * size.height;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    for (final double v in <double>[0, 0.5, 1]) {
      final double y = _y(size, v);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    void curve(Color color, double Function(int) fn) {
      final Path path = Path();
      for (int i = 0; i < duration; i++) {
        final double x = i / (duration - 1) * size.width;
        final double y = _y(size, fn(i));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    double springAt(int i) => spring(i, stiffness: 90, damping: 14);
    double lerpAt(int i) => interpolate(
        i, <num>[0, duration ~/ 2, duration - 1], <num>[0, 1, 0],
        easing: Curves.easeInOut);

    curve(_amber.withValues(alpha: 0.85), lerpAt);
    curve(_mint, springAt);

    // Playhead.
    final double px = frame / (duration - 1) * size.width;
    canvas.drawLine(
      Offset(px, 0),
      Offset(px, size.height),
      Paint()
        ..color = _blue.withValues(alpha: 0.75)
        ..strokeWidth = 2,
    );

    for (final (Color c, double v) in <(Color, double)>[
      (_amber, lerpAt(frame)),
      (_mint, springAt(frame)),
    ]) {
      final Offset p = Offset(px, _y(size, v));
      canvas.drawCircle(p, 13, Paint()..color = c.withValues(alpha: 0.22));
      canvas.drawCircle(p, 7, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.frame != frame || old.duration != duration;
}

// --------------------------------------------------------------- scene 3

class _AppWidgetsScene extends StatelessWidget {
  const _AppWidgetsScene();

  @override
  Widget build(BuildContext context) {
    final int f = Video.frame(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(120, 96, 120, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Eyebrow('reuse', color: _mint),
          const SizedBox(height: 18),
          const _Heading('Widgets from your app'),
          const SizedBox(height: 12),
          const Text(
            'Theme, Provider, Localizations -- supplied by the composition wrapper.',
            style: TextStyle(color: _muted, fontSize: 28),
          ),
          const SizedBox(height: 36),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 22,
                    crossAxisSpacing: 22,
                    childAspectRatio: 1.55,
                    children: <Widget>[
                      for (int i = 0; i < 6; i++)
                        Transform.scale(
                          scale: 0.86 +
                              0.14 *
                                  spring(f - 10 - i * 5,
                                      stiffness: 130, damping: 15),
                          child: Opacity(
                            opacity: interpolate(
                                f, <num>[10 + i * 5, 34 + i * 5], <num>[0, 1]),
                            child: _ProductCard(index: i, frame: f),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                SizedBox(width: 470, child: _TickerPanel(frame: f)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Written the way an app widget is written: it reads `Theme.of` and knows
/// nothing about frames.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.index, required this.frame});

  final int index;
  final int frame;

  static const List<String> _names = <String>[
    'Aurora Lamp', 'Field Notebook', 'Trail Bottle',
    'Desk Mat', 'Cable Loop', 'Ridge Mug',
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x66000000),
            blurRadius: 26,
            offset: Offset(0, 10 + math.sin(frame / 26 + index) * 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    color: scheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _names[index],
                  style: const TextStyle(
                      color: _text, fontSize: 24, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '\$${(24.0 + index * 7.5).toStringAsFixed(2)}',
            style: TextStyle(
                color: scheme.secondary,
                fontSize: 30,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (0.5 + 0.5 * math.sin((frame + index * 20) / 30.0))
                  .clamp(0.05, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0x22FFFFFF),
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything in here animates on its own `Ticker` -- no widget below reads
/// the frame. The renderer drives the animation clock to composition time, so
/// these are deterministic anyway.
class _TickerPanel extends StatelessWidget {
  const _TickerPanel({required this.frame});

  final int frame;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _Eyebrow('own ticker', color: _amber),
            const SizedBox(height: 20),
            const Text(
              'These animate on their own clock.',
              style: TextStyle(
                  color: _text, fontSize: 27, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'AnimationController, AnimatedOpacity, '
              'CircularProgressIndicator -- driven to composition time.',
              style: TextStyle(color: _muted, fontSize: 21, height: 1.35),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                const SizedBox(
                  width: 62,
                  height: 62,
                  child: CircularProgressIndicator(strokeWidth: 6),
                ),
                const SizedBox(width: 26),
                const _PulseDot(),
                const SizedBox(width: 26),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      _FadeInOnMount(
                        child: Text('fade-in on mount',
                            style: TextStyle(color: _mint, fontSize: 22)),
                      ),
                      SizedBox(height: 8),
                      _GrowOnMount(),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            const _CodePill('driveAnimationClock: true', accent: _amber),
          ],
        ),
      );
}

/// A repeating controller, exactly as an app would write it.
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? child) {
          final double v = _c.value;
          return SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 20 + 42 * v,
                  height: 20 + 42 * v,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _blue.withValues(alpha: 0.35 * (1 - v)),
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration:
                      const BoxDecoration(shape: BoxShape.circle, color: _blue),
                ),
              ],
            ),
          );
        },
      );
}

/// The single most common fade-in idiom in Flutter: flip a field in a
/// post-frame callback and let [AnimatedOpacity] do the rest. In a detached
/// tree with no clock, this exports as nothing at all, on every frame.
class _FadeInOnMount extends StatefulWidget {
  const _FadeInOnMount({required this.child});

  final Widget child;

  @override
  State<_FadeInOnMount> createState() => _FadeInOnMountState();
}

class _FadeInOnMountState extends State<_FadeInOnMount> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        child: widget.child,
      );
}

class _GrowOnMount extends StatefulWidget {
  const _GrowOnMount();

  @override
  State<_GrowOnMount> createState() => _GrowOnMountState();
}

class _GrowOnMountState extends State<_GrowOnMount> {
  double _w = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _w = 210);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        width: _w,
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          gradient: const LinearGradient(colors: <Color>[_indigo, _mint]),
        ),
      );
}

// --------------------------------------------------------------- scene 4

class _VideoScene extends StatelessWidget {
  const _VideoScene();

  @override
  Widget build(BuildContext context) {
    final int f = Video.frame(context);
    final double enter = spring(f, stiffness: 88, damping: 16);

    return Padding(
      padding: const EdgeInsets.fromLTRB(120, 96, 120, 120),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const _Eyebrow('compositing', color: _amber),
                const SizedBox(height: 18),
                const _Heading('Video, inside\nthe widget tree'),
                const SizedBox(height: 22),
                const Text(
                  'Decoded with ffmpeg and painted through RawImage -- so it '
                  'can be rounded, tilted, shadowed and drawn under Flutter '
                  'text, and it still lands in the export. The counter is '
                  'burned into the source: it advances exactly one frame per '
                  'composition frame.',
                  style: TextStyle(color: _muted, fontSize: 26, height: 1.5),
                ),
                const SizedBox(height: 28),
                const _CodePill("VideoClip(src: 'assets/demo_clip.mp4')"),
              ],
            ),
          ),
          const SizedBox(width: 60),
          Expanded(
            child: Center(
              child: Transform.scale(
                scale: 0.82 + 0.18 * enter,
                child: Transform.rotate(
                  angle: interpolate(f, <num>[0, _d4], <num>[-0.05, 0.03],
                      easing: Curves.easeInOut),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color:
                                const Color(0xFF000000).withValues(alpha: 0.65),
                            blurRadius: 70,
                            offset: const Offset(0, 34),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            const VideoClip(
                              src: 'assets/demo_clip.mp4',
                              decodeWidth: 1024,
                              decodeHeight: 576,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(30, 60, 30, 26),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      const Color(0x00000000),
                                      const Color(0xFF000000)
                                          .withValues(alpha: 0.85),
                                    ],
                                  ),
                                ),
                                child: Opacity(
                                  opacity: interpolate(
                                      f, <num>[18, 44], <num>[0, 1]),
                                  child: const Text(
                                    'not a platform view',
                                    style: TextStyle(
                                      color: _text,
                                      fontSize: 32,
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
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- scene 5

class _OutroScene extends StatelessWidget {
  const _OutroScene();

  @override
  Widget build(BuildContext context) {
    final int f = Video.frame(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Transform.rotate(
            angle: math.sin(f / 34) * 0.16,
            child: Transform.scale(
              scale: 0.8 + 0.2 * spring(f, stiffness: 110, damping: 14),
              child: ClipOval(
                child: MotionImage(image: _badge, width: 150, height: 150),
              ),
            ),
          ),
          const SizedBox(height: 34),
          Opacity(
            opacity: interpolate(f, <num>[12, 36], <num>[0, 1]),
            child: const Text(
              'Preview it. Then render it.',
              style: TextStyle(
                color: _text,
                fontSize: 76,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Opacity(
            opacity: interpolate(f, <num>[30, 54], <num>[0, 1]),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < 3; i++) ...<Widget>[
                  if (i > 0) ...<Widget>[
                    const SizedBox(width: 18),
                    Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: _muted, shape: BoxShape.circle)),
                    const SizedBox(width: 18),
                  ],
                  Text(
                    <String>['$_total frames', '1920x1080', '60 fps'][i],
                    style: const TextStyle(color: _muted, fontSize: 32),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 46),
          Opacity(
            opacity: interpolate(f, <num>[50, 76], <num>[0, 1]),
            child: Transform.scale(
              scale: 0.94 + 0.06 * spring(f - 50, stiffness: 130, damping: 14),
              child: const _CodePill(
                'fluttermotion render --composition Showreel --out showreel.mp4',
                accent: _blue,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Opacity(
            opacity: interpolate(f, <num>[70, 96], <num>[0, 1]),
            child: const Text(
              'Same widget tree in the preview, the CLI, and on device.',
              style: TextStyle(color: _muted, fontSize: 26),
            ),
          ),
        ],
      ),
    );
  }
}
