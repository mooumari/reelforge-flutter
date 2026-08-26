import 'package:flutter/material.dart';
import 'package:fluttermotion/fluttermotion.dart';

import 'report_data.dart';

/// A 60-second, data-driven vertical reel.
///
/// This exists to be *hard*, not to be pretty. Everything else in this example
/// is a few seconds long and does one thing; this one runs 1800 frames through
/// eight scenes, holds two video decoders open at once, mixes nine audio
/// clips, and draws every number in it from `assets/report.json`. It is the
/// shape of a composition someone would actually ship, at the length they would
/// actually ship it, which is the only way to find the things a 200-frame probe
/// cannot.
///
/// Scene boundaries are declared once, below, and everything else is derived
/// from them -- so moving a scene moves its content, its audio sting and its
/// transition together.
const int fps = 30;

/// One entry per scene: how long it lasts, in seconds.
const List<double> _sceneSeconds = <double>[5, 9, 9, 8, 9, 8, 7, 5];

/// Frame each scene starts on, accumulated from [_sceneSeconds].
final List<int> sceneStarts = () {
  final List<int> starts = <int>[0];
  for (final double seconds in _sceneSeconds) {
    starts.add(starts.last + (seconds * fps).round());
  }
  return starts;
}();

int sceneLength(int i) => sceneStarts[i + 1] - sceneStarts[i];

final int totalFrames = sceneStarts.last;

const Color _ink = Color(0xFF0B0D11);
const Color _paper = Color(0xFFF2F4F8);
const Color _dim = Color(0xFF7C8596);
const Color _accent = Color(0xFF4ADE80);
const Color _warn = Color(0xFFF97066);

final Composition longform = Composition(
  id: 'Longform',
  width: 1080,
  height: 1920,
  fps: fps,
  durationInFrames: totalFrames,
  wrapper: (BuildContext context, Widget child) => DefaultTextStyle(
    style: const TextStyle(
      color: _paper,
      fontSize: 40,
      height: 1.2,
      fontWeight: FontWeight.w500,
    ),
    child: ColoredBox(color: _ink, child: child),
  ),
  builder: (BuildContext context) => const _Longform(),
);

class _Longform extends StatelessWidget {
  const _Longform();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // A music bed under the whole thing, plus one sting per scene change.
        // Nine audio clips is well past anything tested so far.
        const Audio(src: 'assets/music.mp3', volume: 0.35, loop: true),
        for (int i = 1; i < _sceneSeconds.length; i++)
          Sequence(
            from: sceneStarts[i],
            durationInFrames: 30,
            child: const Audio(src: 'assets/chime.mp3', volume: 0.5),
          ),

        _scene(0, const _TitleCard()),
        _scene(1, const _WeeklyBars()),
        _scene(2, const _FootageWithOverlay()),
        _scene(3, const _TeamGrid()),
        // Two clips on screen at once: two decoders open, both streaming,
        // both expected to stay on the same frame as each other.
        _scene(4, const _SplitScreen()),
        _scene(5, const _BigNumbers()),
        _scene(6, const _RevertsLine()),
        _scene(7, const _Outro()),
      ],
    );
  }

  Widget _scene(int index, Widget child) => Sequence(
        from: sceneStarts[index],
        durationInFrames: sceneLength(index),
        child: _SceneFade(length: sceneLength(index), child: child),
      );
}

/// Fades a scene in and out against its own local timeline.
///
/// Inside a [Sequence] the frame is rebased to zero, so a scene never has to
/// know where on the global timeline it sits -- which is what lets the scene
/// list above be reordered without touching anything here.
class _SceneFade extends StatelessWidget {
  const _SceneFade({required this.length, required this.child});

  final int length;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double opacity = interpolate(
      frame,
      <int>[0, 8, length - 8, length],
      <double>[0, 1, 1, 0],
    );
    return Opacity(opacity: opacity, child: child);
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double rise = spring(frame - 4, fps: fps, stiffness: 110, damping: 15);
    final double sub = interpolate(frame, <num>[20, 44], <num>[0, 1],
        easing: Curves.easeOutCubic);

