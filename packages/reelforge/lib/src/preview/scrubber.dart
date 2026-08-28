import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The timeline. Click or drag anywhere on it to seek.
///
/// Seeking is frame-quantised, not time-quantised: the playhead can only ever
/// land on a frame that will actually be rendered, so what you scrub to is
/// what the exporter produces.
class Scrubber extends StatefulWidget {
  const Scrubber({
    super.key,
    required this.frame,
    required this.durationInFrames,
    required this.fps,
    required this.onSeek,
    this.onScrubStart,
    this.onScrubEnd,
  });

  final int frame;
  final int durationInFrames;
  final int fps;
  final ValueChanged<int> onSeek;
  final VoidCallback? onScrubStart;
  final VoidCallback? onScrubEnd;

  @override
  State<Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<Scrubber> {
  bool _dragging = false;
  double? _hoverX;

  int _frameForX(double x, double width) {
    if (width <= 0) return 0;
    final double t = (x / width).clamp(0.0, 1.0);
    return (t * (widget.durationInFrames - 1)).round();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (PointerHoverEvent event) =>
              setState(() => _hoverX = event.localPosition.dx),
          onExit: (_) => setState(() => _hoverX = null),
          // A raw Listener rather than GestureDetector: a horizontal drag
          // recogniser does not fire onStart until the touch slop is
          // exceeded, so press-and-hold on the timeline would leave playback
          // running. This also makes the seek land on press rather than after
          // a slop threshold.
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (PointerDownEvent event) {
              setState(() => _dragging = true);
              widget.onScrubStart?.call();
              widget.onSeek(_frameForX(event.localPosition.dx, width));
            },
            onPointerMove: (PointerMoveEvent event) {
              if (!_dragging) return;
              widget.onSeek(_frameForX(event.localPosition.dx, width));
            },
            onPointerUp: (PointerUpEvent event) {
              if (!_dragging) return;
              setState(() => _dragging = false);
              widget.onScrubEnd?.call();
            },
            onPointerCancel: (PointerCancelEvent event) {
              if (!_dragging) return;
              setState(() => _dragging = false);
              widget.onScrubEnd?.call();
            },
            child: CustomPaint(
              // An explicit size: a CustomPaint with no size and no child
              // collapses to zero width inside a Column, which makes the
              // track invisible *and* unhittable.
              size: Size(width, 34),
              painter: _ScrubberPainter(
                frame: widget.frame,
                durationInFrames: widget.durationInFrames,
                fps: widget.fps,
                hoverX: _dragging ? null : _hoverX,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  _ScrubberPainter({
    required this.frame,
    required this.durationInFrames,
    required this.fps,
    required this.hoverX,
  });

  final int frame;
  final int durationInFrames;
  final int fps;
  final double? hoverX;

  @override
  void paint(Canvas canvas, Size size) {
    const double trackHeight = 6;
    final double trackTop = (size.height - trackHeight) / 2;
    final RRect track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackTop, size.width, trackHeight),
      const Radius.circular(3),
    );

    canvas.drawRRect(track, Paint()..color = PreviewColors.chromeRaised);

    // Second markers, so the timeline reads as time and not just a bar.
    final int seconds = (durationInFrames / fps).floor();
    if (seconds > 0 && size.width / seconds > 6) {
      final Paint tick = Paint()..color = PreviewColors.border;
      for (int s = 1; s <= seconds; s++) {
        final double x = size.width * (s * fps) / (durationInFrames - 1);
        if (x >= size.width) break;
        canvas.drawRect(Rect.fromLTWH(x, trackTop - 4, 1, trackHeight + 8), tick);
      }
    }

    final double progress =
        durationInFrames <= 1 ? 0 : frame / (durationInFrames - 1);
    final double playheadX = size.width * progress;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trackTop, playheadX, trackHeight),
        const Radius.circular(3),
      ),
      Paint()..color = PreviewColors.accent,
    );

    if (hoverX != null) {
      canvas.drawRect(
        Rect.fromLTWH(hoverX!, trackTop - 6, 1, trackHeight + 12),
        Paint()..color = PreviewColors.textDim,
      );
    }

    canvas.drawCircle(
      Offset(playheadX, size.height / 2),
      7,
      Paint()..color = PreviewColors.accent,
    );
    canvas.drawCircle(
      Offset(playheadX, size.height / 2),
      3,
      Paint()..color = PreviewColors.background,
    );
  }

  @override
  bool shouldRepaint(_ScrubberPainter old) =>
      old.frame != frame ||
      old.durationInFrames != durationInFrames ||
      old.hoverX != hoverX;
}