    return Padding(
      padding: const EdgeInsets.all(90),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Transform.translate(
            offset: Offset(0, (1 - rise) * 60),
            child: Text(
              report.period,
              style: const TextStyle(
                color: _accent,
                fontSize: 44,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Transform.translate(
            offset: Offset(0, (1 - rise) * 100),
            child: Text(
              report.headline,
              style: const TextStyle(
                fontSize: 116,
                height: 1.02,
                fontWeight: FontWeight.w800,
                letterSpacing: -3,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Opacity(
            opacity: sub,
            child: Text(
              '${report.releases} releases · ${report.incidents} incidents',
              style: const TextStyle(color: _dim, fontSize: 40),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bar per week, staggered, with every height coming from the data.
class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final int peak = report.peakShipped;

    return Padding(
      padding: const EdgeInsets.fromLTRB(70, 150, 70, 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SceneLabel('Shipped per week'),
          const SizedBox(height: 60),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < report.weeks.length; i++)
                  Expanded(
                    child: _Bar(
                      week: report.weeks[i],
                      fraction: report.weeks[i].shipped / peak,
                      // Each bar starts three frames after the one before it.
                      grow: spring(frame - 10 - i * 3,
                          fps: fps, stiffness: 140, damping: 16),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.week, required this.fraction, required this.grow});

  final Week week;
  final double fraction;
  final double grow;

  @override
  Widget build(BuildContext context) {
    // A spring overshoots, which is what makes the bar land rather than stop.
    // Height can take that; opacity could not.
    final double scale = (grow * fraction).clamp(0.0, 1.2);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: <Widget>[
          // Expanded first, then a height read off the constraints. A
          // FractionallySizedBox here would have nothing to be a fraction of:
          // a Column hands its children unbounded height on the main axis.
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Headroom for the number, so the tallest bar still has
                // somewhere to put it.
                const double headroom = 44;
                final double height = (constraints.maxHeight - headroom) *
                    scale.clamp(0.0, 1.0);
                return Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: height,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: <Color>[Color(0xFF166534), _accent],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    // Rides on top of its own bar rather than sitting in a row
                    // of numbers at the top, where nothing says which bar a
                    // number belongs to.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: height + 8,
                      child: Text(
                        '${week.shipped}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          color: _paper
                              .withValues(alpha: grow.clamp(0.0, 1.0)),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            week.label,
            style: const TextStyle(fontSize: 22, color: _dim),
          ),
        ],
      ),
    );
  }
}

/// Full-bleed footage with the composition drawing over it.
class _FootageWithOverlay extends StatelessWidget {
  const _FootageWithOverlay();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double slide = interpolate(frame, <num>[10, 40], <num>[0, 1],
        easing: Curves.easeOutCubic);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Two seconds of footage under a nine-second scene. Looping is the
        // ordinary answer to that; without it the picture freezes for seven.
        const VideoClip(src: 'assets/clip.mp4', fit: BoxFit.cover, loop: true),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0x00000000), Color(0xCC0B0D11)],
            ),
          ),
        ),
        Positioned(
          left: 70,
          right: 70,
          bottom: 200,
          child: Transform.translate(
            offset: Offset(0, (1 - slide) * 50),
            child: Opacity(
              opacity: slide,
              child: const Text(
                'Every frame is a widget,\nincluding the ones over footage.',
                style: TextStyle(
                  fontSize: 58,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A card per team, staggered in, with the sign of the delta driving colour.
class _TeamGrid extends StatelessWidget {
  const _TeamGrid();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(70, 220, 70, 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SceneLabel('By team'),
          const SizedBox(height: 50),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 0.92,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (int i = 0; i < report.teams.length; i++)
                  _TeamCard(
                    team: report.teams[i],
                    enter: spring(frame - 8 - i * 4,
                        fps: fps, stiffness: 130, damping: 15),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.enter});

  final Team team;
  final double enter;

  @override
  Widget build(BuildContext context) {
    final bool up = team.delta >= 0;
    final double settled = enter.clamp(0.0, 1.0);

    return Opacity(
      opacity: settled,
      child: Transform.scale(
        // Overshoot lives here, where it reads as the card landing.
        scale: 0.9 + enter * 0.1,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF141821),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1F2531)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (up ? _accent : _warn).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  team.owner,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: up ? _accent : _warn,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(team.name,
                      style: const TextStyle(fontSize: 28, color: _dim)),
                  const SizedBox(height: 6),
                  Text(
                    '${up ? '+' : ''}${team.delta.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: up ? _accent : _warn,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two clips on screen at the same time.
///
/// The point of this scene: two decoders open at once, both streaming, both
/// landing on the same composition frame. Nothing before this ever asked for
/// more than one at a time.
class _SplitScreen extends StatelessWidget {
  const _SplitScreen();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double split = interpolate(frame, <num>[0, 30], <num>[0, 1],
        easing: Curves.easeInOutCubic);

    return Column(
      children: <Widget>[
        Expanded(
          child: Transform.translate(
            offset: Offset((1 - split) * -1080, 0),
            child: const VideoClip(
              src: 'assets/clip.mp4',
              fit: BoxFit.cover,
              loop: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Transform.translate(
            offset: Offset((1 - split) * 1080, 0),
            child: const VideoClip(
              src: 'assets/demo_clip.mp4',
              fit: BoxFit.cover,
              loop: true,
              // Enters the source part way in, so this is also a trim landing
              // on an exact frame while another decoder is running -- and a
              // loop that wraps to the trim point rather than to zero.
              trimStartInFrames: 45,
            ),
          ),
        ),
      ],
    );
  }
}

class _BigNumbers extends StatelessWidget {
  const _BigNumbers();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);

    // Counters that count. Each is a pure function of the frame, so scrubbing
    // backwards through them lands on exactly the same number.
    double countTo(num target, int start) => interpolate(
          frame,
          <num>[start, start + 45],
          <num>[0, target],
          easing: Curves.easeOutExpo,
        );

    return Padding(
      padding: const EdgeInsets.all(80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Stat(
            value: countTo(report.releases, 6).round().toString(),
            label: 'releases',
          ),
          const SizedBox(height: 60),
          _Stat(
            value: countTo(report.uptime, 20).toStringAsFixed(2),
            label: 'percent uptime',
            colour: _accent,
          ),
          const SizedBox(height: 60),
          _Stat(
            value: countTo(report.incidents, 34).round().toString(),
            label: 'incidents',
            colour: _warn,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.colour = _paper});

  final String value;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            fontSize: 150,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -6,
            color: colour,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 38, color: _dim)),
      ],
    );
  }
}

/// A line drawn with CustomPaint, revealed left to right.
class _RevertsLine extends StatelessWidget {
  const _RevertsLine();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double reveal = interpolate(frame, <num>[8, 90], <num>[0, 1],
        easing: Curves.easeInOutCubic);

    return Padding(
      padding: const EdgeInsets.fromLTRB(70, 150, 70, 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SceneLabel('Reverts, week by week'),
          const SizedBox(height: 50),
          Expanded(
            child: CustomPaint(
              painter: _LinePainter(weeks: report.weeks, reveal: reveal),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 14),
          // One equal-width slot per week, which is exactly how the painter
          // above places its points.
          Row(
            children: <Widget>[
              for (final Week week in report.weeks)
                Expanded(
                  child: Text(
                    week.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, color: _dim),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.weeks, required this.reveal});

  final List<Week> weeks;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.length < 2) return;
    final int maxReverted = weeks
        .map((Week w) => w.reverted)
        .reduce((int a, int b) => a > b ? a : b)
        .clamp(1, 1 << 30);

    // Points sit at the centre of a slot per week, not at the edges of the
    // box. Two reasons: a point at x = 0 has half its dot painted outside the
    // canvas, and slot centres are where a Row of equal-width labels puts its
    // text, so the axis underneath lines up without being told anything.
    const double dot = 9;
    final double slot = size.width / weeks.length;
    final double top = dot;
    final double usable = size.height - dot * 2;

    double xFor(int i) => slot * (i + 0.5);
    double yFor(int i) =>
        top + usable * (1 - weeks[i].reverted / maxReverted);

    final Path path = Path();
    for (int i = 0; i < weeks.length; i++) {
      if (i == 0) {
        path.moveTo(xFor(i), yFor(i));
      } else {
        path.lineTo(xFor(i), yFor(i));
      }
    }

    // Reveal by clipping rather than by measuring the path: the geometry is
    // the same on every frame, which is what keeps it deterministic.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));
    canvas.drawPath(
      path,
      Paint()
        ..color = _warn
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    for (int i = 0; i < weeks.length; i++) {
      canvas.drawCircle(Offset(xFor(i), yFor(i)), dot, Paint()..color = _warn);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.reveal != reveal || old.weeks != weeks;
}

class _Outro extends StatelessWidget {
  const _Outro();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);
    final double rise = spring(frame - 4, fps: fps, stiffness: 100, damping: 14);
    final double badge = interpolate(frame, <num>[18, 44], <num>[0, 1],
        easing: Curves.easeOutCubic);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Transform.translate(
            offset: Offset(0, (1 - rise) * 40),
            child: Text(
              report.period,
              style: const TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.w800,
                letterSpacing: -3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: badge,
            child: const Text(
              'rendered from a JSON file',
              style: TextStyle(fontSize: 36, color: _dim),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneLabel extends StatelessWidget {
  const _SceneLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 30,
          color: _dim,
          letterSpacing: 3,
          fontWeight: FontWeight.w700,
        ),
      );
}
